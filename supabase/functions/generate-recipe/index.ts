// Supabase Edge Function: generate-recipe
//
// Receives { prompt } from an authenticated client, calls the Gemini API
// with a strict JSON response schema, inserts the recipe as the calling
// user (RLS enforced via their JWT), and returns the new row.
//
// Secrets (never shipped to the client):
//   supabase secrets set GEMINI_API_KEY=...

import { createClient } from "jsr:@supabase/supabase-js@2";

/** Preferred model first; fall back if Google returns 404 (retired model id).
 *  Gemini 2.0 Flash family was shut down 2026-06-01 — use 2.5+. */
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
    title: { type: "STRING", description: "Catchy, appetizing recipe name" },
    description: {
      type: "STRING",
      description: "One or two enticing sentences about the dish",
    },
    emoji: {
      type: "STRING",
      description: "Single emoji that best represents the dish",
    },
    cuisine: { type: "STRING" },
    difficulty: { type: "STRING", enum: ["Easy", "Medium", "Hard"] },
    prep_time_minutes: { type: "INTEGER" },
    cook_time_minutes: { type: "INTEGER" },
    servings: { type: "INTEGER" },
    calories: {
      type: "INTEGER",
      description: "Estimated calories per serving",
    },
    protein_g: { type: "INTEGER", description: "Protein grams per serving" },
    carbs_g: { type: "INTEGER", description: "Carbohydrate grams per serving" },
    fat_g: { type: "INTEGER", description: "Fat grams per serving" },
    tags: {
      type: "ARRAY",
      items: { type: "STRING" },
      description: "3-5 short tags",
    },
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
          tip: {
            type: "STRING",
            description: "Optional pro tip for this step",
          },
        },
        required: ["step", "instruction"],
      },
    },
  },
  required: [
    "title",
    "description",
    "emoji",
    "cuisine",
    "difficulty",
    "prep_time_minutes",
    "cook_time_minutes",
    "servings",
    "tags",
    "ingredients",
    "steps",
  ],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "Invalid request body." }, 400);
    }
    const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
    const servings = body.servings;
    if (!prompt || prompt.length > 500) {
      return json(
        { error: "A prompt of up to 500 characters is required." },
        400,
      );
    }
    const requestedServings =
      Number.isInteger(servings) && servings >= 1 && servings <= 12
        ? (servings as number)
        : null;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "You must be signed in to generate recipes." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in to generate recipes." }, 401);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      console.error("GEMINI_API_KEY is not configured");
      return json(
        { error: "The recipe engine is not configured. Contact support." },
        500,
      );
    }

    const { data: profileRow } = await supabase
      .from("profiles")
      .select("preferences")
      .eq("id", user.id)
      .maybeSingle();
    const prefsText = preferencesToPrompt(profileRow?.preferences);

    const payload = {
      contents: [
        {
          role: "user",
          parts: [
            {
              text:
                `Create one complete, realistic, delicious recipe for this request: "${prompt}". ` +
                (requestedServings
                  ? `The recipe must serve exactly ${requestedServings} ${requestedServings === 1 ? "person" : "people"} — size every ingredient quantity for ${requestedServings} servings. `
                  : "") +
                prefsText +
                "Respect every dietary constraint, time limit and equipment restriction in the request. " +
                "Quantities must use both metric and imperial where sensible. " +
                "Steps must be specific enough for a beginner to follow. " +
                "Include at least 4 ingredients and at least 3 steps. " +
                "Estimate calories, protein, carbs and fat per serving. " +
                'If the dish is 500 calories per serving or fewer, include a "Low-cal" tag; ' +
                'if it has 30 g protein per serving or more, include a "High-protein" tag.',
            },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
        temperature: 0.9,
      },
    };

    const gemini = await callGeminiWithModelFallback(geminiKey, payload);
    if (!gemini.ok) {
      console.error(
        "Gemini call failed",
        gemini.status,
        (gemini.detail || "").slice(0, 800),
        "key_prefix",
        geminiKey.slice(0, 6),
        "key_len",
        geminiKey.length,
      );
      return geminiErrorResponse(gemini.status, gemini.detail);
    }

    const recipe = parseRecipeJson(gemini.text);
    if (!recipe) {
      console.error("Failed to parse Gemini recipe JSON", gemini.text?.slice(0, 400));
      return json(
        {
          error:
            "The recipe engine returned an incomplete response — please try again.",
        },
        502,
      );
    }

    if (!isValidRecipe(recipe)) {
      console.error("Gemini recipe failed validation", recipe);
      return json(
        {
          error:
            "Couldn't build a complete recipe from that prompt — try adding more detail.",
        },
        502,
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
        servings: requestedServings ?? clampInt(recipe.servings, 1, 24, 2),
        calories: nullableInt(recipe.calories),
        protein_g: nullableInt(recipe.protein_g),
        carbs_g: nullableInt(recipe.carbs_g),
        fat_g: nullableInt(recipe.fat_g),
        tags: Array.isArray(recipe.tags)
          ? recipe.tags.map(String).slice(0, 6)
          : [],
        ingredients: recipe.ingredients ?? [],
        steps: recipe.steps ?? [],
        source_prompt: prompt,
      })
      .select(
        "*, author:profiles!recipes_author_id_fkey(id, username, avatar_url)",
      )
      .single();

    if (insertError) {
      console.error("Insert error", insertError);
      if (
        insertError.message?.includes("auth") ||
        insertError.code === "PGRPT13"
      ) {
        return json(
          { error: "You must be signed in to generate recipes." },
          401,
        );
      }
      return json(
        {
          error:
            "Could not save the recipe — please try again. If the problem persists, contact support.",
        },
        500,
      );
    }

    return json({ recipe: row }, 200);
  } catch (err) {
    console.error("Unhandled error", err);
    return json(
      {
        error:
          "Something went wrong while generating — please try again in a moment.",
      },
      500,
    );
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function geminiErrorResponse(status: number, detail: string): Response {
  console.error("Gemini error", status, detail.slice(0, 500));
  const lower = detail.toLowerCase();
  // Google often returns HTTP 400 (not 401) for a bad/revoked API key.
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
          "Recipe engine authentication failed — GEMINI_API_KEY needs to be updated.",
      },
      500,
    );
  }
  if (status === 402 || status === 429) {
    return json(
      { error: "Too many requests — please wait a moment and try again." },
      502,
    );
  }
  if (status === 400 || status === 404) {
    return json(
      {
        error:
          "Couldn't generate that recipe — try rephrasing your request.",
      },
      502,
    );
  }
  return json(
    {
      error:
        "The recipe engine is temporarily unavailable — please try again in a moment.",
    },
    502,
  );
}

