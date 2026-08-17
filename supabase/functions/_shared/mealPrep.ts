/**
 * Canonical ingredient / method inference for meal-prep bundles.
 * Used by generate-recipe, import-recipe, and complete-bundle.
 * Keep in lockstep with ios/.../Utilities/MealPrepBundles.swift.
 */

export type CookingMethod =
  | "oven"
  | "stovetop"
  | "sheet_pan"
  | "air_fryer"
  | "slow_cooker"
  | "grill"
  | "no_cook"
  | "instant_pot"
  | "mixed";

export type BaseProtein =
  | "chicken"
  | "beef"
  | "pork"
  | "turkey"
  | "fish"
  | "shrimp"
  | "tofu"
  | "beans"
  | "eggs"
  | "lamb"
  | "none";

export type MealSlot =
  | "breakfast"
  | "lunch"
  | "dinner"
  | "snack"
  | "dessert"
  | "any";

export interface RecipeLike {
  title?: string;
  description?: string;
  tags?: string[];
  ingredients?: Array<{ item?: string; note?: string }>;
  steps?: Array<{ instruction?: string; tip?: string }>;
  prep_time_minutes?: number;
  cook_time_minutes?: number;
  cuisine?: string;
  primary_method?: string | null;
  base_protein?: string | null;
  meal_slot?: string | null;
  active_prep_minutes?: number | null;
  ingredient_keys?: string[] | null;
  equipment?: string[] | null;
}

export interface RecipePrepMeta {
  ingredient_keys: string[];
  primary_method: CookingMethod;
  base_protein: BaseProtein;
  meal_slot: MealSlot;
  active_prep_minutes: number;
  equipment: string[];
}

export const STAPLES = new Set([
  "salt",
  "pepper",
  "oil",
  "olive oil",
  "vegetable oil",
  "sesame oil",
  "water",
  "butter",
  "sugar",
  "flour",
  "garlic",
  "onion",
  "shallot",
  "vinegar",
  "soy",
  "soy sauce",
  "tamari",
  "lemon",
  "lime",
  "chili",
  "cumin",
  "paprika",
  "oregano",
  "thyme",
  "ginger",
  "spray",
  "cooking spray",
  "black pepper",
  "kosher salt",
  "sea salt",
]);

export const BATCHABLE = new Set([
  "chicken",
  "turkey",
  "beef",
  "pork",
  "tofu",
  "salmon",
  "shrimp",
  "tuna",
  "rice",
  "quinoa",
  "broccoli",
  "cauliflower",
  "sweet potato",
  "chickpea",
  "black bean",
  "lentil",
  "egg",
  "lamb",
]);

const FILLERS = new Set([
  "boneless",
  "skinless",
  "fresh",
  "frozen",
  "large",
  "small",
  "medium",
  "diced",
  "chopped",
  "minced",
  "sliced",
  "cooked",
  "leftover",
  "leftovers",
  "shredded",
  "roasted",
  "canned",
  "drained",
  "dried",
  "ground",
  "whole",
  "baby",
  "extra",
  "firm",
  "can",
  "cloves",
  "fillet",
  "fillets",
  "breast",
  "breasts",
  "thigh",
  "thighs",
  "optional",
  "plus",
]);

const ALIASES: Record<string, string> = {
  chickpeas: "chickpea",
  garbanzo: "chickpea",
  "garbanzo beans": "chickpea",
  "black beans": "black bean",
  "green onion": "scallion",
  "green onions": "scallion",
  "spring onion": "scallion",
  "sweet potatoes": "sweet potato",
  "bell peppers": "bell pepper",
  eggs: "egg",
  "sushi rice": "rice",
  "jasmine rice": "rice",
  "basmati rice": "rice",
  "brown rice": "rice",
  broccolini: "broccoli",
  "broccoli florets": "broccoli",
};

const COLLAPSE = [
  "chicken",
  "turkey",
  "beef",
  "pork",
  "lamb",
  "salmon",
  "tuna",
  "shrimp",
  "tofu",
  "broccoli",
  "cauliflower",
  "spinach",
  "kale",
  "rice",
  "quinoa",
  "chickpea",
  "lentil",
  "egg",
];

const METHODS: CookingMethod[] = [
  "oven",
  "stovetop",
  "sheet_pan",
  "air_fryer",
  "slow_cooker",
  "grill",
  "no_cook",
  "instant_pot",
  "mixed",
];

