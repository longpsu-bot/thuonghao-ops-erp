import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

export function planningPreviewBuildPlugin() {
  return {
    name: "atlas-planning-preview-provenance",
    apply: "build",
    generateBundle() {
      const git = (...args) =>
        execFileSync("git", args, { encoding: "utf8" }).trim();
      const entry = readFileSync("src/main.tsx", "utf8");
      this.emitFile({
        type: "asset",
        fileName: "_atlas-build.json",
        source: JSON.stringify({
          schema: "atlas-planning-preview.v1",
          commit: git("rev-parse", "HEAD"),
          dirty: git("status", "--porcelain", "--untracked-files=no") !== "",
          entrypoint: entry.includes("AtlasVNextConnectedApp")
            ? "AtlasVNextConnectedApp"
            : "AtlasApp",
          supabaseOrigin: process.env.VITE_SUPABASE_URL
            ? new URL(process.env.VITE_SUPABASE_URL).origin
            : null,
        }),
      });
    },
  };
}
