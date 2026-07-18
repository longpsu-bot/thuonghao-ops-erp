import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const fixture = {
  authSubject: "b6000000-0000-0000-0000-000000000101",
  email: "atlas.pa06b.operator@local.test",
  password: "Atlas-PA06B-local-only!",
  correlationId: "b6c90000-0000-0000-0000-000000000100",
  sourceLineRevisionId: "b6c20000-0000-0000-0000-000000000202",
  allocationId: "b6c30000-0000-0000-0000-000000000600",
  allocationLineRevisionId: "b6c30000-0000-0000-0000-000000000603",
  purchaseOrderId: "b6c30000-0000-0000-0000-000000000700",
  purchaseOrderLineRevisionId: "b6c30000-0000-0000-0000-000000000703",
  supplierId: "b6c10000-0000-0000-0000-000000000104",
  ingredientId: "b6c10000-0000-0000-0000-000000000103",
  unitId: "b6c10000-0000-0000-0000-000000000102",
  deliveryLocationId: "b6c10000-0000-0000-0000-000000000101",
  serviceDate: "2026-07-18",
};

const commandIds = {
  recordFirst: "b6c90000-0000-0000-0000-000000000101",
  applyFirst: "b6c90000-0000-0000-0000-000000000102",
  recordStale: "b6c90000-0000-0000-0000-000000000103",
  recordFresh: "b6c90000-0000-0000-0000-000000000104",
  applyStale: "b6c90000-0000-0000-0000-000000000105",
  applyFresh: "b6c90000-0000-0000-0000-000000000106",
};

function assert(condition, safeMessage) {
  if (!condition) throw new Error(safeMessage);
}

function readRequest(payload) {
  return {
    contract_version: "PA-05C.v1",
    correlation_id: fixture.correlationId,
    requested_by_auth_subject: fixture.authSubject,
    payload,
  };
}

function commandRequest({
  commandId,
  idempotencyKey,
  expectedVersion,
  reasonCode,
  payload,
}) {
  return {
    contract_version: "PA-05B.v1",
    command_id: commandId,
    correlation_id: fixture.correlationId,
    idempotency_key: idempotencyKey,
    expected_version: expectedVersion,
    requested_by_auth_subject: fixture.authSubject,
    requested_at: "2026-07-18T01:00:00.000Z",
    reason_code: reasonCode,
    reason_note: "Synthetic PA-06C local acceptance.",
    payload,
  };
}

async function invoke(client, functionName, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(functionName, { request })
    .retry(false);
  if (error || !data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error(`The ${functionName} RPC transport failed safely.`);
  }
  return data;
}

function readinessContext(response) {
  assert(
    response.success === true && Array.isArray(response.readiness_items),
    "READ-02 did not return a successful readiness collection.",
  );
  const item = response.readiness_items[0];
  const allocation = item?.command_context?.fulfilment_allocation;
  const purchaseOrder = item?.command_context?.purchase_commitments?.find(
    (candidate) => candidate.purchase_order_id === fixture.purchaseOrderId,
  );
  assert(
    allocation?.fulfilment_allocation_id === fixture.allocationId &&
      purchaseOrder?.purchase_order_line_revision_id ===
        fixture.purchaseOrderLineRevisionId,
    "READ-02 did not return the predetermined PA-06C command context.",
  );
  return { item, allocation, purchaseOrder };
}

async function readReadiness(client) {
  return readinessContext(
    await invoke(
      client,
      "get_dispatch_evidence_readiness",
      readRequest({
        wholesale_order_line_revision_id: fixture.sourceLineRevisionId,
      }),
    ),
  );
}

async function readBlockers(client) {
  const response = await invoke(
    client,
    "get_operator_blockers",
    readRequest({
      service_date: fixture.serviceDate,
      delivery_location_id: fixture.deliveryLocationId,
    }),
  );
  assert(
    response.success === true && Array.isArray(response.blockers),
    "READ-03 did not return a successful blocker collection.",
  );
  return response.blockers;
}

async function inspectTimeline(client, commandId) {
  const response = await invoke(
    client,
    "get_command_audit_timeline",
    readRequest({ command_id: commandId }),
  );
  assert(
    response.success === true &&
      response.command_receipt_summary &&
      Array.isArray(response.domain_events) &&
      response.domain_events.length === 1 &&
      Array.isArray(response.audit_events) &&
      response.audit_events.length === 1,
    "READ-04 did not return distinct receipt, domain-event, and audit-event evidence.",
  );
}

