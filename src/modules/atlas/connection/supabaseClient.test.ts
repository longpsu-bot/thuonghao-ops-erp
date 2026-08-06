import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createAtlasSupabaseClient } from "./supabaseClient";

describe("Atlas Supabase client factory", () => {
  it("does not call the factory after a safe configuration error", () => {
    const factory = vi.fn();
    expect(
      createAtlasSupabaseClient(
        { status: "configuration_error", safeMessage: "Safe error." },
        factory,
      ),
    ).toEqual({ status: "configuration_error", safeMessage: "Safe error." });
    expect(factory).not.toHaveBeenCalled();
  });

  it("passes only URL, browser key, and no-retry options", () => {
    const client = {} as SupabaseClient;
    const factory = vi.fn(() => client);
    expect(
      createAtlasSupabaseClient(
        {
          status: "configured",
          config: {
            environment: "staging",
            supabaseUrl: "https://abcdefghijklmnopqrst.supabase.co",
            publishableKey: "sb_publishable_atlas_staging_test_value",
            projectRef: "abcdefghijklmnopqrst",
            environmentLabel: "Atlas staging · non-production",
          },
        },
        factory,
      ),
    ).toEqual({
      status: "configured",
      client,
      environmentLabel: "Atlas staging · non-production",
    });
    expect(factory).toHaveBeenCalledWith(
      "https://abcdefghijklmnopqrst.supabase.co",
      "sb_publishable_atlas_staging_test_value",
      { db: { retry: false } },
    );
  });
});
