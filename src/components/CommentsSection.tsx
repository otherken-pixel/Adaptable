import { useEffect, useState } from "react";
import { Flag, MessageCircle, Send, Trash2 } from "lucide-react";
import {
  addComment,
  deleteComment,
  fetchComments,
  reportComment,
} from "@/lib/api";
import { coverGradient } from "@/lib/gradients";
import { timeAgo } from "@/lib/format";
import type { Comment } from "@/lib/types";
import { useAuth } from "@/context/AuthContext";

export default function CommentsSection({ recipeId }: { recipeId: string }) {
  const { profile } = useAuth();
  const [comments, setComments] = useState<Comment[] | null>(null);
  const [draft, setDraft] = useState("");
  const [posting, setPosting] = useState(false);
  const [reported, setReported] = useState<Set<string>>(new Set());
  const [reportBusy, setReportBusy] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchComments(recipeId)
      .then((c) => !cancelled && setComments(c))
      .catch(() => !cancelled && setComments([]));
    return () => {
      cancelled = true;
    };
  }, [recipeId]);

  const post = async () => {
    const body = draft.trim();
    if (!body || !profile || posting) return;
    setPosting(true);
    try {
      const created = await addComment(profile.id, recipeId, body);
      setComments((prev) => [created, ...(prev ?? [])]);
      setDraft("");
    } catch {
      /* keep the draft so the user can retry */
    } finally {
      setPosting(false);
    }
  };

  const remove = (id: string) => {
    if (!profile) return;
    setComments((prev) => (prev ?? []).filter((c) => c.id !== id));
    deleteComment(profile.id, id).catch(() => {
      /* worst case the comment reappears on refresh */
    });
  };

  const report = async (id: string) => {
    if (!profile || reportBusy || reported.has(id)) return;
    const reason = window.prompt(
      "Why are you reporting this comment? (spam, abuse, unsafe advice…)",
      "Inappropriate or unsafe",
    );
    if (!reason?.trim()) return;
    setReportBusy(id);
    try {
      await reportComment(profile.id, id, reason.trim());
      setReported((prev) => new Set(prev).add(id));
    } catch {
      /* toast omitted — silent fail is fine for rare path */
    } finally {
      setReportBusy(null);
    }
  };

  return (
    <section className="mt-8" aria-label="Comments">
      <h2 className="flex items-center gap-2 text-lg font-extrabold tracking-tight">
        <MessageCircle size={19} strokeWidth={2.4} className="text-accent" aria-hidden />
        Comments
        {comments !== null && (
          <span className="text-sm font-bold text-faint">{comments.length}</span>
        )}
      </h2>

      {profile ? (
        <div className="mt-3 flex items-end gap-2 rounded-2xl border border-line bg-raised p-2">
          <label className="sr-only" htmlFor="comment-draft">
            Write a comment
          </label>
          <textarea
            id="comment-draft"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                void post();
              }
            }}
            rows={1}
            maxLength={1000}
            placeholder="How did it turn out? Tips, swaps, results…"
            className="max-h-24 min-h-[40px] flex-1 resize-none bg-transparent px-3 py-2 text-[15px] outline-none placeholder:text-faint"
          />
          <button
            aria-label="Post comment"
            onClick={() => void post()}
            disabled={!draft.trim() || posting}
            className="pressable flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-white shadow-md transition-opacity disabled:opacity-30"
            style={{
              background:
                "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
            }}
          >
            <Send size={16} strokeWidth={2.4} aria-hidden />
          </button>
        </div>
      ) : (
        <p className="mt-3 rounded-2xl border border-dashed border-line px-4 py-3 text-center text-sm text-muted">
          <a
            href={`/auth?next=${encodeURIComponent(`/recipe/${recipeId}`)}`}
            className="font-bold text-accent underline-offset-2 hover:underline"
          >
            Sign in
          </a>{" "}
          to leave a comment.
        </p>
      )}

      <div className="mt-4 space-y-3">
        {comments === null && (
          <>
            <div className="skeleton h-16 rounded-2xl" />
            <div className="skeleton h-16 rounded-2xl" />
          </>
        )}

        {comments !== null && comments.length === 0 && (
          <p className="rounded-2xl border border-dashed border-line px-4 py-6 text-center text-sm text-muted">
            No comments yet — cooked it? Tell everyone how it went. 👩‍🍳
          </p>
        )}

        {comments?.map((c, i) => (
          <div
            key={c.id}
            className="animate-fade-up rounded-2xl border border-line bg-raised p-4"
            style={{ animationDelay: `${Math.min(i, 6) * 50}ms` }}
          >
            <div className="flex items-center gap-2">
              <span
                className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[11px] font-bold text-white"
                style={{
                  background: coverGradient(c.author?.username ?? c.user_id),
                }}
                aria-hidden
              >
                {(c.author?.username ?? "?").slice(0, 1).toUpperCase()}
              </span>
              <span className="min-w-0 truncate text-[13px] font-bold">
                {c.author?.username ?? "anonymous"}
              </span>
              <span className="text-xs text-faint">{timeAgo(c.created_at)}</span>
              <div className="ml-auto flex items-center gap-1">
                {profile && profile.id !== c.user_id && (
                  <button
                    aria-label={
                      reported.has(c.id) ? "Comment reported" : "Report comment"
                    }
                    disabled={reported.has(c.id) || reportBusy === c.id}
                    onClick={() => void report(c.id)}
                    className="pressable flex h-7 w-7 items-center justify-center rounded-full text-faint disabled:opacity-40"
                  >
                    <Flag
                      size={14}
                      strokeWidth={2.2}
                      className={reported.has(c.id) ? "text-accent" : undefined}
                    />
                  </button>
                )}
                {profile?.id === c.user_id && (
                  <button
                    aria-label="Delete comment"
                    onClick={() => remove(c.id)}
                    className="pressable flex h-7 w-7 items-center justify-center rounded-full text-faint"
                  >
                    <Trash2 size={14} strokeWidth={2.2} />
                  </button>
                )}
              </div>
            </div>
            <p className="mt-2 text-[14px] leading-relaxed">{c.body}</p>
            {reported.has(c.id) && (
              <p className="mt-2 text-[12px] font-semibold text-accent">
                Thanks — we received your report.
              </p>
            )}
          </div>
        ))}
      </div>
    </section>
  );
}
