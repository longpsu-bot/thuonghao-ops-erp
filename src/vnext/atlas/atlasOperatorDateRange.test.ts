import { describe, expect, it } from "vitest";
import { operatorDateRangeError } from "./atlasOperatorDateRange";

describe("operator document range", () => {
  it.each([
    ["2026-10-10", "2026-10-10"],
    ["2026-10-10", "2026-10-11"],
    ["2026-10-10", "2026-10-16"],
    ["2026-09-29", "2026-10-05"],
  ])("accepts inclusive dates %s to %s", (start, end) => {
    expect(operatorDateRangeError({ start, end })).toBeNull();
  });
  it("blocks eight inclusive days", () => {
    expect(
      operatorDateRangeError({ start: "2026-10-10", end: "2026-10-17" }),
    ).toBe("Chọn tối đa 7 ngày.");
  });
  it("blocks reversed and invalid calendar dates", () => {
    expect(
      operatorDateRangeError({ start: "2026-10-10", end: "2026-10-09" }),
    ).toBe("Ngày kết thúc phải từ ngày bắt đầu.");
    expect(
      operatorDateRangeError({ start: "2026-02-30", end: "2026-03-01" }),
    ).toBe("Chọn ngày hợp lệ.");
  });
});
