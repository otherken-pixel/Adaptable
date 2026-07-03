import { useState } from "react";
import { Check, Clock, CookingPot, Flame, Gauge, Lightbulb, Share2, Users } from "lucide-react";
import type { Recipe } from "@/lib/types";
import { coverGradient } from "@/lib/gradients";
import VotePill from "./VotePill";
import SaveButton from "./SaveButton";

/** Full recipe render: hero, stats, tappable ingredient checklist, steps. */
export default function RecipeView({ recipe }: { recipe: Recipe }) {
  const [checked, setChecked] = useState<Set<number>>(new Set());

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
      </div>

      {/* Stat band */}
      <div className="mt-5 grid grid-cols-4 gap-2 rounded-card border border-line bg-raised p-3">
        <Stat icon={Clock} value={`${recipe.prep_time_minutes + recipe.cook_time_minutes}m`} label="Total" />
        <Stat icon={CookingPot} value={`${recipe.cook_time_minutes}m`} label="Cook" />
        <Stat icon={Users} value={String(recipe.servings)} label="Serves" />
        {recipe.calories ? (
          <Stat icon={Flame} value={String(recipe.calories)} label="Cal" />
        ) : (
          <Stat icon={Gauge} value={recipe.difficulty} label="Level" />
        )}
      </div>

      {/* Ingredients */}
      <section className="mt-7">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-extrabold tracking-tight">Ingredients</h2>
          <span className="text-xs font-semibold text-faint">
            {checked.size}/{recipe.ingredients.length} gathered
          </span>
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
                  {ing.quantity}
                </span>
              </button>
            );
          })}
        </div>
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
