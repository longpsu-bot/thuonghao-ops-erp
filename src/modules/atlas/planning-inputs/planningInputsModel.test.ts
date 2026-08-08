import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import {
  mondayOf,
  planningPreviewFromResult,
  planningResultMessage,
  viDate,
} from "./planningInputsModel";

describe("Planning input model", () => {
  beforeAll(() => {
    vi.stubEnv("TZ", "Asia/Ho_Chi_Minh");
  });

  afterAll(() => {
    vi.unstubAllEnvs();
  });

  it("maps an ordinary local weekday to its Monday", () => {
    expect(mondayOf(new Date(2026, 7, 6, 10))).toBe("2026-08-03");
  });

  it("maps local Sunday back to the preceding Monday", () => {
    expect(mondayOf(new Date(2026, 7, 9, 12))).toBe("2026-08-03");
  });

  it("preserves an early-morning local Monday across UTC rollover", () => {
    expect(mondayOf(new Date(2026, 7, 9, 0, 30))).toBe("2026-08-03");
  });

  it("returns a zero-padded YYYY-MM-DD date", () => {
    expect(mondayOf(new Date(2026, 0, 7, 10))).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it("formats Vietnamese dates", () => {
    expect(viDate("2026-08-03")).toBe("03/08/2026");
  });

  it("parses a canonical preview and identifies stale source evidence", () => {
    const result: AtlasRpcResult = {
      kind: "success",
      response: {
        success: true,
        preview: {
          week_start: "2026-08-03",
          week_end: "2026-08-09",
          canonical_rows: [],
          source_signature: "checksum",
          row_count: 0,
          issues: { blockers: [], warnings: [] },
          can_save: true,
        },
      },
    };
    expect(planningPreviewFromResult(result)?.source_signature).toBe(
      "checksum",
    );
    expect(
      planningResultMessage({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "STALE_SOURCE_SIGNATURE",
          safe_message: "safe",
        },
      }),
    ).toContain("Nguồn dữ liệu đã thay đổi");
  });
});
