import { describe, expect, it } from "vitest";
import {
  parseExactQuantity,
  formatExactQuantityForOperator,
  sumExactQuantities,
} from "./procurementExactQuantity";

describe("Procurement exact quantities", () => {
  it.each([
    ["0", 0n],
    ["0.000000", 0n],
    [" 12.340000 ", 12340000n],
    ["9007199254740993.000001", 9007199254740993000001n],
  ])("parses %s without floating point", (input, expected) => {
    expect(parseExactQuantity(input)).toBe(expected);
  });
  it.each(["", "-1", "1e3", "NaN", "0.0000001", "1,2", ".5", "1.2.3"])(
    "rejects %s without inferring zero",
    (input) => expect(parseExactQuantity(input)).toBeNull(),
  );
  it("sums and subtracts exactly", () => {
    const total = sumExactQuantities(["0.1", "0.2"]);
    expect(total).toBe(parseExactQuantity("0.3"));
    expect(parseExactQuantity("1")! - total!).toBe(700000n);
    expect(sumExactQuantities([])).toBe(0n);
    expect(sumExactQuantities(["1", "bad"])).toBeNull();
  });
  it("formats trimmed human quantities including negative remainder", () => {
    expect(formatExactQuantityForOperator("123.450000")).toBe("123,45");
    expect(formatExactQuantityForOperator(-1n)).toBe("-0,000001");
    expect(formatExactQuantityForOperator("0.000000")).toBe("0");
    expect(formatExactQuantityForOperator(null)).toBe("—");
    expect(formatExactQuantityForOperator("9007199254740993.000001")).toBe(
      "9007199254740993,000001",
    );
  });
});
