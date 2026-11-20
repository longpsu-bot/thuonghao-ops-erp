import {
  confirmedNeedInputDisplay,
  confirmedNeedQuantityMatchesStep,
  exactDecimalEqual,
  exactQuantityDisplay,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedQuantity,
  shoppingListUnitDisplay,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
  type ConfirmedNeedLineRequest,
} from "../bridges/confirmedNeed";
export function confirmedNeedUnitLabel(
  unit: ConfirmedNeedLine["controlled_unit"],
) {
  try {
    return shoppingListUnitDisplay(unit);
  } catch {
    return "Chưa có ĐVT";
  }
}
export function draftChanged(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  const initial = initialConfirmedNeedDraft(line);
  return (
    line.current_decision_id === null ||
    (draft.quantity_entered === true &&
      (!line.effective_policy ||
        !confirmedNeedQuantityMatchesStep(
          draft.exact_quantity,
          line.effective_policy.planning_step,
        ))) ||
    !exactDecimalEqual(
      initial.exact_quantity,
      normalizeConfirmedNeedQuantity(draft.exact_quantity) ??
        draft.exact_quantity,
    ) ||
    initial.reason_code !== draft.reason_code ||
    initial.reason_note.trim() !== draft.reason_note.trim()
  );
}
export function historicalQuantity(line: ConfirmedNeedLine) {
  return Boolean(
    line.current_decision_id &&
    (!line.effective_policy ||
      !line.confirmed_quantity_after ||
      !confirmedNeedQuantityMatchesStep(
        line.confirmed_quantity_after,
        line.effective_policy.planning_step,
      )),
  );
}
// Local feedback uses the exact effective Planning step; the backend remains
// authoritative for policy resolution, source membership and final eligibility.
export type ConfirmedNeedDraftError = {
  field: "quantity" | "reason" | "note";
  message: string;
};
export function draftError(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
): ConfirmedNeedDraftError | null {
  const initial = initialConfirmedNeedDraft(line);
  if (!line.effective_policy)
    return {
      field: "quantity",
      message: "Không có bước lượng hiệu lực cho dòng nhu cầu này.",
    };
  const entry = draft.quantity_entered
    ? draft.exact_quantity
    : confirmedNeedInputDisplay(initial.exact_quantity);
  if (
    !normalizeConfirmedNeedQuantity(entry) ||
    !confirmedNeedQuantityMatchesStep(
      entry,
      line.effective_policy.planning_step,
    )
  )
    return {
      field: "quantity",
      message: `Số lượng xác nhận phải theo bước ${exactQuantityDisplay(
        line.effective_policy.planning_step,
      )} ${confirmedNeedUnitLabel(line.controlled_unit)}.`,
    };
  const equalsBaseline = exactDecimalEqual(
    normalizeConfirmedNeedQuantity(draft.exact_quantity) ??
      draft.exact_quantity,
    initial.exact_quantity,
  );
  if (
    equalsBaseline &&
    draft.reason_code !== "PROPOSAL_ACCEPTED" &&
    !(line.current_decision_id && initial.reason_code !== "PROPOSAL_ACCEPTED")
  )
    return {
      field: "reason",
      message: "Số lượng không đổi nên không cần lý do điều chỉnh.",
    };
  if (!equalsBaseline && draft.reason_code === "PROPOSAL_ACCEPTED")
    return {
      field: "reason",
      message: "Hãy chọn lý do khi thay đổi số lượng.",
    };
  if (equalsBaseline && !line.current_decision_id && draft.reason_note.trim())
    return {
      field: "note",
      message: "Xóa ghi chú điều chỉnh để xác nhận theo đề xuất ban đầu.",
    };
  return null;
}
export function draftLineRequest(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
): ConfirmedNeedLineRequest {
  return {
    confirmed_need_line_id: line.confirmed_need_line_id,
    expected_current_revision_id: line.current_revision_id,
    expected_current_decision_id: line.current_decision_id,
    proposed_confirmed_quantity:
      normalizeConfirmedNeedQuantity(draft.exact_quantity) ??
      draft.exact_quantity,
    reason_code: draft.reason_code,
    reason_note: draft.reason_note.trim() || null,
  };
}

export function confirmedNeedSchool(school: ConfirmedNeedLine["school"]) {
  return {
    school_id: school.id,
    school_name: school.name,
    display_order: school.display_order,
  };
}
