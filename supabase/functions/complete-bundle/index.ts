// Supabase Edge Function: complete-bundle
//
// Generates the missing meal(s) that turn 0–N seed recipes into a
// 2–5 meal leftover-style prep bundle. Inserts the new recipes as the
// calling user (same daily cap as generate-recipe) and returns the bundle.

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  assertDailyRecipeLimit,
  extractAllergies,
  findAllergyViolations,
} from "../_shared/safety.ts";
import { generateAndUploadCover } from "../_shared/coverImage.ts";
import {
  classifyRecipe,
  formatList,
  inferCookingMethod,
  inferMealSlot,
  insertRecipeRow,
  leftoverFocus,
  recipeInsertPayload,
  sessionMinutes,
  type CookingMethod,
  type MealSlot,
} from "../_shared/mealPrep.ts";

const DAILY_GENERATE_LIMIT = 25;

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

const RECIPE_SELECT =
  "*, author:profiles!recipes_author_id_fkey(id, username, avatar_url)";

const recipeSchema = {
  type: "OBJECT",
  properties: {
    title: { type: "STRING" },
    description: { type: "STRING" },
    emoji: { type: "STRING" },
    cuisine: { type: "STRING" },
    difficulty: { type: "STRING", enum: ["Easy", "Medium", "Hard"] },
    prep_time_minutes: { type: "INTEGER" },
    cook_time_minutes: { type: "INTEGER" },
    servings: { type: "INTEGER" },
    calories: { type: "INTEGER" },
    protein_g: { type: "INTEGER" },
    carbs_g: { type: "INTEGER" },
    fat_g: { type: "INTEGER" },
    tags: { type: "ARRAY", items: { type: "STRING" } },
    primary_method: {
      type: "STRING",
      enum: [
        "oven",
        "stovetop",
        "sheet_pan",
        "air_fryer",
        "slow_cooker",
        "grill",
        "no_cook",
        "instant_pot",
        "mixed",
      ],
    },
    base_protein: {
      type: "STRING",
      enum: [
        "chicken",
        "beef",
        "pork",
        "turkey",
        "fish",
        "shrimp",
        "tofu",
        "beans",
        "eggs",
        "lamb",
        "none",
      ],
    },
    meal_slot: {
      type: "STRING",
      enum: ["breakfast", "lunch", "dinner", "snack", "dessert", "any"],
    },
    active_prep_minutes: { type: "INTEGER" },
    equipment: { type: "ARRAY", items: { type: "STRING" } },
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

const COMPLEMENT: Record<string, CookingMethod[]> = {
  oven: ["stovetop", "no_cook"],
  sheet_pan: ["stovetop", "no_cook"],
  stovetop: ["oven", "sheet_pan", "air_fryer", "slow_cooker", "no_cook"],
  air_fryer: ["stovetop", "no_cook"],
  slow_cooker: ["stovetop", "no_cook"],
  grill: ["stovetop", "no_cook"],
  instant_pot: ["stovetop", "no_cook"],
  no_cook: ["oven", "stovetop", "sheet_pan"],
  mixed: ["no_cook", "air_fryer"],
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

    const rawSize = Number(body.target_size);
    const targetSize =
      Number.isInteger(rawSize) && rawSize >= 2 && rawSize <= 5 ? rawSize : 3;
    const seedIds = Array.isArray(body.seed_recipe_ids)
      ? body.seed_recipe_ids.map(String).filter(Boolean).slice(0, Math.max(0, targetSize - 1))
      : [];
    const kind =
      body.kind === "concurrent" || body.kind === "shared_base"
        ? body.kind
        : "shared_base";

    const SLOT_ORDER: MealSlot[] = ["dinner", "lunch", "breakfast"];
    const requestedSlots = Array.isArray(body.slots)
      ? body.slots.map((s: unknown) => String(s).toLowerCase())
      : [];
    const slotOrder: MealSlot[] = SLOT_ORDER.filter((s) =>
      requestedSlots.length === 0 ? true : requestedSlots.includes(s),
    );
    const windowRaw = String(body.prep_window ?? "60");
    const prepWindow = windowRaw === "30" || windowRaw === "120" ? windowRaw : "60";
    const requestedBase = typeof body.base === "string"
      ? body.base.toLowerCase().trim()
      : "";
    const baseKey = ["chicken", "salmon", "tofu", "beans", "eggs", "chef"].includes(requestedBase)
      ? requestedBase
      : "chef";
    const servingsRaw = Number(body.servings);
    const servings =
      Number.isInteger(servingsRaw) && servingsRaw >= 1 && servingsRaw <= 12
        ? servingsRaw
        : null;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "You must be signed in to build a prep bundle." }, 401);
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
      return json({ error: "You must be signed in to build a prep bundle." }, 401);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      return json(
        { error: "The recipe engine is not configured. Contact support." },
        500,
      );
    }

    const missing = Math.max(0, targetSize - seedIds.length);
    if (missing === 0) {
      return json({ error: "That bundle is already complete." }, 400);
    }

    const rate = await assertDailyRecipeLimit(
      supabase,
      user.id,
      DAILY_GENERATE_LIMIT - (missing - 1),
      "generation",
    );
    if (!rate.ok) return json({ error: rate.error }, rate.status);

    const { data: profileRow } = await supabase
      .from("profiles")
      .select("preferences")
      .eq("id", user.id)
      .maybeSingle();
    const prefs = profileRow?.preferences;
    const allergies = extractAllergies(prefs);
    const prefsText = preferencesToPrompt(prefs);

    let seeds: any[] = [];
    if (seedIds.length > 0) {
      const { data, error } = await supabase
        .from("recipes")
        .select(RECIPE_SELECT)
        .in("id", seedIds);
      if (error) {
        return json({ error: "Could not load the seed recipes." }, 500);
      }
      seeds = data ?? [];
      if (seeds.length !== seedIds.length) {
        return json({ error: "One of those recipes could not be found." }, 404);
      }
    }

    const focus = leftoverFocus(seeds);
    const focusLabel = focus.length > 0
      ? formatList(focus.slice(0, 2))
      : baseKey === "chef"
        ? defaultFocusFromPrefs(prefs)
        : baseKey;
    const usedMethods = seeds.map((s) => inferCookingMethod(s));
    const usedSlots = new Set(seeds.map((s) => inferMealSlot(s)));
    const usedTitles = seeds.map((s) => String(s.title ?? "Untitled"));

    const generatedDrafts: any[] = [];
    for (let i = 0; i < missing; i++) {
      const slotHint = nextSlot(usedSlots, slotOrder);
      const methodHint = complementaryMethod(usedMethods);
      const extra = buildPrompt({
        kind,
        focusLabel,
        seeds: [...seeds, ...generatedDrafts],
        slotHint,
        methodHint,
        prefsText,
        allergies,
        fromScratch: seeds.length === 0 && generatedDrafts.length === 0,
        prepWindow,
        servings,
        remaining: missing - i - 1,
      });

      const draft = await generateComplement(geminiKey, extra, allergies);
      if (!draft.ok) {
        return json({ error: draft.error }, draft.status);
      }
      generatedDrafts.push(draft.recipe);
      usedSlots.add(inferMealSlot(draft.recipe));
      usedMethods.push(inferCookingMethod(draft.recipe));
    }

    const sourcePrompt = seeds.length > 0
      ? `prep-bundle leftover ${focusLabel} from ${usedTitles.join(" + ")}`
      : `prep-bundle ${kind} around ${focusLabel} (${targetSize} meals, ${prepWindow} min)`;

    const inserted: any[] = [];
    for (const draft of generatedDrafts) {
      const { data: row, error: insertError } = await insertRecipeRow(
        supabase,
        recipeInsertPayload({
          authorId: user.id,
          recipe: draft,
          sourcePrompt,
        }),
        RECIPE_SELECT,
      );
      if (insertError || !row) {
        console.error("complete-bundle insert failed", insertError);
        const ids = inserted.map((r) => r.id).filter(Boolean);
        if (ids.length > 0) {
          await supabase.from("recipes").delete().in("id", ids);
        }
        return json(
          { error: "Could not save the generated meal — please try again." },
          500,
        );
      }
      inserted.push(row);
    }

    // Covers in parallel — never block the bundle on a photo miss.
    await Promise.all(
      inserted.map(async (row, idx) => {
        try {
          const imageUrl = await generateAndUploadCover({
            supabase,
            geminiKey,
            userId: user.id,
            recipeId: row.id,
            title: row.title ?? generatedDrafts[idx]?.title,
            description: row.description ?? generatedDrafts[idx]?.description,
            cuisine: row.cuisine ?? generatedDrafts[idx]?.cuisine,
            emoji: row.emoji ?? generatedDrafts[idx]?.emoji,
          });
          if (!imageUrl) return;
          const { data: updated } = await supabase
            .from("recipes")
            .update({ image_url: imageUrl })
            .eq("id", row.id)
            .select(RECIPE_SELECT)
            .single();
          if (updated) inserted[idx] = updated;
        } catch (e) {
          console.error("cover generation skipped", e);
        }
      }),
    );

    const parentId = seeds[0]?.id ?? inserted[0]?.id;
    const focusKeys = leftoverFocus([...seeds, ...inserted]).slice(0, 3);
    if (parentId) {
      for (const child of inserted) {
        if (child.id === parentId) continue;
        const { error: linErr } = await supabase.from("recipe_lineage").insert({
          user_id: user.id,
          parent_recipe_id: parentId,
          child_recipe_id: child.id,
          leftover_focus: focusKeys,
        });
        if (linErr) console.error("lineage insert skipped", linErr);
      }
    }

    const recipes = [...seeds, ...inserted];
    const times = sessionMinutes(recipes);
    const cals = recipes
      .map((r) => r.calories)
      .filter((n: unknown): n is number => typeof n === "number");
    const avgCalories = cals.length
      ? Math.round(cals.reduce((a: number, b: number) => a + b, 0) / cals.length)
      : null;
    const shared = leftoverFocus(recipes).slice(0, 3);
    const headline = kind === "concurrent"
      ? `${methodLabel(usedMethods[0])} + ${methodLabel(usedMethods[1] ?? usedMethods[0])} · Prep in ${times.parallel} min`
      : `Shared base: ${formatList(shared.length ? shared : [focusLabel])}`;
    const reason = kind === "concurrent"
      ? `These cook at the same time without fighting for the same burner or oven.`
      : `Batch-cook ${formatList(shared.length ? shared : [focusLabel])} once, then eat it ${recipes.length} ways.`;

    return json({
      bundle: {
        id: recipes.map((r) => r.id).sort().join("+"),
        kind,
        recipes,
        headline,
        reason,
        shared_ingredients: shared,
        session_minutes: times.parallel,
        active_minutes: times.active,
        avg_calories: avgCalories,
        generated_ids: inserted.map((r) => r.id),
        missing_count: 0,
        leftover_focus: shared.length ? shared : [focusLabel],
      },
    }, 200);
  } catch (err) {
    console.error("complete-bundle unhandled", err);
    return json(
      { error: "Something went wrong while building the bundle — try again." },
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
    parts.push(`The cook's skill level is ${prefs.skill}.`);
  }
  return parts.length > 0 ? parts.join(" ") + " " : "";
}

