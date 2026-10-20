import { describe, expect, it } from "vitest";
import { confirmedNeedCorrectionFromWorkbench } from "./confirmedNeedCorrection";

const release = "b6500000-0000-0000-0000-000000000001";
const authority = () => ({
  contract_version: "RMVP-05.v3",
  operationally_available: true,
  downstream_workflow_available: false,
  supplier_commitment_changed: false,
  source_fingerprint: "a".repeat(64),
  original_release: { confirmed_need_release_id: release },
  purchase_handoff: null,
  current_lines: [],
  pending_obligations: [],
});
const workbench = () => ({
  allowed_actions: { correct_released_confirmed_needs: true },
  need_correction_authority: authority(),
});
describe("K3 correction read projection", () => {
  it("uses only the five server bindings, including genuine absent Handoff", () => {
    expect(confirmedNeedCorrectionFromWorkbench(workbench())?.binding).toEqual({
      expected_confirmed_need_release_id: release,
      expected_purchase_handoff_batch_id: null,
      expected_purchase_handoff_revision_id: null,
      expected_purchase_handoff_version: null,
      expected_source_fingerprint: "a".repeat(64),
    });
  });
  it.each([undefined, false, "true", null])(
    "does not invent permission from an unavailable action %s",
    (action) => {
      const read = {
        ...workbench(),
        allowed_actions: { correct_released_confirmed_needs: action },
      };
      expect(confirmedNeedCorrectionFromWorkbench(read)?.allowed).toBe(false);
    },
  );
  it.each([false, undefined, "true"])(
    "honors unavailable or unknown operational availability %s",
    (available) => {
      const read = workbench();
      Object.assign(read.need_correction_authority, {
        operationally_available: available,
      });
      expect(confirmedNeedCorrectionFromWorkbench(read)?.allowed ?? false).toBe(
        false,
      );
    },
  );
  it("rejects incomplete Handoff evidence and a malformed server fingerprint", () => {
    const read = workbench();
    Object.assign(read.need_correction_authority, {
      purchase_handoff: { purchase_handoff_batch_id: release },
    });
    expect(confirmedNeedCorrectionFromWorkbench(read)).toBeNull();
    Object.assign(read.need_correction_authority, {
      purchase_handoff: null,
      source_fingerprint: "computed-locally",
    });
    expect(confirmedNeedCorrectionFromWorkbench(read)).toBeNull();
  });
});
