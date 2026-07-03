import { Link } from "react-router-dom";
import { Clock, Flame, Gauge } from "lucide-react";
import type { Recipe } from "@/lib/types";
import { coverGradient } from "@/lib/gradients";
import { timeAgo, totalMinutes } from "@/lib/format";
import VotePill from "./VotePill";
import SaveButton from "./SaveButton";

export default function RecipeCard({
  recipe,
  index = 0,
}: {
  recipe: Recipe;
  index?: number;
}) {
  return (
    <Link
      to={`/recipe/${recipe.id}`}
      className="animate-fade-up block overflow-hidden rounded-card border border-line bg-raised shadow-[0_2px_16px_rgb(0_0_0/0.05)]"
      style={{ animationDelay: `${Math.min(index, 8) * 60}ms` }}
    >
      {/* Cover */}
      <div
        className="relative flex h-44 items-center justify-center"
        style={{ background: coverGradient(recipe.id) }}
      >
        <span className="animate-float text-7xl drop-shadow-[0_8px_16px_rgb(0_0_0/0.25)]">
          {recipe.emoji}
        </span>
        <div className="absolute top-3 right-3">
          <SaveButton recipeId={recipe.id} />
        </div>
        <span className="absolute bottom-3 left-3 rounded-full bg-black/35 px-3 py-1 text-xs font-bold tracking-wide text-white backdrop-blur-sm">
          {recipe.cuisine}
        </span>
      </div>

      {/* Body */}
      <div className="space-y-3 p-4">
        <div>
          <h3 className="text-[17px] leading-snug font-bold tracking-tight">
            {recipe.title}
          </h3>
          <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-muted">
            {recipe.description}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Meta icon={Clock} label={totalMinutes(recipe.prep_time_minutes, recipe.cook_time_minutes)} />
          <Meta icon={Gauge} label={recipe.difficulty} />
          {recipe.calories ? <Meta icon={Flame} label={`${recipe.calories} cal`} /> : null}
        </div>

        <div className="flex items-center justify-between border-t border-line pt-3">
          <div className="flex min-w-0 items-center gap-2">
            <span
              className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[11px] font-bold text-white"
              style={{ background: coverGradient(recipe.author?.username ?? recipe.author_id) }}
            >
              {(recipe.author?.username ?? "?").slice(0, 1).toUpperCase()}
            </span>
            <div className="min-w-0 leading-tight">
              <p className="truncate text-xs font-semibold">
                {recipe.author?.username ?? "anonymous"}
              </p>
              <p className="text-[11px] text-faint">{timeAgo(recipe.created_at)}</p>
            </div>
          </div>
          <VotePill recipeId={recipe.id} baseCount={recipe.net_upvotes} />
        </div>
      </div>
    </Link>
  );
}

function Meta({
  icon: Icon,
  label,
}: {
  icon: typeof Clock;
  label: string;
}) {
  return (
    <span className="flex items-center gap-1 rounded-full bg-sunken px-2.5 py-1 text-xs font-semibold text-muted">
      <Icon size={13} strokeWidth={2.2} />
      {label}
    </span>
  );
}
