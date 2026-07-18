import { afterEach, describe, expect, it, vi } from "vitest";
import { readFileSync } from "node:fs";
import {
  parseLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const apiUrl = "http://127.0.0.1:54321";
const anonKey = "local-anon-key-that-must-not-appear-in-errors";
const serviceRoleKey = "local-service-role-key-that-must-not-appear-in-errors";
const previousNpmExecPath = process.env.npm_execpath;

afterEach(() => {
  if (previousNpmExecPath === undefined) delete process.env.npm_execpath;
  else process.env.npm_execpath = previousNpmExecPath;
});

describe("local Supabase status parser", () => {
  it("keeps the committed browser environment example free of generated keys", () => {
    const environmentExample = readFileSync(".env.example", "utf8");
    expect(environmentExample).toContain(
      "VITE_SUPABASE_PUBLISHABLE_KEY=replace-with-local-publishable-key",
    );
    expect(environmentExample).not.toMatch(
      /VITE_SUPABASE_SERVICE_ROLE_KEY|eyJ[A-Za-z0-9_-]+\.|sb_(publishable|secret)_/,
    );
  });

  it("accepts the documented legacy status fields", () => {
    expect(
      parseLocalSupabaseStatus(
        {
          API_URL: apiUrl,
          ANON_KEY: anonKey,
          SERVICE_ROLE_KEY: serviceRoleKey,
        },
        { requireAdminKey: true },
      ),
    ).toEqual({ apiUrl, browserKey: anonKey, serviceRoleKey });
    expect(
      parseLocalSupabaseStatus({
        API_URL: apiUrl,
        ANON_KEY: anonKey,
        SERVICE_ROLE_KEY: serviceRoleKey,
      }),
    ).toEqual({ apiUrl, browserKey: anonKey });
  });

  it("accepts the current browser-key alias without treating SECRET_KEY as an admin key", () => {
    expect(
      parseLocalSupabaseStatus({
        API_URL: apiUrl,
        PUBLISHABLE_KEY: "current-publishable-alias",
      }),
    ).toEqual({ apiUrl, browserKey: "current-publishable-alias" });
    expect(() =>
      parseLocalSupabaseStatus(
        {
          API_URL: apiUrl,
          PUBLISHABLE_KEY: "current-publishable-alias",
          SECRET_KEY: "unsupported-admin-alias",
        },
        { requireAdminKey: true },
      ),
    ).toThrow("admin key is missing");
  });

  it.each([
    [{ ANON_KEY: anonKey, SERVICE_ROLE_KEY: serviceRoleKey }, "API URL"],
    [{ API_URL: apiUrl, SERVICE_ROLE_KEY: serviceRoleKey }, "browser key"],
    [{ API_URL: apiUrl, ANON_KEY: anonKey }, "admin key"],
  ])("fails safely when a required field is missing", (status, expected) => {
    expect(() =>
      parseLocalSupabaseStatus(status, { requireAdminKey: true }),
    ).toThrow(expected);
  });

  it("rejects a non-loopback URL without exposing keys", () => {
    let message = "";
    try {
      parseLocalSupabaseStatus({
        API_URL: "https://qnthofvccilhnefdcxnz.supabase.co",
        ANON_KEY: anonKey,
        SERVICE_ROLE_KEY: serviceRoleKey,
      });
    } catch (error) {
      message = error instanceof Error ? error.message : String(error);
    }
    expect(message).toContain("loopback");
    expect(message).not.toContain(anonKey);
    expect(message).not.toContain(serviceRoleKey);
  });

  it("never includes local keys in missing-field errors", () => {
    for (const status of [
      { API_URL: apiUrl, SERVICE_ROLE_KEY: serviceRoleKey },
      { API_URL: apiUrl, ANON_KEY: anonKey },
    ]) {
      let message = "";
      try {
        parseLocalSupabaseStatus(status, { requireAdminKey: true });
      } catch (error) {
        message = error instanceof Error ? error.message : String(error);
      }
      expect(message).not.toContain(anonKey);
      expect(message).not.toContain(serviceRoleKey);
    }
  });

  it("invokes the repository CLI through pnpm exec without logging status", () => {
    process.env.npm_execpath = "C:/repo/pnpm.cjs";
    const execFile = vi.fn(() => "{}");
    const consoleSpy = vi.spyOn(console, "log").mockImplementation(() => {});
    runPinnedSupabase(["status", "-o", "json"], {
      execFile,
      encoding: "utf8",
    });
    expect(execFile).toHaveBeenCalledWith(
      process.execPath,
      ["C:/repo/pnpm.cjs", "exec", "supabase", "status", "-o", "json"],
      { encoding: "utf8" },
    );
    expect(consoleSpy).not.toHaveBeenCalled();
    consoleSpy.mockRestore();
  });
});