function recordPayload(quantity, evidenceReference, occurredAt) {
  return {
    purchase_order_line_revision_id: fixture.purchaseOrderLineRevisionId,
    supplier_id: fixture.supplierId,
    ingredient_id: fixture.ingredientId,
    unit_id: fixture.unitId,
    evidence_quantity: quantity,
    evidence_reference: evidenceReference,
    occurred_at: occurredAt,
  };
}

function applyPayload(evidenceId, quantity, occurredAt) {
  return {
    supplier_receiving_evidence_id: evidenceId,
    fulfilment_allocation_line_revision_id: fixture.allocationLineRevisionId,
    unit_id: fixture.unitId,
    applied_quantity: quantity,
    occurred_at: occurredAt,
  };
}

function assertSuccessfulCommand(response, safeMessage) {
  assert(
    response.success === true && response.idempotency_status === "COMPLETED",
    safeMessage,
  );
}

function assertStale(response, expectedVersion, actualVersion) {
  assert(
    response.success === false &&
      response.error_code === "STALE_VERSION" &&
      response.expected_version === expectedVersion &&
      response.actual_version === actualVersion,
    "The stale-version guard did not return its reviewed safe category.",
  );
}

function mutateFixtureToVersionTwo() {
  const staleFixturePath = fileURLToPath(
    new URL(
      "../supabase/local/pa_06c_stale_version_fixture.sql",
      import.meta.url,
    ),
  );
  runPinnedSupabase(["db", "query", "--local", "--file", staleFixturePath], {
    stdio: "inherit",
  });
}

function assertDatabaseAcceptance() {
  const assertionPath = fileURLToPath(
    new URL(
      "../supabase/local/pa_06c_supplier_evidence_acceptance_assertion.sql",
      import.meta.url,
    ),
  );
  runPinnedSupabase(["db", "query", "--local", "--file", assertionPath], {
    stdio: "inherit",
  });
}

