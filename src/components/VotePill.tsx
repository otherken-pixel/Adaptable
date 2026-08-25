import { ArrowBigDown, ArrowBigUp } from "lucide-react";
import { useEngagement } from "@/context/EngagementContext";
import { useAuth } from "@/context/AuthContext";
import { compactCount } from "@/lib/format";
import { recordVoteTaste } from "@/lib/tasteMemory";
import type { Recipe } from "@/lib/types";

interface Props {
  recipeId: string;
  /** Server-known net upvotes (before the user's optimistic delta). */
  baseCount: number;
  size?: "sm" | "lg";
  /** When set, thumbs write into taste memory. */
  recipe?: Recipe;
}

/** Up/down voting pill with optimistic count, shared everywhere. */
export default function VotePill({ recipeId, baseCount, size = "sm", recipe }: Props) {
  const { votes, voteDelta, castVote } = useEngagement();
  const { profile, updatePreferences } = useAuth();
  const myVote = votes[recipeId] ?? 0;
  const count = baseCount + (voteDelta[recipeId] ?? 0);

  const iconSize = size === "lg" ? 22 : 18;
  const pad = size === "lg" ? "px-1.5 py-1.5" : "px-1 py-1";

  const vote = (value: 1 | -1) => {
    const current = myVote;
    const next = current === value ? null : value;
    castVote(recipeId, value);
    if (!recipe || !profile?.preferences || next === null) return;
    void updatePreferences(recordVoteTaste(recipe, next, profile.preferences));
  };

  return (
    <div
      className={`flex items-center rounded-full border border-line bg-raised ${pad} shadow-sm`}
      onClick={(e) => {
        // Cards wrap this pill in a link — voting shouldn't navigate.
        e.preventDefault();
        e.stopPropagation();
      }}
    >
      <button
        aria-label="Upvote"
        onClick={() => vote(1)}
        className={`pressable flex h-8 w-8 items-center justify-center rounded-full ${
          myVote === 1 ? "bg-accent-soft text-up" : "text-muted"
        }`}
      >
        <ArrowBigUp
          size={iconSize}
          strokeWidth={2}
          fill={myVote === 1 ? "currentColor" : "none"}
          className={myVote === 1 ? "animate-pop" : ""}
        />
      </button>
      <span
        className={`min-w-7 text-center text-sm font-bold tabular-nums ${
          myVote === 1 ? "text-up" : myVote === -1 ? "text-down" : "text-content"
        }`}
      >
        {compactCount(count)}
      </span>
      <button
        aria-label="Downvote"
        onClick={() => vote(-1)}
        className={`pressable flex h-8 w-8 items-center justify-center rounded-full ${
          myVote === -1 ? "bg-accent-soft text-down" : "text-muted"
        }`}
      >
        <ArrowBigDown
          size={iconSize}
          strokeWidth={2}
          fill={myVote === -1 ? "currentColor" : "none"}
          className={myVote === -1 ? "animate-pop" : ""}
        />
      </button>
    </div>
  );
}
