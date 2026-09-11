import { expect, it } from "vitest";
import { schoolPxkQuantity } from "./schoolPxkQuantity";
it.each([
  ["100.000000", "100"],
  ["48.500000", "48,5"],
  ["25.750000", "25,75"],
  ["9007199254740993123456789.123450", "9007199254740993123456789,12345"],
  ["0.000001", "0,000001"],
  ["0.000000", "0"],
])("presents exact %s as %s without numeric conversion", (input, output) => {
  expect(schoolPxkQuantity(input)).toBe(output);
});
