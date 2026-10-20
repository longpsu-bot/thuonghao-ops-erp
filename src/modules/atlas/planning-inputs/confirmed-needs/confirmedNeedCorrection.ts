// Structural read validation only. PostgreSQL decides correction eligibility.
export type ConfirmedNeedCorrectionBinding = {
  expected_confirmed_need_release_id: string;
  expected_purchase_handoff_batch_id: string | null;
  expected_purchase_handoff_revision_id: string | null;
  expected_purchase_handoff_version: number | null;
  expected_source_fingerprint: string;
};
export type ConfirmedNeedCorrectionLine = {
  confirmed_need_line_id: string;
  current_revision_id: string;
  predecessor_revision_id: string | null;
  current_decision_id: string | null;
  predecessor_decision_id: string | null;
  old_confirmed_quantity: string | null;
  new_confirmed_quantity: string;
  difference: string | null;
  reason_code: string | null;
  reason_note: string | null;
  decided_by_actor_id: string | null;
  decided_at: string | null;
};
const record = (value: unknown): Record<string, unknown> | null =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
const uuid = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value);
const nullableText = (value: unknown) =>
  value === null || typeof value === "string";
const decimal = (value: unknown) =>
  typeof value === "string" && /^-?\d+(?:\.\d+)?$/.test(value);
function evidence(value: unknown): value is ConfirmedNeedCorrectionLine {
  const line = record(value);
  return Boolean(
    line &&
    typeof line.confirmed_need_line_id === "string" &&
    typeof line.current_revision_id === "string" &&
    decimal(line.new_confirmed_quantity) &&
    (line.old_confirmed_quantity === null ||
      decimal(line.old_confirmed_quantity)) &&
    (line.difference === null || decimal(line.difference)) &&
    [
      "predecessor_revision_id",
      "current_decision_id",
      "predecessor_decision_id",
      "reason_code",
      "reason_note",
      "decided_by_actor_id",
      "decided_at",
    ].every((key) => nullableText(line[key])),
  );
}
export function confirmedNeedCorrectionFromWorkbench(value: unknown) {
  const workbench = record(value),
    authority = record(workbench?.need_correction_authority);
  const release = record(authority?.original_release);
  if (
    !authority ||
    authority.contract_version !== "RMVP-05.v3" ||
    typeof authority.operationally_available !== "boolean" ||
    typeof authority.downstream_workflow_available !== "boolean" ||
    authority.supplier_commitment_changed !== false ||
    !uuid(release?.confirmed_need_release_id) ||
    typeof authority.source_fingerprint !== "string" ||
    !/^[0-9a-f]{64}$/.test(authority.source_fingerprint) ||
    !Array.isArray(authority.current_lines) ||
    !authority.current_lines.every(evidence) ||
    !Array.isArray(authority.pending_obligations) ||
    !authority.pending_obligations.every((item) => typeof item === "string")
  )
    return null;
  const handoff =
    authority.purchase_handoff === null
      ? null
      : record(authority.purchase_handoff);
  if (
    authority.purchase_handoff !== null &&
    (!handoff ||
      !uuid(handoff.purchase_handoff_batch_id) ||
      !uuid(handoff.purchase_handoff_revision_id) ||
      typeof handoff.version !== "number" ||
      !Number.isSafeInteger(handoff.version) ||
      handoff.version < 1)
  )
    return null;
  const binding: ConfirmedNeedCorrectionBinding = {
    expected_confirmed_need_release_id: release.confirmed_need_release_id,
    expected_purchase_handoff_batch_id:
      (handoff?.purchase_handoff_batch_id as string | null) ?? null,
    expected_purchase_handoff_revision_id:
      (handoff?.purchase_handoff_revision_id as string | null) ?? null,
    expected_purchase_handoff_version:
      (handoff?.version as number | null) ?? null,
    expected_source_fingerprint: authority.source_fingerprint,
  };
  return {
    binding,
    allowed:
      record(workbench?.allowed_actions)?.correct_released_confirmed_needs ===
        true && authority.operationally_available === true,
    downstreamReviewAvailable: authority.downstream_workflow_available,
    lines: authority.current_lines,
    pendingObligations: authority.pending_obligations as string[],
  };
}
