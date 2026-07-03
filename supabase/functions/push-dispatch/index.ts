// Supabase Edge Function: push-dispatch
//
// Sends device pushes DIRECTLY to Apple's APNs — no Firebase, no FCM.
// Wire it to a Database Webhook on `insert into public.notifications`
// (Dashboard → Database → Webhooks) with a custom header:
//   x-webhook-secret: <PUSH_WEBHOOK_SECRET>
//
// Secrets:
//   supabase secrets set \
//     APNS_AUTH_KEY="$(cat AuthKey_XXXXXXXXXX.p8)" \
//     APNS_KEY_ID=XXXXXXXXXX \
//     APNS_TEAM_ID=YYYYYYYYYY \
//     APNS_BUNDLE_ID=com.adaptable.app \
//     PUSH_WEBHOOK_SECRET=<random string>
//
// Deploy with: supabase functions deploy push-dispatch --no-verify-jwt
// (the webhook secret is the auth; there is no user JWT on webhooks).
//
// Android note: Google only allows background push through FCM. This
// project deliberately avoids Firebase, so Android relies on the
// Supabase Realtime in-app inbox instead.

import { createClient } from "jsr:@supabase/supabase-js@2";

const APNS_HOST = Deno.env.get("APNS_SANDBOX") === "true"
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";

interface NotificationRow {
  id: string;
  user_id: string;
  actor_id: string | null;
  recipe_id: string | null;
  type: "vote" | "comment" | "cook";
}

const VERBS: Record<NotificationRow["type"], string> = {
  vote: "upvoted",
  comment: "commented on",
  cook: "just cooked",
};

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("PUSH_WEBHOOK_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }

  try {
    const payload = await req.json();
    const row = payload?.record as NotificationRow | undefined;
    if (!row?.user_id) return json({ skipped: "no record" });

    // Service-role client: this function runs server-side only.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const [{ data: tokens }, { data: actor }, { data: recipe }] =
      await Promise.all([
        admin
          .from("device_tokens")
          .select("token, platform")
          .eq("user_id", row.user_id)
          .eq("platform", "ios"),
        row.actor_id
          ? admin.from("profiles").select("username").eq("id", row.actor_id).maybeSingle()
          : Promise.resolve({ data: null }),
        row.recipe_id
          ? admin.from("recipes").select("title, emoji").eq("id", row.recipe_id).maybeSingle()
          : Promise.resolve({ data: null }),
      ]);

    if (!tokens || tokens.length === 0) return json({ skipped: "no ios tokens" });

    const who = actor?.username ?? "Someone";
    const what = recipe ? `${recipe.emoji} ${recipe.title}` : "your recipe";
    const alert = {
      title: "Adaptable",
      body: `${who} ${VERBS[row.type]} ${what}`,
    };

    const jwt = await apnsJwt();
    const results = await Promise.all(
      tokens.map(async ({ token }) => {
        const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          body: JSON.stringify({
            aps: { alert, sound: "default", badge: 1 },
            recipe_id: row.recipe_id,
          }),
        });
        // 410 Unregistered → the device removed the app; drop the token.
        if (res.status === 410) {
          await admin.from("device_tokens").delete().eq("token", token);
        }
        return res.status;
      }),
    );

    return json({ sent: results });
  } catch (err) {
    console.error("push-dispatch error", err);
    return json({ error: "dispatch failed" }, 500);
  }
});

/** ES256-signed provider token for APNs, built with WebCrypto only. */
async function apnsJwt(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_AUTH_KEY")!;

  const pkcs8 = pemToArrayBuffer(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = b64url(
    JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }),
  );
  const signingInput = `${header}.${claims}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${b64urlBytes(new Uint8Array(signature))}`;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

function b64url(s: string): string {
  return b64urlBytes(new TextEncoder().encode(s));
}

function b64urlBytes(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
