// Supabase Edge Function: report-plus-entitlement
//
// Authenticated iOS clients send a StoreKit 2 JWS (or transaction id).
// Plus is granted only after App Store Server API verification.
// A client `isPlus` / `is_plus` boolean is ignored.
//
// Secrets (Ken — App Store Connect → Users and Access → Integrations
// → In-App Purchase):
//   supabase secrets set APPLE_IAP_ISSUER_ID=...
//   supabase secrets set APPLE_IAP_KEY_ID=...
//   supabase secrets set APPLE_IAP_PRIVATE_KEY="$(cat SubscriptionKey_XXXX.p8)"
//   supabase secrets set APPLE_BUNDLE_ID=com.adaptable.app
//
// Interim without those keys: do not invent credentials. Grant Plus for
// App Review via SQL as service_role / dashboard:
//   insert into public.plus_entitlements (user_id, is_plus, product_id, environment)
//   values ('<user-uuid>', true, 'manual-review', 'Manual')
//   on conflict (user_id) do update
//     set is_plus = excluded.is_plus, product_id = excluded.product_id,
//         environment = excluded.environment, updated_at = now();

import { createClient } from "jsr:@supabase/supabase-js@2";
import { verifyPlusTransaction } from "../_shared/appleStoreKit.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "You must be signed in." }, 401);
    }

    const caller = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await caller.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in." }, 401);
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "Invalid request body." }, 400);
    }

    const signedTransactionInfo =
      typeof body.signedTransactionInfo === "string"
        ? body.signedTransactionInfo
        : typeof body.signed_transaction_info === "string"
        ? body.signed_transaction_info
        : undefined;
    const transactionId =
      typeof body.transactionId === "string"
        ? body.transactionId
        : typeof body.originalTransactionId === "string"
        ? body.originalTransactionId
        : undefined;

    const verified = await verifyPlusTransaction({
      signedTransactionInfo,
      transactionId,
    });
    if (!verified.ok) {
      return json(
        { error: verified.error, code: verified.code ?? undefined },
        verified.status,
      );
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error: upsertError } = await admin.from("plus_entitlements").upsert({
      user_id: user.id,
      is_plus: verified.transaction.entitled,
      product_id: verified.transaction.productId,
      original_transaction_id: verified.transaction.originalTransactionId,
      expires_at: verified.transaction.expiresAt,
      environment: verified.transaction.environment,
      updated_at: new Date().toISOString(),
    });
    if (upsertError) {
      console.error("plus_entitlements upsert failed", upsertError);
      return json({ error: "Could not save Plus status. Try again." }, 500);
    }

    return json(
      {
        is_plus: verified.transaction.entitled,
        expires_at: verified.transaction.expiresAt,
        product_id: verified.transaction.productId,
      },
      200,
    );
  } catch (err) {
    console.error("report-plus-entitlement error", err);
    return json({ error: "Unexpected error." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
