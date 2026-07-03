import { ArrowBigDown, ArrowBigUp } from "lucide-react";
import { useEngagement } from "@/context/EngagementContext";
import { compactCount } from "@/lib/format";

interface Props {
  recipeId: string;
  /** Server-known net upvotes (before the user's optimistic delta). */
  baseCount: number;
  size?: "sm" | "lg";
}

/** Up/down voting pill with optimistic count, shared everywhere. */
export default function VotePill({ recipeId, baseCount, size = "sm" }: Props) {
  const { votes, voteDelta, castVote } = useEngagement();
  const myVote = votes[recipeId] ?? 0;
  const count = baseCount + (voteDelta[recipeId] ?? 0);

  const iconSize = size === "lg" ? 22 : 18;
  const pad = size === "lg" ? "px-1.5 py-1.5" : "px-1 py-1";

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
        onClick={() => castVote(recipeId, 1)}
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
        onClick={() => castVote(recipeId, -1)}
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
