/**
 * Server-built surprise brief: cuisine × protein × method lottery.
 * Clients send structured locks only — never a free-text prompt.
 * Method may be locked (e.g. Crock pot → slow_cooker); otherwise it is drawn.
 * Keep in lockstep with src/lib/surprise.ts option lists.
 */

import type { BaseProtein, CookingMethod, MealSlot } from "./mealPrep.ts";

export const SURPRISE_CUISINES = [
  "Italian",
  "Mexican",
  "Thai",
  "Chinese",
  "Japanese",
  "Indian",
  "Korean",
  "Mediterranean",
  "French",
  "American",
  "Middle Eastern",
  "Vietnamese",
  "Greek",
  "Spanish",
  "Caribbean",
  "North African",
] as const;

export const SURPRISE_TIMES = [15, 20, 30, 45, 60] as const;

export const SURPRISE_SLOTS = [
  "breakfast",
  "lunch",
  "dinner",
  "snack",
  "dessert",
] as const;

export const SURPRISE_METHODS: CookingMethod[] = [
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

export const SURPRISE_PROTEINS: BaseProtein[] = [
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

export type PantryMode = "leftover" | "fridge";

export interface SurpriseConstraints {
  max_minutes?: number | null;
  meal_slot?: string | null;
  cuisine?: string | null;
  pantry_mode?: string | null;
  ingredients?: string[] | null;
  method?: string | null;
}

export interface ParsedSurpriseConstraints {
  max_minutes: number | null;
  meal_slot: MealSlot | null;
  cuisine: string | null;
  pantry_mode: PantryMode | null;
  ingredients: string[];
  method: CookingMethod | null;
}

export interface SurpriseBrief {
  prompt: string;
  cuisine: string;
  protein: BaseProtein;
  method: CookingMethod;
  meal_slot: MealSlot;
  max_minutes: number | null;
  pantry_mode: PantryMode | null;
  ingredients: string[];
}

const METHOD_LABEL: Record<CookingMethod, string> = {
  oven: "oven",
  stovetop: "stovetop",
  sheet_pan: "sheet-pan",
  air_fryer: "air-fryer",
  slow_cooker: "crock-pot / slow-cooker",
  grill: "grill",
  no_cook: "no-cook",
  instant_pot: "Instant Pot",
  mixed: "mixed-method",
};

const PROTEIN_LABEL: Record<BaseProtein, string> = {
  chicken: "chicken",
  beef: "beef",
  pork: "pork",
  turkey: "turkey",
  fish: "fish",
  shrimp: "shrimp",
  tofu: "tofu",
  beans: "beans or lentils",
  eggs: "eggs",
  lamb: "lamb",
  none: "a vegetable-forward plate (no main animal protein)",
};

const CUISINE_SET = new Set<string>(
  SURPRISE_CUISINES.map((c) => c.toLowerCase()),
);
const TIME_SET = new Set<number>(SURPRISE_TIMES);
const SLOT_SET = new Set<string>(SURPRISE_SLOTS);

export function parseSurpriseConstraints(
  raw: unknown,
): ParsedSurpriseConstraints {
  const obj = raw && typeof raw === "object"
    ? raw as SurpriseConstraints
    : {};

  let max_minutes: number | null = null;
  if (typeof obj.max_minutes === "number" && TIME_SET.has(obj.max_minutes)) {
    max_minutes = obj.max_minutes;
  }

  let meal_slot: MealSlot | null = null;
  if (typeof obj.meal_slot === "string") {
    const slot = obj.meal_slot.trim().toLowerCase();
    if (SLOT_SET.has(slot) && slot !== "any") meal_slot = slot as MealSlot;
  }

  let cuisine: string | null = null;
  if (typeof obj.cuisine === "string") {
    const hit = SURPRISE_CUISINES.find(
      (c) => c.toLowerCase() === obj.cuisine!.trim().toLowerCase(),
    );
    if (hit) cuisine = hit;
  }

  let pantry_mode: PantryMode | null = null;
  if (obj.pantry_mode === "leftover" || obj.pantry_mode === "fridge") {
    pantry_mode = obj.pantry_mode;
  }

  let method: CookingMethod | null = null;
  if (typeof obj.method === "string") {
    const key = obj.method.trim().toLowerCase().replace(/[\s-]+/g, "_");
    const hit = SURPRISE_METHODS.find((m) => m === key);
    if (hit) method = hit;
  }

  const ingredients = sanitizeIngredientLocks(obj.ingredients);

  return { max_minutes, meal_slot, cuisine, pantry_mode, ingredients, method };
}

export function sanitizeIngredientLocks(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const clean = item.replace(/\s+/g, " ").trim().slice(0, 40);
    if (clean.length < 2) continue;
    const key = clean.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(clean);
    if (out.length >= 12) break;
  }
  return out;
}

export function parseExcludeTitles(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const clean = item.replace(/\s+/g, " ").trim().slice(0, 140);
    if (clean.length < 3) continue;
    const key = clean.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(clean);
    if (out.length >= 12) break;
  }
  return out;
}

