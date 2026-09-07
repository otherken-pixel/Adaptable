/**
 * Surprise-roll option lists for Create (web).
 * Keep in lockstep with supabase/functions/_shared/surprise.ts.
 */

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
  { id: "breakfast", label: "Breakfast" },
  { id: "lunch", label: "Lunch" },
  { id: "dinner", label: "Dinner" },
  { id: "snack", label: "Snack" },
  { id: "dessert", label: "Dessert" },
] as const;

export type PantryMode = "leftover" | "fridge";

export interface SurpriseConstraints {
  max_minutes?: number | null;
  meal_slot?: string | null;
  cuisine?: string | null;
  pantry_mode?: PantryMode | null;
  ingredients?: string[] | null;
  method?: string | null;
  max_calories?: number | null;
  min_protein?: number | null;
}

export function isPreviewRecipe(recipe: { id?: string } | null | undefined): boolean {
  return recipe?.id === "preview" || Boolean(recipe?.id?.startsWith("preview-"));
}
