// Supabase Edge Function: import-recipe
//
// Turns any recipe source into structured Adaptable data via Gemini:
//   { url }                        — recipe blog / YouTube / social link
//   { image_base64, mime_type }    — photo of a cookbook page or card
//   { text }                       — pasted caption or free text
//
// The page/photo/text is parsed by Gemini against the same strict JSON
// schema used for generation, inserted under the caller's identity
// (RLS enforced), and returned. Import is free and unlimited by design.

import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.0-flash";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const recipeSchema = {
  type: "OBJECT",
  properties: {
    title: { type: "STRING" },
    description: { type: "STRING" },
    emoji: { type: "STRING", description: "Single emoji that best represents the dish" },
    cuisine: { type: "STRING" },
    difficulty: { type: "STRING", enum: ["Easy", "Medium", "Hard"] },
    prep_time_minutes: { type: "INTEGER" },
    cook_time_minutes: { type: "INTEGER" },
    servings: { type: "INTEGER" },
    calories: { type: "INTEGER", description: "Estimated calories per serving" },
    protein_g: { type: "INTEGER", description: "Protein grams per serving" },
    carbs_g: { type: "INTEGER", description: "Carbohydrate grams per serving" },
    fat_g: { type: "INTEGER", description: "Fat grams per serving" },
    tags: { type: "ARRAY", items: { type: "STRING" } },
    ingredients: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          item: { type: "STRING" },
          quantity: { type: "STRING" },
          note: { type: "STRING" },
        },
        required: ["item", "quantity"],
      },
    },
    steps: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          step: { type: "INTEGER" },
          instruction: { type: "STRING" },
          tip: { type: "STRING" },
        },
        required: ["step", "instruction"],
      },
    },
  },
  required: [
    "title", "description", "emoji", "cuisine", "difficulty",
    "prep_time_minutes", "cook_time_minutes", "servings", "tags",
    "ingredients", "steps",
  ],
};

