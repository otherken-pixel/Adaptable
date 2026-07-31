import type { Recipe } from "./types";
import { totalMinutes } from "./format";
import { scaleQuantity } from "./quantity";
import { recipeShareURL, SITE_URL } from "./site";

export interface SharePayload {
  title: string;
  /** Full recipe body without trailing URL (for Web Share `text` + separate `url`). */
  text: string;
  /** Full recipe body including URL (clipboard / plain-text targets). */
  textWithUrl: string;
  url: string;
}

/**
 * Build a best-in-class share payload for iMessage and other targets:
 * full scaled recipe as plain text (cookable without the app) + deep link URL.
 */
export function buildRecipeShare(
  recipe: Recipe,
  servings: number = recipe.servings,
): SharePayload {
  const factor = recipe.servings > 0 ? servings / recipe.servings : 1;
  const url = recipeShareURL(recipe.id);
  const emoji = recipe.emoji?.trim() || "🍳";
  const title = recipe.title?.trim() || "Recipe";
  const lines: string[] = [];

  lines.push(`${emoji} ${title}`);
  lines.push("");

  if (recipe.description?.trim()) {
    lines.push(recipe.description.trim());
    lines.push("");
  }

  const meta: string[] = [];
  const mins = totalMinutes(
    recipe.prep_time_minutes ?? 0,
    recipe.cook_time_minutes ?? 0,
  );
  if (mins) meta.push(`⏱ ${mins}`);
  if (recipe.difficulty) meta.push(recipe.difficulty);
  meta.push(`Serves ${servings}`);
  lines.push(meta.join(" · "));
  lines.push("");

  const ingredients = recipe.ingredients ?? [];
  if (ingredients.length > 0) {
    lines.push("INGREDIENTS");
    for (const ing of ingredients) {
      const qty = scaleQuantity(ing.quantity, factor);
      const note = ing.note?.trim() ? ` (${ing.note.trim()})` : "";
      const qtyPart = qty?.trim() ? `${qty.trim()} ` : "";
      lines.push(`• ${qtyPart}${ing.item}${note}`);
    }
    lines.push("");
  }

  const steps = recipe.steps ?? [];
  if (steps.length > 0) {
    lines.push("METHOD");
    for (const step of steps) {
      lines.push(`${step.step}. ${step.instruction.trim()}`);
      if (step.tip?.trim()) {
        lines.push(`   💡 ${step.tip.trim()}`);
      }
    }
    lines.push("");
  }

  lines.push("Made with Adaptable");
  const text = lines.join("\n").trim();
  const textWithUrl = `${text}\n${url}`;

  return {
    title: `${emoji} ${title}`,
    text,
    textWithUrl,
    url,
  };
}

export { SITE_URL, recipeShareURL };
