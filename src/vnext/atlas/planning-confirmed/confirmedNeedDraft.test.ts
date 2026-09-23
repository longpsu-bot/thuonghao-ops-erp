import { describe, expect, it } from "vitest";
import { initialConfirmedNeedDraft } from "../bridges/confirmedNeed";
import { reviewLine } from "./confirmedNeedReviewFixtures";
import { draftError, historicalQuantity } from "./confirmedNeedDraft";

function lineForStep(step: string, unitCode = "kg") {
  const line = reviewLine();
  line.proposed_confirmed_quantity = "1.200000";
  line.confirmed_quantity_after = null;
  line.current_decision_id = null;
  line.current_decision_number = null;
  line.current_decision_kind = null;
  line.effective_policy!.planning_step = step;
  line.controlled_unit.code = unitCode;
  return line;
}

describe("Confirmed Need exact Planning-step drafts", () => {
  it("keeps a fresh high-precision proposal editable", () => {
    const line = lineForStep("0.000001");
    line.proposed_confirmed_quantity = "10.123456";
    expect(historicalQuantity(line)).toBe(false);
  });

  it("protects only an authoritative historical value that cannot round-trip through its policy step", () => {
    const line = reviewLine();
    line.confirmed_quantity_after = "10.123456";
    line.effective_policy!.planning_step = "0.250000";
    expect(historicalQuantity(line)).toBe(true);
    line.confirmed_quantity_after = "10.250000";
    expect(historicalQuantity(line)).toBe(false);
  });

  it.each(["1.23", "1.230000"])("accepts exact %s at step 0.01", (quantity) => {
    const line = lineForStep("0.010000");
    expect(
      draftError(line, {
        ...initialConfirmedNeedDraft(line),
        exact_quantity: quantity,
        quantity_entered: true,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Bếp yêu cầu",
      }),
    ).toBeNull();
  });

  it("rejects 1.235 at step 0.01 with the applicable step and unit", () => {
    const line = lineForStep("0.010000");
    expect(
      draftError(line, {
        ...initialConfirmedNeedDraft(line),
        exact_quantity: "1.235",
        quantity_entered: true,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Bếp yêu cầu",
      }),
    ).toBe("Số lượng phải là bội số của bước 0,01 kg.");
  });

  it.each(["4", "4.0"])("accepts exact %s at step 1", (quantity) => {
    const line = lineForStep("1.000000", "Quả");
    expect(
      draftError(line, {
        ...initialConfirmedNeedDraft(line),
        exact_quantity: quantity,
        quantity_entered: true,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Bếp yêu cầu",
      }),
    ).toBeNull();
  });

  it("rejects 4.5 at step 1 without replacing the entered value", () => {
    const line = lineForStep("1.000000", "Quả");
    const draft = {
      ...initialConfirmedNeedDraft(line),
      exact_quantity: "4.5",
      quantity_entered: true,
      reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT" as const,
      reason_note: "Bếp yêu cầu",
    };
    expect(draftError(line, draft)).toBe(
      "Số lượng phải là bội số của bước 1 Quả.",
    );
    expect(draft.exact_quantity).toBe("4.5");
  });
});