export function allowedSurpriseProteins(prefs: unknown): BaseProtein[] {
  const { diets, allergies } = dietAllergyLists(prefs);
  let pool: BaseProtein[] = [...SURPRISE_PROTEINS];

  const vegan = diets.some((d) => d.includes("vegan"));
  const vegetarian = vegan || diets.some((d) => d.includes("vegetarian"));
  const pescatarian = diets.some((d) => d.includes("pescatarian"));

  if (vegan) {
    pool = pool.filter((p) => p === "tofu" || p === "beans" || p === "none");
  } else if (vegetarian) {
    pool = pool.filter((p) =>
      p === "tofu" || p === "beans" || p === "eggs" || p === "none"
    );
  } else if (pescatarian) {
    pool = pool.filter((p) =>
      p === "fish" ||
      p === "shrimp" ||
      p === "tofu" ||
      p === "beans" ||
      p === "eggs" ||
      p === "none"
    );
  }

  if (allergies.some((a) => a.includes("fish"))) {
    pool = pool.filter((p) => p !== "fish");
  }
  if (allergies.some((a) => a.includes("shellfish") || a.includes("shrimp"))) {
    pool = pool.filter((p) => p !== "shrimp");
  }
  if (allergies.some((a) => a === "egg" || a.startsWith("egg"))) {
    pool = pool.filter((p) => p !== "eggs");
  }
  if (allergies.some((a) => a.includes("soy"))) {
    pool = pool.filter((p) => p !== "tofu");
  }

  return pool.length > 0 ? pool : ["beans", "none"];
}

