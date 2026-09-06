/**
 * Write static /privacy /support /terms /community HTML for App Review
 * (no JavaScript required). Run from `npm run build`.
 */
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { LEGAL_DOCS, formatInline } from "../src/site/legal.ts";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function nav(current) {
  const links = [
    ["/", "Home"],
    ["/support", "Support"],
    ["/privacy", "Privacy"],
    ["/terms", "Terms"],
    ["/community", "Community"],
  ];
  return links
    .map(([href, label]) => {
      const cur = href === `/${current}` ? ' aria-current="page"' : "";
      return `<a href="${href}"${cur}>${label}</a>`;
    })
    .join("\n        ");
}

function page(doc) {
  const sections = doc.sections
    .map((section) => {
      const id = section.id ? ` id="${section.id}"` : "";
      const ps = (section.paragraphs ?? [])
        .map((p) => `<p>${formatInline(p)}</p>`)
        .join("\n");
      const ul = section.bullets
        ? `<ul>${section.bullets.map((b) => `<li>${formatInline(b)}</li>`).join("")}</ul>`
        : "";
      const after = (section.after ?? [])
        .map((p) => `<p>${formatInline(p)}</p>`)
        .join("\n");
      return `<h2${id}>${section.heading}</h2>\n${ps}\n${ul}\n${after}`;
    })
    .join("\n");

  const kicker = doc.updated
    ? `<p class="kicker">Last updated: ${doc.updated}</p>`
    : "";
  const lede = doc.lede ? `<p>${formatInline(doc.lede)}</p>` : "";
  const contact = doc.contact
    ? `<div class="hero-contact"><a class="email" href="mailto:${doc.contact.email}">${doc.contact.email}</a><p>${doc.contact.note}</p></div>`
    : "";

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <title>${doc.title} — Adaptable</title>
  <meta name="description" content="${doc.title} for Adaptable, the AI recipe app." />
  <link rel="icon" href="/icon.svg" type="image/svg+xml" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  <link rel="stylesheet" href="/site.css" />
</head>
<body>
  <header class="site-header">
    <div class="wrap">
      <a class="brand" href="/"><img src="/icon.svg" width="32" height="32" alt="" />Adaptable</a>
      <details class="nav-drawer">
        <summary class="nav-toggle">
          <span class="nav-toggle-bars" aria-hidden="true"></span>
          <span class="sr-only">Menu</span>
        </summary>
        <nav class="nav">
        ${nav(doc.slug)}
        </nav>
      </details>
    </div>
  </header>
  <main class="wrap">
    <article>
      ${kicker}
      <h1>${doc.title}</h1>
      ${lede}
      ${contact}
      ${sections}
    </article>
  </main>
  <footer class="site-footer">
    <div class="wrap">
      <nav>
        <a href="/privacy">Privacy</a>
        <a href="/terms">Terms</a>
        <a href="/support">Support</a>
        <a href="/community">Community</a>
        <a href="/auth">Get the app</a>
      </nav>
      <p class="note">Apple, the Apple logo, and App Store are trademarks of Apple Inc.</p>
    </div>
  </footer>
</body>
</html>
`;
}

for (const doc of LEGAL_DOCS) {
  const dest = join(root, "public", `${doc.slug}.html`);
  writeFileSync(dest, page(doc));
  console.log("wrote", dest);
}
