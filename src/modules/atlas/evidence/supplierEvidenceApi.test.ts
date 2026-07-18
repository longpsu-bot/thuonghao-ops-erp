import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcName, AtlasRpcRequest } from "../connection/atlasRpc";
import {
  PA06C_BLOCKER_SELECTOR,
  PA06C_READINESS_SELECTOR,
} from "./pa06cFixture";
import {
  createSupplierEvidenceApi,
  PA06C_RPC_FUNCTIONS,
  type EvidenceCommandRequest,
} from "./supplierEvidenceApi";

const subject = "b6000000-0000-0000-0000-000000000101";
const correlation = "b6c90000-0000-0000-0000-000000000100";

const commandRequest: EvidenceCommandRequest = {
  contract_version: "PA-05B.v1",
  command_id: "b6c90000-0000-0000-0000-000000000101",
  correlation_id: correlation,
  idempotency_key: "pa06c-test-command",
  expected_version: 1,
  requested_by_auth_subject: subject,
  requested_at: "2026-07-18T01:00:00.000Z",
  reason_code: "SUPPLIER_RECEIPT",
  reason_note: null,
  payload: { evidence_quantity: 10 },
};

describe("PA-06C supplier Evidence API boundary", () => {
  it("exposes exactly the two approved commands and three approved reads", () => {
    expect(PA06C_RPC_FUNCTIONS).toEqual({
      recordEvidence: "atlas_api.record_supplier_receiving_evidence",
      applyEvidence: "atlas_api.apply_supplier_evidence_to_allocation",
      getReadiness: "atlas_api.get_dispatch_evidence_readiness",
      getBlockers: "atlas_api.get_operator_blockers",
      getTimeline: "atlas_api.get_command_audit_timeline",
    });
    expect(Object.keys(PA06C_RPC_FUNCTIONS)).toHaveLength(5);
  });

  it("passes frozen command envelopes through without mutation", async () => {
    const invoke = vi.fn().mockResolvedValue({
      kind: "success",
      response: { success: true },
    });
    const api = createSupplierEvidenceApi({ invoke });

    await api.recordEvidence(commandRequest);
    await api.applyEvidence(commandRequest);

    expect(invoke).toHaveBeenNthCalledWith(
      1,
      PA06C_RPC_FUNCTIONS.recordEvidence,
      commandRequest,
    );
    expect(invoke).toHaveBeenNthCalledWith(
      2,
      PA06C_RPC_FUNCTIONS.applyEvidence,
      commandRequest,
    );
  });

  it("constructs only the fixed READ-02 and READ-03 fixture selectors", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createSupplierEvidenceApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });

    await api.getReadiness(subject, correlation);
    await api.getBlockers(subject, correlation);

    expect(calls).toEqual([
      [
        PA06C_RPC_FUNCTIONS.getReadiness,
        {
          contract_version: "PA-05C.v1",
          requested_by_auth_subject: subject,
          correlation_id: correlation,
          payload: PA06C_READINESS_SELECTOR,
        },
      ],
      [
        PA06C_RPC_FUNCTIONS.getBlockers,
        {
          contract_version: "PA-05C.v1",
          requested_by_auth_subject: subject,
          correlation_id: correlation,
          payload: PA06C_BLOCKER_SELECTOR,
        },
      ],
    ]);
  });

  it("constructs READ-04 only from the selected command identity", async () => {
    const invoke = vi.fn().mockResolvedValue({
      kind: "success",
      response: { success: true },
    });
    const api = createSupplierEvidenceApi({ invoke });

    await api.getTimeline(subject, correlation, commandRequest.command_id);

    expect(invoke).toHaveBeenCalledWith(PA06C_RPC_FUNCTIONS.getTimeline, {
      contract_version: "PA-05C.v1",
      requested_by_auth_subject: subject,
      correlation_id: correlation,
      payload: { command_id: commandRequest.command_id },
    });
  });
});
