/**
 * Shared keepable-recipe checks for generate-recipe (preview + keep).
 * A keepable recipe needs a real ingredient list and cookable steps —
 * not just "≥2 of each".
 */

export const MIN_INGREDIENTS = 4;
export const MIN_STEPS = 3;
export const MIN_TITLE = 3;
export const MIN_ITEM = 2;
export const MIN_INSTRUCTION = 16;

export function isRealIngredient(ing: unknown): boolean {
  if (!ing || typeof ing !== "object") return false;
  const row = ing as { item?: unknown; quantity?: unknown };
  const item = typeof row.item === "string" ? row.item.trim() : "";
  const quantity = typeof row.quantity === "string" ? row.quantity.trim() : "";
  return item.length >= MIN_ITEM && quantity.length >= 1;
}

export function isCookableStep(step: unknown): boolean {
  if (!step || typeof step !== "object") return false;
  const row = step as { instruction?: unknown };
  const instruction = typeof row.instruction === "string"
    ? row.instruction.trim()
    : "";
  if (instruction.length < MIN_INSTRUCTION) return false;
  return /[a-z]/i.test(instruction);
}

/** True when the model output is complete enough to keep and cook. */
// deno-lint-ignore no-explicit-any
export function isValidRecipe(recipe: any): boolean {
  if (!recipe || typeof recipe !== "object") return false;
  const title = typeof recipe.title === "string" ? recipe.title.trim() : "";
  if (title.length < MIN_TITLE) return false;
  if (!Array.isArray(recipe.ingredients)) return false;
  if (recipe.ingredients.filter(isRealIngredient).length < MIN_INGREDIENTS) {
    return false;
  }
  if (!Array.isArray(recipe.steps)) return false;
  if (recipe.steps.filter(isCookableStep).length < MIN_STEPS) return false;
  return true;
}
