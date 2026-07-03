import type { ReactNode } from "react";

export default function EmptyState({
  emoji,
  title,
  body,
  action,
}: {
  emoji: string;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <div className="animate-fade-up flex flex-col items-center gap-3 px-8 py-16 text-center">
      <span className="animate-float text-6xl">{emoji}</span>
      <h3 className="text-lg font-bold">{title}</h3>
      <p className="max-w-64 text-sm leading-relaxed text-muted">{body}</p>
      {action}
    </div>
  );
}
