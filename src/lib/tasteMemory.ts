/**
 * Quiet taste updates from keep / thumbs. Mirrors iOS TasteMemory.swift.
 * Allergies stay a hard server rule — this only drifts likes.
 */

import type { Preferences, Recipe } from "./types";

export interface LearnedTaste {
  cuisines?: Record<string, number>;
  proteins?: Record<string, number>;
  staples?: string[];
  spice_delta?: number;
}

function proteinFrom(recipe: Recipe): string | null {
  if (recipe.base_protein && recipe.base_protein !== "none") {
    return recipe.base_protein;
  }
  return null;
}

export function recordRecipeTaste(
  recipe: Recipe,
  prefs: Preferences,
  delta = 1,
): Preferences {
  const learned: LearnedTaste = { ...(prefs.learned ?? {}) };
  const cuisines = { ...(learned.cuisines ?? {}) };
  const proteins = { ...(learned.proteins ?? {}) };
  if (recipe.cuisine) {
    cuisines[recipe.cuisine] = (cuisines[recipe.cuisine] ?? 0) + delta;
  }
  const protein = proteinFrom(recipe);
  if (protein) {
    proteins[protein] = (proteins[protein] ?? 0) + delta;
  }
  return {
    ...prefs,
    learned: {
      ...learned,
      cuisines,
      proteins,
      staples: learned.staples ?? [],
      spice_delta: learned.spice_delta ?? 0,
    },
  };
}

export function recordVoteTaste(
  recipe: Recipe,
  value: 1 | -1,
  prefs: Preferences,
): Preferences {
  return recordRecipeTaste(recipe, prefs, value);
}