const PROTEINS: BaseProtein[] = [
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
];

const SLOTS: MealSlot[] = [
  "breakfast",
  "lunch",
  "dinner",
  "snack",
  "dessert",
  "any",
];

const PROTEIN_FROM_KEY: Record<string, BaseProtein> = {
  chicken: "chicken",
  turkey: "turkey",
  beef: "beef",
  pork: "pork",
  lamb: "lamb",
  salmon: "fish",
  tuna: "fish",
  cod: "fish",
  fish: "fish",
  shrimp: "shrimp",
  tofu: "tofu",
  chickpea: "beans",
  "black bean": "beans",
  lentil: "beans",
  bean: "beans",
  egg: "eggs",
};

export function normalizeIngredient(item: string): string {
  let s = (item ?? "").toLowerCase();
  const cut = (ch: string) => {
    const i = s.indexOf(ch);
    if (i >= 0) s = s.slice(0, i);
  };
  cut("(");
  cut(",");
  cut(";");
  s = s
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  const parts = s.split(" ").filter((w) => w && !FILLERS.has(w));
  s = parts.join(" ");
  if (ALIASES[s]) return ALIASES[s];
  for (const token of COLLAPSE) {
    if (s === token || s.includes(token)) return token;
  }
  if (s.endsWith("oes") && s.length > 5) return s.slice(0, -2);
  if (s.endsWith("s") && s.length > 4 && !s.endsWith("ss")) return s.slice(0, -1);
  return s;
}

export function ingredientKeys(
  ingredients: Array<{ item?: string }> | undefined,
): string[] {
  const keys = new Set<string>();
  for (const ing of ingredients ?? []) {
    const key = normalizeIngredient(ing.item ?? "");
    if (!key || STAPLES.has(key)) continue;
    keys.add(key);
  }
  return [...keys];
}

export function inferBaseProtein(recipe: RecipeLike): BaseProtein {
  const stored = clampProtein(recipe.base_protein);
  if (stored && stored !== "none") return stored;
  const keys = recipe.ingredient_keys ?? ingredientKeys(recipe.ingredients);
  for (const key of keys) {
    if (PROTEIN_FROM_KEY[key]) return PROTEIN_FROM_KEY[key];
  }
  const hay = `${recipe.title ?? ""} ${(recipe.tags ?? []).join(" ")}`.toLowerCase();
  for (const [token, protein] of Object.entries(PROTEIN_FROM_KEY)) {
    if (hay.includes(token)) return protein;
  }
  return "none";
}

export function inferCookingMethod(recipe: RecipeLike): CookingMethod {
  const stored = clampMethod(recipe.primary_method);
  if (stored) return stored;

  const tags = (recipe.tags ?? []).map((t) => t.toLowerCase());
  const tagHay = tags.join(" ");
  if (/(sheet[-\s]?pan)/.test(tagHay)) return "sheet_pan";
  if (/(air[-\s]?fry)/.test(tagHay)) return "air_fryer";
  if (/(no[-\s]?cook|overnight)/.test(tagHay)) return "no_cook";
  if (/(slow[-\s]?cook|crock)/.test(tagHay)) return "slow_cooker";
  if (/(instant[-\s]?pot|pressure)/.test(tagHay)) return "instant_pot";
  if (/\bgrill/.test(tagHay)) return "grill";
  if (/(one[-\s]?pot|one[-\s]?pan|stir[-\s]?fry)/.test(tagHay)) return "stovetop";

  const steps = (recipe.steps ?? [])
    .map((s) => `${s.instruction ?? ""} ${s.tip ?? ""}`)
    .join(" ")
    .toLowerCase();
  const hits = new Set<CookingMethod>();
  if (/(roast|bake|broil|oven)/.test(steps)) hits.add("oven");
  if (/(sheet pan|sheet-pan)/.test(steps)) hits.add("sheet_pan");
  if (/(sauté|saute|sear|simmer|boil|stir[-\s]?fry|pan[-\s]?fry|wilt|skillet)/.test(steps)) {
    hits.add("stovetop");
  }
  if (/(air[-\s]?fry)/.test(steps)) hits.add("air_fryer");
  if (/\bgrill/.test(steps)) hits.add("grill");
  if (/(slow[-\s]?cook|crock)/.test(steps)) hits.add("slow_cooker");
  if (/(instant[-\s]?pot|pressure cook)/.test(steps)) hits.add("instant_pot");
  if (/(no heat|refrigerate|overnight|no cook)/.test(steps)) hits.add("no_cook");

  if (hits.has("sheet_pan")) return "sheet_pan";
  if (hits.size === 0) {
    if ((recipe.cook_time_minutes ?? 0) === 0) return "no_cook";
    return "stovetop";
  }
  if (hits.size === 1) return [...hits][0];
  if (hits.has("oven") && hits.has("stovetop")) return "mixed";
  if (hits.has("oven")) return "oven";
  return [...hits][0];
}

