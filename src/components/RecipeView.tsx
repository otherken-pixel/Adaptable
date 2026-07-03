import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Check,
  ChefHat,
  Clock,
  CookingPot,
  Flame,
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
import { useShopping } from "@/context/ShoppingContext";
import VotePill from "./VotePill";
import SaveButton from "./SaveButton";

/** Full recipe render: hero, stats, scalable ingredient checklist, steps. */
export default function RecipeView({ recipe }: { recipe: Recipe }) {
  const navigate = useNavigate();
  const { addRecipe } = useShopping();
  const [checked, setChecked] = useState<Set<number>>(new Set());
  const [servings, setServings] = useState(recipe.servings);
  const [addedToList, setAddedToList] = useState(false);

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
              <span
                key={t}
                className="rounded-full bg-accent-soft px-3 py-1 text-xs font-bold text-accent"
              >
                {t}
              </span>
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
      </div>

      {/* Stat band */}
      <div className="mt-5 grid grid-cols-4 gap-2 rounded-card border border-line bg-raised p-3">
        <Stat icon={Clock} value={`${recipe.prep_time_minutes + recipe.cook_time_minutes}m`} label="Total" />
        <Stat icon={CookingPot} value={`${recipe.cook_time_minutes}m`} label="Cook" />
        <Stat icon={Users} value={String(servings)} label="Serves" />
        {recipe.calories ? (
          <Stat
            icon={Flame}
            value={String(Math.round(recipe.calories))}
            label="Cal/serv"
          />
        ) : (
          <Stat icon={Gauge} value={recipe.difficulty} label="Level" />
        )}
      </div>

      {/* Start cooking CTA */}
      <button
        onClick={() => navigate(`/cook/${recipe.id}?servings=${servings}`)}
        className="pressable mt-4 flex h-14 w-full items-center justify-center gap-2.5 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25"
        style={{
          background:
            "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
        }}
      >
        <ChefHat size={20} strokeWidth={2.2} />
        Start Cooking
      </button>

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
