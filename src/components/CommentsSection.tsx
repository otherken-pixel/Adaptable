import { useEffect, useState } from "react";
import { MessageCircle, Send, Trash2 } from "lucide-react";
import { addComment, deleteComment, fetchComments } from "@/lib/api";
import { coverGradient } from "@/lib/gradients";
import { timeAgo } from "@/lib/format";
import type { Comment } from "@/lib/types";
import { useAuth } from "@/context/AuthContext";

export default function CommentsSection({ recipeId }: { recipeId: string }) {
  const { profile } = useAuth();
  const [comments, setComments] = useState<Comment[] | null>(null);
  const [draft, setDraft] = useState("");
  const [posting, setPosting] = useState(false);

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

  return (
    <section className="mt-8">
      <h2 className="flex items-center gap-2 text-lg font-extrabold tracking-tight">
        <MessageCircle size={19} strokeWidth={2.4} className="text-accent" />
        Comments
        {comments !== null && (
          <span className="text-sm font-bold text-faint">{comments.length}</span>
        )}
      </h2>

      {/* Composer */}
      <div className="mt-3 flex items-end gap-2 rounded-2xl border border-line bg-raised p-2">
        <textarea
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
          <Send size={16} strokeWidth={2.4} />
        </button>
      </div>

      {/* List */}
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
              >
                {(c.author?.username ?? "?").slice(0, 1).toUpperCase()}
              </span>
              <span className="min-w-0 truncate text-[13px] font-bold">
                {c.author?.username ?? "anonymous"}
              </span>
              <span className="text-xs text-faint">{timeAgo(c.created_at)}</span>
              {profile?.id === c.user_id && (
                <button
                  aria-label="Delete comment"
                  onClick={() => remove(c.id)}
                  className="pressable ml-auto flex h-7 w-7 items-center justify-center rounded-full text-faint"
                >
                  <Trash2 size={14} strokeWidth={2.2} />
                </button>
              )}
            </div>
            <p className="mt-2 text-[14px] leading-relaxed">{c.body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
