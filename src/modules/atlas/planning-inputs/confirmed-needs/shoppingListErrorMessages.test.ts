import { describe, expect, it } from "vitest";
import { ShoppingListError } from "./shoppingListContract";

describe("Shopping-list recovery guidance", () => {
  it.each([
    ["READ_ONLY_WORKBENCH", /Chọn.*ngày.*chỉnh sửa/],
    ["STALE_AUTHORITY", /nhu cầu.*thay đổi/i],
    ["DIRTY_WORKBENCH", /Lưu.*bỏ.*thay đổi/],
    ["WORKBENCH_DATE_MISMATCH", /khoảng ngày/],
    ["INVALID_QUANTITY", /số lượng/i],
  ])("explains %s with the appropriate recovery", (code, guidance) => {
    expect(new ShoppingListError(code).message).toMatch(guidance);
    expect(new ShoppingListError(code).code).toBe(code);
  });
  it("preserves structural rejection and explicit caller guidance", () => {
    expect(new ShoppingListError("WORKBOOK_INVALID").message).toMatch(
      /sai cấu trúc/,
    );
    expect(
      new ShoppingListError("READ_ONLY_WORKBENCH", "Explicit guidance").message,
    ).toBe("Explicit guidance");
  });
});
