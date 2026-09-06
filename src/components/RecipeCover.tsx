import { coverGradient } from "@/lib/gradients";

/** Dish photo when available; otherwise emoji on gradient (legacy recipes). */
export default function RecipeCover({
  recipeId,
  emoji,
  imageUrl,
  cuisine,
  heightClass = "h-44",
  emojiClass = "text-7xl",
  priority = false,
  width,
  height,
  children,
}: {
  recipeId: string;
  emoji?: string | null;
  imageUrl?: string | null;
  cuisine?: string | null;
  heightClass?: string;
  emojiClass?: string;
  /** Eager-load the LCP photo (marketing hero). Default stays lazy. */
  priority?: boolean;
  width?: number;
  height?: number;
  children?: React.ReactNode;
}) {
  return (
    <div
      className={`relative flex ${heightClass} items-center justify-center overflow-hidden bg-sunken`}
      style={{ background: coverGradient(recipeId) }}
    >
      {imageUrl ? (
        <img
          src={imageUrl}
          alt=""
          width={width}
          height={height}
          className="absolute inset-0 h-full w-full object-cover"
          loading={priority ? "eager" : "lazy"}
          fetchPriority={priority ? "high" : "auto"}
          decoding={priority ? "sync" : "async"}
        />
      ) : (
        <span
          className={`animate-float drop-shadow-[0_8px_16px_rgb(0_0_0/0.25)] ${emojiClass}`}
          aria-hidden
        >
          {emoji || "🍳"}
        </span>
      )}
      {imageUrl && (
        <div className="absolute inset-0 bg-gradient-to-t from-black/45 via-transparent to-black/10" />
      )}
      {cuisine ? (
        <span className="absolute bottom-3 left-3 rounded-full bg-black/40 px-3 py-1 text-xs font-bold tracking-wide text-white backdrop-blur-sm">
          {cuisine}
        </span>
      ) : null}
      {children}
    </div>
  );
}
