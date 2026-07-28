import { describe, expect, it } from "vitest";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import {
  mondayOf,
  planningPreviewFromResult,
  planningResultMessage,
  viDate,
} from "./planningInputsModel";

describe("Planning input model", () => {
  it("formats an explicit Monday service week and Vietnamese dates", () => {
    expect(mondayOf(new Date("2026-08-06T10:00:00Z"))).toBe("2026-08-03");
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