function defaultFocusFromPrefs(prefs: any): string {
  const diets = Array.isArray(prefs?.diets)
    ? prefs.diets.map((d: string) => String(d).toLowerCase())
    : [];
  if (diets.some((d: string) => d.includes("vegan"))) return "tofu";
  if (diets.some((d: string) => d.includes("vegetarian"))) return "chickpea";
  if (diets.some((d: string) => d.includes("pescatarian"))) return "salmon";
  return "chicken";
}

function nextSlot(used: Set<MealSlot>, order: MealSlot[]): MealSlot {
  const seq: MealSlot[] = order.length > 0 ? order : ["dinner", "lunch", "breakfast"];
  const unused = seq.find((s) => !used.has(s));
  if (unused) return unused;
  return seq[used.size % seq.length];
}

function complementaryMethod(used: CookingMethod[]): CookingMethod {
  if (used.length === 0) return "sheet_pan";
  const options = COMPLEMENT[used[0]] ?? ["stovetop"];
  return options.find((m) => !used.includes(m)) ?? options[0];
}

function methodLabel(method: CookingMethod | undefined): string {
  switch (method) {
    case "sheet_pan":
      return "Sheet pan";
    case "air_fryer":
      return "Air fryer";
    case "slow_cooker":
      return "Slow cooker";
    case "instant_pot":
      return "Instant Pot";
    case "no_cook":
      return "No-cook";
    case "stovetop":
      return "Stovetop";
    case "oven":
      return "Oven";
    case "grill":
      return "Grill";
    default:
      return "Mixed";
  }
}

