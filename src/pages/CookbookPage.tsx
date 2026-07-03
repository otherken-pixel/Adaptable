import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { fetchSavedRecipes } from "@/lib/api";
import type { Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import EmptyState from "@/components/EmptyState";
import { FeedSkeleton } from "@/components/Skeletons";
import { useAuth } from "@/context/AuthContext";
import { useEngagement } from "@/context/EngagementContext";

export default function CookbookPage() {
  const { profile } = useAuth();
  const { savedIds } = useEngagement();
  const [recipes, setRecipes] = useState<Recipe[] | null>(null);

  useEffect(() => {
    if (!profile) return;
    let cancelled = false;
    fetchSavedRecipes(profile.id)
      .then((r) => !cancelled && setRecipes(r))
      .catch(() => !cancelled && setRecipes([]));
    return () => {
      cancelled = true;
    };
    // Re-fetch when the saved set changes so unsaves disappear live.
  }, [profile, savedIds]);

  const visible = recipes?.filter((r) => savedIds.has(r.id)) ?? null;

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <header className="pt-6 pb-4">
        <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
          Your collection
        </p>
        <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
          Cookbook
        </h1>
      </header>

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
    </div>
  );
}
