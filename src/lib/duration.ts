/**
 * Pull a cook-timer duration out of instruction text so every step with
 * "sear 4 minutes" or "boil eggs 6½ minutes" gets a one-tap timer.
 */

const UNIT_SECONDS: Record<string, number> = {
  hour: 3600,
  hr: 3600,
  minute: 60,
  min: 60,
  second: 1,
  sec: 1,
};

export function extractTimerSeconds(text: string): number | null {
  // Normalize unicode fractions attached to numbers: "6½" → "6.5"
  const normalized = text
    .replace(/(\d+)\s*½/g, "$1.5")
    .replace(/(\d+)\s*¼/g, "$1.25")
    .replace(/(\d+)\s*¾/g, "$1.75");

  // Clock style: "6:30"
  const clock = normalized.match(/\b(\d{1,2}):([0-5]\d)\b/);
  if (clock) {
    const secs = parseInt(clock[1], 10) * 60 + parseInt(clock[2], 10);
    if (secs >= 10 && secs <= 6 * 3600) return secs;
  }

  // "4 minutes", "2–3 minutes", "90 seconds", "1 hour"
  const re =
    /(\d+(?:\.\d+)?)\s*(?:[-–—]|to\s+)?\s*(\d+(?:\.\d+)?)?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b/i;
  const m = normalized.match(re);
  if (!m) return null;

  const upper = m[2] ? parseFloat(m[2]) : parseFloat(m[1]);
  const unitKey = m[3].toLowerCase().replace(/s$/, "");
  const mult = UNIT_SECONDS[unitKey];
  if (!mult) return null;

  const secs = Math.round(upper * mult);
  if (secs < 10 || secs > 6 * 3600) return null;
  return secs;
}

export function formatClock(totalSeconds: number): string {
  const s = Math.max(0, Math.round(totalSeconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
  return `${m}:${String(sec).padStart(2, "0")}`;
}
