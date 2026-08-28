import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import fs from "node:fs";
import path from "node:path";

const LEGAL_HTML: Record<string, string> = {
  "/privacy": "privacy.html",
  "/support": "support.html",
  "/terms": "terms.html",
  "/community": "community.html",
};

/** Serve prerendered legal HTML at pretty URLs in `vite dev`. */
function legalHtmlPlugin(): Plugin {
  return {
    name: "legal-html",
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = req.url?.split("?")[0]?.replace(/\/$/, "") ?? "";
        const file = LEGAL_HTML[url];
        if (!file) return next();
        const fp = path.resolve("public", file);
        if (!fs.existsSync(fp)) return next();
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        fs.createReadStream(fp).pipe(res);
      });
    },
  };
}

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    legalHtmlPlugin(),
    {
      name: "smart-app-banner",
      transformIndexHtml(html) {
        const id = process.env.VITE_APP_STORE_ID?.trim();
        if (!id) return html;
        return html.replace(
          "</head>",
          `    <meta name="apple-itunes-app" content="app-id=${id}" />\n  </head>`,
        );
      },
    },
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
