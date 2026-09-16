// @vitest-environment node
import { describe, it, expect, vi } from "vitest";
import { mkdtemp, readFile, rm, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  prepareInstall,
  validWebAppUrl,
} from "../integrations/google-apps-script/weekly-menu/manual/Prepare-Install.mjs";
const url = "https://script.google.com/macros/s/fixture-deployment/exec";
const secret = "a".repeat(64);
describe("manual installer package", () => {
  it.each([
    url + "?secret=bad",
    url.replace("https:", "http:"),
    url.replace("script.google.com", "evil.test"),
    url.replace("/exec", "/dev"),
  ])("rejects invalid deployment %s", (value) =>
    expect(validWebAppUrl(value)).toBe(false),
  );
  it("stores only the digest in the generated Apps Script and sends raw credential by stdin", async () => {
    const directory = await mkdtemp(join(tmpdir(), "atlas-manual-test-"));
    const run = vi.fn(() => ({ status: 0 }));
    try {
      const result = await prepareInstall({
        directory,
        webAppUrl: url,
        run,
        randomSecret: () => secret,
      });
      const config = await readFile(
        join(directory, "AtlasWeeklyMenuConfig.gs"),
        "utf8",
      );
      expect(config).toContain("secretSha256");
      expect(config).not.toContain(secret);
      expect(config).toContain("1kSNc69C-Fe7QYjmbwYiCL6Kf01r2dsvonRIC7qn2urI");
      const secretCall = run.mock.calls.find(([, args]) =>
        args.includes("ATLAS_WEEKLY_MENU_WEBAPP_SECRET"),
      );
      expect(secretCall[2].input).toBe(secret);
      expect(secretCall[1].join(" ")).not.toContain(secret);
      expect(JSON.stringify(result)).not.toContain(secret);
      await expect(
        prepareInstall({
          directory,
          webAppUrl: url,
          run,
          randomSecret: () => secret,
        }),
      ).rejects.toThrow("OUTPUT_EXISTS");
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
  it("refuses a saved reader credential rather than silently rotating a working integration", async () => {
    const directory = await mkdtemp(join(tmpdir(), "atlas-manual-test-"));
    const run = vi.fn((_cmd, args) => ({
      status: 0,
      stdout:
        args[0] === "secret" && args[1] === "list"
          ? JSON.stringify([{ name: "ATLAS_WEEKLY_MENU_WEBAPP_SECRET" }])
          : "[]",
    }));
    try {
      await expect(
        prepareInstall({
          directory,
          webAppUrl: url,
          run,
          randomSecret: () => secret,
        }),
      ).rejects.toThrow("READER_SECRET_ALREADY_EXISTS");
      expect(run.mock.calls.filter(([, a]) => a[1] === "set")).toHaveLength(0);
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
  it("aborts before secret generation/writes when GitHub authentication is unavailable", async () => {
    const directory = await mkdtemp(join(tmpdir(), "atlas-manual-test-"));
    const run = vi.fn(() => ({ status: 1 }));
    const randomSecret = vi.fn();
    try {
      await expect(
        prepareInstall({ directory, webAppUrl: url, run, randomSecret }),
      ).rejects.toThrow("GITHUB_AUTH_REQUIRED");
      expect(randomSecret).not.toHaveBeenCalled();
      await expect(
        access(join(directory, "AtlasWeeklyMenuConfig.gs")),
      ).rejects.toThrow();
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
});
