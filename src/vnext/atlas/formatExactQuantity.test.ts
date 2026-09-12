import { describe, expect, it } from "vitest";
import { formatExactQuantity, formatExactDelta } from "./formatExactQuantity";
describe("exact quantity presentation", () => {
  it.each([
    ["100.000000", "100"],
    ["48.500000", "48,5"],
    ["25.750000", "25,75"],
    ["900719925474099312345.123456", "900719925474099312345,123456"],
  ])("preserves %s", (value, want) =>
    expect(formatExactQuantity(value)).toBe(want),
  );
  it.each([
    ["0.000000", "0"],
    ["-0.000000", "0"],
    ["2.500000", "+2,5"],
    ["-2.500000", "-2,5"],
    ["900719925474099312345.123456", "+900719925474099312345,123456"],
    ["-0.000001", "-0,000001"],
  ])("signs backend delta %s", (value, want) =>
    expect(formatExactDelta(value)).toBe(want),
  );
});
