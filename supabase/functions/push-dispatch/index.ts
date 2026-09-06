import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { hasServiceRole, hasSharedSecret } from "../_shared/adminAuth.ts";
import { isNotificationsWebhook, pushCopy } from "../_shared/pushCopy.ts";

/**
 * Dispatch Apple Push Notifications.
 *
 * Two call shapes:
 *  1. Supabase Database Webhook on `notifications` INSERT:
 *     { type, table, record: { user_id, actor_id, recipe_id, type } }
 *     Looks up `device_tokens` for record.user_id and sends derived copy.
 *  2. Direct (legacy / ops): { deviceToken, title, body, isSandbox?, customData? }
 *
 * Auth: `x-webhook-secret` (PUSH_WEBHOOK_SECRET) or service-role Bearer.
 * On APNs 410, prune the `device_tokens` row — not `profiles.push_token`.
 *
 * Secrets: APNS_PRIVATE_KEY or APNS_AUTH_KEY, APNS_KEY_ID, APNS_TEAM_ID,
 * APNS_BUNDLE_ID, PUSH_WEBHOOK_SECRET.
 */

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

serve(async (req) => {
  try {
    const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!hasSharedSecret(req, webhookSecret) && !hasServiceRole(req, serviceKey)) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return new Response("Missing required fields", { status: 400 });
    }

    if (isNotificationsWebhook(body)) {
      return await dispatchWebhook(body.record);
    }

    const deviceToken = typeof body.deviceToken === "string" ? body.deviceToken.trim() : "";
    const title = typeof body.title === "string" ? body.title : "";
    const alertBody = typeof body.body === "string" ? body.body : "";
    if (!deviceToken || !title || !alertBody) {
      return new Response("Missing required fields", { status: 400 });
    }

    const result = await sendApns({
      deviceToken,
      title,
      body: alertBody,
      isSandbox: body.isSandbox === true,
      customData: body.customData && typeof body.customData === "object"
        ? body.customData
        : {},
    });
    return json(result.body, result.status);
  } catch (error) {
    console.error("Edge Function Error:", error);
    return new Response("Internal Server Error", { status: 500 });
  }
});

async function dispatchWebhook(record: {
  user_id?: string;
  actor_id?: string | null;
  recipe_id?: string | null;
  type?: string;
}): Promise<Response> {
  const userId = record.user_id;
  if (!userId) return json({ error: "Missing user_id" }, 400);

  const { data: tokens, error: tokenError } = await supabaseAdmin
    .from("device_tokens")
    .select("token, platform, is_sandbox")
    .eq("user_id", userId);

  if (tokenError) {
    console.error("device_tokens lookup failed", tokenError);
    return json({ error: "Could not look up device tokens" }, 500);
  }

  const iosTokens = (tokens ?? [])
    .filter((row: { platform?: string }) => {
      const platform = String(row.platform ?? "ios").toLowerCase();
      return platform === "ios" || platform === "unknown";
    })
    .map((row: { token?: string; is_sandbox?: boolean }) => ({
      token: String(row.token ?? "").trim(),
      isSandbox: row.is_sandbox === true,
    }))
    .filter((row: { token: string }) => row.token);

  if (iosTokens.length === 0) {
    return json({ success: true, sent: 0 }, 200);
  }

  let actorName: string | null = null;
  let recipeTitle: string | null = null;
  if (record.actor_id) {
    const { data } = await supabaseAdmin
      .from("profiles")
      .select("username")
      .eq("id", record.actor_id)
      .maybeSingle();
    actorName = typeof data?.username === "string" ? data.username : null;
  }
  if (record.recipe_id) {
    const { data } = await supabaseAdmin
      .from("recipes")
      .select("title")
      .eq("id", record.recipe_id)
      .maybeSingle();
    recipeTitle = typeof data?.title === "string" ? data.title : null;
  }

  const copy = pushCopy({
    type: record.type,
    actorName,
    recipeTitle,
  });
  const customData = {
    recipe_id: record.recipe_id ?? undefined,
    type: record.type ?? undefined,
  };

  let sent = 0;
  let lastStatus = 200;
  let lastError: string | undefined;
  for (const { token: deviceToken, isSandbox } of iosTokens) {
    const result = await sendApns({
      deviceToken,
      title: copy.title,
      body: copy.body,
      isSandbox,
      customData,
    });
    if (result.status === 200) sent += 1;
    else {
      lastStatus = result.status;
      lastError = (result.body as { error?: string }).error;
    }
  }

  if (sent === 0 && lastStatus !== 200) {
    return json({ success: false, sent: 0, error: lastError }, lastStatus);
  }
  return json({ success: true, sent }, 200);
}

async function sendApns(opts: {
  deviceToken: string;
  title: string;
  body: string;
  isSandbox: boolean;
  customData: Record<string, unknown>;
  retriedOpposite?: boolean;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const privateKey =
    Deno.env.get("APNS_PRIVATE_KEY") || Deno.env.get("APNS_AUTH_KEY") || "";
  const keyId = Deno.env.get("APNS_KEY_ID") || "";
  const teamId = Deno.env.get("APNS_TEAM_ID") || "";
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") || "com.adaptable.app";
  if (!privateKey || !keyId || !teamId) {
    return {
      status: 500,
      body: { success: false, error: "APNs is not configured." },
    };
  }

  const jwt = await create(
    { alg: "ES256", kid: keyId },
    { iss: teamId, iat: getNumericDate(0) },
    privateKey,
  );

  const payload = {
    aps: {
      alert: { title: opts.title, body: opts.body },
      sound: "default",
    },
    ...opts.customData,
  };

  const host = opts.isSandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  const url = `https://${host}/3/device/${opts.deviceToken}`;

  const apnsResponse = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (apnsResponse.status === 200) {
    return { status: 200, body: { success: true } };
  }

  // Wrong APNs environment (sandbox vs production) often comes back 400.
  if (apnsResponse.status === 400 && !opts.retriedOpposite) {
    return await sendApns({
      ...opts,
      isSandbox: !opts.isSandbox,
      retriedOpposite: true,
    });
  }

  if (apnsResponse.status === 410) {
    console.log(`Token ${opts.deviceToken} is invalid (410). Removing...`);
    await supabaseAdmin
      .from("device_tokens")
      .delete()
      .eq("token", opts.deviceToken);
    return {
      status: 410,
      body: { success: false, error: "Device token expired" },
    };
  }

  const errorText = await apnsResponse.text();
  console.error("APNs Error:", errorText);
  return {
    status: apnsResponse.status,
    body: { success: false, error: errorText },
  };
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