export function inferMealSlot(recipe: RecipeLike): MealSlot {
  const stored = clampSlot(recipe.meal_slot);
  if (stored && stored !== "any") return stored;
  const hay = `${recipe.title ?? ""} ${recipe.description ?? ""} ${(recipe.tags ?? []).join(" ")}`
    .toLowerCase();
  if (/(breakfast|brunch|overnight oat|morning)/.test(hay)) return "breakfast";
  if (/(dessert|brownie|cookie|cake|ice cream)/.test(hay)) return "dessert";
  if (/(snack|appetizer|dip)/.test(hay)) return "snack";
  if (/\blunch\b/.test(hay)) return "lunch";
  if (/(dinner|weeknight|supper)/.test(hay)) return "dinner";
  return "any";
}

export function inferEquipment(recipe: RecipeLike): string[] {
  if (Array.isArray(recipe.equipment) && recipe.equipment.length > 0) {
    return recipe.equipment.map(String);
  }
  const method = inferCookingMethod(recipe);
  const fromMethod: Record<CookingMethod, string[]> = {
    oven: ["oven"],
    sheet_pan: ["oven", "sheet_pan"],
    stovetop: ["skillet"],
    air_fryer: ["air_fryer"],
    slow_cooker: ["slow_cooker"],
    grill: ["grill"],
    no_cook: [],
    instant_pot: ["instant_pot"],
    mixed: ["oven", "skillet"],
  };
  return fromMethod[method];
}

export function inferActivePrepMinutes(recipe: RecipeLike): number {
  if (
    typeof recipe.active_prep_minutes === "number" &&
    Number.isFinite(recipe.active_prep_minutes)
  ) {
    return Math.max(0, Math.round(recipe.active_prep_minutes));
  }
  const prep = Math.max(0, recipe.prep_time_minutes ?? 0);
  const cook = Math.max(0, recipe.cook_time_minutes ?? 0);
  const method = inferCookingMethod(recipe);
  const handsOff = new Set<CookingMethod>([
    "oven",
    "sheet_pan",
    "air_fryer",
    "slow_cooker",
    "grill",
  ]);
  if (handsOff.has(method)) return prep + Math.round(cook * 0.15);
  if (method === "no_cook") return prep;
  if (method === "mixed") return prep + Math.round(cook * 0.5);
  return prep + Math.round(cook * 0.85);
}

export function classifyRecipe(recipe: RecipeLike): RecipePrepMeta {
  const keys = ingredientKeys(recipe.ingredients);
  return {
    ingredient_keys: keys,
    primary_method: inferCookingMethod({ ...recipe, ingredient_keys: keys }),
    base_protein: inferBaseProtein({ ...recipe, ingredient_keys: keys }),
    meal_slot: inferMealSlot(recipe),
    active_prep_minutes: inferActivePrepMinutes(recipe),
    equipment: inferEquipment(recipe),
  };
}

export function clampMethod(value: unknown): CookingMethod | null {
  const s = String(value ?? "");
  return (METHODS as string[]).includes(s) ? (s as CookingMethod) : null;
}

export function clampProtein(value: unknown): BaseProtein | null {
  const s = String(value ?? "");
  return (PROTEINS as string[]).includes(s) ? (s as BaseProtein) : null;
}

export function clampSlot(value: unknown): MealSlot | null {
  const s = String(value ?? "");
  return (SLOTS as string[]).includes(s) ? (s as MealSlot) : null;
}

export function batchableShared(keysA: string[], keysB: string[]): string[] {
  return keysA.filter((k) => BATCHABLE.has(k) && keysB.includes(k));
}

