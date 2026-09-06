import { useEffect, useId, useState } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import { Menu, X } from "lucide-react";
import { APP_STORE_URL, SUPPORT_EMAIL } from "@/lib/site";
import BrandMark from "./BrandMark";
import AppStoreCta from "./AppStoreCta";

const NAV = [
  { to: "/#features", label: "Features", hash: true },
  { to: "/support", label: "Support", hash: false },
  { to: "/privacy", label: "Privacy", hash: false },
  { to: "/terms", label: "Terms", hash: false },
  { to: "/community", label: "Community", hash: false },
] as const;

function navClass(active: boolean) {
  return `text-[13px] font-semibold ${active ? "text-content" : "text-muted hover:text-content"}`;
}

export default function MarketingLayout({
  title,
  children,
}: {
  title?: string;
  children: React.ReactNode;
}) {
  const { pathname } = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuId = useId();

  useEffect(() => {
    const prev = document.title;
    document.title = title
      ? `${title} — Adaptable`
      : "Adaptable — AI recipes for iPhone";
    return () => {
      document.title = prev;
    };
  }, [title]);

  useEffect(() => {
    setMenuOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!menuOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMenuOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [menuOpen]);

  return (
    <div className="site-page min-h-dvh bg-surface text-content">
      <header className="sticky top-0 z-20 border-b border-line bg-surface/85 backdrop-blur-lg">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-5">
          <Link to="/" className="flex items-center gap-2.5 font-extrabold tracking-tight">
            <BrandMark size={32} />
            Adaptable
          </Link>
          <nav className="hidden items-center gap-5 sm:flex" aria-label="Primary">
            <DesktopLinks />
            <HeaderStoreCta />
          </nav>
          <button
            type="button"
            className="pressable -mr-1 flex h-10 w-10 items-center justify-center rounded-full text-content sm:hidden"
            aria-expanded={menuOpen}
            aria-controls={menuId}
            aria-label={menuOpen ? "Close menu" : "Open menu"}
            onClick={() => setMenuOpen((open) => !open)}
          >
            {menuOpen ? <X size={22} strokeWidth={2.2} /> : <Menu size={22} strokeWidth={2.2} />}
          </button>
        </div>
        {menuOpen ? (
          <nav
            id={menuId}
            className="border-t border-line px-5 py-3 sm:hidden"
            aria-label="Primary"
          >
            <div className="mx-auto flex max-w-6xl flex-col gap-1">
              {NAV.map((item) =>
                item.hash ? (
                  <a
                    key={item.to}
                    href={item.to}
                    className="rounded-xl px-2 py-2.5 text-[15px] font-semibold text-muted hover:bg-sunken hover:text-content"
                    onClick={() => setMenuOpen(false)}
                  >
                    {item.label}
                  </a>
                ) : (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    className={({ isActive }) =>
                      `rounded-xl px-2 py-2.5 text-[15px] font-semibold ${
                        isActive ? "bg-sunken text-content" : "text-muted hover:bg-sunken hover:text-content"
                      }`
                    }
                  >
                    {item.label}
                  </NavLink>
                ),
              )}
              <div className="px-2 pt-3 pb-1">
                <HeaderStoreCta />
              </div>
            </div>
          </nav>
        ) : null}
      </header>

      {children}

      <footer className="border-t border-line">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 px-5 py-10 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <Link to="/" className="flex items-center gap-2.5 font-extrabold">
              <BrandMark size={28} />
              Adaptable
            </Link>
            <p className="mt-2 max-w-xs text-sm text-muted">
              AI recipes that adapt to you — on iPhone.
            </p>
            <div className="mt-4">
              <AppStoreCta />
            </div>
          </div>
          <nav className="flex flex-col gap-2 text-[13px] font-semibold text-muted">
            <Link to="/privacy" className="hover:text-content">
              Privacy Policy
            </Link>
            <Link to="/terms" className="hover:text-content">
              Terms of Use
            </Link>
            <Link to="/support" className="hover:text-content">
              Support
            </Link>
            <Link to="/community" className="hover:text-content">
              Community
            </Link>
            <a href={`mailto:${SUPPORT_EMAIL}`} className="hover:text-content">
              {SUPPORT_EMAIL}
            </a>
            {APP_STORE_URL ? (
              <a href={APP_STORE_URL} className="hover:text-content">
                App Store
              </a>
            ) : null}
          </nav>
        </div>
        <p className="mx-auto max-w-6xl px-5 pb-10 text-xs text-faint">
          Apple, the Apple logo, and App Store are trademarks of Apple Inc.
        </p>
      </footer>
    </div>
  );
}

const DESKTOP_NAV = NAV.filter((item) =>
  item.hash || item.to === "/support" || item.to === "/privacy",
);

function DesktopLinks() {
  return (
    <>
      {DESKTOP_NAV.map((item) =>
        item.hash ? (
          <a key={item.to} href={item.to} className={navClass(false)}>
            {item.label}
          </a>
        ) : (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) => navClass(isActive)}
          >
            {item.label}
          </NavLink>
        ),
      )}
    </>
  );
}

function HeaderStoreCta() {
  if (APP_STORE_URL) {
    return (
      <a
        href={APP_STORE_URL}
        className="pressable inline-flex rounded-full bg-content px-3.5 py-1.5 text-[13px] font-bold text-surface"
      >
        Get the app
      </a>
    );
  }

  return (
    <span className="inline-flex rounded-full border border-line bg-raised px-3.5 py-1.5 text-[13px] font-bold text-muted">
      Coming soon
    </span>
  );
}
