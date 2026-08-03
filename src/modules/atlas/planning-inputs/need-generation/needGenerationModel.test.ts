import { describe, expect, it } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  formatQuantity,
  needGenerationReadbackFromResult,
  needGenerationResultAllowsExactRetry,
  needGenerationResultIsStale,
  needGenerationWorkbenchFromResult,
} from "./needGenerationModel";

const workbench = {
  period: { period_start: "2026-08-03", period_end: "2026-08-09" },
  allowed_actions: {},
  pagination: {},
  grouped_requirements: [],
  blocking_issues: [],
  warnings: [],
  run_history: [],
};

describe("RMVP-04 authoritative model", () => {
  it("accepts shaped workbench and command readback only from success results", () => {
    const read: AtlasRpcResult = {
      kind: "success",
      response: { success: true, workbench: workbench as never },
    };
    const command: AtlasRpcResult = {
      kind: "success",
      response: {
        success: true,
        authoritative_readback: workbench as never,
      },
    };
    expect(needGenerationWorkbenchFromResult(read)).toBe(workbench);
    expect(needGenerationReadbackFromResult(command)).toBe(workbench);
  });

  it("distinguishes exact retry outcomes from stale outcomes", () => {
    const retryable: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        safe_message: "safe",
        retryable: true,
      },
    };
    const stale: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_SOURCE_BINDING",
        safe_message: "safe",
      },
    };
    expect(needGenerationResultAllowsExactRetry(retryable)).toBe(true);
    expect(needGenerationResultIsStale(retryable)).toBe(false);
    expect(needGenerationResultAllowsExactRetry(stale)).toBe(false);
    expect(needGenerationResultIsStale(stale)).toBe(true);
  });

  it("formats backend quantities without recalculating them", () => {
    expect(formatQuantity(12.345678)).toBe("12,345678");
    expect(formatQuantity(0)).toBe("0");
  });
});