/**
 * Calls Gemini with one automatic retry on 5xx, and falls back across
 * model ids when a model returns 404 (retired/renamed).
 */
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
    // Only fall through to the next model on "model not found".
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
  // One more retry for rate limits with slightly longer backoff.
  if (!res.ok && res.status === 429) {
    console.error("Gemini 429, retrying once after backoff");
    await sleep(1200);
    res = await call();
  }

  if (!res.ok) {
    return { ok: false, status: res.status, detail: await res.text() };
  }

  const geminiJson = await res.json();
  const finishReason = geminiJson?.candidates?.[0]?.finishReason;
  if (finishReason === "SAFETY" || finishReason === "BLOCKED") {
    return {
      ok: false,
      status: 400,
      detail: `blocked: ${finishReason}`,
    };
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
  // Some responses put structured JSON in a different shape.
  if (part && typeof part === "object" && !part.text) {
    try {
      return JSON.stringify(part);
    } catch {
      return null;
    }
  }
  return null;
}

/** Strip markdown fences and parse Gemini JSON output. */
// deno-lint-ignore no-explicit-any
function parseRecipeJson(raw: string): any | null {
  let text = raw.trim();
  // ```json ... ``` or ``` ... ```
  const fence = text.match(/^```(?:json)?\s*([\s\S]*?)```$/i);
  if (fence) text = fence[1].trim();
  try {
    return JSON.parse(text);
  } catch {
    // Last resort: first {...} block
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
  if (!Array.isArray(recipe.ingredients) || recipe.ingredients.length < 2) {
    return false;
  }
  if (!Array.isArray(recipe.steps) || recipe.steps.length < 2) return false;
  return true;
}

function clampInt(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
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

/** Turns the profile's taste preferences into prompt constraints. */
// deno-lint-ignore no-explicit-any
function preferencesToPrompt(prefs: any): string {
  if (!prefs || typeof prefs !== "object") return "";
  const parts: string[] = [];
  if (Array.isArray(prefs.diets) && prefs.diets.length > 0) {
    parts.push(`The cook follows these diets: ${prefs.diets.join(", ")}.`);
  }
  if (Array.isArray(prefs.allergies) && prefs.allergies.length > 0) {
    parts.push(
      `STRICT SAFETY RULE — the recipe must contain absolutely no ${prefs.allergies.join(", no ")}, in any form or derivative.`,
    );
  }
  if (Array.isArray(prefs.dislikes) && prefs.dislikes.length > 0) {
    parts.push(
      `Avoid these disliked ingredients: ${prefs.dislikes.join(", ")}.`,
    );
  }
  if (typeof prefs.spice === "string" && prefs.spice) {
    parts.push(`Preferred spice level: ${prefs.spice}.`);
  }
  if (typeof prefs.skill === "string" && prefs.skill) {
    parts.push(
      `The cook's skill level is ${prefs.skill} — pitch technique accordingly.`,
    );
  }
  return parts.length > 0 ? parts.join(" ") + " " : "";
}
