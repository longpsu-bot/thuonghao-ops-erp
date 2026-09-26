import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { planningPreviewBuildPlugin } from "./scripts/planning-preview-build-plugin.mjs";

export default defineConfig({
  base: "./",
  plugins: [react(), planningPreviewBuildPlugin()],
  server: { host: "127.0.0.1", port: 3000, strictPort: true },
  test: { environment: "jsdom" },
});
