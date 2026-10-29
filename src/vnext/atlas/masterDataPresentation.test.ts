import { describe, expect, it } from "vitest";
import {
  operatorMasterReference,
  operatorUnitLabel,
} from "./masterDataPresentation";

describe("operator-facing imported master labels", () => {
  it("hides migration-only references while retaining business references", () => {
    expect(operatorMasterReference("v1-school-11")).toBeNull();
    expect(operatorMasterReference("v1-ingredient-931")).toBeNull();
    expect(operatorMasterReference("TH001")).toBe("TH001");
  });

  it("uses the Unit name when its code is technical", () => {
    expect(
      operatorUnitLabel({
        unit_code: "v1-unit-ea9046ea54e4",
        unit_name: "Hộp",
      }),
    ).toBe("Hộp");
    expect(operatorUnitLabel({ unit_code: "kg", unit_name: "Kilogram" })).toBe(
      "kg",
    );
  });
});
