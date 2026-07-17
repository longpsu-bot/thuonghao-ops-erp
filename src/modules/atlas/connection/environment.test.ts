import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { readAtlasBrowserEnvironment } from "./environment";
import { createAtlasSupabaseClient } from "./supabaseClient";

describe("Atlas browser environment", () => {
  it("fails safely when the URL is missing", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
      }).status,
    ).toBe("configuration_error");
  });

  it("fails safely when the publishable key is missing", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_SUPABASE_URL: "http://127.0.0.1:54321",
      }).status,
    ).toBe("configuration_error");
  });

  it("rejects a malformed URL without returning its value", () => {
    const unsafeValue = "not-a-url-with-private-diagnostic";
    const result = readAtlasBrowserEnvironment({
      VITE_SUPABASE_URL: unsafeValue,
      VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
    });
    expect(result.status).toBe("configuration_error");
    if (result.status === "configuration_error") {
      expect(result.safeMessage).not.toContain(unsafeValue);
    }
  });

  it("accepts the documented local URL and publishable key", () => {
    expect(
      readAtlasBrowserEnvironment({
        VITE_SUPABASE_URL: "http://127.0.0.1:54321/",
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
      }),
    ).toEqual({
      status: "configured",
      config: {
        supabaseUrl: "http://127.0.0.1:54321",
        publishableKey: "local-publishable",
        environmentLabel: "Local · non-production",
      },
    });
  });

  it("does not accept a hosted fallback", () => {
    const result = readAtlasBrowserEnvironment({
      VITE_SUPABASE_URL: "https://example.supabase.co",
      VITE_SUPABASE_PUBLISHABLE_KEY: "hosted-key",
    });
    expect(result.status).toBe("configuration_error");
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

  it("initializes one client with browser-safe settings and retries disabled", () => {
    const client = {} as SupabaseClient;
    const factory = vi.fn(() => client);
    const result = createAtlasSupabaseClient(
      readAtlasBrowserEnvironment({
        VITE_SUPABASE_URL: "http://localhost:54321",
        VITE_SUPABASE_PUBLISHABLE_KEY: "local-publishable",
      }),
      factory,
    );
    expect(result).toEqual({ status: "configured", client });
    expect(factory).toHaveBeenCalledOnce();
    expect(factory).toHaveBeenCalledWith(
      "http://localhost:54321",
      "local-publishable",
      { db: { retry: false } },
    );
  });
});
