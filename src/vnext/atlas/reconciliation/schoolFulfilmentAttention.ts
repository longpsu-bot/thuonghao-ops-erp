import type { SchoolFulfilmentRow } from "../bridges/schoolFulfilment";

/** Presentation only: comparison and operational readiness remain independent facts. */
export function needsAttention(row: SchoolFulfilmentRow): boolean {
  return (
    row.comparison_status !== "OK" ||
    row.blockers.length > 0 ||
    row.pxk_state === "REPLACEMENT_REQUIRED" ||
    row.pxk_state === "BLOCKED"
  );
}
