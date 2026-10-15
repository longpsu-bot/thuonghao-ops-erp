import { describe, expect, it } from "vitest";
import { humanUnitLabel, operatorUnitLabel } from "./unitDisplay";

describe("operator Unit labels", () => {
  it.each([
    [" Cái ", "v1-unit-91a0b1c14124", "Cái"],
    ["Kilogram", "kg", "Kilogram"],
    ["Miếng", "piece", "Miếng"],
    [null, "kg", "kg"],
    ["?", "kg", "kg"],
    ["v1-unit-technical", "kg", "kg"],
  ])("prefers human name %s then legacy code %s", (name, code, expected) => {
    expect(humanUnitLabel(name, code)).toBe(expected);
    expect(operatorUnitLabel(name, code)).toBe(expected);
  });
  it.each([
    [null, "v1-unit-91a0b1c14124"],
    [undefined, "atlas:unit"],
    ["unit_internal", "?"],
    ["", "a4150000-0000-4000-8000-000000000001"],
    ["Cái\nkhác", "\t"],
  ])("shows a controlled warning for missing human evidence", (name, code) => {
    expect(humanUnitLabel(name, code)).toBeNull();
    expect(operatorUnitLabel(name, code)).toBe("Chưa có tên đơn vị");
  });
});
