/**
 * Daily calorie / macro goals and per-plate planner math.
 * Keep in lockstep with src/lib/nutrition.ts helpers and iOS Nutrition.swift.
 *
 * Counting rule: one planned meal contributes eat_servings × per-serving
 * macros (default eat_servings = 1). Cook yield is ignored.
 */

export const CALORIE_PRESETS = [1600, 2000, 2400] as const;
export const PROTEIN_PRESETS = [100, 130, 160] as const;
export const DEFAULT_MEALS_PER_DAY = 3;
export const MIN_MEALS_PER_DAY = 1;
export const MAX_MEALS_PER_DAY = 6;
export const MIN_CALORIE_TARGET = 800;
export const MAX_CALORIE_TARGET = 5000;
export const MIN_MACRO_G = 10;
export const MAX_MACRO_G = 400;
export const MIN_EAT_SERVINGS = 1;
export const MAX_EAT_SERVINGS = 8;
export const GOAL_SLACK = 0.15;
export const CALORIE_LOCKS = [400, 500, 650] as const;
export const PROTEIN_LOCKS = [30, 40] as const;
export const FILL_MIN_CALORIES = 150;
export const FILL_MIN_PROTEIN = 10;

export interface NutritionGoals {
  calorie_target: number | null;
  protein_target_g: number | null;
  carbs_target_g: number | null;
  fat_target_g: number | null;
  meals_per_day: number;
}

export interface MacroSet {
  calories: number | null;
  protein_g: number | null;
  carbs_g: number | null;
  fat_g: number | null;
}

export interface DayNutrition {
  totals: MacroSet;
  unknownMeals: number;
  mealCount: number;
}

export interface RecipeMacros {
  calories?: number | null;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
}

export interface PlannedPlate {
  recipe?: RecipeMacros | null;
  eat_servings?: number | null;
}

function clampInt(value: unknown, min: number, max: number): number | null {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return null;
  const rounded = Math.round(n);
  if (rounded < min || rounded > max) return null;
  return rounded;
}

export function clampCalorieTarget(value: unknown): number | null {
  return clampInt(value, MIN_CALORIE_TARGET, MAX_CALORIE_TARGET);
}

export function clampMacroGrams(value: unknown): number | null {
  return clampInt(value, MIN_MACRO_G, MAX_MACRO_G);
}

export function clampMealsPerDay(value: unknown): number {
  return clampInt(value, MIN_MEALS_PER_DAY, MAX_MEALS_PER_DAY) ??
    DEFAULT_MEALS_PER_DAY;
}

export function clampEatServings(value: unknown): number {
  return clampInt(value, MIN_EAT_SERVINGS, MAX_EAT_SERVINGS) ?? 1;
}

export function parseNutritionGoals(prefs: unknown): NutritionGoals {
  const p = prefs && typeof prefs === "object"
    ? prefs as Record<string, unknown>
    : {};
  return {
    calorie_target: clampCalorieTarget(p.calorie_target),
    protein_target_g: clampMacroGrams(p.protein_target_g),
    carbs_target_g: clampMacroGrams(p.carbs_target_g),
    fat_target_g: clampMacroGrams(p.fat_target_g),
    meals_per_day: clampMealsPerDay(p.meals_per_day),
  };
}

export function hasAnyGoal(goals: NutritionGoals): boolean {
  return goals.calorie_target !== null ||
    goals.protein_target_g !== null ||
    goals.carbs_target_g !== null ||
    goals.fat_target_g !== null;
}

export function perMealBudget(goals: NutritionGoals): MacroSet {
  const n = Math.max(1, goals.meals_per_day);
  const split = (daily: number | null): number | null =>
    daily === null ? null : Math.round(daily / n);
  return {
    calories: split(goals.calorie_target),
    protein_g: split(goals.protein_target_g),
    carbs_g: split(goals.carbs_target_g),
    fat_g: split(goals.fat_target_g),
  };
}

function scaleMacro(value: number | null | undefined, plates: number): number | null {
  if (value === null || value === undefined) return null;
  if (!Number.isFinite(value)) return null;
  return Math.round(value * plates);
}

export function plateMacros(
  recipe: RecipeMacros | null | undefined,
  eatServings: unknown = 1,
): MacroSet {
  const plates = clampEatServings(eatServings);
  return {
    calories: scaleMacro(recipe?.calories, plates),
    protein_g: scaleMacro(recipe?.protein_g, plates),
    carbs_g: scaleMacro(recipe?.carbs_g, plates),
    fat_g: scaleMacro(recipe?.fat_g, plates),
  };
}

