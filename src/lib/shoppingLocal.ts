import type { ShoppingItem } from "./types";

/** localStorage-backed shopping list used in Demo Mode. */

const KEY = "adaptable.shopping.v1";

function load(): ShoppingItem[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw) as ShoppingItem[];
  } catch {
    /* corrupted — start fresh */
  }
  return [];
}

let items = load();

function persist() {
  try {
    localStorage.setItem(KEY, JSON.stringify(items));
  } catch {
    /* storage unavailable — keep in memory */
  }
}

function newId(): string {
  return typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `it-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export const shoppingLocal = {
  list(): ShoppingItem[] {
    return [...items];
  },
  add(
    rows: Array<Pick<ShoppingItem, "recipe_id" | "recipe_title" | "item" | "quantity">>,
  ): ShoppingItem[] {
    const created = rows.map((r) => ({
      ...r,
      id: newId(),
      checked: false,
      created_at: new Date().toISOString(),
    }));
    items = [...created, ...items];
    persist();
    return created;
  },
  setChecked(id: string, checked: boolean) {
    items = items.map((i) => (i.id === id ? { ...i, checked } : i));
    persist();
  },
  remove(id: string) {
    items = items.filter((i) => i.id !== id);
    persist();
  },
  clearChecked() {
    items = items.filter((i) => !i.checked);
    persist();
  },
};
