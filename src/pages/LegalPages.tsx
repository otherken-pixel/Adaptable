import LegalDocument from "@/site/LegalDocument";
import { legalDoc } from "@/site/legal";

export function PrivacyPage() {
  return <LegalDocument doc={legalDoc("privacy")} />;
}

export function SupportPage() {
  return <LegalDocument doc={legalDoc("support")} />;
}

export function TermsPage() {
  return <LegalDocument doc={legalDoc("terms")} />;
}

export function CommunityPage() {
  return <LegalDocument doc={legalDoc("community")} />;
}
