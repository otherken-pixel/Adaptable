import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.adaptable.app",
  appName: "Adaptable",
  webDir: "dist",
  ios: {
    contentInset: "never",
    backgroundColor: "#0c0a09",
  },
  android: {
    backgroundColor: "#0c0a09",
  },
  server: {
    androidScheme: "https",
  },
};

export default config;
