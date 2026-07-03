import { BrowserRouter, Route, Routes, useLocation } from "react-router-dom";
import { useEffect } from "react";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { EngagementProvider } from "@/context/EngagementContext";
import BottomNav from "@/components/BottomNav";
import FeedPage from "@/pages/FeedPage";
import GeneratePage from "@/pages/GeneratePage";
import RecipeDetailPage from "@/pages/RecipeDetailPage";
import CookbookPage from "@/pages/CookbookPage";
import ProfilePage from "@/pages/ProfilePage";
import AuthPage from "@/pages/AuthPage";
import { ChefHat } from "lucide-react";

function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

function Shell() {
  const { profile, loading } = useAuth();

  if (loading) {
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

  if (!profile) return <AuthPage />;

  return (
    <EngagementProvider>
      <ScrollToTop />
      <Routes>
        <Route path="/" element={<FeedPage />} />
        <Route path="/create" element={<GeneratePage />} />
        <Route path="/recipe/:id" element={<RecipeDetailPage />} />
        <Route path="/cookbook" element={<CookbookPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="*" element={<FeedPage />} />
      </Routes>
      <BottomNav />
    </EngagementProvider>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Shell />
      </AuthProvider>
    </BrowserRouter>
  );
}
