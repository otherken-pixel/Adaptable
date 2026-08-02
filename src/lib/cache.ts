/**
 * Stale-while-revalidate local cache for feed + recipes.
 * Speeds up revisits and keeps last-known data available offline.
 */

const FEED_KEY = "adaptable.cache.feed.v1";
const RECIPE_PREFIX = "adaptable.cache.recipe.v1.";
const MAX_RECIPE_ENTRIES = 40;

interface CacheEnvelope<T> {
  savedAt: number;
  data: T;
}

function read<T>(key: string): CacheEnvelope<T> | null {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw) as CacheEnvelope<T>;
  } catch {
    return null;
  }
}

function write<T>(key: string, data: T): void {
  try {
    localStorage.setItem(key, JSON.stringify({ savedAt: Date.now(), data }));
  } catch {
    /* quota — ignore */
  }
}

export function getCachedFeed<T>(): T | null {
  return read<T>(FEED_KEY)?.data ?? null;
}

export function setCachedFeed<T>(data: T): void {
  write(FEED_KEY, data);
}

export function getCachedRecipe<T>(id: string): T | null {
  return read<T>(RECIPE_PREFIX + id)?.data ?? null;
}

export function setCachedRecipe<T extends { id: string }>(recipe: T): void {
  write(RECIPE_PREFIX + recipe.id, recipe);
  // Bound growth: drop oldest keys beyond the cap.
  try {
    const keys = Object.keys(localStorage)
      .filter((k) => k.startsWith(RECIPE_PREFIX))
      .map((k) => {
        const env = read<unknown>(k);
        return { k, t: env?.savedAt ?? 0 };
      })
      .sort((a, b) => b.t - a.t);
    for (const { k } of keys.slice(MAX_RECIPE_ENTRIES)) {
      localStorage.removeItem(k);
    }
  } catch {
    /* ignore */
  }
}

export function isOnline(): boolean {
  return typeof navigator === "undefined" ? true : navigator.onLine;
}
