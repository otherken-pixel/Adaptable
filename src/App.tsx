import { BrowserRouter, Route, Routes, useLocation, Navigate, useNavigate } from "react-router-dom";
import { useEffect } from "react";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { EngagementProvider } from "@/context/EngagementContext";
import { ShoppingProvider } from "@/context/ShoppingContext";
import { NotificationsProvider } from "@/context/NotificationsContext";
import ActivityPage from "@/pages/ActivityPage";
import BottomNav from "@/components/BottomNav";
import FeedPage from "@/pages/FeedPage";
import GeneratePage from "@/pages/GeneratePage";
import RecipeDetailPage from "@/pages/RecipeDetailPage";
import CookModePage from "@/pages/CookModePage";
import CookbookPage from "@/pages/CookbookPage";
import ShoppingListPage from "@/pages/ShoppingListPage";
import ProfilePage from "@/pages/ProfilePage";
import AuthPage from "@/pages/AuthPage";
import ResetPasswordPage from "@/pages/ResetPasswordPage";
import TasteProfilePage from "@/pages/TasteProfilePage";
import OnboardingPage from "@/pages/OnboardingPage";
import { PrivacyPage, SupportPage } from "@/pages/LegalPages";
import { ChefHat } from "lucide-react";

function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

function Splash() {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <div
        className="flex h-16 w-16 animate-float items-center justify-center rounded-3xl shadow-xl shadow-accent/25"
        style={{
          background:
            "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
        }}
      >
        <ChefHat size={30} className="text-white" strokeWidth={2} />
      </div>
    </div>
  );
}

function needsOnboarding(): boolean {
  try {
    return !localStorage.getItem("adaptable.onboarding.v1.done");
  } catch {
    return false;
  }
}

/** Full signed-in app chrome. */
function AuthenticatedShell() {
  const { profile } = useAuth();
  const location = useLocation();

  // First session: full multi-step onboarding before a cold feed.
  const showOnboarding =
    !!profile &&
    needsOnboarding() &&
    !location.pathname.startsWith("/privacy") &&
    !location.pathname.startsWith("/support") &&
    !location.pathname.startsWith("/reset-password");

  if (showOnboarding && location.pathname !== "/onboarding") {
    return <Navigate to="/onboarding" replace />;
  }

  return (
    <>
      <ScrollToTop />
      <Routes>
        <Route path="/onboarding" element={<OnboardingPage />} />
        <Route path="/" element={<FeedPage />} />
        <Route path="/create" element={<GeneratePage />} />
        <Route path="/recipe/:id" element={<RecipeDetailPage />} />
        <Route path="/cook/:id" element={<CookModePage />} />
        <Route path="/cookbook" element={<CookbookPage />} />
        <Route path="/list" element={<ShoppingListPage />} />
        <Route path="/activity" element={<ActivityPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/taste" element={<TasteProfilePage />} />
        <Route path="/privacy" element={<PrivacyPage />} />
        <Route path="/support" element={<SupportPage />} />
        <Route path="/reset-password" element={<ResetPasswordPage />} />
        <Route path="/auth" element={<Navigate to="/" replace />} />
        <Route path="*" element={<FeedPage />} />
      </Routes>
      {location.pathname !== "/onboarding" && <BottomNav />}
    </>
  );
}

/**
 * Public routes work without a session (shared recipe links, legal pages).
 * Everything else requires sign-in.
 */
/** After OAuth / sign-in, open the recipe (or other path) the user was trying to reach. */
function PostAuthRedirect() {
  const { profile } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!profile) return;
    const next = sessionStorage.getItem("adaptable.next");
    if (!next?.startsWith("/") || next.startsWith("//")) return;
    sessionStorage.removeItem("adaptable.next");
    navigate(next, { replace: true });
  }, [profile, navigate]);

  return null;
}

function Shell() {
  const { profile, loading } = useAuth();
  const location = useLocation();

  if (loading) return <Splash />;

  // Always available — share links and App Store requirements.
  const publicExact = ["/privacy", "/support", "/reset-password", "/auth"];
  const isPublicRecipe = location.pathname.startsWith("/recipe/");
  const isPublic =
    isPublicRecipe || publicExact.includes(location.pathname);

  if (!profile) {
    if (isPublic) {
      return (
        <>
          <ScrollToTop />
          <Routes>
            <Route path="/recipe/:id" element={<RecipeDetailPage />} />
            <Route path="/privacy" element={<PrivacyPage />} />
            <Route path="/support" element={<SupportPage />} />
            <Route path="/reset-password" element={<ResetPasswordPage />} />
            <Route path="/auth" element={<AuthPage />} />
            <Route path="*" element={<AuthPage />} />
          </Routes>
        </>
      );
    }
    return <AuthPage />;
  }

  return (
    <>
      <PostAuthRedirect />
      <AuthenticatedShell />
    </>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <EngagementProvider>
          <ShoppingProvider>
            <NotificationsProvider>
              <Shell />
            </NotificationsProvider>
          </ShoppingProvider>
        </EngagementProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