function addNullable(a: number | null, b: number | null): number | null {
  if (a === null && b === null) return null;
  return (a ?? 0) + (b ?? 0);
}

export function sumDayPlates(entries: PlannedPlate[]): DayNutrition {
  let totals: MacroSet = {
    calories: null,
    protein_g: null,
    carbs_g: null,
    fat_g: null,
  };
  let unknownMeals = 0;
  for (const entry of entries) {
    const plate = plateMacros(entry.recipe, entry.eat_servings);
    const missing = plate.calories === null && plate.protein_g === null &&
      plate.carbs_g === null && plate.fat_g === null;
    if (missing) {
      unknownMeals += 1;
      continue;
    }
    totals = {
      calories: addNullable(totals.calories, plate.calories),
      protein_g: addNullable(totals.protein_g, plate.protein_g),
      carbs_g: addNullable(totals.carbs_g, plate.carbs_g),
      fat_g: addNullable(totals.fat_g, plate.fat_g),
    };
  }
  return { totals, unknownMeals, mealCount: entries.length };
}

export function remainingBudget(
  goals: NutritionGoals,
  totals: MacroSet,
): MacroSet {
  const leftover = (daily: number | null, used: number | null): number | null => {
    if (daily === null) return null;
    return daily - (used ?? 0);
  };
  return {
    calories: leftover(goals.calorie_target, totals.calories),
    protein_g: leftover(goals.protein_target_g, totals.protein_g),
    carbs_g: leftover(goals.carbs_target_g, totals.carbs_g),
    fat_g: leftover(goals.fat_target_g, totals.fat_g),
  };
}

export function recipeFitsGoals(
  recipe: RecipeMacros,
  goals: NutritionGoals,
  slack = GOAL_SLACK,
): boolean {
  if (!hasAnyGoal(goals)) return false;
  const budget = perMealBudget(goals);
  if (budget.calories !== null) {
    if (recipe.calories === null || recipe.calories === undefined) return false;
    if (recipe.calories > Math.round(budget.calories * (1 + slack))) return false;
  }
  if (budget.protein_g !== null) {
    if (recipe.protein_g === null || recipe.protein_g === undefined) return false;
    if (recipe.protein_g < Math.round(budget.protein_g * (1 - slack))) return false;
  }
  if (budget.carbs_g !== null) {
    if (recipe.carbs_g === null || recipe.carbs_g === undefined) return false;
    const lo = Math.round(budget.carbs_g * (1 - slack));
    const hi = Math.round(budget.carbs_g * (1 + slack));
    if (recipe.carbs_g < lo || recipe.carbs_g > hi) return false;
  }
  if (budget.fat_g !== null) {
    if (recipe.fat_g === null || recipe.fat_g === undefined) return false;
    const lo = Math.round(budget.fat_g * (1 - slack));
    const hi = Math.round(budget.fat_g * (1 + slack));
    if (recipe.fat_g < lo || recipe.fat_g > hi) return false;
  }
  return true;
}

export function recipeGoalScore(recipe: RecipeMacros, goals: NutritionGoals): number {
  if (!hasAnyGoal(goals)) return 0;
  return recipeFitsGoals(recipe, goals) ? 3 : 0;
}

export function nutritionGoalsToPrompt(prefs: unknown): string {
  const goals = parseNutritionGoals(prefs);
  if (!hasAnyGoal(goals)) return "";
  const budget = perMealBudget(goals);
  const parts: string[] = [];
  if (goals.calorie_target !== null && budget.calories !== null) {
    parts.push(
      `The cook is aiming for about ${goals.calorie_target} calories per day across ${goals.meals_per_day} meals (around ${budget.calories} calories per serving).`,
    );
  }
  if (goals.protein_target_g !== null && budget.protein_g !== null) {
    parts.push(
      `They want about ${goals.protein_target_g} g protein per day (around ${budget.protein_g} g per serving).`,
    );
  }
  if (goals.carbs_target_g !== null && budget.carbs_g !== null) {
    parts.push(
      `Daily carb target is about ${goals.carbs_target_g} g (around ${budget.carbs_g} g per serving).`,
    );
  }
  if (goals.fat_target_g !== null && budget.fat_g !== null) {
    parts.push(
      `Daily fat target is about ${goals.fat_target_g} g (around ${budget.fat_g} g per serving).`,
    );
  }
  parts.push(
    "Stay close to those planning targets without sacrificing a complete, satisfying meal. These are estimates, not medical requirements.",
  );
  return parts.join(" ") + " ";
}