export function buildSurpriseBrief(opts: {
  prefs?: unknown;
  constraints?: ParsedSurpriseConstraints;
  excludeTitles?: string[];
  random?: () => number;
}): SurpriseBrief {
  const rand = opts.random ?? Math.random;
  const constraints = opts.constraints ?? parseSurpriseConstraints(null);
  const learned = readLearned(opts.prefs);

  const cuisine = constraints.cuisine ??
    pickWeighted(
      [...SURPRISE_CUISINES],
      (c) => 1 + (learned.cuisines[c] ?? 0),
      rand,
    );

  const proteins = allowedSurpriseProteins(opts.prefs);
  const protein = pickWeighted(
    proteins,
    (p) => 1 + (learned.proteins[p] ?? 0) * 2,
    rand,
  );

  let methods = [...SURPRISE_METHODS];
  if (constraints.max_minutes !== null && constraints.max_minutes <= 20) {
    methods = methods.filter((m) =>
      m === "stovetop" || m === "no_cook" || m === "air_fryer" || m === "sheet_pan"
    );
  }
  if (constraints.pantry_mode === "leftover") {
    methods = methods.filter((m) =>
      m === "stovetop" || m === "oven" || m === "no_cook" || m === "mixed"
    );
  }
  if (methods.length === 0) methods = ["stovetop"];
  const method = constraints.method ?? pickWeighted(methods, () => 1, rand);

  const meal_slot = constraints.meal_slot ??
    pickWeighted<MealSlot>(
      ["dinner", "lunch", "breakfast", "snack", "dessert"],
      (s) => s === "dinner" ? 3 : s === "lunch" ? 2 : 1,
      rand,
    );

  const parts = [
    `Surprise the cook with one complete ${meal_slot} recipe.`,
    `Cuisine: ${cuisine}.`,
    `Main protein: ${PROTEIN_LABEL[protein]}.`,
    `Primary method: ${METHOD_LABEL[method]}.`,
  ];

  if (constraints.max_minutes !== null) {
    parts.push(
      `Total prep + cook time must stay at or under ${constraints.max_minutes} minutes.`,
    );
  }

  if (constraints.pantry_mode === "leftover") {
    parts.push(
      constraints.ingredients.length > 0
        ? "Build the dish around the leftover ingredients in the UNTRUSTED DATA block — they are already cooked or leftover and should be the stars."
        : "Design a leftover-friendly dish that reheats well the next day.",
    );
  } else if (constraints.pantry_mode === "fridge") {
    parts.push(
      constraints.ingredients.length > 0
        ? "Use mainly the fridge items in the UNTRUSTED DATA block. Staples like oil, salt, pepper and water are available. Minimize anything new."
        : "Cook from a typical home fridge — common produce, dairy or leftovers — and minimize a store run.",
    );
  }

  if (learned.staples.length > 0 && !constraints.pantry_mode) {
    parts.push(
      `They often have ${learned.staples.slice(0, 6).join(", ")} around — use those if they fit.`,
    );
  }

  const exclude = (opts.excludeTitles ?? [])
    .map((t) => t.trim())
    .filter((t) => t.length >= 3)
    .slice(0, 12);
  if (exclude.length > 0) {
    parts.push(`Do not reuse these recent titles: ${exclude.join("; ")}.`);
  }

  parts.push("Invent a fresh dish — not a generic 'bowl' with no technique.");

  return {
    prompt: parts.join(" ").slice(0, 480),
    cuisine,
    protein,
    method,
    meal_slot,
    max_minutes: constraints.max_minutes,
    pantry_mode: constraints.pantry_mode,
    ingredients: constraints.ingredients,
  };
}

function dietAllergyLists(prefs: unknown): { diets: string[]; allergies: string[] } {
  if (!prefs || typeof prefs !== "object") return { diets: [], allergies: [] };
  const p = prefs as { diets?: unknown; allergies?: unknown };
  const diets = Array.isArray(p.diets)
    ? p.diets.map((d) => String(d).toLowerCase())
    : [];
  const allergies = Array.isArray(p.allergies)
    ? p.allergies.map((a) => String(a).toLowerCase())
    : [];
  return { diets, allergies };
}

function readLearned(prefs: unknown): {
  cuisines: Record<string, number>;
  proteins: Record<string, number>;
  staples: string[];
} {
  if (!prefs || typeof prefs !== "object") {
    return { cuisines: {}, proteins: {}, staples: [] };
  }
  const learned = (prefs as { learned?: unknown }).learned;
  if (!learned || typeof learned !== "object") {
    return { cuisines: {}, proteins: {}, staples: [] };
  }
  const row = learned as {
    cuisines?: unknown;
    proteins?: unknown;
    staples?: unknown;
  };
  return {
    cuisines: numberMap(row.cuisines),
    proteins: numberMap(row.proteins),
    staples: Array.isArray(row.staples)
      ? row.staples.map(String).map((s) => s.trim()).filter(Boolean).slice(0, 12)
      : [],
  };
}

function numberMap(raw: unknown): Record<string, number> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const out: Record<string, number> = {};
  for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
    const n = typeof v === "number" ? v : Number(v);
    if (Number.isFinite(n) && n > 0) out[k] = n;
  }
  return out;
}

export function pickWeighted<T>(
  items: T[],
  weight: (item: T) => number,
  random: () => number = Math.random,
): T {
  if (items.length === 0) {
    throw new Error("pickWeighted called with no items");
  }
  const weights = items.map((item) => Math.max(0.01, weight(item)));
  const total = weights.reduce((a, b) => a + b, 0);
  let cursor = random() * total;
  for (let i = 0; i < items.length; i++) {
    cursor -= weights[i];
    if (cursor <= 0) return items[i];
  }
  return items[items.length - 1];
}

export function cuisineAllowed(value: string): boolean {
  return CUISINE_SET.has(value.trim().toLowerCase());
}
