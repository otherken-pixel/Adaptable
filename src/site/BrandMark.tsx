import { ChefHat } from "lucide-react";

export default function BrandMark({ size = 32 }: { size?: number }) {
  const icon = Math.round(size * 0.5);
  return (
    <span
      className="inline-flex shrink-0 items-center justify-center rounded-[10px] shadow-sm shadow-accent/20"
      style={{
        width: size,
        height: size,
        background:
          "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
      }}
      aria-hidden
    >
      <ChefHat size={icon} className="text-white" strokeWidth={2.2} />
    </span>
  );
}
