import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { fetchMySaveIds, fetchMyVotes, setVote, toggleSave } from "@/lib/api";
import type { VoteValue } from "@/lib/types";
import { useAuth } from "./AuthContext";

/**
 * Shared optimistic state for votes + saves so every card, detail page
 * and the cookbook stay in sync instantly, before the server confirms.
 */
interface EngagementState {
  votes: Record<string, VoteValue>;
  savedIds: Set<string>;
  /** Local net_upvote deltas from the user's own optimistic votes. */
  voteDelta: Record<string, number>;
  castVote: (recipeId: string, value: VoteValue) => void;
  toggleSaved: (recipeId: string) => void;
}

const EngagementContext = createContext<EngagementState | null>(null);

export function EngagementProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const [votes, setVotes] = useState<Record<string, VoteValue>>({});
  const [savedIds, setSavedIds] = useState<Set<string>>(new Set());
  const [voteDelta, setVoteDelta] = useState<Record<string, number>>({});

  useEffect(() => {
    if (!profile) {
      setVotes({});
      setSavedIds(new Set());
      setVoteDelta({});
      return;
    }
    let cancelled = false;
    Promise.all([fetchMyVotes(profile.id), fetchMySaveIds(profile.id)])
      .then(([v, s]) => {
        if (cancelled) return;
        setVotes(v);
        setSavedIds(new Set(s));
      })
      .catch(() => {
        /* non-fatal: engagement state loads lazily */
      });
    return () => {
      cancelled = true;
    };
  }, [profile]);

  const castVote = useCallback(
    (recipeId: string, value: VoteValue) => {
      if (!profile) return;
      setVotes((prev) => {
        const current = prev[recipeId] ?? 0;
        const next: VoteValue | null = current === value ? null : value;
        setVoteDelta((d) => ({
          ...d,
          [recipeId]: (d[recipeId] ?? 0) - current + (next ?? 0),
        }));
        setVote(profile.id, recipeId, next).catch(() => {
          // Roll back on failure.
          setVotes((p) => ({ ...p, [recipeId]: current as VoteValue }));
          setVoteDelta((d) => ({
            ...d,
            [recipeId]: (d[recipeId] ?? 0) + current - (next ?? 0),
          }));
        });
        const copy = { ...prev };
        if (next === null) delete copy[recipeId];
        else copy[recipeId] = next;
        return copy;
      });
    },
    [profile],
  );

  const toggleSaved = useCallback(
    (recipeId: string) => {
      if (!profile) return;
      setSavedIds((prev) => {
        const wasSaved = prev.has(recipeId);
        const next = new Set(prev);
        if (wasSaved) next.delete(recipeId);
        else next.add(recipeId);
        toggleSave(profile.id, recipeId, wasSaved).catch(() => {
          setSavedIds((p) => {
            const rollback = new Set(p);
            if (wasSaved) rollback.add(recipeId);
            else rollback.delete(recipeId);
            return rollback;
          });
        });
        return next;
      });
    },
    [profile],
  );

  const value = useMemo(
    () => ({ votes, savedIds, voteDelta, castVote, toggleSaved }),
    [votes, savedIds, voteDelta, castVote, toggleSaved],
  );

  return (
    <EngagementContext.Provider value={value}>
      {children}
    </EngagementContext.Provider>
  );
}

export function useEngagement(): EngagementState {
  const ctx = useContext(EngagementContext);
  if (!ctx) throw new Error("useEngagement must be used within EngagementProvider");
  return ctx;
}
