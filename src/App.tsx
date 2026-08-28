import { BrowserRouter, Route, Routes, Navigate, useLocation } from "react-router-dom";
import { useEffect } from "react";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import ResetPasswordPage from "@/pages/ResetPasswordPage";
import {
  CommunityPage,
  PrivacyPage,
  SupportPage,
  TermsPage,
} from "@/pages/LegalPages";
import LandingPage from "@/site/LandingPage";
import GetAppPage from "@/site/GetAppPage";
import { ChefHat } from "lucide-react";

function ScrollToTop() {
  const { pathname, hash } = useLocation();
  useEffect(() => {
    if (hash) return;
    window.scrollTo(0, 0);
  }, [pathname, hash]);
  return null;
}

function Splash() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-surface">
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

/** Public marketing site only — cooking happens in the iPhone app. */
function Shell() {
  const { loading } = useAuth();
  const { pathname } = useLocation();

  if (pathname.startsWith("/reset-password") && loading) return <Splash />;

  return (
    <>
      <ScrollToTop />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/privacy" element={<PrivacyPage />} />
        <Route path="/support" element={<SupportPage />} />
        <Route path="/terms" element={<TermsPage />} />
        <Route path="/community" element={<CommunityPage />} />
        <Route path="/reset-password" element={<ResetPasswordPage />} />
        <Route path="/recipe/:id" element={<GetAppPage kind="recipe" />} />
        <Route path="/cook/:id" element={<GetAppPage kind="cook" />} />
        <Route path="/auth" element={<Navigate to="/" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
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