function summarizeRecipe(recipe: any): string {
  const meta = classifyRecipe(recipe);
  const ings = (recipe.ingredients ?? [])
    .slice(0, 8)
    .map((i: { item?: string }) => i.item)
    .filter(Boolean)
    .join(", ");
  return (
    `"${recipe.title}" (${meta.meal_slot}, ${meta.primary_method}, ` +
    `${(recipe.prep_time_minutes ?? 0) + (recipe.cook_time_minutes ?? 0)} min). ` +
    `Ingredients: ${ings}.`
  );
}

function buildPrompt(opts: {
  kind: "shared_base" | "concurrent";
  focusLabel: string;
  seeds: any[];
  slotHint: MealSlot;
  methodHint: CookingMethod;
  prefsText: string;
  allergies: string[];
  fromScratch: boolean;
  prepWindow: string;
  servings: number | null;
  remaining: number;
}): string {
  const existing = opts.seeds.map(summarizeRecipe).join(" ");
  const leftoverCount = opts.remaining;
  const leftoverRule = opts.fromScratch
    ? `This is the ${opts.seeds.length === 0 ? "batch-cook anchor" : "leftover"} meal in a ${opts.kind} prep bundle around ${opts.focusLabel}. ` +
      (opts.seeds.length === 0
        ? `Cook a generous batch of ${opts.focusLabel} so leftovers can become ${leftoverCount > 0 ? leftoverCount : "more"} distinct meals.`
        : `CRITICAL: use leftover cooked ${opts.focusLabel} as a primary ingredient — do not start that ingredient raw. Steps must say "use the leftover ${opts.focusLabel}".`)
    : `CRITICAL: this meal must use leftover cooked ${opts.focusLabel} as a primary ingredient. ` +
      `Do not start that ingredient raw or give it a long cook. ` +
      `Steps must say "use the leftover ${opts.focusLabel} from earlier this week".`;

  const windowRule = opts.prepWindow === "30"
    ? "The entire prep session including the batch cook must fit in about 30 minutes. Keep the anchor simple (one pan or one pot)."
    : opts.prepWindow === "120"
      ? "This is a Sunday session — up to about 2 hours for the batch cook. Make a generous, flavorful base so leftover meals stay interesting."
      : "The cook has about an hour for the batch-cook session. Leftover meals should then come together in about 15–20 minutes.";

  const kindRule = opts.kind === "concurrent"
    ? `It must cook at the same time as the other meals using method "${opts.methodHint}" so equipment does not clash.`
    : `This meal is specifically for ${opts.slotHint}. Once the leftover ${opts.focusLabel} is ready, leftover meals should come together in about 20 minutes.`;

  const servingsRule = opts.servings
    ? ` Write the recipe for ${opts.servings} servings.`
    : "";

  return (
    `Create one complete, realistic, delicious recipe. ${opts.prefsText}` +
    (existing ? `The cook already has: ${existing} ` : "") +
    leftoverRule +
    " " +
    windowRule +
    " " +
    kindRule +
    servingsRule +
    " Do not repeat an existing title or the same cuisine+dish shape. " +
    "Quantities must use both metric and imperial where sensible. " +
    "At least 4 ingredients and 3 steps. " +
    "Estimate calories, protein, carbs and fat per serving. " +
    'If 500 calories/serving or fewer, include a "Low-cal" tag; ' +
    'if 30 g protein or more, include a "High-protein" tag. ' +
    'Include a "Meal-prep" tag.'
  );
}

