import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { fetchRecipe } from "@/lib/api";
import type { Recipe } from "@/lib/types";
import { APP_STORE_URL } from "@/lib/site";
import MarketingLayout from "./MarketingLayout";
import AppStoreCta from "./AppStoreCta";

export default function GetAppPage({ kind }: { kind: "recipe" | "cook" }) {
  const { id } = useParams<{ id: string }>();
  const [recipe, setRecipe] = useState<Recipe | null | undefined>(undefined);

  useEffect(() => {
    if (!id) {
      setRecipe(null);
      return;
    }
    let cancelled = false;
    fetchRecipe(id)
      .then((r) => {
        if (!cancelled) setRecipe(r);
      })
      .catch(() => {
        if (!cancelled) setRecipe(null);
      });
    return () => {
      cancelled = true;
    };
  }, [id]);

  const title = recipe?.title;
  const heading =
    kind === "cook"
      ? title
        ? `Cook “${title}” in the app`
        : "Cook this in the Adaptable app"
      : title
        ? `Open “${title}” in the app`
        : "Open this recipe in the Adaptable app";

  return (
    <MarketingLayout title={title ?? "Get the app"}>
      <section className="mx-auto max-w-xl px-5 pt-14 pb-20 text-center">
        <p className="text-[11px] font-extrabold tracking-[0.14em] text-accent uppercase">
          iPhone app
        </p>
        <h1 className="mt-3 text-3xl font-extrabold tracking-tight sm:text-4xl">
          {heading}
        </h1>
        {recipe?.description ? (
          <p className="mt-4 text-[15px] leading-relaxed text-muted">
            {recipe.description}
          </p>
        ) : (
          <p className="mt-4 text-[15px] leading-relaxed text-muted">
            Recipes, Cook Mode, and your cookbook live in the iPhone app — not
            in the browser.
          </p>
        )}
        <div className="mt-8 flex flex-col items-center gap-4">
          <AppStoreCta size="lg" />
          {APP_STORE_URL ? null : (
            <p className="text-sm text-muted">
              If Adaptable is already on this iPhone, open the app to continue.
            </p>
          )}
        </div>
      </section>
    </MarketingLayout>
  );
}
