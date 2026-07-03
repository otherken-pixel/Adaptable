import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Check, Minus, Plus, ShoppingBasket, X } from "lucide-react";
import { fetchMealPlans, fetchSavedRecipes, removeMealPlan, updateMealPlanServings } from "@/lib/api";
import type { MealPlanEntry, Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import EmptyState from "@/components/EmptyState";
import { FeedSkeleton } from "@/components/Skeletons";
import { useAuth } from "@/context/AuthContext";
import { useEngagement } from "@/context/EngagementContext";
import { useShopping } from "@/context/ShoppingContext";
import { coverGradient } from "@/lib/gradients";

type Tab = "saved" | "planner";

export default function CookbookPage() {
  const { profile } = useAuth();
  const { savedIds } = useEngagement();
  const { addRecipe } = useShopping();
  const [tab, setTab] = useState<Tab>("saved");
  const [recipes, setRecipes] = useState<Recipe[] | null>(null);
  const [plans, setPlans] = useState<MealPlanEntry[] | null>(null);
  const [weekAdded, setWeekAdded] = useState(false);

  useEffect(() => {
    if (!profile) return;
    let cancelled = false;
    fetchSavedRecipes(profile.id)
      .then((r) => !cancelled && setRecipes(r))
      .catch(() => !cancelled && setRecipes([]));
    return () => {
      cancelled = true;
    };
  }, [profile, savedIds]);

  const loadPlans = useCallback(() => {
    if (!profile) return;
    fetchMealPlans(profile.id)
      .then(setPlans)
      .catch(() => setPlans([]));
  }, [profile]);

  useEffect(() => {
    loadPlans();
  }, [loadPlans]);

  const visible = recipes?.filter((r) => savedIds.has(r.id)) ?? null;

  // Upcoming plans grouped by day (past entries hidden).
  const grouped = useMemo(() => {
    if (!plans) return null;
    const today = new Date().toISOString().slice(0, 10);
    const upcoming = plans.filter((p) => p.plan_date >= today && p.recipe);
    const byDay = new Map<string, MealPlanEntry[]>();
    for (const p of upcoming) {
      const list = byDay.get(p.plan_date) ?? [];
      list.push(p);
      byDay.set(p.plan_date, list);
    }
    return [...byDay.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  }, [plans]);

  const upcomingCount = grouped?.reduce((n, [, list]) => n + list.length, 0) ?? 0;

  const dayLabel = (iso: string) => {
    const today = new Date().toISOString().slice(0, 10);
    const tomorrow = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
    if (iso === today) return "Today";
    if (iso === tomorrow) return "Tomorrow";
    return new Date(iso + "T12:00:00").toLocaleDateString(undefined, {
      weekday: "long",
      month: "short",
      day: "numeric",
    });
  };

  const changeServings = (entry: MealPlanEntry, delta: number) => {
    if (!profile) return;
    const next = Math.min(24, Math.max(1, entry.servings + delta));
    if (next === entry.servings) return;
    setPlans((prev) =>
      prev ? prev.map((p) => (p.id === entry.id ? { ...p, servings: next } : p)) : prev,
    );
    updateMealPlanServings(profile.id, entry.id, next).catch(loadPlans);
  };

  const remove = (entry: MealPlanEntry) => {
    if (!profile) return;
    setPlans((prev) => (prev ? prev.filter((p) => p.id !== entry.id) : prev));
    removeMealPlan(profile.id, entry.id).catch(loadPlans);
  };

  // The feature competitors miss: the whole upcoming plan → groceries,
  // scaled per-entry.
  const addWeekToGroceries = () => {
    if (!grouped || weekAdded) return;
    for (const [, entries] of grouped) {
      for (const entry of entries) {
        if (!entry.recipe) continue;
        addRecipe(entry.recipe, entry.servings / entry.recipe.servings);
      }
    }
    setWeekAdded(true);
    setTimeout(() => setWeekAdded(false), 2500);
  };

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <header className="flex items-end justify-between pt-6 pb-4">
        <div>
          <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
            Your kitchen
          </p>
          <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
            Cookbook
          </h1>
        </div>
        <div className="flex rounded-full bg-sunken p-1">
          {(
            [
              { id: "saved", label: "Saved" },
              { id: "planner", label: "Planner" },
            ] as const
          ).map(({ id, label }) => (
            <button
              key={id}
              onClick={() => setTab(id)}
              className={`pressable rounded-full px-4 py-1.5 text-[13px] font-bold transition-colors ${
                tab === id ? "bg-raised text-content shadow-sm" : "text-muted"
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </header>

      {tab === "saved" && (
        <>
          {visible === null && <FeedSkeleton />}
          {visible !== null && visible.length === 0 && (
            <EmptyState
              emoji="📖"
              title="Your cookbook is empty"
              body="Tap the bookmark on any recipe to keep it here forever."
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
          {visible !== null && visible.length > 0 && (
            <div className="space-y-4">
              {visible.map((r, i) => (
                <RecipeCard key={r.id} recipe={r} index={i} />
              ))}
            </div>
          )}
        </>
      )}

      {tab === "planner" && (
        <>
          {grouped === null && <FeedSkeleton />}

          {grouped !== null && upcomingCount === 0 && (
            <EmptyState
              emoji="🗓️"
              title="Nothing planned yet"
              body="Open any recipe and tap the calendar button to plan your week — then send the whole week to Groceries in one tap."
              action={
                <Link
                  to="/"
                  className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
                >
                  Find something delicious
                </Link>
              }
            />
          )}

          {grouped !== null && upcomingCount > 0 && (
            <>
              <button
                onClick={addWeekToGroceries}
                className={`pressable mb-5 flex h-13 w-full items-center justify-center gap-2 rounded-2xl text-[15px] font-extrabold transition-colors ${
                  weekAdded
                    ? "bg-accent-soft text-accent"
                    : "bg-content text-surface shadow-lg"
                }`}
              >
                {weekAdded ? (
                  <>
                    <Check size={18} strokeWidth={2.6} className="animate-pop" />
                    Everything's on the grocery list
                  </>
                ) : (
                  <>
                    <ShoppingBasket size={18} strokeWidth={2.2} />
                    Add {upcomingCount} planned {upcomingCount === 1 ? "meal" : "meals"} to Groceries
                  </>
                )}
              </button>

              <div className="space-y-6">
                {grouped.map(([iso, entries], gi) => (
                  <section
                    key={iso}
                    className="animate-fade-up"
                    style={{ animationDelay: `${gi * 60}ms` }}
                  >
                    <h2 className="mb-2 px-1 text-[15px] font-extrabold tracking-tight">
                      {dayLabel(iso)}
                    </h2>
                    <div className="space-y-2.5">
                      {entries.map((entry) => (
                        <div
                          key={entry.id}
                          className="flex items-center gap-3 rounded-2xl border border-line bg-raised p-3"
                        >
                          <Link
                            to={`/recipe/${entry.recipe_id}`}
                            className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl text-2xl"
                            style={{ background: coverGradient(entry.recipe_id) }}
                          >
                            {entry.recipe?.emoji ?? "🍽️"}
                          </Link>
                          <Link
                            to={`/recipe/${entry.recipe_id}`}
                            className="min-w-0 flex-1"
                          >
                            <p className="truncate text-[14px] leading-snug font-bold">
                              {entry.recipe?.title ?? "Recipe"}
                            </p>
                            <p className="text-xs text-faint">
                              {entry.recipe
                                ? `${entry.recipe.prep_time_minutes + entry.recipe.cook_time_minutes} min`
                                : ""}
                            </p>
                          </Link>
                          <div className="flex shrink-0 items-center gap-0.5 rounded-full bg-sunken p-0.5">
                            <button
                              aria-label="Fewer servings"
                              onClick={() => changeServings(entry, -1)}
                              className="pressable flex h-7 w-7 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
                            >
                              <Minus size={13} strokeWidth={2.6} />
                            </button>
                            <span className="min-w-6 text-center text-xs font-extrabold tabular-nums">
                              {entry.servings}
                            </span>
                            <button
                              aria-label="More servings"
                              onClick={() => changeServings(entry, 1)}
                              className="pressable flex h-7 w-7 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
                            >
                              <Plus size={13} strokeWidth={2.6} />
                            </button>
                          </div>
                          <button
                            aria-label="Remove from plan"
                            onClick={() => remove(entry)}
                            className="pressable flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-faint"
                          >
                            <X size={15} strokeWidth={2.4} />
                          </button>
                        </div>
                      ))}
                    </div>
                  </section>
                ))}
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
