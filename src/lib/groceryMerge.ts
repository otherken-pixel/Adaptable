/**
 * Dedupe / merge grocery lines when adding a recipe again.
 * Matches on normalized item name within the same recipe block when possible.
 */

export function normalizeGroceryKey(item: string): string {
  return item
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Prefer keeping an existing quantity; if both present, join lightly. */
export function mergeQuantities(existing: string, incoming: string): string {
  const a = existing.trim();
  const b = incoming.trim();
  if (!a) return b;
  if (!b || a === b) return a;
  // Avoid noisy "1 cup + 1 cup" explosion — keep first and note extra.
  if (a.toLowerCase().includes(b.toLowerCase())) return a;
  return `${a} + ${b}`;
}
