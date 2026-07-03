// Supabase Edge Function: delete-account
//
// Permanently deletes the calling user's account. The caller is
// identified strictly from their JWT; the service-role client is used
// only for the final auth.admin delete. Every app table references
// profiles with ON DELETE CASCADE, so recipes, votes, saves, comments,
// cooks, shopping items, notifications and device tokens all go too.
//
// Required for App Store review (account deletion must be in-app).

import { createClient } from "jsr:@supabase/supabase-js@2";

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
    const caller = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    const { data: { user }, error: authError } = await caller.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in." }, 401);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) {
      console.error("delete-account failed", user.id, error);
      return json({ error: "Could not delete the account. Try again." }, 500);
    }

    return json({ success: true }, 200);
  } catch (err) {
    console.error("delete-account error", err);
    return json({ error: "Unexpected error." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
