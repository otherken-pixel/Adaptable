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
import type { Recipe, ShoppingItem } from "@/lib/types";
import { useAuth } from "./AuthContext";

interface ShoppingState {
  items: ShoppingItem[];
  uncheckedCount: number;
  /** Adds all of a recipe's ingredients, scaled to the chosen servings. */
  addRecipe: (recipe: Recipe, scaleFactor: number) => void;
  toggle: (id: string) => void;
  remove: (id: string) => void;
  clearChecked: () => void;
}

const ShoppingContext = createContext<ShoppingState | null>(null);

export function ShoppingProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const [items, setItems] = useState<ShoppingItem[]>([]);

  useEffect(() => {
    if (!profile) {
      setItems([]);
      return;
    }
    let cancelled = false;
    fetchShoppingItems(profile.id)
      .then((rows) => !cancelled && setItems(rows))
      .catch(() => {
        /* list loads lazily; failures are non-fatal */
      });
    return () => {
      cancelled = true;
    };
  }, [profile]);

  const addRecipe = useCallback(
    (recipe: Recipe, scaleFactor: number) => {
      if (!profile) return;
      const rows = recipe.ingredients.map((ing) => ({
        recipe_id: recipe.id,
        recipe_title: recipe.title,
        item: ing.item,
        quantity: scaleQuantity(ing.quantity, scaleFactor),
      }));
      // Optimistic placeholder rows, replaced by server rows on success.
      const now = new Date().toISOString();
      const temp: ShoppingItem[] = rows.map((r, i) => ({
        ...r,
        id: `tmp-${Date.now()}-${i}`,
        checked: false,
        created_at: now,
      }));
      setItems((prev) => [...temp, ...prev]);
      addShoppingItems(profile.id, rows)
        .then((created) =>
          setItems((prev) => [
            ...created,
            ...prev.filter((it) => !temp.some((t) => t.id === it.id)),
          ]),
        )
        .catch(() =>
          setItems((prev) => prev.filter((it) => !temp.some((t) => t.id === it.id))),
        );
    },
    [profile],
  );

  const toggle = useCallback(
    (id: string) => {
      if (!profile) return;
      setItems((prev) => {
        const target = prev.find((i) => i.id === id);
        if (!target) return prev;
        const next = !target.checked;
        setShoppingItemChecked(profile.id, id, next).catch(() =>
          setItems((p) => p.map((i) => (i.id === id ? { ...i, checked: !next } : i))),
        );
        return prev.map((i) => (i.id === id ? { ...i, checked: next } : i));
      });
    },
    [profile],
  );

  const remove = useCallback(
    (id: string) => {
      if (!profile) return;
      setItems((prev) => {
        const removed = prev.find((i) => i.id === id);
        removeShoppingItem(profile.id, id).catch(
          () => removed && setItems((p) => [removed, ...p]),
        );
        return prev.filter((i) => i.id !== id);
      });
    },
    [profile],
  );

  const clearChecked = useCallback(() => {
    if (!profile) return;
    setItems((prev) => {
      const kept = prev.filter((i) => !i.checked);
      clearCheckedShoppingItems(profile.id).catch(() => setItems(prev));
      return kept;
    });
  }, [profile]);

  const uncheckedCount = useMemo(
    () => items.filter((i) => !i.checked).length,
    [items],
  );

  const value = useMemo(
    () => ({ items, uncheckedCount, addRecipe, toggle, remove, clearChecked }),
    [items, uncheckedCount, addRecipe, toggle, remove, clearChecked],
  );

  return <ShoppingContext.Provider value={value}>{children}</ShoppingContext.Provider>;
}

export function useShopping(): ShoppingState {
  const ctx = useContext(ShoppingContext);
  if (!ctx) throw new Error("useShopping must be used within ShoppingProvider");
  return ctx;
}
