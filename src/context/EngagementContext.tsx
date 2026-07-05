import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  fetchFollowees,
  fetchMySaveIds,
  fetchMyVotes,
  setFollow,
  setVote,
  toggleSave,
} from "@/lib/api";
import type { VoteValue } from "@/lib/types";
import { useAuth } from "./AuthContext";

/**
 * Shared optimistic state for votes, saves and follows so every card,
 * detail page and the cookbook stay in sync instantly.
 */
interface EngagementState {
  votes: Record<string, VoteValue>;
  savedIds: Set<string>;
  followedIds: Set<string>;
  /** Local net_upvote deltas from the user's own optimistic votes. */
  voteDelta: Record<string, number>;
  castVote: (recipeId: string, value: VoteValue) => void;
  toggleSaved: (recipeId: string) => void;
  toggleFollowChef: (chefId: string) => void;
}

const EngagementContext = createContext<EngagementState | null>(null);

export function EngagementProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const [votes, setVotes] = useState<Record<string, VoteValue>>({});
  const [savedIds, setSavedIds] = useState<Set<string>>(new Set());
  const [followedIds, setFollowedIds] = useState<Set<string>>(new Set());
  const [voteDelta, setVoteDelta] = useState<Record<string, number>>({});

  useEffect(() => {
    if (!profile) {
      setVotes({});
      setSavedIds(new Set());
      setFollowedIds(new Set());
      setVoteDelta({});
      return;
    }
    let cancelled = false;
    Promise.all([
      fetchMyVotes(profile.id),
      fetchMySaveIds(profile.id),
      fetchFollowees(profile.id),
    ])
      .then(([v, s, f]) => {
        if (cancelled) return;
        setVotes(v);
        setSavedIds(new Set(s));
        setFollowedIds(new Set(f));
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
      // Capture the vote before and after state immediately so the
      // rollback doesn't depend on stale closure variables.
      setVotes((prev) => {
        const current = prev[recipeId] ?? 0;
        const next: VoteValue | null = current === value ? null : value;
        // Snapshot deltas NOW so the catch block uses correct values
        // rather than whatever prev was when .catch() actually runs.
        const rollbackVoteDelta = current - (next ?? 0);

        setVote(profile.id, recipeId, next).catch(() => {
          // Rollback using captured deltas — guaranteed to match
          // the optimistic update that was applied.
          setVotes((p) => {
            const copy = { ...p };
            if (next === null) {
              delete copy[recipeId];
            } else {
              copy[recipeId] = current as VoteValue;
            }
            return copy;
          });
          setVoteDelta((d) => ({
            ...d,
            [recipeId]: (d[recipeId] ?? 0) + rollbackVoteDelta,
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

  const toggleFollowChef = useCallback(
    (chefId: string) => {
      if (!profile || chefId === profile.id) return;
      setFollowedIds((prev) => {
        const wasFollowing = prev.has(chefId);
        const next = new Set(prev);
        if (wasFollowing) next.delete(chefId);
        else next.add(chefId);
        setFollow(profile.id, chefId, !wasFollowing).catch(() =>
          setFollowedIds((p) => {
            const rollback = new Set(p);
            if (wasFollowing) rollback.add(chefId);
            else rollback.delete(chefId);
            return rollback;
          }),
        );
        return next;
      });
    },
    [profile],
  );

  const value = useMemo(
    () => ({
      votes,
      savedIds,
      followedIds,
      voteDelta,
      castVote,
      toggleSaved,
      toggleFollowChef,
    }),
    [
      votes,
      savedIds,
      followedIds,
      voteDelta,
      castVote,
      toggleSaved,
      toggleFollowChef,
    ],
  );

  return (
    <EngagementContext.Provider value={value}>
      {children}
    </EngagementContext.Provider>
  );
}

export function useEngagement(): EngagementState {
  const ctx = useContext(EngagementContext);
  if (!ctx)
    throw new Error("useEngagement must be used within EngagementProvider");
  return ctx;
}
