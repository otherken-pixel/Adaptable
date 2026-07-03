import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Sparkles } from "lucide-react";
import { fetchFeed } from "@/lib/api";
import type { FeedSort, Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import { FeedSkeleton } from "@/components/Skeletons";
import EmptyState from "@/components/EmptyState";
import { useAuth } from "@/context/AuthContext";

export default function FeedPage() {
  const [sort, setSort] = useState<FeedSort>("top");
  const [recipes, setRecipes] = useState<Recipe[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const { isDemo } = useAuth();

  useEffect(() => {
    let cancelled = false;
    setRecipes(null);
    setError(null);
    fetchFeed(sort)
      .then((r) => !cancelled && setRecipes(r))
      .catch(() => !cancelled && setError("Couldn't load the feed. Pull to retry."));
    return () => {
      cancelled = true;
    };
  }, [sort]);

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      {/* Header */}
      <header className="flex items-end justify-between pt-6 pb-4">
        <div>
          <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
            Adaptable
          </p>
          <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
            Discover
          </h1>
        </div>
        <SortToggle sort={sort} onChange={setSort} />
      </header>

      {isDemo && (
        <div className="animate-fade-up mb-4 flex items-center gap-2.5 rounded-2xl bg-accent-soft px-4 py-3 text-[13px] leading-snug font-medium text-accent">
          <Sparkles size={16} className="shrink-0" />
          Demo Mode — add Supabase keys in .env to go live. Everything here still
          works locally.
        </div>
      )}

      {error && (
        <EmptyState
          emoji="📡"
          title="Connection hiccup"
          body={error}
          action={
            <button
              onClick={() => setSort((s) => s)}
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Retry
            </button>
          }
        />
      )}

      {!error && recipes === null && <FeedSkeleton />}

      {!error && recipes !== null && recipes.length === 0 && (
        <EmptyState
          emoji="🍳"
          title="Nothing cooking yet"
          body="Be the first — describe what you're craving and let the AI take it from there."
          action={
            <Link
              to="/create"
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Generate a recipe
            </Link>
          }
        />
      )}

      {!error && recipes !== null && recipes.length > 0 && (
        <div className="space-y-4">
          {recipes.map((r, i) => (
            <RecipeCard key={r.id} recipe={r} index={i} />
          ))}
        </div>
      )}
    </div>
  );
}

function SortToggle({
  sort,
  onChange,
}: {
  sort: FeedSort;
  onChange: (s: FeedSort) => void;
}) {
  return (
    <div className="flex rounded-full bg-sunken p-1">
      {(["top", "new"] as const).map((s) => (
        <button
          key={s}
          onClick={() => onChange(s)}
          className={`pressable rounded-full px-4 py-1.5 text-[13px] font-bold capitalize transition-colors ${
            sort === s ? "bg-raised text-content shadow-sm" : "text-muted"
          }`}
        >
          {s}
        </button>
      ))}
    </div>
  );
}