async function main() {
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  const client = createClient(apiUrl, browserKey, {
    db: { retry: false },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  let signedIn = false;
  try {
    const { data, error } = await client.auth.signInWithPassword({
      email: fixture.email,
      password: fixture.password,
    });
    assert(
      !error && data.session?.user.id === fixture.authSubject,
      "The deterministic PA-06C local sign-in did not succeed.",
    );
    signedIn = true;
    const { data: sessionData, error: sessionError } =
      await client.auth.getSession();
    assert(
      !sessionError && sessionData.session?.user.id === fixture.authSubject,
      "The deterministic PA-06C Auth session was not available.",
    );

    const initial = await readReadiness(client);
    assert(
      initial.purchaseOrder.purchase_order_version === 1 &&
        initial.allocation.fulfilment_allocation_version === 1 &&
        Number(initial.item.applied_evidence_quantity) === 0,
      "The PA-06C fixture did not begin at versions 1/1 with no applied Evidence.",
    );
    await readBlockers(client);

    const firstRecordRequest = commandRequest({
      commandId: commandIds.recordFirst,
      idempotencyKey: "pa06c-record-001",
      expectedVersion: initial.purchaseOrder.purchase_order_version,
      reasonCode: "SUPPLIER_RECEIPT",
      payload: recordPayload(
        4,
        "PA06C-EVIDENCE-001",
        "2026-07-18T01:01:00.000Z",
      ),
    });
    const firstRecord = await invoke(
      client,
      "record_supplier_receiving_evidence",
      firstRecordRequest,
    );
    assertSuccessfulCommand(
      firstRecord,
      "The first Record Evidence command failed.",
    );
    const firstEvidenceId =
      firstRecord.affected_aggregate_ids?.supplier_receiving_evidence_id;
    assert(
      typeof firstEvidenceId === "string",
      "Record Evidence returned no Evidence identity.",
    );
    await readReadiness(client);
    await readBlockers(client);
    await inspectTimeline(client, commandIds.recordFirst);

    const firstRecordReplay = await invoke(
      client,
      "record_supplier_receiving_evidence",
      firstRecordRequest,
    );
    assert(
      firstRecordReplay.success === true &&
        firstRecordReplay.idempotency_status === "COMPLETED" &&
        firstRecordReplay.affected_aggregate_ids
          ?.supplier_receiving_evidence_id === firstEvidenceId,
      "The exact Record Evidence replay did not return the original result.",
    );

    const firstApplyRequest = commandRequest({
      commandId: commandIds.applyFirst,
      idempotencyKey: "pa06c-apply-001",
      expectedVersion: initial.allocation.fulfilment_allocation_version,
      reasonCode: "APPLY_SUPPLIER_EVIDENCE",
      payload: applyPayload(firstEvidenceId, 4, "2026-07-18T01:02:00.000Z"),
    });
    const firstApply = await invoke(
      client,
      "apply_supplier_evidence_to_allocation",
      firstApplyRequest,
    );
    assertSuccessfulCommand(
      firstApply,
      "The first Apply Evidence command failed.",
    );
    await readReadiness(client);
    await readBlockers(client);
    await inspectTimeline(client, commandIds.applyFirst);

    const firstApplyReplay = await invoke(
      client,
      "apply_supplier_evidence_to_allocation",
      firstApplyRequest,
    );
    assert(
      firstApplyReplay.success === true &&
        firstApplyReplay.idempotency_status === "COMPLETED" &&
        firstApplyReplay.affected_aggregate_ids?.evidence_application_id ===
          firstApply.affected_aggregate_ids?.evidence_application_id,
      "The exact Apply Evidence replay did not return the original result.",
    );

    mutateFixtureToVersionTwo();

    const staleRecord = await invoke(
      client,
      "record_supplier_receiving_evidence",
      commandRequest({
        commandId: commandIds.recordStale,
        idempotencyKey: "pa06c-record-stale-002",
        expectedVersion: 1,
        reasonCode: "SUPPLIER_RECEIPT",
        payload: recordPayload(
          6,
          "PA06C-EVIDENCE-002",
          "2026-07-18T01:03:00.000Z",
        ),
      }),
    );
    assertStale(staleRecord, 1, 2);
    const refreshedForRecord = await readReadiness(client);
    assert(
      refreshedForRecord.purchaseOrder.purchase_order_version === 2,
      "READ-02 did not refresh the current Purchase Order version.",
    );
    const freshRecord = await invoke(
      client,
      "record_supplier_receiving_evidence",
      commandRequest({
        commandId: commandIds.recordFresh,
        idempotencyKey: "pa06c-record-fresh-002",
        expectedVersion:
          refreshedForRecord.purchaseOrder.purchase_order_version,
        reasonCode: "SUPPLIER_RECEIPT",
        payload: recordPayload(
          6,
          "PA06C-EVIDENCE-002",
          "2026-07-18T01:03:00.000Z",
        ),
      }),
    );
    assertSuccessfulCommand(
      freshRecord,
      "The refreshed Record Evidence command failed.",
    );
    const secondEvidenceId =
      freshRecord.affected_aggregate_ids?.supplier_receiving_evidence_id;
    assert(
      typeof secondEvidenceId === "string",
      "The refreshed command returned no Evidence identity.",
    );

    const staleApply = await invoke(
      client,
      "apply_supplier_evidence_to_allocation",
      commandRequest({
        commandId: commandIds.applyStale,
        idempotencyKey: "pa06c-apply-stale-002",
        expectedVersion: 1,
        reasonCode: "APPLY_SUPPLIER_EVIDENCE",
        payload: applyPayload(secondEvidenceId, 6, "2026-07-18T01:04:00.000Z"),
      }),
    );
    assertStale(staleApply, 1, 2);
    const refreshedForApply = await readReadiness(client);
    assert(
      refreshedForApply.allocation.fulfilment_allocation_version === 2,
      "READ-02 did not refresh the current allocation version.",
    );
    const freshApply = await invoke(
      client,
      "apply_supplier_evidence_to_allocation",
      commandRequest({
        commandId: commandIds.applyFresh,
        idempotencyKey: "pa06c-apply-fresh-002",
        expectedVersion:
          refreshedForApply.allocation.fulfilment_allocation_version,
        reasonCode: "APPLY_SUPPLIER_EVIDENCE",
        payload: applyPayload(secondEvidenceId, 6, "2026-07-18T01:04:00.000Z"),
      }),
    );
    assertSuccessfulCommand(
      freshApply,
      "The refreshed Apply Evidence command failed.",
    );

    const completed = await readReadiness(client);
    await readBlockers(client);
    assert(
      Number(completed.item.applied_evidence_quantity) === 10 &&
        completed.item.evidence_references.length === 2,
      "The final readiness view did not trace both Evidence rows and 10 applied units.",
    );
    assertDatabaseAcceptance();
  } finally {
    if (signedIn) {
      const { error: signOutError } = await client.auth.signOut({
        scope: "local",
      });
      assert(!signOutError, "The deterministic PA-06C sign-out failed.");
      const { data: afterSignOut, error: sessionError } =
        await client.auth.getSession();
      assert(
        !sessionError && !afterSignOut.session,
        "The PA-06C local session remained after sign-out.",
      );
    }
  }

  console.log(
    "Verified PA-06C fixture reads, reviewed commands, exact replays, stale refresh, timelines, and sign-out.",
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "PA-06C local acceptance failed safely.",
  );
  process.exitCode = 1;
}
