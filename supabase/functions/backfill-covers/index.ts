/**
 * One-shot / periodic: generate dish photos for recipes missing image_url.
 * Requires SUPABASE_SERVICE_ROLE_KEY + GEMINI_API_KEY secrets.
 *
 * Auth: service-role Bearer OR x-backfill-secret / Bearer matching BACKFILL_SECRET.
 * A signed-in user JWT is not enough.
 * Body: { limit?: number }.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { generateAndUploadCover } from "../_shared/coverImage.ts";
import { hasServiceRole, hasSharedSecret } from "../_shared/adminAuth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-backfill-secret",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    const url = Deno.env.get("SUPABASE_URL");
    const backfillSecret = Deno.env.get("BACKFILL_SECRET");
    if (!serviceKey || !geminiKey || !url) {
      return json({ error: "Missing service role or Gemini key." }, 500);
    }

    if (!hasServiceRole(req, serviceKey) && !hasSharedSecret(req, backfillSecret)) {
      return json({ error: "You must be an operator to backfill covers." }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Number(body.limit) || 5, 20);

    const admin = createClient(url, serviceKey);
    const { data: rows, error } = await admin
      .from("recipes")
      .select("id, author_id, title, description, cuisine, emoji, image_url")
      .is("image_url", null)
      .order("net_upvotes", { ascending: false })
      .limit(limit);

    if (error) return json({ error: error.message }, 500);

    const results: Array<{ id: string; ok: boolean; url?: string }> = [];
    for (const r of rows ?? []) {
      const imageUrl = await generateAndUploadCover({
        supabase: admin,
        geminiKey,
        userId: r.author_id,
        recipeId: r.id,
        title: r.title ?? "Dish",
        description: r.description,
        cuisine: r.cuisine,
        emoji: r.emoji,
      });
      if (imageUrl) {
        await admin.from("recipes").update({ image_url: imageUrl }).eq("id", r.id);
        results.push({ id: r.id, ok: true, url: imageUrl });
      } else {
        results.push({ id: r.id, ok: false });
      }
    }

    return json({ processed: results.length, results }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: "Backfill failed." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
