import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Check, Minus, Plus, ShoppingBasket, X } from "lucide-react";
import {
  fetchMealPlans,
  fetchSavedRecipes,
  removeMealPlan,
  updateMealPlanEatServings,
  updateMealPlanServings,
} from "@/lib/api";
import type { MealPlanEntry, Recipe } from "@/lib/types";
import {
  clampEatServings,
  formatPlateMeta,
  hasAnyGoal,
  parseNutritionGoals,
  remainingBudget,
  shouldOfferFillToday,
  suggestedFillSlot,
  sumDayPlates,
} from "@/lib/nutrition";
import RecipeCard from "@/components/RecipeCard";
import EmptyState from "@/components/EmptyState";
import { FeedSkeleton } from "@/components/Skeletons";
import { useAuth } from "@/context/AuthContext";
import { useEngagement } from "@/context/EngagementContext";
import { useShopping } from "@/context/ShoppingContext";
import { coverGradient } from "@/lib/gradients";
import { localISODate } from "@/lib/format";

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
    const today = localISODate();
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
    const today = localISODate();
    const tomorrow = localISODate(new Date(Date.now() + 86_400_000));
    if (iso === today) return "Today";
    if (iso === tomorrow) return "Tomorrow";
    return new Date(iso + "T12:00:00").toLocaleDateString(undefined, {
      weekday: "long",
      month: "short",
      day: "numeric",
    });
  };

  const goals = parseNutritionGoals(profile?.preferences);

  const fillHref = (remaining: ReturnType<typeof remainingBudget>) => {
    const slot = suggestedFillSlot();
    const params = new URLSearchParams({ fill: "1", slot });
    if (remaining.calories != null) params.set("cal", String(remaining.calories));
    if (remaining.protein_g != null) params.set("protein", String(remaining.protein_g));
    return `/create?${params.toString()}`;
  };

  const changeEatServings = (entry: MealPlanEntry, delta: number) => {
    if (!profile) return;
    const current = clampEatServings(entry.eat_servings);
    const next = clampEatServings(current + delta);
    if (next === current) return;
    setPlans((prev) =>
      prev
        ? prev.map((p) => (p.id === entry.id ? { ...p, eat_servings: next } : p))
        : prev,
    );
    updateMealPlanEatServings(profile.id, entry.id, next).catch(loadPlans);
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
                <div className="flex flex-col items-center gap-2">
                  <Link
                    to="/"
                    className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
                  >
                    Find something delicious
                  </Link>
                  {hasAnyGoal(goals) && (
                    <Link
                      to={fillHref(remainingBudget(goals, {
                        calories: null,
                        protein_g: null,
                        carbs_g: null,
                        fat_g: null,
                      }))}
                      className="pressable rounded-full bg-accent-soft px-5 py-2 text-sm font-bold text-accent"
                    >
                      Generate a plate for today
                    </Link>
                  )}
                </div>
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
                    <DayNutritionCard
                      entries={entries}
                      goals={goals}
                      fillHref={fillHref}
                      isToday={iso === localISODate()}
                    />
                    <div className="space-y-2.5">
                      {entries.map((entry) => {
                        const eat = clampEatServings(entry.eat_servings);
                        const macros = formatPlateMeta(entry.recipe ?? {}, eat);
                        return (
                        <div
                          key={entry.id}
                          className="rounded-2xl border border-line bg-raised p-3"
                        >
                          <div className="flex items-center gap-3">
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
                              {[
                                entry.recipe
                                  ? `${entry.recipe.prep_time_minutes + entry.recipe.cook_time_minutes} min`
                                  : "",
                                macros,
                              ]
                                .filter(Boolean)
                                .join(" · ")}
                            </p>
                          </Link>
                          <button
                            aria-label="Remove from plan"
                            onClick={() => remove(entry)}
                            className="pressable flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-faint"
                          >
                            <X size={15} strokeWidth={2.4} />
                          </button>
                          </div>
                          <div className="mt-2 flex flex-wrap gap-2">
                            <MiniStepper
                              label="Cook"
                              value={entry.servings}
                              onChange={(d) => changeServings(entry, d)}
                            />
                            <MiniStepper
                              label="Eat"
                              value={eat}
                              onChange={(d) => changeEatServings(entry, d)}
                            />
                          </div>
                        </div>
                        );
                      })}
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

function DayNutritionCard({
  entries,
  goals,
  fillHref,
  isToday,
}: {
  entries: MealPlanEntry[];
  goals: ReturnType<typeof parseNutritionGoals>;
  fillHref: (remaining: ReturnType<typeof remainingBudget>) => string;
  isToday: boolean;
}) {
  const day = sumDayPlates(entries);
  const remaining = remainingBudget(goals, day.totals);
  const bits: string[] = [];
  if (day.totals.calories != null) {
    bits.push(
      goals.calorie_target
        ? `${day.totals.calories} / ${goals.calorie_target} cal`
        : `${day.totals.calories} cal planned`,
    );
  }
  if (day.totals.protein_g != null) {
    bits.push(
      goals.protein_target_g
        ? `${day.totals.protein_g} / ${goals.protein_target_g}g P`
        : `${day.totals.protein_g}g P`,
    );
  }
  const progress =
    goals.calorie_target && goals.calorie_target > 0
      ? Math.min(1, (day.totals.calories ?? 0) / goals.calorie_target)
      : 0;
  const fillLabel =
    remaining.calories != null && remaining.calories < 0
      ? "Generate a lighter plate"
      : remaining.calories != null && remaining.calories >= 150
        ? `Generate something ~${remaining.calories} cal to finish today`
        : "Generate a plate that finishes today";

  return (
    <div className="mb-2.5 rounded-2xl bg-sunken px-3 py-3">
      <div className="flex items-center justify-between gap-2">
        <p className="text-[12px] font-bold text-muted">
          {bits.join(" · ") || "No nutrition estimates yet"}
        </p>
        {!hasAnyGoal(goals) && (
          <Link to="/taste" className="text-[12px] font-extrabold text-accent">
            Set goals
          </Link>
        )}
      </div>
      {hasAnyGoal(goals) && goals.calorie_target ? (
        <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-raised">
          <div
            className="h-full rounded-full bg-accent"
            style={{ width: `${Math.round(progress * 100)}%` }}
          />
        </div>
      ) : null}
      {day.unknownMeals > 0 && (
        <p className="mt-1.5 text-[11px] font-semibold text-faint">
          {day.unknownMeals === 1
            ? "1 meal has no estimate"
            : `${day.unknownMeals} meals have no estimate`}
        </p>
      )}
      {shouldOfferFillToday(goals, remaining, isToday) && (
        <Link
          to={fillHref(remaining)}
          className="mt-2 inline-block text-[13px] font-extrabold text-accent"
        >
          {fillLabel}
        </Link>
      )}
    </div>
  );
}

function MiniStepper({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (delta: number) => void;
}) {
  return (
    <div className="flex items-center gap-1 rounded-full bg-sunken p-0.5">
      <span className="pl-2 text-[11px] font-bold text-faint">{label}</span>
      <button
        aria-label={`Fewer ${label.toLowerCase()} servings`}
        onClick={() => onChange(-1)}
        className="pressable flex h-7 w-7 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
      >
        <Minus size={13} strokeWidth={2.6} />
      </button>
      <span className="min-w-6 text-center text-xs font-extrabold tabular-nums">
        {value}
      </span>
      <button
        aria-label={`More ${label.toLowerCase()} servings`}
        onClick={() => onChange(1)}
        className="pressable flex h-7 w-7 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
      >
        <Plus size={13} strokeWidth={2.6} />
      </button>
    </div>
  );
}
