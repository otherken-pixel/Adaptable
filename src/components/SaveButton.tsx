import { Bookmark } from "lucide-react";
import { useEngagement } from "@/context/EngagementContext";

interface Props {
  recipeId: string;
  variant?: "icon" | "bar";
}

export default function SaveButton({ recipeId, variant = "icon" }: Props) {
  const { savedIds, toggleSaved } = useEngagement();
  const saved = savedIds.has(recipeId);

  if (variant === "bar") {
    return (
      <button
        onClick={() => toggleSaved(recipeId)}
        className={`pressable flex h-12 flex-1 items-center justify-center gap-2 rounded-2xl text-[15px] font-bold transition-colors ${
          saved
            ? "bg-accent-soft text-accent"
            : "bg-content text-surface shadow-lg"
        }`}
      >
        <Bookmark
          size={18}
          strokeWidth={2.4}
          fill={saved ? "currentColor" : "none"}
          className={saved ? "animate-pop" : ""}
        />
        {saved ? "In your Cookbook" : "Save to Cookbook"}
      </button>
    );
  }

  return (
    <button
      aria-label={saved ? "Remove from cookbook" : "Save to cookbook"}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleSaved(recipeId);
      }}
      className={`pressable flex h-10 w-10 items-center justify-center rounded-full border border-line bg-raised shadow-sm ${
        saved ? "text-accent" : "text-muted"
      }`}
    >
      <Bookmark
        size={18}
        strokeWidth={2.2}
        fill={saved ? "currentColor" : "none"}
        className={saved ? "animate-pop" : ""}
      />
    </button>
  );
}
