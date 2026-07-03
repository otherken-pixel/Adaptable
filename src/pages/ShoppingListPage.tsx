import { useMemo } from "react";
import { Link } from "react-router-dom";
import { Check, Trash2, X } from "lucide-react";
import { useShopping } from "@/context/ShoppingContext";
import EmptyState from "@/components/EmptyState";
import type { ShoppingItem } from "@/lib/types";

export default function ShoppingListPage() {
  const { items, uncheckedCount, toggle, remove, clearChecked } = useShopping();

  const groups = useMemo(() => {
    const byRecipe = new Map<string, ShoppingItem[]>();
    for (const item of items) {
      const key = item.recipe_title || "Other items";
      const list = byRecipe.get(key) ?? [];
      list.push(item);
      byRecipe.set(key, list);
    }
    return [...byRecipe.entries()];
  }, [items]);

  const checkedCount = items.length - uncheckedCount;

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <header className="flex items-end justify-between pt-6 pb-4">
        <div>
          <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
            {uncheckedCount > 0 ? `${uncheckedCount} to grab` : "All set"}
          </p>
          <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
            Groceries
          </h1>
        </div>
        {checkedCount > 0 && (
          <button
            onClick={clearChecked}
            className="pressable flex items-center gap-1.5 rounded-full bg-sunken px-4 py-2 text-[13px] font-bold text-muted"
          >
            <Trash2 size={14} strokeWidth={2.4} />
            Clear done
          </button>
        )}
      </header>

      {items.length === 0 && (
        <EmptyState
          emoji="🛒"
          title="Nothing on the list"
          body="Open any recipe and tap “Add to groceries” — ingredients land here, scaled to your servings."
          action={
            <Link
              to="/"
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Browse recipes
            </Link>
          }
        />
      )}

      <div className="space-y-5">
        {groups.map(([title, groupItems], gi) => {
          const done = groupItems.filter((i) => i.checked).length;
          return (
            <section
              key={title}
              className="animate-fade-up"
              style={{ animationDelay: `${gi * 60}ms` }}
            >
              <div className="mb-2 flex items-baseline justify-between px-1">
                <h2 className="text-[15px] font-extrabold tracking-tight">{title}</h2>
                <span className="text-xs font-semibold text-faint">
                  {done}/{groupItems.length}
                </span>
              </div>
              <div className="overflow-hidden rounded-card border border-line bg-raised">
                {groupItems.map((item, i) => (
                  <div
                    key={item.id}
                    className={`flex items-center gap-3 px-4 py-3 transition-opacity ${
                      i > 0 ? "border-t border-line" : ""
                    } ${item.checked ? "opacity-45" : ""}`}
                  >
                    <button
                      aria-label={item.checked ? "Uncheck" : "Check off"}
                      onClick={() => toggle(item.id)}
                      className={`pressable flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 transition-colors ${
                        item.checked
                          ? "border-accent bg-accent text-white"
                          : "border-line"
                      }`}
                    >
                      {item.checked && (
                        <Check size={14} strokeWidth={3} className="animate-pop" />
                      )}
                    </button>
                    <button
                      onClick={() => toggle(item.id)}
                      className="min-w-0 flex-1 text-left"
                    >
                      <span
                        className={`block truncate text-[15px] font-semibold ${
                          item.checked ? "line-through" : ""
                        }`}
                      >
                        {item.item}
                      </span>
                    </button>
                    <span className="shrink-0 text-sm font-bold text-muted tabular-nums">
                      {item.quantity}
                    </span>
                    <button
                      aria-label="Remove item"
                      onClick={() => remove(item.id)}
                      className="pressable -mr-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-faint"
                    >
                      <X size={15} strokeWidth={2.4} />
                    </button>
                  </div>
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
