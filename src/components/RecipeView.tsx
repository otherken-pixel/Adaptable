import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  CalendarPlus,
  Check,
  ChefHat,
  Clock,
  CookingPot,
  ExternalLink,
  Gauge,
  Lightbulb,
  Minus,
  Plus,
  Share2,
  ShoppingBasket,
  Shuffle,
  Users,
} from "lucide-react";
import type { Recipe } from "@/lib/types";
import { coverGradient } from "@/lib/gradients";
import { scaleQuantity } from "@/lib/quantity";
import { localISODate } from "@/lib/format";
import { addMealPlan } from "@/lib/api";
import { useShopping } from "@/context/ShoppingContext";
import { useAuth } from "@/context/AuthContext";
import VotePill from "./VotePill";
import SaveButton from "./SaveButton";

function nextDays(count: number): Array<{ iso: string; label: string }> {
  const fmt = new Intl.DateTimeFormat(undefined, { weekday: "short" });
  return Array.from({ length: count }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() + i);
    // Local date, not toISOString(): UTC is already tomorrow in US evenings.
    const iso = localISODate(d);
    const label = i === 0 ? "Today" : i === 1 ? "Tomorrow" : fmt.format(d);
    return { iso, label };
  });
}

/** Full recipe render: hero, stats, scalable ingredient checklist, steps. */
export default function RecipeView({ recipe }: { recipe: Recipe }) {
  const navigate = useNavigate();
  const { addRecipe } = useShopping();
  const { profile } = useAuth();
  const [checked, setChecked] = useState<Set<number>>(new Set());
  const [servings, setServings] = useState(recipe.servings);
  const [addedToList, setAddedToList] = useState(false);
  const [planOpen, setPlanOpen] = useState(false);
  const [planned, setPlanned] = useState<string | null>(null);

  const planFor = (iso: string, label: string) => {
    if (!profile) return;
    addMealPlan(profile.id, recipe.id, iso, servings).catch(() => {});
    setPlanOpen(false);
    setPlanned(label);
    setTimeout(() => setPlanned(null), 2500);
  };

  const factor = servings / recipe.servings;

  const toggle = (i: number) =>
    setChecked((prev) => {
      const next = new Set(prev);
      if (next.has(i)) next.delete(i);
      else next.add(i);
      return next;
    });

  const share = async () => {
    const text = `${recipe.emoji} ${recipe.title} — made with Adaptable`;
    try {
      if (navigator.share) await navigator.share({ title: recipe.title, text });
      else await navigator.clipboard.writeText(text);
    } catch {
      /* user dismissed the share sheet */
    }
  };

  const addToGroceries = () => {
    if (addedToList) return;
    addRecipe(recipe, factor);
    setAddedToList(true);
    setTimeout(() => setAddedToList(false), 2500);
  };

  return (
    <div className="animate-fade-up">
      {/* Hero */}
      <div
        className="relative flex h-56 flex-col items-center justify-center rounded-card"
        style={{ background: coverGradient(recipe.id) }}
      >
        <span className="animate-float text-8xl drop-shadow-[0_10px_20px_rgb(0_0_0/0.3)]">
          {recipe.emoji}
        </span>
        <span className="absolute bottom-4 left-4 rounded-full bg-black/35 px-3 py-1 text-xs font-bold tracking-wide text-white backdrop-blur-sm">
          {recipe.cuisine}
        </span>
      </div>

      {/* Title block */}
      <div className="mt-5 space-y-3">
        <h1 className="text-[26px] leading-tight font-extrabold tracking-tight">
          {recipe.title}
        </h1>
        <p className="text-[15px] leading-relaxed text-muted">{recipe.description}</p>
        {recipe.tags.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {recipe.tags.map((t) => (
              <button
                key={t}
                onClick={() => navigate(`/?tag=${encodeURIComponent(t)}`)}
                className="pressable rounded-full bg-accent-soft px-3 py-1 text-xs font-bold text-accent"
              >
                {t}
              </button>
            ))}
          </div>
        )}
        {recipe.cook_count > 0 && (
          <p className="text-[13px] font-semibold text-muted">
            🍳 Cooked{" "}
            <span className="text-content">{recipe.cook_count.toLocaleString()}</span>{" "}
            {recipe.cook_count === 1 ? "time" : "times"} by the community
          </p>
        )}
        {recipe.source_url && (
          <a
            href={recipe.source_url}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="pressable inline-flex items-center gap-1.5 rounded-full bg-sunken px-3 py-1.5 text-xs font-bold text-muted"
          >
            <ExternalLink size={12} strokeWidth={2.4} />
            Imported from {safeHost(recipe.source_url)}
          </a>
        )}
      </div>

      {/* Stat band */}
      <div className="mt-5 grid grid-cols-4 gap-2 rounded-card border border-line bg-raised p-3">
        <Stat icon={Clock} value={`${recipe.prep_time_minutes + recipe.cook_time_minutes}m`} label="Total" />
        <Stat icon={CookingPot} value={`${recipe.cook_time_minutes}m`} label="Cook" />
        <Stat icon={Users} value={String(servings)} label="Serves" />
        <Stat icon={Gauge} value={recipe.difficulty} label="Level" />
      </div>

      {/* Nutrition per serving */}
      {(recipe.protein_g ?? recipe.carbs_g ?? recipe.fat_g) !== null && (
        <div className="mt-3 grid grid-cols-4 gap-2 rounded-card border border-line bg-raised p-3">
          <Macro value={recipe.calories} unit="" label="Calories" />
          <Macro value={recipe.protein_g} unit="g" label="Protein" />
          <Macro value={recipe.carbs_g} unit="g" label="Carbs" />
          <Macro value={recipe.fat_g} unit="g" label="Fat" />
        </div>
      )}

      {/* Start cooking + plan */}
      <div className="mt-4 flex gap-3">
        <button
          onClick={() => navigate(`/cook/${recipe.id}?servings=${servings}`)}
          className="pressable flex h-14 flex-1 items-center justify-center gap-2.5 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25"
          style={{
            background:
              "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
          }}
        >
          <ChefHat size={20} strokeWidth={2.2} />
          Start Cooking
        </button>
        <button
          aria-label="Add to meal plan"
          onClick={() => setPlanOpen(true)}
          className={`pressable flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl border transition-colors ${
            planned ? "border-accent bg-accent-soft text-accent" : "border-line bg-raised text-muted"
          }`}
        >
          {planned ? (
            <Check size={20} strokeWidth={2.6} className="animate-pop" />
          ) : (
            <CalendarPlus size={20} strokeWidth={2.2} />
          )}
        </button>
      </div>
      {planned && (
        <p className="animate-fade-up mt-2 text-center text-[13px] font-bold text-accent">
          Planned for {planned} ({servings} servings) — see it in Cookbook →
          Planner
        </p>
      )}

      {/* Day picker sheet */}
      {planOpen && (
        <div
          className="fixed inset-0 z-50 flex flex-col justify-end bg-black/45"
          onClick={() => setPlanOpen(false)}
        >
          <div
            className="animate-fade-up rounded-t-[28px] bg-surface p-5 pb-safe"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mx-auto mb-4 h-1.5 w-10 rounded-full bg-line" />
            <h3 className="text-lg font-extrabold tracking-tight">
              Plan “{recipe.title}”
            </h3>
            <p className="mt-1 text-sm text-muted">
              {servings} {servings === 1 ? "serving" : "servings"} — pick a day.
            </p>
            <div className="mt-4 mb-4 grid grid-cols-4 gap-2">
              {nextDays(8).map(({ iso, label }, i) => (
                <button
                  key={iso}
                  onClick={() => planFor(iso, label)}
                  className="pressable flex flex-col items-center rounded-2xl border border-line bg-raised py-3"
                >
                  <span className="text-[13px] font-extrabold">{label}</span>
                  <span className="text-[11px] text-faint">
                    {i === 0 ? "" : iso.slice(5).replace("-", "/")}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Ingredients */}
      <section className="mt-7">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-extrabold tracking-tight">Ingredients</h2>
          <div className="flex items-center gap-1 rounded-full bg-sunken p-1">
            <button
              aria-label="Fewer servings"
              onClick={() => setServings((s) => Math.max(1, s - 1))}
              className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
            >
              <Minus size={15} strokeWidth={2.6} />
            </button>
            <span className="min-w-16 text-center text-[13px] font-extrabold">
              {servings} {servings === 1 ? "serving" : "servings"}
            </span>
            <button
              aria-label="More servings"
              onClick={() => setServings((s) => Math.min(24, s + 1))}
              className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
            >
              <Plus size={15} strokeWidth={2.6} />
            </button>
          </div>
        </div>

        <div className="mt-3 overflow-hidden rounded-card border border-line bg-raised">
          {recipe.ingredients.map((ing, i) => {
            const done = checked.has(i);
            return (
              <button
                key={i}
                onClick={() => toggle(i)}
                className={`flex w-full items-center gap-3 px-4 py-3 text-left transition-opacity ${
                  i > 0 ? "border-t border-line" : ""
                } ${done ? "opacity-45" : ""}`}
              >
                <span
                  className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 transition-colors ${
                    done ? "border-accent bg-accent text-white" : "border-line"
                  }`}
                >
                  {done && <Check size={14} strokeWidth={3} className="animate-pop" />}
                </span>
                <span className="min-w-0 flex-1">
                  <span className={`block text-[15px] font-semibold ${done ? "line-through" : ""}`}>
                    {ing.item}
                  </span>
                  {ing.note && (
                    <span className="block text-xs text-faint">{ing.note}</span>
                  )}
                </span>
                <span className="shrink-0 text-sm font-bold text-muted tabular-nums">
                  {scaleQuantity(ing.quantity, factor)}
                </span>
              </button>
            );
          })}
        </div>

        <button
          onClick={addToGroceries}
          className={`pressable mt-3 flex h-12 w-full items-center justify-center gap-2 rounded-2xl border text-[14px] font-bold transition-colors ${
            addedToList
              ? "border-accent bg-accent-soft text-accent"
              : "border-line bg-raised text-content"
          }`}
        >
          {addedToList ? (
            <>
              <Check size={17} strokeWidth={2.6} className="animate-pop" />
              {recipe.ingredients.length} items added to Groceries
            </>
          ) : (
            <>
              <ShoppingBasket size={17} strokeWidth={2.2} />
              Add all to Groceries
            </>
          )}
        </button>
      </section>

      {/* Steps */}
      <section className="mt-7">
        <h2 className="text-lg font-extrabold tracking-tight">Method</h2>
        <ol className="mt-3 space-y-3">
          {recipe.steps.map((s) => (
            <li
              key={s.step}
              className="rounded-card border border-line bg-raised p-4"
            >
              <div className="flex gap-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-content text-[13px] font-extrabold text-surface">
                  {s.step}
                </span>
                <p className="pt-0.5 text-[15px] leading-relaxed">{s.instruction}</p>
              </div>
              {s.tip && (
                <div className="mt-3 ml-10 flex items-start gap-2 rounded-xl bg-accent-soft px-3 py-2">
                  <Lightbulb size={14} className="mt-0.5 shrink-0 text-accent" />
                  <p className="text-[13px] leading-snug font-medium text-accent">
                    {s.tip}
                  </p>
                </div>
              )}
            </li>
          ))}
        </ol>
      </section>

      {/* Action bar */}
      <div className="mt-7 flex items-center gap-3">
        <VotePill recipeId={recipe.id} baseCount={recipe.net_upvotes} size="lg" />
        <SaveButton recipeId={recipe.id} variant="bar" />
        <button
          aria-label="Share"
          onClick={share}
          className="pressable flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl border border-line bg-raised text-muted"
        >
          <Share2 size={19} strokeWidth={2.2} />
        </button>
      </div>

      {/* Remix */}
      <button
        onClick={() => navigate(`/create?remix=${recipe.id}`)}
        className="pressable mt-3 flex h-12 w-full items-center justify-center gap-2 rounded-2xl border border-dashed border-line text-[14px] font-bold text-muted"
      >
        <Shuffle size={16} strokeWidth={2.2} className="text-accent" />
        Remix this recipe — make it yours
      </button>
    </div>
  );
}

function safeHost(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "source";
  }
}

function Macro({
  value,
  unit,
  label,
}: {
  value: number | null;
  unit: string;
  label: string;
}) {
  return (
    <div className="flex flex-col items-center gap-0.5 py-1">
      <span className="text-[15px] font-extrabold tabular-nums">
        {value !== null ? `${value}${unit}` : "—"}
      </span>
      <span className="text-[10px] font-semibold tracking-wide text-faint uppercase">
        {label}
      </span>
    </div>
  );
}

function Stat({
  icon: Icon,
  value,
  label,
}: {
  icon: typeof Clock;
  value: string;
  label: string;
}) {
  return (
    <div className="flex flex-col items-center gap-0.5 py-1">
      <Icon size={17} strokeWidth={2.2} className="text-accent" />
      <span className="text-[15px] font-extrabold tabular-nums">{value}</span>
      <span className="text-[10px] font-semibold tracking-wide text-faint uppercase">
        {label}
      </span>
    </div>
  );
}
