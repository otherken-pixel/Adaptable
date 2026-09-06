import { APP_STORE_URL } from "@/lib/site";
import MarketingLayout from "./MarketingLayout";
import AppStoreCta from "./AppStoreCta";

const COPY = {
  auth: {
    title: "Sign in on iPhone",
    body: "Accounts and cooking live in the Adaptable iPhone app — not in the browser. There is no web sign-in.",
  },
  create: {
    title: "Create recipes in the iPhone app",
    body: "The generator, imports, and your cookbook live in Adaptable for iPhone — not on this website.",
  },
  discover: {
    title: "Discover recipes in the iPhone app",
    body: "The community feed is in the Adaptable iPhone app. This site is for download, support, and legal pages.",
  },
  cook: {
    title: "Cook Mode is in the iPhone app",
    body: "Step-by-step cooking, timers, and Live Activities run on iPhone — not in the browser.",
  },
} as const;

export type IosOnlyKind = keyof typeof COPY;

export default function IosOnlyPage({ kind }: { kind: IosOnlyKind }) {
  const copy = COPY[kind];

  return (
    <MarketingLayout title={copy.title}>
      <section className="mx-auto max-w-xl px-5 pt-14 pb-20 text-center">
        <p className="text-[11px] font-extrabold tracking-[0.14em] text-accent uppercase">
          iPhone app
        </p>
        <h1 className="mt-3 text-3xl font-extrabold tracking-tight sm:text-4xl">
          {copy.title}
        </h1>
        <p className="mt-4 text-[15px] leading-relaxed text-muted">{copy.body}</p>
        <div className="mt-8 flex flex-col items-center gap-4">
          <AppStoreCta size="lg" />
          {APP_STORE_URL ? (
            <a
              href={APP_STORE_URL}
              className="text-sm font-semibold text-accent underline-offset-2 hover:underline"
            >
              Open in the App Store
            </a>
          ) : (
            <p className="text-sm text-muted">
              If Adaptable is already on this iPhone, open the app to continue.
            </p>
          )}
        </div>
      </section>
    </MarketingLayout>
  );
}
