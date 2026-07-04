export function totalMinutes(prep: number, cook: number): string {
  const total = prep + cook;
  if (total >= 60) {
    const h = Math.floor(total / 60);
    const m = total % 60;
    return m ? `${h} hr ${m} min` : `${h} hr`;
  }
  return `${total} min`;
}

export function timeAgo(iso: string): string {
  const seconds = Math.max(1, (Date.now() - new Date(iso).getTime()) / 1000);
  if (seconds < 60) return "just now";
  const minutes = seconds / 60;
  if (minutes < 60) return `${Math.floor(minutes)}m ago`;
  const hours = minutes / 60;
  if (hours < 24) return `${Math.floor(hours)}h ago`;
  const days = hours / 24;
  if (days < 7) return `${Math.floor(days)}d ago`;
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}

/**
 * Local-timezone yyyy-mm-dd. Never use toISOString() for calendar dates:
 * it returns UTC, which is already "tomorrow" during US evenings.
 */
export function localISODate(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function compactCount(n: number): string {
  if (Math.abs(n) >= 1000) return `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k`;
  return String(n);
}
