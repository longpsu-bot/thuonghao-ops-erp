import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { readAtlasBrowserEnvironment } from "./environment";
import { createAtlasSupabaseClient } from "./supabaseClient";

const stagingRef = "abcdefghijklmnopqrst";
const publishableKey = "sb_publishable_atlas_staging_test_value";

function legacyJwt(role: string): string {
  const payload = btoa(JSON.stringify({ role }))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
  return `header.${payload}.signature`;
}

describe("Atlas browser environment", () => {
  it("accepts the documented local configuration", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "local",
        VITE_SUPABASE_URL: "http://127.0.0.1:54321/",
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
      }),
    ).toEqual({
      status: "configured",
      config: {
        environment: "local",
        supabaseUrl: "http://127.0.0.1:54321",
        publishableKey: "local-publishable",
        environmentLabel: "Local · non-production",
      },
    });
  });

  it("accepts staging only with an HTTPS project URL and browser-safe key", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "staging",
        VITE_SUPABASE_URL: `https://${stagingRef}.supabase.co/path`,
        VITE_SUPABASE_PUBLISHABLE_KEY: publishableKey,
      }),
    ).toEqual({
      status: "configured",
      config: {
        environment: "staging",
        supabaseUrl: `https://${stagingRef}.supabase.co`,
        publishableKey,
        projectRef: stagingRef,
        environmentLabel: "Atlas staging · non-production",
      },
    });
  });

  it.each([undefined, "", "production", "preview", "unknown"])(
    "fails closed for unsupported environment %s",
    (environment) => {
      expect(
        readAtlasBrowserEnvironment({
          VITE_ATLAS_ENVIRONMENT: environment,
          VITE_SUPABASE_URL: "http://127.0.0.1:54321",
          VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
        }).status,
      ).toBe("configuration_error");
    },
  );

  it("rejects local configuration with a hosted URL", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "local",
        VITE_SUPABASE_URL: `https://${stagingRef}.supabase.co`,
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
      }).status,
    ).toBe("configuration_error");
  });

  it("rejects staging configuration with a loopback URL", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "staging",
        VITE_SUPABASE_URL: "https://localhost:54321",
        VITE_SUPABASE_PUBLISHABLE_KEY: publishableKey,
      }).status,
    ).toBe("configuration_error");
  });

  it.each([
    "not-a-url-with-private-diagnostic",
    "https://user:password@abcdefghijklmnopqrst.supabase.co",
    "https://qnthofvccilhnefdcxnz.supabase.co",
  ])("rejects unsafe URL without echoing it", (unsafeUrl) => {
    const result = readAtlasBrowserEnvironment({
      VITE_ATLAS_ENVIRONMENT: "staging",
      VITE_SUPABASE_URL: unsafeUrl,
      VITE_SUPABASE_PUBLISHABLE_KEY: publishableKey,
    });
    expect(result.status).toBe("configuration_error");
    if (result.status === "configuration_error") {
      expect(result.safeMessage).not.toContain(unsafeUrl);
      expect(result.safeMessage).not.toContain("qnthofvccilhnefdcxnz");
    }
  });

  it.each([
    undefined,
    "",
    "malformed key with spaces",
    "sb_secret_private-value",
    legacyJwt("service_role"),
  ])("rejects missing, malformed, or privileged keys", (unsafeKey) => {
    const result = readAtlasBrowserEnvironment({
      VITE_ATLAS_ENVIRONMENT: "staging",
      VITE_SUPABASE_URL: `https://${stagingRef}.supabase.co`,
      VITE_SUPABASE_PUBLISHABLE_KEY: unsafeKey,
    });
    expect(result.status).toBe("configuration_error");
    if (result.status === "configuration_error" && unsafeKey) {
      expect(result.safeMessage).not.toContain(unsafeKey);
    }
  });

  it("accepts a legacy anonymous JWT", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "staging",
        VITE_SUPABASE_URL: `https://${stagingRef}.supabase.co`,
        VITE_SUPABASE_PUBLISHABLE_KEY: legacyJwt("anon"),
      }).status,
    ).toBe("configured");
  });

  it("rejects credentials placed in unrelated browser variables", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "local",
        VITE_SUPABASE_URL: "http://localhost:54321",
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
        VITE_SUPABASE_SERVICE_ROLE_KEY: "must-not-enter-browser",
      }).status,
    ).toBe("configuration_error");
  });

  it("does not initialize a client when configuration is invalid", () => {
    const factory = vi.fn();
    const result = createAtlasSupabaseClient(
      readAtlasBrowserEnvironment({}),
      factory,
    );
    expect(result.status).toBe("configuration_error");
    expect(factory).not.toHaveBeenCalled();
  });

  it("initializes one client with retries disabled and retains the label", () => {
    const client = {} as SupabaseClient;
    const factory = vi.fn(() => client);
    const result = createAtlasSupabaseClient(
      readAtlasBrowserEnvironment({
        VITE_ATLAS_ENVIRONMENT: "local",
        VITE_SUPABASE_URL: "http://localhost:54321",
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
      }),
      factory,
    );
    expect(result).toEqual({
      status: "configured",
      client,
      environmentLabel: "Local · non-production",
    });
    expect(factory).toHaveBeenCalledOnce();
    expect(factory).toHaveBeenCalledWith(
      "http://localhost:54321",
      "local-publishable",
      { db: { retry: false } },
    );
  });
});
