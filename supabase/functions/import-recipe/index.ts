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

/** Gemini 2.0 Flash family shut down 2026-06-01 — use 2.5+. */
const GEMINI_MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
];

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
  "Include every ingredient and step you can extract. " +
  "If the source contains no recipe at all, return a recipe titled exactly " +
  '"NO_RECIPE_FOUND".';

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "Invalid request body." }, 400);
    }
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

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "You must be signed in to import recipes." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in to import recipes." }, 401);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      console.error("GEMINI_API_KEY is not configured");
      return json({ error: "The import engine is not configured. Contact support." }, 500);
    }

    const parts: unknown[] = [];
    let sourceUrl: string | null = null;

    if (imageBase64) {
      // Strip data-URL prefix if a client sent one.
      const pure = imageBase64.replace(/^data:[^;]+;base64,/, "");
      parts.push({ inline_data: { mime_type: mimeType, data: pure } });
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

    const payload = {
      contents: [{ role: "user", parts }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
        temperature: 0.2,
      },
    };

    const gemini = await callGeminiWithModelFallback(geminiKey, payload);
    if (!gemini.ok) {
      return geminiErrorResponse(gemini.status, gemini.detail);
    }

    const recipe = parseRecipeJson(gemini.text);
    if (!recipe) {
      return json({ error: "Nothing could be extracted." }, 502);
    }
    if (recipe.title === "NO_RECIPE_FOUND") {
      return json({ error: "No recipe found in that source." }, 422);
    }
    if (!isValidRecipe(recipe)) {
      return json(
        { error: "Couldn't extract a complete recipe — try a clearer photo or paste the text." },
        422,
      );
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
        prep_time_minutes: clampInt(recipe.prep_time_minutes, 0, 24 * 60, 0),
        cook_time_minutes: clampInt(recipe.cook_time_minutes, 0, 24 * 60, 0),
        servings: clampInt(recipe.servings, 1, 24, 2),
        calories: nullableInt(recipe.calories),
        protein_g: nullableInt(recipe.protein_g),
        carbs_g: nullableInt(recipe.carbs_g),
        fat_g: nullableInt(recipe.fat_g),
        tags: Array.isArray(recipe.tags) ? recipe.tags.map(String).slice(0, 6) : [],
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

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function geminiErrorResponse(status: number, detail: string): Response {
  console.error("Gemini import error", status, detail.slice(0, 500));
  const lower = detail.toLowerCase();
  if (
    status === 401 ||
    status === 403 ||
    lower.includes("api key not valid") ||
    lower.includes("api_key_invalid") ||
    lower.includes("permission_denied")
  ) {
    return json(
      {
        error:
          "Import engine authentication failed — GEMINI_API_KEY needs to be updated.",
      },
      500,
    );
  }
  if (status === 429 || status === 402) {
    return json(
      { error: "Too many requests — please wait a moment and try again." },
      502,
    );
  }
  if (status === 400 || status === 404) {
    return json(
      { error: "Couldn't read that source — try pasting the text instead." },
      502,
    );
  }
  return json({ error: "The import engine is unavailable. Try again." }, 502);
}

async function callGeminiWithModelFallback(
  geminiKey: string,
  payload: unknown,
): Promise<{ ok: true; text: string } | { ok: false; status: number; detail: string }> {
  let lastStatus = 502;
  let lastDetail = "";

  for (const model of GEMINI_MODELS) {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`;
    const result = await callGeminiWithRetry(url, payload);
    if (result.ok) return result;
    lastStatus = result.status;
    lastDetail = result.detail;
    if (result.status !== 404) break;
    console.error(`Gemini model unavailable, trying next: ${model}`);
  }

  return { ok: false, status: lastStatus, detail: lastDetail };
}

async function callGeminiWithRetry(
  url: string,
  payload: unknown,
): Promise<{ ok: true; text: string } | { ok: false; status: number; detail: string }> {
  const call = () =>
    fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

  let res = await call();
  if (!res.ok && res.status >= 500) {
    console.error("Gemini 5xx, retrying once", res.status);
    await sleep(600);
    res = await call();
  }
  if (!res.ok && res.status === 429) {
    await sleep(1200);
    res = await call();
  }

  if (!res.ok) {
    return { ok: false, status: res.status, detail: await res.text() };
  }

  const geminiJson = await res.json();
  const finishReason = geminiJson?.candidates?.[0]?.finishReason;
  if (finishReason === "SAFETY" || finishReason === "BLOCKED") {
    return { ok: false, status: 400, detail: `blocked: ${finishReason}` };
  }

  const text = extractCandidateText(geminiJson);
  if (!text) {
    return {
      ok: false,
      status: 502,
      detail: JSON.stringify(geminiJson).slice(0, 400),
    };
  }
  return { ok: true, text };
}

function extractCandidateText(geminiJson: unknown): string | null {
  // deno-lint-ignore no-explicit-any
  const j = geminiJson as any;
  const part = j?.candidates?.[0]?.content?.parts?.[0];
  if (typeof part?.text === "string" && part.text.trim()) return part.text;
  return null;
}

// deno-lint-ignore no-explicit-any
function parseRecipeJson(raw: string): any | null {
  let text = raw.trim();
  const fence = text.match(/^```(?:json)?\s*([\s\S]*?)```$/i);
  if (fence) text = fence[1].trim();
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(text.slice(start, end + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

// deno-lint-ignore no-explicit-any
function isValidRecipe(recipe: any): boolean {
  if (!recipe || typeof recipe !== "object") return false;
  if (!recipe.title || typeof recipe.title !== "string") return false;
  if (!Array.isArray(recipe.ingredients) || recipe.ingredients.length < 1) return false;
  if (!Array.isArray(recipe.steps) || recipe.steps.length < 1) return false;
  return true;
}

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function nullableInt(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.round(n);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
