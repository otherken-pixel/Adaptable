/**
 * Shared allergy scanning + daily rate limits for generate/import edge functions.
 */

/** Common synonym expansions so "peanut" also matches groundnut oil, etc. */
const ALLERGEN_ALIASES: Record<string, string[]> = {
  peanut: ["peanut", "peanuts", "groundnut", "ground nut", "arachis"],
  peanuts: ["peanut", "peanuts", "groundnut", "ground nut", "arachis"],
  "tree nut": [
    "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia",
    "brazil nut", "pine nut", "tree nut", "nutella", "marzipan",
  ],
  "tree nuts": [
    "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia",
    "brazil nut", "pine nut", "tree nut", "nutella", "marzipan",
  ],
  nut: [
    "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia",
    "brazil nut", "pine nut", "peanut", "tree nut",
  ],
  nuts: [
    "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia",
    "brazil nut", "pine nut", "peanut", "tree nut",
  ],
  dairy: [
    "milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey", "casein",
    "lactose", "ghee", "paneer", "mozzarella", "cheddar", "parmesan", "parmigiano",
    "feta", "ricotta", "brie", "gouda", "gruyere", "halloumi", "mascarpone",
    "cottage cheese", "sour cream", "creme fraiche", "half and half",
  ],
  milk: [
    "milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey", "casein",
    "lactose", "ghee", "paneer", "mozzarella", "cheddar", "parmesan", "parmigiano",
    "feta", "ricotta", "brie", "gouda", "gruyere", "halloumi", "mascarpone",
    "cottage cheese", "sour cream",
  ],
  egg: ["egg", "eggs", "mayonnaise", "aioli", "meringue"],
  eggs: ["egg", "eggs", "mayonnaise", "aioli", "meringue"],
  gluten: [
    "wheat", "barley", "rye", "malt", "seitan", "flour", "breadcrumbs",
    "bread crumbs", "soy sauce", "pasta", "couscous", "farro", "spelt",
  ],
  wheat: ["wheat", "flour", "breadcrumbs", "bread crumbs", "seitan", "bulgur"],
  shellfish: [
    "shrimp", "prawn", "crab", "lobster", "crawfish", "crayfish", "scallop",
    "clam", "mussel", "oyster", "shellfish", "calamari", "squid",
  ],
  fish: [
    "fish", "salmon", "tuna", "cod", "anchovy", "sardine", "trout", "bass",
    "halibut", "tilapia", "fish sauce",
  ],
  soy: ["soy", "soya", "tofu", "tempeh", "edamame", "miso", "soy sauce", "tamari"],
  sesame: ["sesame", "tahini", "benne", "hummus"],
  mustard: ["mustard"],
};

export function extractAllergies(prefs: unknown): string[] {
  if (!prefs || typeof prefs !== "object") return [];
  const allergies = (prefs as { allergies?: unknown }).allergies;
  if (!Array.isArray(allergies)) return [];
  return allergies.map(String).map((s) => s.trim()).filter(Boolean);
}

function termsForAllergy(label: string): string[] {
  const key = label.toLowerCase().trim();
  if (ALLERGEN_ALIASES[key]) return ALLERGEN_ALIASES[key];
  // Also try singular/plural simple forms
  const bare = key.replace(/s$/, "");
  if (ALLERGEN_ALIASES[bare]) return ALLERGEN_ALIASES[bare];
  return [key];
}

/** Returns allergen labels that appear to be present in the recipe text. */
export function findAllergyViolations(
  recipe: {
    title?: string;
    description?: string;
    ingredients?: Array<{ item?: string; note?: string }>;
    steps?: Array<{ instruction?: string; tip?: string }>;
  },
  allergies: string[],
): string[] {
  if (!allergies.length) return [];

  const chunks: string[] = [
    recipe.title ?? "",
    recipe.description ?? "",
    ...(recipe.ingredients ?? []).map(
      (i) => `${i.item ?? ""} ${i.note ?? ""}`,
    ),
    ...(recipe.steps ?? []).map(
      (s) => `${s.instruction ?? ""} ${s.tip ?? ""}`,
    ),
  ];
  const haystack = chunks.join(" \n ").toLowerCase();

  const hits: string[] = [];
  for (const allergy of allergies) {
    const terms = termsForAllergy(allergy);
    const matched = terms.some((t) => {
      if (t.length < 3) {
        // Short tokens: word boundary-ish
        return new RegExp(`(^|[^a-z])${escapeReg(t)}([^a-z]|$)`, "i").test(
          haystack,
        );
      }
      return haystack.includes(t);
    });
    if (matched) hits.push(allergy);
  }
  return [...new Set(hits)];
}

function escapeReg(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Soft daily cap: count recipes authored today (UTC). */
/** Optional ops hook when a content report is filed (set REPORT_WEBHOOK_URL). */
export async function notifyReport(payload: {
  targetType: string;
  targetId: string;
  reason: string;
  reporterId: string;
}): Promise<void> {
  const url = Deno.env.get("REPORT_WEBHOOK_URL");
  if (!url) return;
  try {
    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text: `Adaptable report: ${payload.targetType} ${payload.targetId} — ${payload.reason} (by ${payload.reporterId})`,
        ...payload,
      }),
    });
  } catch (e) {
    console.error("report webhook failed", e);
  }
}

export async function assertDailyRecipeLimit(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  limit: number,
  actionLabel: string,
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);

  const { count, error } = await supabase
    .from("recipes")
    .select("id", { count: "exact", head: true })
    .eq("author_id", userId)
    .gte("created_at", start.toISOString());

  if (error) {
    console.error("rate limit count failed", error);
    // Fail open on counter errors so a DB blip doesn't block cooking.
    return { ok: true };
  }

  if ((count ?? 0) >= limit) {
    return {
      ok: false,
      status: 429,
      error: `Daily ${actionLabel} limit reached (${limit}/day). Try again tomorrow — this keeps the AI kitchen fair for everyone.`,
    };
  }
  return { ok: true };
}

/** Soft daily cap for actions that do not insert a recipe (e.g. fridge reads). */
export async function assertDailyActionLimit(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  action: string,
  limit: number,
  actionLabel: string,
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);

  const { count, error } = await supabase
    .from("ai_usage_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action", action)
    .gte("created_at", start.toISOString());

  if (error) {
    console.error("action rate limit count failed", error);
    return { ok: true };
  }

  if ((count ?? 0) >= limit) {
    return {
      ok: false,
      status: 429,
      error: `Daily ${actionLabel} limit reached (${limit}/day). Try again tomorrow — this keeps the AI kitchen fair for everyone.`,
    };
  }

  const { error: insertError } = await supabase.from("ai_usage_events").insert({
    user_id: userId,
    action,
  });
  if (insertError) {
    console.error("action rate limit insert failed", insertError);
  }
  return { ok: true };
}