export function sessionMinutes(recipes: RecipeLike[]): {
  active: number;
  parallel: number;
} {
  const active = recipes.reduce((n, r) => n + inferActivePrepMinutes(r), 0);
  const maxTotal = Math.max(
    0,
    ...recipes.map((r) => (r.prep_time_minutes ?? 0) + (r.cook_time_minutes ?? 0)),
  );
  return { active, parallel: Math.max(active, maxTotal) };
}

export function leftoverFocus(recipes: RecipeLike[]): string[] {
  const counts = new Map<string, number>();
  for (const r of recipes) {
    const keys = r.ingredient_keys ?? ingredientKeys(r.ingredients);
    for (const k of keys) {
      if (!BATCHABLE.has(k)) continue;
      counts.set(k, (counts.get(k) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .map(([k]) => k);
}

export function formatList(items: string[]): string {
  if (items.length === 0) return "";
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} & ${items[1]}`;
  return `${items.slice(0, -1).join(", ")} & ${items[items.length - 1]}`;
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
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.round(n);
}

/** Build a recipes insert payload, including prep-meta columns. */
export function recipeInsertPayload(opts: {
  authorId: string;
  // deno-lint-ignore no-explicit-any
  recipe: any;
  sourcePrompt: string;
  sourceUrl?: string | null;
  servings?: number;
}): Record<string, unknown> {
  const recipe = opts.recipe ?? {};
  const meta = classifyRecipe(recipe);
  const method = clampMethod(recipe.primary_method) ?? meta.primary_method;
  const protein = clampProtein(recipe.base_protein) ?? meta.base_protein;
  const slot = clampSlot(recipe.meal_slot) ?? meta.meal_slot;
  const active =
    typeof recipe.active_prep_minutes === "number"
      ? clampInt(recipe.active_prep_minutes, 0, 24 * 60, meta.active_prep_minutes)
      : meta.active_prep_minutes;
  return {
    author_id: opts.authorId,
    title: String(recipe.title ?? "Untitled").slice(0, 140),
    description: recipe.description ?? "",
    emoji: recipe.emoji ?? "🍽️",
    cuisine: recipe.cuisine ?? "Fusion",
    difficulty: ["Easy", "Medium", "Hard"].includes(recipe.difficulty)
      ? recipe.difficulty
      : "Easy",
    prep_time_minutes: clampInt(recipe.prep_time_minutes, 0, 24 * 60, 0),
    cook_time_minutes: clampInt(recipe.cook_time_minutes, 0, 24 * 60, 0),
    servings: opts.servings ?? clampInt(recipe.servings, 1, 24, 2),
    calories: nullableInt(recipe.calories),
    protein_g: nullableInt(recipe.protein_g),
    carbs_g: nullableInt(recipe.carbs_g),
    fat_g: nullableInt(recipe.fat_g),
    tags: Array.isArray(recipe.tags) ? recipe.tags.map(String).slice(0, 6) : [],
    ingredients: recipe.ingredients ?? [],
    steps: recipe.steps ?? [],
    source_prompt: opts.sourcePrompt,
    source_url: opts.sourceUrl ?? null,
    ingredient_keys: meta.ingredient_keys,
    primary_method: method,
    base_protein: protein,
    meal_slot: slot,
    active_prep_minutes: active,
    equipment: Array.isArray(recipe.equipment)
      ? recipe.equipment.map(String)
      : meta.equipment,
  };
}

const META_COLUMNS = [
  "ingredient_keys",
  "primary_method",
  "base_protein",
  "meal_slot",
  "active_prep_minutes",
  "equipment",
];

/** Insert a recipe; if prep-meta columns are not migrated yet, retry without them. */
export async function insertRecipeRow(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  payload: Record<string, unknown>,
  select: string,
  // deno-lint-ignore no-explicit-any
): Promise<{ data: any; error: any }> {
  const first = await supabase.from("recipes").insert(payload).select(select).single();
  if (!first.error) return first;
  const msg = String(first.error.message ?? first.error.code ?? "");
  const missingMeta = META_COLUMNS.some((c) => msg.includes(c));
  if (!missingMeta) return first;
  const fallback = { ...payload };
  for (const c of META_COLUMNS) delete fallback[c];
  return await supabase.from("recipes").insert(fallback).select(select).single();
}