const IMPORT_INSTRUCTIONS =
  "Extract the single main recipe from the provided source, faithfully — " +
  "keep the author's quantities, steps and intent. Fill in reasonable " +
  "estimates only for missing metadata (times, servings, nutrition). " +
  "Write the description in an appetizing but honest tone. 3-5 short tags " +
  '(include "Low-cal" if 500 calories/serving or fewer). ' +
  "If the source contains no recipe at all, return a recipe titled exactly " +
  '"NO_RECIPE_FOUND".';

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const url: string | undefined = typeof body.url === "string" ? body.url.trim() : undefined;
    const text: string | undefined = typeof body.text === "string" ? body.text.trim() : undefined;
    const imageBase64: string | undefined =
      typeof body.image_base64 === "string" ? body.image_base64 : undefined;
    const mimeType: string =
      typeof body.mime_type === "string" ? body.mime_type : "image/jpeg";

    if (!url && !text && !imageBase64) {
      return json({ error: "Provide a url, text, or image to import." }, 400);
    }
    if (imageBase64 && imageBase64.length > 6_000_000) {
      return json({ error: "Image too large — keep it under ~4 MB." }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in to import recipes." }, 401);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      return json({ error: "GEMINI_API_KEY is not configured." }, 500);
    }

    // Build the Gemini parts from whichever source we were given.
    const parts: unknown[] = [];
    let sourceUrl: string | null = null;

    if (imageBase64) {
      parts.push({ inline_data: { mime_type: mimeType, data: imageBase64 } });
      parts.push({ text: IMPORT_INSTRUCTIONS });
    } else if (url) {
      let parsed: URL;
      try {
        parsed = new URL(url);
        if (!["http:", "https:"].includes(parsed.protocol)) throw new Error();
      } catch {
        return json({ error: "That doesn't look like a valid link." }, 400);
      }
      sourceUrl = parsed.toString();

      let pageText = "";
      try {
        const res = await fetch(sourceUrl, {
          headers: {
            "User-Agent":
              "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            Accept: "text/html,application/xhtml+xml",
          },
          signal: AbortSignal.timeout(12_000),
        });
        if (!res.ok) throw new Error(`status ${res.status}`);
        const html = await res.text();
        // Prefer JSON-LD Recipe blocks (most food blogs ship them),
        // fall back to stripped page text.
        const ldBlocks = [...html.matchAll(
          /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
        )].map((m) => m[1]).join("\n");
        const stripped = html
          .replace(/<script[\s\S]*?<\/script>/gi, " ")
          .replace(/<style[\s\S]*?<\/style>/gi, " ")
          .replace(/<[^>]+>/g, " ")
          .replace(/\s+/g, " ");
        pageText = (ldBlocks + "\n" + stripped).slice(0, 40_000);
      } catch {
        return json(
          {
            error:
              "Couldn't read that page (some sites block robots). Try pasting the recipe text or a screenshot instead.",
          },
          422,
        );
      }
      parts.push({
        text: `${IMPORT_INSTRUCTIONS}\n\nSource URL: ${sourceUrl}\n\nPAGE CONTENT:\n${pageText}`,
      });
    } else {
      parts.push({
        text: `${IMPORT_INSTRUCTIONS}\n\nPASTED TEXT:\n${text!.slice(0, 20_000)}`,
      });
    }

    const geminiRes = await callGeminiWithRetry(geminiKey, {
      contents: [{ role: "user", parts }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
        temperature: 0.2, // faithful extraction, not creativity
      },
    });

    if (!geminiRes.ok) {
      const detail = await geminiRes.text();
      console.error("Gemini error", geminiRes.status, detail);
      if (geminiRes.status === 400 || geminiRes.status === 404) {
        return json(
          { error: "Couldn't read that source — try pasting the text instead." },
          502,
        );
      }
      if (geminiRes.status === 429 || geminiRes.status === 402) {
        return json(
          { error: "Too many requests — please wait a moment and try again." },
          502,
        );
      }
      return json({ error: "The import engine is unavailable. Try again." }, 502);
    }

    const geminiJson = await geminiRes.json();
    const raw = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!raw) return json({ error: "Nothing could be extracted." }, 502);

    const recipe = JSON.parse(raw);
    if (recipe.title === "NO_RECIPE_FOUND") {
      return json({ error: "No recipe found in that source." }, 422);
    }

    const { data: row, error: insertError } = await supabase
      .from("recipes")
      .insert({
        author_id: user.id,
        title: String(recipe.title).slice(0, 140),
        description: recipe.description ?? "",
        emoji: recipe.emoji ?? "🍽️",
        cuisine: recipe.cuisine ?? "Fusion",
        difficulty: ["Easy", "Medium", "Hard"].includes(recipe.difficulty)
          ? recipe.difficulty
          : "Easy",
        prep_time_minutes: recipe.prep_time_minutes ?? 0,
        cook_time_minutes: recipe.cook_time_minutes ?? 0,
        servings: recipe.servings ?? 2,
        calories: recipe.calories ?? null,
        protein_g: recipe.protein_g ?? null,
        carbs_g: recipe.carbs_g ?? null,
        fat_g: recipe.fat_g ?? null,
        tags: Array.isArray(recipe.tags) ? recipe.tags.slice(0, 6) : [],
        ingredients: recipe.ingredients ?? [],
        steps: recipe.steps ?? [],
        source_prompt: "",
        source_url: sourceUrl,
      })
      .select("*, author:profiles!recipes_author_id_fkey(id, username, avatar_url)")
      .single();

    if (insertError) {
      console.error("Insert error", insertError);
      return json({ error: "Could not save the imported recipe." }, 500);
    }

    return json({ recipe: row }, 200);
  } catch (err) {
    console.error("Unhandled error", err);
    return json({ error: "Unexpected error importing recipe." }, 500);
  }
});

/**
 * Calls Gemini, retrying once after a short backoff on a 5xx response —
 * those are transient on Google's end, unlike 4xx (bad request/model)
 * which will just fail the same way again.
 */
async function callGeminiWithRetry(
  geminiKey: string,
  payload: unknown,
): Promise<Response> {
  const call = () =>
    fetch(`${GEMINI_URL}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  const first = await call();
  if (first.ok || first.status < 500) return first;
  console.error("Gemini 5xx, retrying once", first.status);
  await new Promise((resolve) => setTimeout(resolve, 500));
  return call();
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
