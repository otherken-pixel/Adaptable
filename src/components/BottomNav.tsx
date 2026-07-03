import { NavLink, useLocation } from "react-router-dom";
import {
  Flame,
  Sparkles,
  Bookmark,
  CircleUserRound,
  ShoppingBasket,
} from "lucide-react";
import { useShopping } from "@/context/ShoppingContext";

const tabs = [
  { to: "/", label: "Discover", icon: Flame },
  { to: "/cookbook", label: "Cookbook", icon: Bookmark },
  { to: "/create", label: "Create", icon: Sparkles, hero: true },
  { to: "/list", label: "Groceries", icon: ShoppingBasket },
  { to: "/profile", label: "You", icon: CircleUserRound },
];

export default function BottomNav() {
  const { pathname } = useLocation();
  const { uncheckedCount } = useShopping();

  // Cook mode is a fully immersive screen — no chrome.
  if (pathname.startsWith("/cook/")) return null;

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 border-t border-line pb-safe backdrop-blur-xl"
      style={{ background: "var(--nav-blur-bg)" }}
    >
      <div className="mx-auto flex h-[64px] max-w-lg items-stretch justify-around px-1">
        {tabs.map(({ to, label, icon: Icon, hero }) => {
          const active = pathname === to;
          if (hero) {
            return (
              <NavLink
                key={to}
                to={to}
                aria-label={label}
                className="pressable flex flex-col items-center justify-center px-3"
              >
                <span
                  className={`flex h-12 w-12 items-center justify-center rounded-2xl shadow-lg transition-shadow ${
                    active ? "shadow-accent/40" : "shadow-accent/25"
                  }`}
                  style={{
                    background:
                      "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
                  }}
                >
                  <Icon size={24} strokeWidth={2.2} className="text-white" />
                </span>
              </NavLink>
            );
          }
          return (
            <NavLink
              key={to}
              to={to}
              aria-label={label}
              className="pressable relative flex min-w-14 flex-col items-center justify-center gap-0.5"
            >
              <span className="relative">
                <Icon
                  size={23}
                  strokeWidth={active ? 2.4 : 1.8}
                  className={active ? "text-accent" : "text-faint"}
                  fill={active && Icon === Bookmark ? "currentColor" : "none"}
                />
                {to === "/list" && uncheckedCount > 0 && (
                  <span className="absolute -top-1.5 -right-2 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1 text-[9px] font-extrabold text-white">
                    {uncheckedCount > 99 ? "99" : uncheckedCount}
                  </span>
                )}
              </span>
              <span
                className={`text-[10px] font-semibold tracking-wide ${
                  active ? "text-accent" : "text-faint"
                }`}
              >
                {label}
              </span>
            </NavLink>
          );
        })}
      </div>
    </nav>
  );
}
