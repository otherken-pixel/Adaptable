import { Link } from "react-router-dom";
import { ChevronLeft } from "lucide-react";

function LegalShell({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-safe">
      <div className="flex items-center gap-1 pt-4 pb-3">
        <Link
          to="/"
          aria-label="Back"
          className="pressable -ml-2 flex h-10 w-10 items-center justify-center rounded-full text-muted"
        >
          <ChevronLeft size={26} strokeWidth={2.4} />
        </Link>
        <h1 className="text-lg font-extrabold tracking-tight">{title}</h1>
      </div>
      <article className="prose-sm space-y-4 pb-12 text-[15px] leading-relaxed text-muted">
        {children}
      </article>
    </div>
  );
}

export function PrivacyPage() {
  return (
    <LegalShell title="Privacy Policy">
      <p className="text-xs font-bold tracking-wide text-faint uppercase">
        Last updated: August 2, 2026
      </p>
      <p>
        Adaptable (“we”) builds AI recipes that adapt to your tastes. This
        policy explains what we collect and how we use it.
      </p>
      <h2 className="text-base font-extrabold text-content">What we collect</h2>
      <ul className="list-disc space-y-1 pl-5">
        <li>Account data: email, username, optional avatar.</li>
        <li>
          Taste profile: diets, allergies, dislikes, household size, spice and
          skill preferences — used only to personalize recipes.
        </li>
        <li>
          Content you create: prompts, imported sources, recipes, comments,
          meal plans, grocery lists, cook photos.
        </li>
        <li>
          Device data for push notifications (APNs token) when you enable
          alerts.
        </li>
        <li>Basic product analytics needed to run the service (errors, auth).</li>
      </ul>
      <h2 className="text-base font-extrabold text-content">How we use it</h2>
      <ul className="list-disc space-y-1 pl-5">
        <li>Generate and import recipes via Google Gemini on our servers.</li>
        <li>Sync your cookbook, plans, and groceries across devices.</li>
        <li>Show public community recipes, votes, and comments.</li>
        <li>Notify you about activity on your recipes when push is enabled.</li>
      </ul>
      <h2 className="text-base font-extrabold text-content">Sharing</h2>
      <p>
        We do not sell your personal data. We use Supabase for database and
        auth, Google Gemini for recipe generation, Vercel for web hosting, and
        Apple Push Notification service for device alerts. Public recipes you
        publish are visible to everyone.
      </p>
      <h2 className="text-base font-extrabold text-content">Your choices</h2>
      <ul className="list-disc space-y-1 pl-5">
        <li>Edit your taste profile any time in the app.</li>
        <li>Disable push notifications in system settings.</li>
        <li>Delete your account in Profile — this permanently removes your data.</li>
      </ul>
      <h2 className="text-base font-extrabold text-content">Contact</h2>
      <p>
        Questions:{" "}
        <a className="font-bold text-accent" href="mailto:privacy@adaptable.app">
          privacy@adaptable.app
        </a>{" "}
        or see{" "}
        <Link to="/support" className="font-bold text-accent">
          Support
        </Link>
        .
      </p>
    </LegalShell>
  );
}

export function SupportPage() {
  return (
    <LegalShell title="Support">
      <p>
        We’re here to help you cook. Reach us at{" "}
        <a className="font-bold text-accent" href="mailto:support@adaptable.app">
          support@adaptable.app
        </a>
        .
      </p>
      <h2 className="text-base font-extrabold text-content">Common fixes</h2>
      <ul className="list-disc space-y-2 pl-5">
        <li>
          <strong className="text-content">Recipe generation failed</strong> —
          check your connection and try again in a minute. Daily limits protect
          the AI engine for everyone.
        </li>
        <li>
          <strong className="text-content">Allergies</strong> — set them in Taste
          Profile. We block generations that still contain listed allergens when
          we can detect them; always double-check ingredients if you have a
          severe allergy.
        </li>
        <li>
          <strong className="text-content">Push notifications</strong> — enable
          them in Profile, then allow Adaptable in iOS Settings → Notifications.
        </li>
        <li>
          <strong className="text-content">Shared recipe links</strong> — open in
          Safari or tap to open the Adaptable app when installed.
        </li>
      </ul>
      <h2 className="text-base font-extrabold text-content">Legal</h2>
      <p>
        <Link to="/privacy" className="font-bold text-accent">
          Privacy Policy
        </Link>
      </p>
    </LegalShell>
  );
}
