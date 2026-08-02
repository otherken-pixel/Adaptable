import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  addShoppingItems,
  clearCheckedShoppingItems,
  fetchShoppingItems,
  removeShoppingItem,
  setShoppingItemChecked,
} from "@/lib/api";
import { scaleQuantity } from "@/lib/quantity";
import { mergeQuantities, normalizeGroceryKey } from "@/lib/groceryMerge";
import { isOnline } from "@/lib/cache";
import type { Recipe, ShoppingItem } from "@/lib/types";
import { useAuth } from "./AuthContext";
import { useOnline } from "@/hooks/useOnline";

const QUEUE_KEY = "adaptable.shopping.offlineQueue.v1";

type QueueOp =
  | { type: "toggle"; id: string; checked: boolean }
  | { type: "remove"; id: string }
  | { type: "clearChecked" };

interface ShoppingState {
  items: ShoppingItem[];
  uncheckedCount: number;
  pendingSync: number;
  /** Adds all of a recipe's ingredients, scaled — merges duplicates. */
  addRecipe: (recipe: Recipe, scaleFactor: number) => void;
  toggle: (id: string) => void;
  remove: (id: string) => void;
  clearChecked: () => void;
}

const ShoppingContext = createContext<ShoppingState | null>(null);

function readQueue(): QueueOp[] {
  try {
    return JSON.parse(localStorage.getItem(QUEUE_KEY) ?? "[]") as QueueOp[];
  } catch {
    return [];
  }
}

function writeQueue(ops: QueueOp[]) {
  try {
    localStorage.setItem(QUEUE_KEY, JSON.stringify(ops));
  } catch {
    /* ignore */
  }
}

export function ShoppingProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const online = useOnline();
  const [items, setItems] = useState<ShoppingItem[]>([]);
  const [queue, setQueue] = useState<QueueOp[]>(() => readQueue());

  const enqueue = useCallback((op: QueueOp) => {
    setQueue((prev) => {
      const next = [...prev, op];
      writeQueue(next);
      return next;
    });
  }, []);

  const flushQueue = useCallback(
    async (userId: string, ops: QueueOp[]) => {
      if (!ops.length) return;
      const remaining: QueueOp[] = [];
      for (const op of ops) {
        try {
          if (op.type === "toggle") {
            await setShoppingItemChecked(userId, op.id, op.checked);
          } else if (op.type === "remove") {
            await removeShoppingItem(userId, op.id);
          } else if (op.type === "clearChecked") {
            await clearCheckedShoppingItems(userId);
          }
        } catch {
          remaining.push(op);
        }
      }
      writeQueue(remaining);
      setQueue(remaining);
      if (remaining.length < ops.length) {
        const rows = await fetchShoppingItems(userId);
        setItems(rows);
      }
    },
    [],
  );

  useEffect(() => {
    if (!profile) {
      setItems([]);
      return;
    }
    let cancelled = false;
    fetchShoppingItems(profile.id)
      .then((rows) => !cancelled && setItems(rows))
      .catch(() => {
        /* list loads lazily */
      });
    return () => {
      cancelled = true;
    };
  }, [profile]);

  // Flush offline ops when we come back online.
  useEffect(() => {
    if (!profile || !online || queue.length === 0) return;
    void flushQueue(profile.id, queue);
  }, [online, profile, queue, flushQueue]);

  const addRecipe = useCallback(
    (recipe: Recipe, scaleFactor: number) => {
      if (!profile) return;

      // Client-side merge: skip items already on list with same normalized name
      // for this recipe (or any recipe if names match exactly).
      const existingKeys = new Map(
        items
          .filter((i) => !i.checked)
          .map((i) => [normalizeGroceryKey(i.item), i] as const),
      );

      const toAdd: Array<{
        recipe_id: string;
        recipe_title: string;
        item: string;
        quantity: string;
      }> = [];
      const quantityPatches: Array<{ id: string; quantity: string }> = [];

      for (const ing of recipe.ingredients) {
        const key = normalizeGroceryKey(ing.item);
        const qty = scaleQuantity(ing.quantity, scaleFactor);
        const hit = existingKeys.get(key);
        if (hit) {
          // Already on list — merge quantities in UI; server keeps original row.
          quantityPatches.push({
            id: hit.id,
            quantity: mergeQuantities(hit.quantity, qty),
          });
        } else {
          toAdd.push({
            recipe_id: recipe.id,
            recipe_title: recipe.title,
            item: ing.item,
            quantity: qty,
          });
        }
      }

      if (quantityPatches.length) {
        setItems((prev) =>
          prev.map((i) => {
            const p = quantityPatches.find((x) => x.id === i.id);
            return p ? { ...i, quantity: p.quantity } : i;
          }),
        );
      }

      if (toAdd.length === 0) return;

      const now = new Date().toISOString();
      const temp: ShoppingItem[] = toAdd.map((r, i) => ({
        ...r,
        id: `tmp-${Date.now()}-${i}`,
        checked: false,
        created_at: now,
      }));
      setItems((prev) => [...temp, ...prev]);
      addShoppingItems(profile.id, toAdd)
        .then((created) =>
          setItems((prev) => [
            ...created,
            ...prev.filter((it) => !temp.some((t) => t.id === it.id)),
          ]),
        )
        .catch(() =>
          setItems((prev) =>
            prev.filter((it) => !temp.some((t) => t.id === it.id)),
          ),
        );
    },
    [profile, items],
  );

  const toggle = useCallback(
    (id: string) => {
      if (!profile) return;
      setItems((prev) => {
        const target = prev.find((i) => i.id === id);
        if (!target) return prev;
        const next = !target.checked;
        if (!isOnline()) {
          enqueue({ type: "toggle", id, checked: next });
        } else {
          setShoppingItemChecked(profile.id, id, next).catch(() =>
            setItems((p) =>
              p.map((i) => (i.id === id ? { ...i, checked: !next } : i)),
            ),
          );
        }
        return prev.map((i) => (i.id === id ? { ...i, checked: next } : i));
      });
    },
    [profile, enqueue],
  );

  const remove = useCallback(
    (id: string) => {
      if (!profile) return;
      setItems((prev) => {
        const removed = prev.find((i) => i.id === id);
        if (!isOnline()) {
          enqueue({ type: "remove", id });
        } else {
          removeShoppingItem(profile.id, id).catch(
            () => removed && setItems((p) => [removed, ...p]),
          );
        }
        return prev.filter((i) => i.id !== id);
      });
    },
    [profile, enqueue],
  );

  const clearChecked = useCallback(() => {
    if (!profile) return;
    setItems((prev) => {
      const kept = prev.filter((i) => !i.checked);
      if (!isOnline()) {
        enqueue({ type: "clearChecked" });
      } else {
        clearCheckedShoppingItems(profile.id).catch(() => setItems(prev));
      }
      return kept;
    });
  }, [profile, enqueue]);

  const uncheckedCount = useMemo(
    () => items.filter((i) => !i.checked).length,
    [items],
  );

  const value = useMemo(
    () => ({
      items,
      uncheckedCount,
      pendingSync: queue.length,
      addRecipe,
      toggle,
      remove,
      clearChecked,
    }),
    [items, uncheckedCount, queue.length, addRecipe, toggle, remove, clearChecked],
  );

  return (
    <ShoppingContext.Provider value={value}>{children}</ShoppingContext.Provider>
  );
}

export function useShopping(): ShoppingState {
  const ctx = useContext(ShoppingContext);
  if (!ctx) throw new Error("useShopping must be used within ShoppingProvider");
  return ctx;
}
