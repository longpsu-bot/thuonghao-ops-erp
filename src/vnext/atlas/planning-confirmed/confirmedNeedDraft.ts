import {
  confirmedNeedInputDisplay,
  exactDecimalEqual,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedEntry,
  normalizeConfirmedNeedQuantity,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
  type ConfirmedNeedLineRequest,
} from "../bridges/confirmedNeed";
export function draftChanged(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  const initial = initialConfirmedNeedDraft(line);
  return (
    line.current_decision_id === null ||
    (draft.quantity_entered === true &&
      !normalizeConfirmedNeedEntry(draft.exact_quantity)) ||
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
  return !normalizeConfirmedNeedEntry(
    confirmedNeedInputDisplay(initialConfirmedNeedDraft(line).exact_quantity),
  );
}
// Local input restrictions mirror the reviewed legacy editor; the backend remains
// authoritative for policy steps, source membership and final eligibility.
export function draftError(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  const initial = initialConfirmedNeedDraft(line);
  if (
    !normalizeConfirmedNeedEntry(
      draft.quantity_entered
        ? draft.exact_quantity
        : confirmedNeedInputDisplay(initial.exact_quantity),
    )
  )
    return "Số lượng phải là số không âm, tối đa 2 chữ số thập phân.";
  const equalsProposal = exactDecimalEqual(
    normalizeConfirmedNeedQuantity(draft.exact_quantity) ??
      draft.exact_quantity,
    line.proposed_confirmed_quantity,
  );
  if (
    equalsProposal &&
    draft.reason_code !== "PROPOSAL_ACCEPTED" &&
    !(line.current_decision_id && initial.reason_code !== "PROPOSAL_ACCEPTED")
  )
    return "Số lượng không đổi nên không cần lý do điều chỉnh.";
  if (!equalsProposal && draft.reason_code === "PROPOSAL_ACCEPTED")
    return "Hãy chọn lý do khi thay đổi số lượng.";
  if (
    ["OPERATIONAL_QUANTITY_ADJUSTMENT", "OTHER"].includes(draft.reason_code) &&
    !draft.reason_note.trim()
  )
    return "Lý do này cần ghi chú.";
  if (
    line.current_decision_id &&
    draftChanged(line, draft) &&
    !draft.reason_note.trim()
  )
    return "Thay đổi nội dung đã lưu cần ghi chú.";
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