async function generateComplement(
  geminiKey: string,
  instruction: string,
  allergies: string[],
): Promise<{ ok: true; recipe: any } | { ok: false; status: number; error: string }> {
  const temperature = allergies.length > 0 ? 0.45 : 0.8;

  async function once(extra: string) {
    const payload = {
      contents: [{ role: "user", parts: [{ text: instruction + extra }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
        temperature,
      },
    };
    return await callGeminiWithModelFallback(geminiKey, payload);
  }

  let gemini = await once("");
  if (!gemini.ok) {
    return {
      ok: false,
      status: 502,
      error: "The recipe engine is temporarily unavailable — please try again.",
    };
  }

  let recipe = parseRecipeJson(gemini.text);
  if (!recipe || !isValidRecipe(recipe)) {
    return {
      ok: false,
      status: 502,
      error: "Couldn't build a complete leftover meal — please try again.",
    };
  }

  let violations = findAllergyViolations(recipe, allergies);
  if (violations.length > 0) {
    gemini = await once(
      ` CRITICAL REWRITE: The previous draft illegally contained ${violations.join(", ")}. ` +
        `Produce a completely different recipe with ZERO ${violations.join(", ")}.`,
    );
    if (gemini.ok) {
      const rewritten = parseRecipeJson(gemini.text);
      if (rewritten && isValidRecipe(rewritten)) {
        recipe = rewritten;
        violations = findAllergyViolations(recipe, allergies);
      }
    }
    if (violations.length > 0) {
      return {
        ok: false,
        status: 422,
        error:
          `We blocked this meal because it still looked like it contained your allergen(s): ${violations.join(", ")}.`,
      };
    }
  }

  return { ok: true, recipe };
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
    await sleep(600);
    res = await call();
  }
  if (!res.ok && res.status === 429) {
    await sleep(1200);
    res = await call();
  }
  if (!res.ok) return { ok: false, status: res.status, detail: await res.text() };

  const geminiJson = await res.json();
  const finishReason = geminiJson?.candidates?.[0]?.finishReason;
  if (finishReason === "SAFETY" || finishReason === "BLOCKED") {
    return { ok: false, status: 400, detail: `blocked: ${finishReason}` };
  }
  const text = extractCandidateText(geminiJson);
  if (!text) {
    return { ok: false, status: 502, detail: "empty candidate" };
  }
  return { ok: true, text };
}

function extractCandidateText(geminiJson: unknown): string | null {
  const j = geminiJson as any;
  const part = j?.candidates?.[0]?.content?.parts?.[0];
  if (typeof part?.text === "string" && part.text.trim()) return part.text;
  return null;
}

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

function isValidRecipe(recipe: any): boolean {
  if (!recipe || typeof recipe !== "object") return false;
  if (!recipe.title || typeof recipe.title !== "string") return false;
  if (!Array.isArray(recipe.ingredients) || recipe.ingredients.length < 2) return false;
  if (!Array.isArray(recipe.steps) || recipe.steps.length < 2) return false;
  return true;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
