import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ChevronLeft } from "lucide-react";
import { fetchRecipe } from "@/lib/api";
import type { Recipe } from "@/lib/types";
import RecipeView from "@/components/RecipeView";
import EmptyState from "@/components/EmptyState";

export default function RecipeDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [recipe, setRecipe] = useState<Recipe | null | undefined>(undefined);

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    fetchRecipe(id)
      .then((r) => !cancelled && setRecipe(r))
      .catch(() => !cancelled && setRecipe(null));
    return () => {
      cancelled = true;
    };
  }, [id]);

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
          <p className="ml-1 text-sm font-semibold text-muted">
            by <span className="text-content">{recipe.author.username}</span>
          </p>
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

      {recipe && <RecipeView recipe={recipe} />}
    </div>
  );
}
