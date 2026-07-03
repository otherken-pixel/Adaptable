// Supabase Edge Function: generate-recipe
//
// Receives { prompt } from an authenticated client, calls the Gemini API
// with a strict JSON response schema, inserts the recipe as the calling
// user (RLS enforced via their JWT), and returns the new row.
//
// Secrets (never shipped to the client):
//   supabase secrets set GEMINI_API_KEY=...

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
    title: { type: "STRING", description: "Catchy, appetizing recipe name" },
    description: {
      type: "STRING",
      description: "One or two enticing sentences about the dish",
    },
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
    tags: { type: "ARRAY", items: { type: "STRING" }, description: "3-5 short tags" },
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
          tip: { type: "STRING", description: "Optional pro tip for this step" },
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
    const { prompt, servings } = await req.json();
    if (!prompt || typeof prompt !== "string" || prompt.length > 500) {
      return json({ error: "A prompt of up to 500 characters is required." }, 400);
    }
    // Optional party size chosen in the app; enforced on the insert below.
    const requestedServings =
      Number.isInteger(servings) && servings >= 1 && servings <= 12
        ? (servings as number)
        : null;

    // Client scoped to the caller's JWT — every DB write below runs
    // under their identity and is subject to RLS.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in to generate recipes." }, 401);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      return json({ error: "GEMINI_API_KEY is not configured." }, 500);
    }

    // Taste profile — injected into every generation. Allergies are a
    // hard safety rule, everything else shapes tone and ingredients.
    const { data: profileRow } = await supabase
      .from("profiles")
      .select("preferences")
      .eq("id", user.id)
      .maybeSingle();
    const prefsText = preferencesToPrompt(profileRow?.preferences);

    const geminiRes = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
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
      }),
    });

    if (!geminiRes.ok) {
      const detail = await geminiRes.text();
      console.error("Gemini error", geminiRes.status, detail);
      return json({ error: "The recipe engine is unavailable. Try again." }, 502);
    }

    const geminiJson = await geminiRes.json();
    const text = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return json({ error: "Gemini returned an empty response." }, 502);
    }

    const recipe = JSON.parse(text);

    const { data: row, error: insertError } = await supabase
      .from("recipes")
      .insert({
        author_id: user.id,
        title: recipe.title,
        description: recipe.description ?? "",
        emoji: recipe.emoji ?? "🍽️",
        cuisine: recipe.cuisine ?? "Fusion",
        difficulty: ["Easy", "Medium", "Hard"].includes(recipe.difficulty)
          ? recipe.difficulty
          : "Easy",
        prep_time_minutes: recipe.prep_time_minutes ?? 0,
        cook_time_minutes: recipe.cook_time_minutes ?? 0,
        servings: requestedServings ?? recipe.servings ?? 2,
        calories: recipe.calories ?? null,
        protein_g: recipe.protein_g ?? null,
        carbs_g: recipe.carbs_g ?? null,
        fat_g: recipe.fat_g ?? null,
        tags: Array.isArray(recipe.tags) ? recipe.tags.slice(0, 6) : [],
        ingredients: recipe.ingredients ?? [],
        steps: recipe.steps ?? [],
        source_prompt: prompt,
      })
      .select("*, author:profiles(id, username, avatar_url)")
      .single();

    if (insertError) {
      console.error("Insert error", insertError);
      return json({ error: "Could not save the generated recipe." }, 500);
    }

    return json({ recipe: row }, 200);
  } catch (err) {
    console.error("Unhandled error", err);
    return json({ error: "Unexpected error generating recipe." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
    parts.push(`Avoid these disliked ingredients: ${prefs.dislikes.join(", ")}.`);
  }
  if (typeof prefs.spice === "string" && prefs.spice) {
    parts.push(`Preferred spice level: ${prefs.spice}.`);
  }
  if (typeof prefs.skill === "string" && prefs.skill) {
    parts.push(`The cook's skill level is ${prefs.skill} — pitch technique accordingly.`);
  }
  return parts.length > 0 ? parts.join(" ") + " " : "";
}