export function lockConstraintPrompt(
  maxCalories?: number | null,
  minProtein?: number | null,
): string {
  const parts: string[] = [];
  if (typeof maxCalories === "number" && maxCalories > 0) {
    parts.push(`Keep this at or under ${Math.round(maxCalories)} calories per serving.`);
  }
  if (typeof minProtein === "number" && minProtein > 0) {
    parts.push(`Include at least ${Math.round(minProtein)} g protein per serving.`);
  }
  return parts.length > 0 ? parts.join(" ") + " " : "";
}

export function suggestedFillSlot(now: Date = new Date()): string {
  const hour = now.getHours();
  if (hour < 11) return "breakfast";
  if (hour < 15) return "lunch";
  return "dinner";
}

export function fillTodayPrompt(opts: {
  remaining: MacroSet;
  slot?: string | null;
}): string {
  const slot = opts.slot || suggestedFillSlot();
  const bits: string[] = [`A complete ${slot} that finishes today's plan`];
  if (opts.remaining.calories !== null) {
    if (opts.remaining.calories >= FILL_MIN_CALORIES) {
      bits.push(`around ${opts.remaining.calories} calories`);
    } else if (opts.remaining.calories < 0) {
      bits.push("as light as possible on calories");
    }
  }
  if (
    opts.remaining.protein_g !== null &&
    opts.remaining.protein_g >= FILL_MIN_PROTEIN
  ) {
    bits.push(`at least ${opts.remaining.protein_g} g protein`);
  }
  return bits.join(", ") + ".";
}

export function formatPlateMeta(recipe: RecipeMacros, eatServings = 1): string {
  const plate = plateMacros(recipe, eatServings);
  const bits: string[] = [];
  if (plate.calories !== null) bits.push(`${plate.calories} cal`);
  if (plate.protein_g !== null) bits.push(`${plate.protein_g}g P`);
  return bits.join(" · ");
}

export function summarizeGoals(goals: NutritionGoals): string {
  const bits: string[] = [];
  if (goals.calorie_target !== null) bits.push(`${goals.calorie_target} cal`);
  if (goals.protein_target_g !== null) bits.push(`${goals.protein_target_g}g P`);
  if (goals.carbs_target_g !== null) bits.push(`${goals.carbs_target_g}g C`);
  if (goals.fat_target_g !== null) bits.push(`${goals.fat_target_g}g F`);
  return bits.join(" · ");
}

export function recipeFitLine(recipe: RecipeMacros, goals: NutritionGoals): string | null {
  if (!hasAnyGoal(goals)) return null;
  const budget = perMealBudget(goals);
  if (recipe.calories === null || recipe.calories === undefined) {
    return "No calorie estimate — check the ingredients if you are tracking today.";
  }
  if (budget.calories !== null) {
    const delta = recipe.calories - budget.calories;
    if (Math.abs(delta) <= Math.round(budget.calories * GOAL_SLACK)) {
      return `Fits your ~${budget.calories} cal per-meal budget.`;
    }
    if (delta > 0) {
      return `About ${delta} cal over your ~${budget.calories} cal per-meal target.`;
    }
    return `About ${Math.abs(delta)} cal under your ~${budget.calories} cal per-meal target.`;
  }
  if (budget.protein_g !== null) {
    if (recipe.protein_g === null || recipe.protein_g === undefined) {
      return "No protein estimate for this plate.";
    }
    const delta = recipe.protein_g - budget.protein_g;
    if (delta >= 0) return `Hits your ~${budget.protein_g} g protein per-meal target.`;
    return `About ${Math.abs(delta)} g short of your ~${budget.protein_g} g protein target.`;
  }
  return null;
}

export function shouldOfferFillToday(
  goals: NutritionGoals,
  remaining: MacroSet,
): boolean {
  if (!hasAnyGoal(goals)) return false;
  if (remaining.calories !== null && remaining.calories >= FILL_MIN_CALORIES) {
    return true;
  }
  if (remaining.protein_g !== null && remaining.protein_g >= FILL_MIN_PROTEIN) {
    return true;
  }
  if (remaining.calories !== null && remaining.calories < 0) return true;
  return false;
}

export function fillLocksFromRemaining(remaining: MacroSet): {
  maxCalories: number | null;
  minProtein: number | null;
} {
  const maxCalories = remaining.calories !== null && remaining.calories > 0
    ? Math.max(FILL_MIN_CALORIES, remaining.calories)
    : remaining.calories !== null && remaining.calories < 0
    ? CALORIE_LOCKS[0]
    : null;
  const minProtein =
    remaining.protein_g !== null && remaining.protein_g >= FILL_MIN_PROTEIN
      ? remaining.protein_g
      : null;
  return { maxCalories, minProtein };
}
