export type LegalSection = {
  id?: string;
  heading: string;
  paragraphs?: string[];
  bullets?: string[];
  /** Paragraphs rendered after the list, when both are needed. */
  after?: string[];
};

export type LegalDoc = {
  slug: "privacy" | "support" | "terms" | "community";
  title: string;
  updated?: string;
  lede?: string;
  contact?: { email: string; note: string };
  sections: LegalSection[];
};

/** Escape then apply **bold** and [label](href). Trusted author copy only. */
export function formatInline(text: string): string {
  const escaped = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
  return escaped
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(
      /\[([^\]]+)\]\(([^)]+)\)/g,
      '<a href="$2">$1</a>',
    );
}

export const LEGAL_DOCS: LegalDoc[] = [
  {
    slug: "privacy",
    title: "Privacy Policy",
    updated: "August 28, 2026",
    lede: "Adaptable (“we”) builds AI recipes that adapt to your tastes. This policy explains what we collect, how we use it, who we share it with, and the choices you have.",
    sections: [
      {
        heading: "Who we are",
        paragraphs: [
          "Adaptable is a recipe app for iPhone and the web. The service is operated from the product at [adaptable.cooking](/). Questions: [privacy@adaptable.app](mailto:privacy@adaptable.app).",
        ],
      },
      {
        heading: "What we collect",
        paragraphs: [
          "We collect only what we need to run the product:",
        ],
        bullets: [
          "**Account:** email address, username, and an optional profile photo. If you sign in with Google, Google shares your email and basic profile with us so we can create your account.",
          "**Taste profile:** diets, allergies, dislikes, household size, spice level, and cooking skill. Used only to personalize recipes.",
          "**Content you create:** prompts, imported recipe sources, recipes, comments, meal plans, grocery lists, and photos of dishes you cook or pages you import.",
          "**Device data for alerts:** an Apple Push Notification service (APNs) token when you enable notifications on iOS.",
          "**Diagnostics:** basic error and authentication logs needed to keep the service running. We do not run advertising SDKs or sell analytics to data brokers.",
        ],
      },
      {
        heading: "Device permissions",
        paragraphs: [
          "On iPhone, the system will ask before we use these. You can revoke them in iOS Settings at any time.",
        ],
        bullets: [
          "**Camera** — snap a cookbook page, a recipe screenshot, or a photo of a dish you cooked.",
          "**Photo library** — pick an existing photo to import a recipe or share a cooked dish.",
          "**Microphone and speech recognition** — Cook Mode optional voice commands such as “next” and “start timer.” Audio is processed to understand the command; we do not keep a voice archive.",
          "**Reminders** — optional export of your grocery list into Apple Reminders.",
        ],
      },
      {
        heading: "How we use it",
        bullets: [
          "Generate and import recipes with Google Gemini on our servers. Your prompt, taste profile, and (for imports) the source text or photo are sent to Gemini to produce a structured recipe.",
          "Sync your cookbook, meal plans, and groceries across devices.",
          "Show public community recipes, votes, comments, and cook photos that you choose to publish.",
          "Send activity alerts when push is enabled (votes, comments, and cooks on your recipes).",
          "Keep the service reliable and secure (abuse prevention, account recovery).",
        ],
      },
      {
        heading: "Sharing",
        paragraphs: [
          "We do not sell your personal data. We do not use it for third-party advertising or tracking across other companies’ apps or websites.",
          "We use these processors, who see only what they need to provide their service:",
        ],
        bullets: [
          "**Supabase** — database, authentication, file storage, and realtime updates.",
          "**Google Gemini** — recipe generation and import on our servers. The Gemini API key never ships in the app.",
          "**Google** — if you choose “Continue with Google,” for sign-in only.",
          "**Vercel** — hosts the website.",
          "**Apple Push Notification service** — device alerts on iOS.",
        ],
        after: [
          "Public recipes, comments, votes, and cook photos you publish are visible to anyone with the link or the app. Do not post personal information you want to keep private.",
        ],
      },
      {
        id: "your-choices",
        heading: "Your choices",
        bullets: [
          "Edit your taste profile any time in the app (Profile → Taste Profile).",
          "Disable push notifications in iOS Settings → Notifications → Adaptable.",
          "Revoke camera, microphone, speech, photos, or Reminders access in iOS Settings.",
          "Request a copy of your data or ask a question at [privacy@adaptable.app](mailto:privacy@adaptable.app).",
          "Delete your account — see below.",
        ],
      },
      {
        heading: "Account deletion",
        paragraphs: [
          "You can delete your account in the app: **Profile → Delete account**. Deletion is permanent. It removes your profile, recipes, votes, saves, comments, grocery list, meal plans, photos, and push token.",
          "If you cannot open the app, email [support@adaptable.app](mailto:support@adaptable.app) from the address on the account and we will delete it. We aim to finish email requests within 7 days.",
        ],
      },
      {
        heading: "Retention",
        paragraphs: [
          "We keep account and content data for as long as the account is open. After deletion we remove personal data from our live systems, except records we must keep for security, abuse investigation, or law (for example a truncated log that an account was deleted). Public copies of a recipe that someone else has remixed may remain as that person’s content.",
        ],
      },
      {
        heading: "Children",
        paragraphs: [
          "Adaptable is not directed at children under 13, and we do not knowingly collect personal information from them. If you believe we have, email [privacy@adaptable.app](mailto:privacy@adaptable.app) and we will delete it.",
        ],
      },
      {
        heading: "Changes",
        paragraphs: [
          "If we change this policy in a material way, we will update the date above and, when required, notify you in the app or by email.",
        ],
      },
      {
        heading: "Contact",
        paragraphs: [
          "Privacy questions: [privacy@adaptable.app](mailto:privacy@adaptable.app). Support: [support@adaptable.app](mailto:support@adaptable.app) or our [Support page](/support).",
        ],
      },
    ],
  },
  {
    slug: "support",
    title: "Support",
    lede: "We’re here to help you cook. Reach a person at the address below — this is the contact Apple reviewers and customers should use.",
    contact: {
      email: "support@adaptable.app",
      note: "We read every message and aim to reply within 2 business days.",
    },
    sections: [
      {
        heading: "Delete your account",
        paragraphs: [
          "Apple requires account deletion in the app. Open **Profile**, scroll to **Delete account**, and confirm. This permanently erases your data.",
          "Locked out? Email [support@adaptable.app](mailto:support@adaptable.app) from the address on the account. Tell us you want the account deleted.",
        ],
      },
      {
        heading: "Sign-in and password",
        bullets: [
          "Forgot password — use **Forgot password?** on the sign-in screen. We email a reset link.",
          "No confirmation email — check spam, then try signing up again or email support.",
          "Google sign-in issues — try email and password, or contact us with the email on the Google account.",
        ],
      },
      {
        heading: "Common fixes",
        bullets: [
          "**Recipe generation failed** — check your connection and try again in a minute. Daily limits protect the AI engine for everyone.",
          "**Allergies** — set them in Taste Profile. We block generations that still contain listed allergens when we can detect them. Always double-check ingredients if you have a severe allergy. Adaptable is not a medical device.",
          "**Push notifications** — enable them in Profile, then allow Adaptable in iOS Settings → Notifications.",
          "**Shared recipe links** — open in Safari, or tap to open the Adaptable app when it is installed.",
        ],
      },
      {
        heading: "Report content",
        paragraphs: [
          "See something abusive, unsafe, or spammy? In the app, use **Report** on a comment. For a recipe or anything urgent (including a safety issue), email [support@adaptable.app](mailto:support@adaptable.app) with the link and a short description.",
          "We review reports and may remove content or suspend accounts that break our [Community guidelines](/community).",
        ],
      },
      {
        heading: "Legal",
        paragraphs: [
          "[Privacy Policy](/privacy) · [Terms of Use](/terms) · [Community guidelines](/community)",
        ],
      },
    ],
  },
  {
    slug: "terms",
    title: "Terms of Use",
    updated: "August 28, 2026",
    lede: "These terms govern your use of Adaptable on iPhone and the web. The App Store listing also uses Apple’s standard EULA. If you do not agree, do not use the app.",
    sections: [
      {
        heading: "The service",
        paragraphs: [
          "Adaptable generates, imports, and shares recipes. Features may change. We may set fair-use limits on AI generation so the engine stays available.",
        ],
      },
      {
        heading: "Accounts",
        paragraphs: [
          "You must provide an accurate email and keep your login safe. You are responsible for activity on your account. We may suspend or delete accounts that violate these terms or our [Community guidelines](/community).",
          "You can delete your account at any time (Profile → Delete account). See the [Privacy Policy](/privacy) for what we remove.",
        ],
      },
      {
        heading: "Your content",
        paragraphs: [
          "You keep ownership of recipes, comments, and photos you post. You grant Adaptable a worldwide, non-exclusive license to host, display, and share that content as part of the service (for example a public recipe page and Universal Links).",
          "You represent that you have the right to post what you upload, including photos and imported text.",
        ],
      },
      {
        heading: "AI-generated recipes",
        paragraphs: [
          "Recipes produced by the generator or importer are machine-assisted. They can be wrong, incomplete, or a poor match for your kitchen. You are responsible for how you cook and what you serve.",
          "AI output is **not** medical, nutrition, or dietetic advice.",
        ],
      },
      {
        heading: "Food safety and allergies",
        paragraphs: [
          "Taste Profile allergies are a best-effort filter, not a guarantee. Detection can miss ingredients, cross-contact, or regional names. If you have a severe allergy or medical dietary need, read every ingredient yourself and follow advice from a qualified professional. We are not liable for allergic reactions or foodborne illness.",
        ],
      },
      {
        heading: "Acceptable use",
        bullets: [
          "Do not post illegal, harassing, or pornographic content.",
          "Do not attempt to scrape, overload, or reverse-engineer the service beyond ordinary use.",
          "Do not use generation to produce content that is unrelated to cooking or that violates these terms.",
        ],
      },
      {
        heading: "Disclaimer",
        paragraphs: [
          "The service is provided “as is.” We disclaim warranties to the fullest extent allowed by law. Our liability is limited to the amount you paid us in the last 12 months (currently $0 if the app is free), except where the law does not allow that limit.",
        ],
      },
      {
        heading: "Contact",
        paragraphs: [
          "[support@adaptable.app](mailto:support@adaptable.app) · [Privacy Policy](/privacy)",
        ],
      },
    ],
  },
  {
    slug: "community",
    title: "Community guidelines",
    updated: "August 28, 2026",
    lede: "Adaptable is a kitchen, not a dumping ground. Publish recipes and comments you would be willing to serve a guest.",
    sections: [
      {
        heading: "Do",
        bullets: [
          "Share recipes, tips, and cook photos that help someone else make dinner.",
          "Say when a swap is experimental. Label very spicy or allergen-heavy dishes clearly.",
          "Credit a source when you import or adapt someone else’s recipe.",
        ],
      },
      {
        heading: "Don’t",
        bullets: [
          "Harassment, hate, or sexual content.",
          "Spam, scams, or off-topic promotion.",
          "Unsafe food advice presented as fact (for example canning or wild foraging shortcuts that can make people sick).",
          "Impersonation or posting someone else’s private information.",
        ],
      },
      {
        heading: "How to report",
        paragraphs: [
          "Use **Report** on a comment in the app, or email [support@adaptable.app](mailto:support@adaptable.app) with a link and why it breaks these rules. We review reports and may remove content or suspend accounts.",
        ],
      },
      {
        heading: "Contact",
        paragraphs: [
          "[support@adaptable.app](mailto:support@adaptable.app) · [Support](/support) · [Terms of Use](/terms)",
        ],
      },
    ],
  },
];

export function legalDoc(slug: LegalDoc["slug"]): LegalDoc {
  const doc = LEGAL_DOCS.find((d) => d.slug === slug);
  if (!doc) throw new Error(`Unknown legal doc: ${slug}`);
  return doc;
}
