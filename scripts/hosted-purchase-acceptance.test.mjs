import { test } from "vitest";
import assert from "node:assert/strict";
import {
  executeAcceptance,
  assertPreflight,
} from "./hosted-purchase-acceptance.mjs";

test("preflight fails closed on changed target or downstream facts", () => {
  const valid = {
    batch: { state: "DRAFT_REVIEW", version: 2 },
    allocations: 0,
    handoffs: 0,
    po_roots: 0,
    po_lines: 0,
  };
  const read = {
    success: true,
    rows: Array.from({ length: 236 }, (_, i) => ({
      complete: true,
      family_quantity: "1.000000",
      recommendation: { supplier_id: String(i % 17) },
    })),
    preparation: {
      ready: true,
      allowed: true,
      blockers: [],
      expected_version: 2,
      confirmed_need_batch_id: "69661e86-abb3-4bf4-88a5-4717fe18c472",
      service_date: "2026-10-12",
    },
  };
  assert.doesNotThrow(() => assertPreflight(valid, read));
  assert.throws(() => assertPreflight({ ...valid, allocations: 1 }, read));
  assert.throws(() =>
    assertPreflight(valid, { ...read, rows: read.rows.slice(1) }),
  );
});

test("unknown transport outcome performs readback and never sends another command", async () => {
  let calls = 0,
    reads = 0;
  const evidence = {};
  await assert.rejects(
    executeAcceptance({
      request: { command_id: "known" },
      evidence,
      save: () => {},
      rpc: async () => {
        calls++;
        throw Error("disconnect");
      },
      snapshot: async () => {
        reads++;
        return { allocations: 236 };
      },
    }),
  );
  assert.equal(calls, 1);
  assert.equal(reads, 1);
  assert.equal(evidence.recovery.allocations, 236);
  assert.equal(evidence.status, "UNKNOWN_OUTCOME");
});

test("successful replay reuses the same object and rejects any fact delta", async () => {
  const request = { command_id: "known" };
  const evidence = {};
  let calls = 0;
  await assert.rejects(
    executeAcceptance({
      request,
      evidence,
      save: () => {},
      rpc: async (r) => {
        assert.equal(r, request);
        calls++;
        return { elapsed_ms: 12, response: { success: true } };
      },
      snapshot: async () => ({ changed: calls }),
      validate: () => {},
    }),
    /REPLAY_FACT_DELTA/,
  );
  assert.equal(calls, 2);
});

test("confirmed failure never replays", async () => {
  let calls = 0;
  await assert.rejects(
    executeAcceptance({
      request: {},
      evidence: {},
      save: () => {},
      rpc: async () => {
        calls++;
        return { elapsed_ms: 20, response: { success: false } };
      },
      snapshot: async () => ({}),
      validate: () => {},
    }),
    /PUBLIC_COMMAND_FAILED/,
  );
  assert.equal(calls, 1);
});

test("successful command and exact replay preserve both response and facts", async () => {
  const request = { command_id: "known" };
  const evidence = {};
  let calls = 0;
  await executeAcceptance({
    request,
    evidence,
    save: () => {},
    rpc: async (r) => {
      assert.equal(r, request);
      calls++;
      return { elapsed_ms: 100, response: { success: true } };
    },
    snapshot: async () => ({ fact_digest: "same" }),
    validate: () => {},
  });
  assert.equal(calls, 2);
  assert.equal(evidence.status, "HOSTED_ACCEPTANCE_PASS");
});
