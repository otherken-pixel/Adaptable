/**
 * Client-side allergy helpers (UI badges + Discover / Cook).
 * Implementation is the shared table in
 * `supabase/functions/_shared/allergenLexicon.ts` — same matcher the
 * edge functions use for 422. Keep iOS `AllergenLexicon.swift` in lockstep.
 */

export {
  TASTE_PROFILE_ALLERGY_CHIPS,
  canonicalAllergyKey,
  findAllergyViolations,
  findIngredientAllergyViolations,
  termsForAllergy,
} from "../../supabase/functions/_shared/allergenLexicon.ts";

import {
  findAllergyViolations,
  findIngredientAllergyViolations,
} from "../../supabase/functions/_shared/allergenLexicon.ts";

/** Full-recipe scan — badges and Discover For you. */
export function recipeMayContainAllergens(
  recipe: {
    title?: string;
    description?: string;
    ingredients?: Array<{ item?: string; note?: string }>;
    steps?: Array<{ instruction?: string }>;
  },
  allergies: string[] | undefined,
): string[] {
  if (!allergies?.length) return [];
  return findAllergyViolations(recipe, allergies);
}

/** Ingredient-only scan — Cook Mode hard-block. */
export function recipeIngredientsHitAllergens(
  recipe: {
    ingredients?: Array<{ item?: string; note?: string }>;
  },
  allergies: string[] | undefined,
): string[] {
  if (!allergies?.length) return [];
  return findIngredientAllergyViolations(recipe, allergies);
}
