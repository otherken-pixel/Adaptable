export function RecipeCardSkeleton() {
  return (
    <div className="overflow-hidden rounded-card border border-line bg-raised">
      <div className="skeleton h-44" />
      <div className="space-y-3 p-4">
        <div className="skeleton h-5 w-3/4 rounded-lg" />
        <div className="skeleton h-4 w-full rounded-lg" />
        <div className="flex gap-2">
          <div className="skeleton h-6 w-16 rounded-full" />
          <div className="skeleton h-6 w-14 rounded-full" />
          <div className="skeleton h-6 w-18 rounded-full" />
        </div>
      </div>
    </div>
  );
}

export function FeedSkeleton() {
  return (
    <div className="space-y-4">
      <RecipeCardSkeleton />
      <RecipeCardSkeleton />
      <RecipeCardSkeleton />
    </div>
  );
}
