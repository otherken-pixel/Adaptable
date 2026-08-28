import { useEffect } from "react";
import { Link, NavLink } from "react-router-dom";
import { APP_STORE_URL, SUPPORT_EMAIL } from "@/lib/site";
import BrandMark from "./BrandMark";
import AppStoreCta from "./AppStoreCta";

export default function MarketingLayout({
  title,
  children,
}: {
  title?: string;
  children: React.ReactNode;
}) {
  useEffect(() => {
    const prev = document.title;
    document.title = title
      ? `${title} — Adaptable`
      : "Adaptable — AI recipes for iPhone";
    return () => {
      document.title = prev;
    };
  }, [title]);

  return (
    <div className="site-page min-h-dvh bg-surface text-content">
      <header className="sticky top-0 z-20 border-b border-line bg-surface/85 backdrop-blur-lg">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-5">
          <Link to="/" className="flex items-center gap-2.5 font-extrabold tracking-tight">
            <BrandMark size={32} />
            Adaptable
          </Link>
          <nav className="hidden items-center gap-5 sm:flex">
            <a href="/#features" className="text-[13px] font-semibold text-muted hover:text-content">
              Features
            </a>
            <NavLink
              to="/support"
              className={({ isActive }) =>
                `text-[13px] font-semibold ${isActive ? "text-content" : "text-muted hover:text-content"}`
              }
            >
              Support
            </NavLink>
            <NavLink
              to="/privacy"
              className={({ isActive }) =>
                `text-[13px] font-semibold ${isActive ? "text-content" : "text-muted hover:text-content"}`
              }
            >
              Privacy
            </NavLink>
            {APP_STORE_URL ? (
              <a
                href={APP_STORE_URL}
                className="pressable rounded-full bg-content px-3.5 py-1.5 text-[13px] font-bold text-surface"
              >
                Get the app
              </a>
            ) : (
              <span className="rounded-full bg-content px-3.5 py-1.5 text-[13px] font-bold text-surface">
                iPhone app
              </span>
            )}
          </nav>
        </div>
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
