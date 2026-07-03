import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ChevronLeft, UserCheck, UserPlus } from "lucide-react";
import { fetchRecipe, fetchRecipePhotos } from "@/lib/api";
import type { Recipe, RecipePhoto } from "@/lib/types";
import RecipeView from "@/components/RecipeView";
import CommentsSection from "@/components/CommentsSection";
import EmptyState from "@/components/EmptyState";
import { useAuth } from "@/context/AuthContext";
import { useEngagement } from "@/context/EngagementContext";
import { timeAgo } from "@/lib/format";

export default function RecipeDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { profile } = useAuth();
  const { followedIds, toggleFollowChef } = useEngagement();
  const [recipe, setRecipe] = useState<Recipe | null | undefined>(undefined);
  const [photos, setPhotos] = useState<RecipePhoto[]>([]);

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    fetchRecipe(id)
      .then((r) => !cancelled && setRecipe(r))
      .catch(() => !cancelled && setRecipe(null));
    fetchRecipePhotos(id)
      .then((p) => !cancelled && setPhotos(p))
      .catch(() => {
        /* photo strip is optional */
      });
    return () => {
      cancelled = true;
    };
  }, [id]);

  const isOwnRecipe = recipe?.author_id === profile?.id;
  const following = recipe ? followedIds.has(recipe.author_id) : false;

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <div className="flex items-center pt-4 pb-3">
        <button
          aria-label="Back"
          onClick={() => (window.history.length > 1 ? navigate(-1) : navigate("/"))}
          className="pressable -ml-2 flex h-10 w-10 items-center justify-center rounded-full text-muted"
        >
          <ChevronLeft size={26} strokeWidth={2.4} />
        </button>
        {recipe?.author && (
          <p className="ml-1 min-w-0 flex-1 truncate text-sm font-semibold text-muted">
            by <span className="text-content">{recipe.author.username}</span>
          </p>
        )}
        {recipe && !isOwnRecipe && (
          <button
            onClick={() => toggleFollowChef(recipe.author_id)}
            className={`pressable flex shrink-0 items-center gap-1.5 rounded-full px-4 py-2 text-[13px] font-bold transition-colors ${
              following
                ? "bg-accent-soft text-accent"
                : "bg-content text-surface shadow-sm"
            }`}
          >
            {following ? (
              <>
                <UserCheck size={14} strokeWidth={2.6} /> Following
              </>
            ) : (
              <>
                <UserPlus size={14} strokeWidth={2.6} /> Follow
              </>
            )}
          </button>
        )}
      </div>

      {recipe === undefined && (
        <div className="space-y-4">
          <div className="skeleton h-56 rounded-card" />
          <div className="skeleton h-7 w-3/4 rounded-lg" />
          <div className="skeleton h-4 w-full rounded-lg" />
          <div className="skeleton h-24 rounded-card" />
        </div>
      )}

      {recipe === null && (
        <EmptyState
          emoji="🔍"
          title="Recipe not found"
          body="It may have been removed, or the link is off."
          action={
            <Link
              to="/"
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Back to Discover
            </Link>
          }
        />
      )}

      {recipe && (
        <>
          <RecipeView recipe={recipe} />

          {/* Community "I cooked it" photos */}
          {photos.length > 0 && (
            <section className="mt-8">
              <h2 className="text-lg font-extrabold tracking-tight">
                From the community's kitchens 📸
              </h2>
              <div className="scrollbar-none -mx-4 mt-3 flex gap-3 overflow-x-auto px-4">
                {photos.map((p) => (
                  <figure key={p.id} className="shrink-0">
                    <img
                      src={p.url}
                      alt="Community cooking result"
                      loading="lazy"
                      className="h-36 w-36 rounded-2xl border border-line object-cover"
                    />
                    <figcaption className="mt-1 text-center text-[11px] text-faint">
                      {timeAgo(p.created_at)}
                    </figcaption>
                  </figure>
                ))}
              </div>
            </section>
          )}

          <CommentsSection recipeId={recipe.id} />
        </>
      )}
    </div>
  );
}
