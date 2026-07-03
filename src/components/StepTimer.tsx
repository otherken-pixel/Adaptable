import { useEffect, useRef, useState } from "react";
import { Pause, Play, RotateCcw, TimerIcon } from "lucide-react";
import { formatClock } from "@/lib/duration";

/**
 * One-tap countdown for a cooking step. Beeps + vibrates on completion.
 * Remounted per step via `key`, so state resets automatically.
 */
export default function StepTimer({ seconds }: { seconds: number }) {
  const [remaining, setRemaining] = useState(seconds);
  const [running, setRunning] = useState(false);
  const [finished, setFinished] = useState(false);
  const endAtRef = useRef<number | null>(null);

  useEffect(() => {
    if (!running) return;
    endAtRef.current = Date.now() + remaining * 1000;
    const tick = setInterval(() => {
      const left = Math.max(0, Math.round((endAtRef.current! - Date.now()) / 1000));
      setRemaining(left);
      if (left === 0) {
        clearInterval(tick);
        setRunning(false);
        setFinished(true);
        ring();
      }
    }, 250);
    return () => clearInterval(tick);
    // remaining intentionally omitted: endAt is fixed when running starts
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [running]);

  const reset = () => {
    setRunning(false);
    setFinished(false);
    setRemaining(seconds);
  };

  const progress = 1 - remaining / seconds;
  const R = 15;
  const CIRC = 2 * Math.PI * R;

  return (
    <div
      className={`flex items-center gap-3 rounded-2xl border px-4 py-3 transition-colors ${
        finished
          ? "border-accent bg-accent-soft"
          : "border-line bg-raised"
      }`}
    >
      <div className="relative flex h-10 w-10 items-center justify-center">
        <svg viewBox="0 0 36 36" className="h-10 w-10 -rotate-90">
          <circle
            cx="18"
            cy="18"
            r={R}
            fill="none"
            stroke="var(--line)"
            strokeWidth="3.5"
          />
          <circle
            cx="18"
            cy="18"
            r={R}
            fill="none"
            stroke="var(--accent)"
            strokeWidth="3.5"
            strokeLinecap="round"
            strokeDasharray={CIRC}
            strokeDashoffset={CIRC * (1 - progress)}
            style={{ transition: "stroke-dashoffset 0.3s linear" }}
          />
        </svg>
        <TimerIcon
          size={15}
          className="absolute text-accent"
          strokeWidth={2.4}
        />
      </div>

      <div className="min-w-0 flex-1">
        <p className="text-xl leading-none font-extrabold tracking-tight tabular-nums">
          {formatClock(remaining)}
        </p>
        <p className="mt-0.5 text-[11px] font-semibold text-faint">
          {finished ? "Time's up!" : running ? "Counting down…" : "Step timer"}
        </p>
      </div>

      {!finished && (
        <button
          aria-label={running ? "Pause timer" : "Start timer"}
          onClick={() => setRunning((r) => !r)}
          className="pressable flex h-11 w-11 items-center justify-center rounded-full text-white shadow-md"
          style={{
            background:
              "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
          }}
        >
          {running ? (
            <Pause size={18} strokeWidth={2.4} fill="currentColor" />
          ) : (
            <Play size={18} strokeWidth={2.4} fill="currentColor" className="ml-0.5" />
          )}
        </button>
      )}
      {(finished || (!running && remaining !== seconds)) && (
        <button
          aria-label="Reset timer"
          onClick={reset}
          className="pressable flex h-11 w-11 items-center justify-center rounded-full border border-line bg-raised text-muted"
        >
          <RotateCcw size={17} strokeWidth={2.2} />
        </button>
      )}
    </div>
  );
}

function ring() {
  try {
    navigator.vibrate?.([220, 90, 220, 90, 400]);
  } catch {
    /* not supported */
  }
  try {
    const AudioCtx =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext?: typeof AudioContext })
        .webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    [0, 0.35, 0.7].forEach((t) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = 880;
      gain.gain.setValueAtTime(0.001, ctx.currentTime + t);
      gain.gain.exponentialRampToValueAtTime(0.28, ctx.currentTime + t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + t + 0.3);
      osc.connect(gain).connect(ctx.destination);
      osc.start(ctx.currentTime + t);
      osc.stop(ctx.currentTime + t + 0.32);
    });
    setTimeout(() => void ctx.close(), 1600);
  } catch {
    /* audio unavailable */
  }
}
