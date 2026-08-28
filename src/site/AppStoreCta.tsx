import { APP_STORE_URL } from "@/lib/site";

/** Official Apple badge only when the listing exists. Never a homemade mark. */
export default function AppStoreCta({ className = "" }: { className?: string }) {
  if (!APP_STORE_URL) {
    return (
      <p className={`text-sm font-semibold text-muted ${className}`}>
        Coming soon on the App Store
      </p>
    );
  }

  return (
    <a
      href={APP_STORE_URL}
      className={`inline-block ${className}`}
      aria-label="Download on the App Store"
    >
      <img
        src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83"
        alt="Download on the App Store"
        height={40}
        className="h-10 w-auto"
      />
    </a>
  );
}
