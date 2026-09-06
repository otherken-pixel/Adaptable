import { APP_STORE_URL } from "@/lib/site";

/** Official Apple badge only when the listing exists. Never a homemade mark. */
export default function AppStoreCta({
  className = "",
  size = "md",
}: {
  className?: string;
  size?: "md" | "lg";
}) {
  const height = size === "lg" ? 54 : 40;

  if (!APP_STORE_URL) {
    return (
      <p
        className={`inline-flex items-center rounded-full border border-line bg-raised px-5 py-3 text-sm font-bold text-muted ${className}`}
        aria-disabled="true"
      >
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
        height={height}
        width={Math.round((height * 250) / 83)}
        className={size === "lg" ? "h-[54px] w-auto" : "h-10 w-auto"}
      />
    </a>
  );
}
