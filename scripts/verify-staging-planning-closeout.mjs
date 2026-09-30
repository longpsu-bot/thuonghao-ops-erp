import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";
import {
  classifyPlanningAdoptionManifest,
  planningAdoptionPostDeployQuerySql,
} from "./verify-staging-planning-adoption-manifest.mjs";

const SUBJECT = "a1010000-0000-4000-8000-000000000101";
const SYNTHETIC_ACTOR = "a1010000-0000-4000-8000-000000000001";
const RETAINED_RUN = "0c83b440-8fb2-4a77-9735-804ef4c89ea0";
const RETAINED_BATCH = "a0311e0a-a4de-48b9-a529-fe7464a3352b";
const CERTIFIED_PREVIEW_BASE_SHA = "9ba47752b5d7e2f750bca19d723c8de46751b771";
const APPROVED_PREVIEW_SHA = "a51759a1ae3c5d38e957b3824ee5c38c33e69205";
const APPROVED_PREVIEW_URL = "https://06e87532.thuonghao-ops-erp.pages.dev/";
const EXPECTED_SOURCE_FINGERPRINTS = Object.freeze({
  pantry: "d751713988987e9331980363e24189ce",
  attendance: "f0868d16c763ac48fc0d38bf22c47b95",
  weekly_menu: "7a165883b92ada506dfdc7a021e44710",
});
const APPROVED_COUNT_POLICIES = new Map([
  ["v1-unit-034ce34d3ff3", "Quả"],
  ["v1-unit-2d183c73d76a", "Bó"],
  ["v1-unit-469606e98b7e", "Gói"],
  ["v1-unit-46bab433cc1a", "Cốc"],
  ["v1-unit-83bea5cf6378", "Miếng"],
  ["v1-unit-91a0b1c14124", "Cái"],
  ["v1-unit-9837090d3b3f", "Hũ"],
  ["v1-unit-b1e160b3fbfb", "Chai"],
  ["v1-unit-c854d71627b2", "Cây"],
  ["v1-unit-cac06658f903", "Lon"],
  ["v1-unit-cad1515b85c4", "Ổ"],
  ["v1-unit-dafac3b7da11", "Bịch"],
  ["v1-unit-ea9046ea54e4", "Hộp"],
  ["v1-unit-eb0ce03e77fa", "Trái"],
]);
const RETAINED_ADOPTION_IDENTITY_FIELDS = Object.freeze([
  ["recipe_id", "recipe_id"],
  ["recipe_line_id", "recipe_line_id"],
  ["ingredient_id", "ingredient_id"],
]);
const RETAINED_ADOPTION_LINEAGE_SIDES = Object.freeze([
  Object.freeze({
    name: "TARGET",
    fields: Object.freeze([
      ["target_recipe_version_id", "recipe_version_id"],
      ["target_recipe_line_revision_id", "recipe_line_revision_id"],
      ["corrected_unit_id", "unit_id"],
    ]),
  }),
  Object.freeze({
    name: "PREDECESSOR",
    fields: Object.freeze([
      ["predecessor_recipe_version_id", "recipe_version_id"],
      ["predecessor_recipe_line_revision_id", "recipe_line_revision_id"],
      ["source_unit_id", "unit_id"],
    ]),
  }),
]);

const exactRetainedAdoptionFields = (evidence, theoretical, fields) =>
  fields.every(([evidenceField, theoreticalField]) => {
    const evidenceValue = evidence?.[evidenceField];
    const theoreticalValue = theoretical?.[theoreticalField];
    return (
      evidenceValue !== null &&
      evidenceValue !== undefined &&
      theoreticalValue !== null &&
      theoreticalValue !== undefined &&
      evidenceValue === theoreticalValue
    );
  });

export function retainedAdoptionLineageSide(evidence, theoretical) {
  if (
    evidence?.evidence_kind !==
      "OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION" ||
    evidence.source_system !== "OPS_V1" ||
    !exactRetainedAdoptionFields(
      evidence,
      theoretical,
      RETAINED_ADOPTION_IDENTITY_FIELDS,
    )
  )
    return null;
  return (
    RETAINED_ADOPTION_LINEAGE_SIDES.find(({ fields }) =>
      exactRetainedAdoptionFields(evidence, theoretical, fields),
    )?.name ?? null
  );
}

export function planningCloseoutPoliciesAccepted(rows) {
  if (!Array.isArray(rows) || rows.length !== 15) return false;
  const seen = new Set();
  for (const row of rows) {
    if (seen.has(row.unit_code)) return false;
    seen.add(row.unit_code);
    if (row.unit_code === "kg") {
      if (
        row.unit_name !== "Kilogram" ||
        row.dimension_code !== "MASS" ||
        row.unit_status !== "ACTIVE" ||
        row.planning_step !== 0.01 ||
        row.effective_from !== "2026-01-01" ||
        row.effective_to !== null ||
        row.policy_revision_status !== "ACTIVE" ||
        row.revision_number !== 1
      )
        return false;
    } else if (
      row.unit_name !== APPROVED_COUNT_POLICIES.get(row.unit_code) ||
      row.dimension_code !== "COUNT" ||
      row.unit_status !== "ACTIVE" ||
      row.planning_step !== 1 ||
      row.effective_from !== "2026-09-14" ||
      row.effective_to !== null ||
      row.policy_revision_status !== "ACTIVE" ||
      row.revision_number !== 1
    )
      return false;
  }
  return (
    seen.size === 15 &&
    [...APPROVED_COUNT_POLICIES.keys()].every((code) => seen.has(code)) &&
    seen.has("kg")
  );
}
function canonicalJson(value) {
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  return value;
}
const sameJson = (left, right) =>
  JSON.stringify(canonicalJson(left)) === JSON.stringify(canonicalJson(right));
const exactDate = (item) =>
  item?.period_start === "2026-09-17" && item?.period_end === "2026-09-17";
function preflightAccepted(preflight, currentness, runId, batchId) {
  const source = preflight?.source_date_fingerprints;
  const keys = ["attendance", "pantry", "weekly_menu"];
  return (
    preflight?.readiness_state === "READY" &&
    preflight.downstream_currentness === currentness &&
    preflight.blocking_issue_count === 0 &&
    source?.service_date === "2026-09-17" &&
    sameJson(Object.keys(source.selected ?? {}).sort(), keys) &&
    keys.every(
      (key) =>
        typeof source.selected[key] === "string" &&
        source.selected[key].length > 0,
    ) &&
    sameJson(source.selected, source.current) &&
    (runId
      ? preflight.current_need?.need_generation_run_id === runId &&
        preflight.current_need?.confirmed_need_batch_id === batchId &&
        preflight.current_need?.need_generation_run_version === 3 &&
        preflight.current_need?.confirmed_need_batch_version >= 1
      : preflight.current_need == null)
  );
}
function generationReceiptAccepted(receipt, run, batch, batchVersion) {
  return (
    receipt?.command_name === "execute_need_generation" &&
    receipt.actor_id === SYNTHETIC_ACTOR &&
    receipt.outcome === "COMPLETED" &&
    receipt.success === true &&
    receipt.affected_aggregate_ids?.need_generation_run_id === run.id &&
    receipt.affected_aggregate_ids?.confirmed_need_batch_id === batch.id &&
    receipt.new_versions?.need_generation_run_version === 3 &&
    receipt.new_versions?.confirmed_need_batch_version === batchVersion
  );
}

// Audit history is unordered. Each receipt must have exactly one semantic role.
export function classifyPlanningGenerationReceipts(
  receipts,
  successorRunId = null,
) {
  if (!Array.isArray(receipts)) return null;
  const roles = {
    original: null,
    benign: null,
    legacy_retryable_failure: null,
    correction: null,
  };
  const commands = new Set();
  for (const receipt of receipts) {
    if (
      typeof receipt?.command_id !== "string" ||
      !receipt.command_id ||
      commands.has(receipt.command_id)
    )
      return null;
    commands.add(receipt.command_id);
    const retained = generationReceiptAccepted(
      receipt,
      { id: RETAINED_RUN },
      { id: RETAINED_BATCH },
      1,
    );
    const correctionKey =
      typeof receipt.idempotency_key === "string" &&
      receipt.idempotency_key.startsWith("planning-d046-correction:") &&
      receipt.idempotency_key.length > "planning-d046-correction:".length;
    let role;
    if (
      retained &&
      receipt.idempotency_status === "COMPLETED" &&
      receipt.expected_version === 1 &&
      typeof receipt.idempotency_key === "string" &&
      receipt.idempotency_key.length > 0 &&
      !correctionKey
    ) {
      role = "original";
    } else if (
      retained &&
      receipt.idempotency_status === "NO_CHANGE" &&
      receipt.expected_version === 3 &&
      correctionKey
    ) {
      role = "benign";
    } else if (
      receipt.command_name === "execute_need_generation" &&
      receipt.actor_id === SYNTHETIC_ACTOR &&
      receipt.expected_version === 3 &&
      correctionKey &&
      receipt.outcome === "FAILED_NON_RETRYABLE" &&
      receipt.success === false &&
      receipt.retryable === true &&
      receipt.error_code === "RETRYABLE_CONCURRENCY_FAILURE" &&
      receipt.idempotency_status === null &&
      receipt.affected_aggregate_ids == null &&
      receipt.new_versions == null
    ) {
      role = "legacy_retryable_failure";
    } else if (
      successorRunId &&
      generationReceiptAccepted(
        receipt,
        { id: successorRunId },
        { id: RETAINED_BATCH },
        2,
      ) &&
      receipt.idempotency_status === "COMPLETED" &&
      receipt.expected_version === 3 &&
      correctionKey
    ) {
      role = "correction";
    } else return null;
    if (roles[role]) return null;
    roles[role] = receipt;
  }
  return roles.original &&
    (successorRunId ? roles.correction : !roles.correction)
    ? roles
    : null;
}

export function classifyPlanningCheckpoint(snapshot) {
  const fail = () => {
    throw new Error("PLANNING_CLOSEOUT_BASELINE_REJECTED");
  };
  if (
    !Array.isArray(snapshot?.runs) ||
    !Array.isArray(snapshot?.batches) ||
    !Array.isArray(snapshot?.receipts) ||
    snapshot.handoffs !== 0 ||
    snapshot.save_receipt_count !== 0
  )
    fail();
  if (snapshot.runs.length === 0 && snapshot.batches.length === 0) {
    if (
      snapshot.receipts.length !== 0 ||
      !preflightAccepted(snapshot.preflight, "NOT_GENERATED", null, null)
    )
      fail();
    return {
      mode: "ZERO_BASELINE",
      runId: null,
      batchId: null,
      fingerprints: snapshot.preflight.source_date_fingerprints.selected,
    };
  }
  if (snapshot.runs.length !== 2 || snapshot.batches.length !== 1) fail();
  const predecessor = snapshot.runs.find((run) => run.id === RETAINED_RUN);
  const run = snapshot.runs.find((item) => item.id !== RETAINED_RUN);
  const batch = snapshot.batches[0];
  if (
    !predecessor ||
    !run ||
    !exactDate(predecessor) ||
    !exactDate(run) ||
    !exactDate(batch) ||
    batch.id !== RETAINED_BATCH ||
    predecessor.status !== "INVALIDATED" ||
    predecessor.version !== 4 ||
    predecessor.generated_line_count !== 304 ||
    predecessor.release_snapshot_line_count !== 304 ||
    predecessor.actor_id !== SYNTHETIC_ACTOR ||
    run.status !== "RELEASED_FOR_CONFIRMATION" ||
    run.version !== 3 ||
    run.predecessor_run_id !== predecessor.id ||
    run.generated_line_count !== 304 ||
    run.release_snapshot_line_count !== 304 ||
    run.blocking_issue_count !== 0 ||
    run.warning_count !== 0 ||
    run.actor_id !== SYNTHETIC_ACTOR ||
    batch.status !== "DRAFT_REVIEW" ||
    batch.version !== 2 ||
    batch.source_kind !== "NEED_GENERATION" ||
    batch.origin_run_id !== predecessor.id ||
    batch.current_run_id !== run.id ||
    batch.origin_run_version !== 3 ||
    batch.current_run_version !== 3 ||
    batch.line_count !== 248 ||
    batch.stable_line_count !== 249 ||
    batch.decision_count !== 0 ||
    batch.current_decision_count !== 0 ||
    batch.adjustment_count !== 0 ||
    batch.acceptance_count !== 0 ||
    !preflightAccepted(snapshot.preflight, "CURRENT", run.id, batch.id) ||
    snapshot.preflight.current_need.confirmed_need_batch_version !== 2 ||
    !classifyPlanningGenerationReceipts(snapshot.receipts, run.id) ||
    snapshot.d046?.predecessor_release_contribution_count !== 304 ||
    snapshot.d046?.successor_release_contribution_count !== 304 ||
    snapshot.d046?.current_snapshot_pair_count !== 248 ||
    snapshot.d046?.exact_proposal_count !== 248 ||
    snapshot.d046?.invalid_proposal_count !== 0 ||
    snapshot.d046?.retained_pre_d046_null_pair_count !== 248 ||
    snapshot.d046?.allowed_unit_transition_count !== 1 ||
    snapshot.d046?.invalid_unit_transition_count !== 0 ||
    snapshot.d046?.current_raw_membership_count !== 304
  )
    fail();
  try {
    classifyPlanningAdoptionManifest(snapshot.adoption_manifest, "post-deploy");
  } catch {
    fail();
  }
  return {
    mode: "D046_CORRECTED_RESUME",
    predecessorRunId: predecessor.id,
    currentRunId: run.id,
    batchId: batch.id,
    currentLineCount: batch.line_count,
    fingerprints: snapshot.preflight.source_date_fingerprints.selected,
  };
}

function saveReceiptAccepted(receipt) {
  return (
    receipt?.command_name === "save_confirmed_needs" &&
    receipt.actor_id === SYNTHETIC_ACTOR &&
    receipt.scope_key ===
      `${SYNTHETIC_ACTOR}:ConfirmedNeedBatch:${RETAINED_BATCH}` &&
    receipt.outcome === "COMPLETED" &&
    receipt.request_contract_version === "RMVP-05.v2" &&
    receipt.requested_by_auth_subject === SUBJECT &&
    receipt.request_reason_code === "CONFIRMED_NEED_SAVED" &&
    receipt.request_batch_id === RETAINED_BATCH &&
    receipt.expected_version === 2 &&
    receipt.success === true &&
    receipt.idempotency_status === "COMPLETED" &&
    receipt.confirmed_need_batch_id === RETAINED_BATCH &&
    receipt.prior_batch_version === 2 &&
    receipt.resulting_batch_version === 3 &&
    receipt.adjusted_line_count === 1 &&
    receipt.unchanged_accepted_line_count === 247
  );
}

function diagnosticDimension(expected, actual) {
  return {
    expected,
    actual: actual ?? null,
    pass: sameJson(expected, actual),
  };
}

function safelyAccepted(predicate) {
  try {
    return Boolean(predicate());
  } catch {
    return false;
  }
}

function postSaveCloseoutChecks(snapshot) {
  const runs = Array.isArray(snapshot?.runs) ? snapshot.runs : [];
  const batches = Array.isArray(snapshot?.batches) ? snapshot.batches : [];
  const receipts = Array.isArray(snapshot?.receipts) ? snapshot.receipts : [];
  const saveReceipts = Array.isArray(snapshot?.save_receipts)
    ? snapshot.save_receipts
    : [];
  const predecessor = runs.find((run) => run?.id === RETAINED_RUN);
  const run = runs.find((item) => item?.id !== RETAINED_RUN);
  const batch = batches[0];
  const accepted = (predicate) => diagnosticDimension(true, predicate);
  const checks = {
    policies: accepted(
      safelyAccepted(() =>
        planningCloseoutPoliciesAccepted(snapshot?.policies),
      ),
    ),
    run_count: diagnosticDimension(2, runs.length),
    batch_count: diagnosticDimension(1, batches.length),
    generation_receipt_semantics: accepted(
      safelyAccepted(() =>
        classifyPlanningGenerationReceipts(receipts, run?.id),
      ),
    ),
    save_receipt_projection_count: diagnosticDimension(1, saveReceipts.length),
    save_receipt_count: diagnosticDimension(1, snapshot?.save_receipt_count),
    save_receipt_semantics: accepted(
      saveReceipts.length === 1 && saveReceiptAccepted(saveReceipts[0]),
    ),
    purchase_handoff_count: diagnosticDimension(0, snapshot?.handoffs),
    decision_fingerprint: accepted(
      /^[a-f0-9]{64}$/.test(snapshot?.decision_fingerprint ?? ""),
    ),
    predecessor_present: accepted(Boolean(predecessor)),
    current_run_present: accepted(Boolean(run)),
    exact_service_dates: accepted(
      safelyAccepted(
        () => exactDate(predecessor) && exactDate(run) && exactDate(batch),
      ),
    ),
    batch_identity: accepted(batch?.id === RETAINED_BATCH),
    predecessor_lineage: accepted(
      predecessor?.status === "INVALIDATED" &&
        predecessor?.version === 4 &&
        predecessor?.generated_line_count === 304 &&
        predecessor?.release_snapshot_line_count === 304 &&
        predecessor?.actor_id === SYNTHETIC_ACTOR,
    ),
    current_run_lineage: accepted(
      run?.status === "RELEASED_FOR_CONFIRMATION" &&
        run?.version === 3 &&
        run?.predecessor_run_id === predecessor?.id &&
        run?.generated_line_count === 304 &&
        run?.release_snapshot_line_count === 304 &&
        run?.blocking_issue_count === 0 &&
        run?.warning_count === 0 &&
        run?.actor_id === SYNTHETIC_ACTOR,
    ),
    batch_state_lineage: accepted(
      batch?.status === "DRAFT_REVIEW" &&
        batch?.version === 3 &&
        batch?.source_kind === "NEED_GENERATION" &&
        batch?.origin_run_id === predecessor?.id &&
        batch?.current_run_id === run?.id &&
        batch?.origin_run_version === 3 &&
        batch?.current_run_version === 3,
    ),
    current_line_count: diagnosticDimension(248, batch?.line_count),
    stable_line_identity_count: diagnosticDimension(
      249,
      batch?.stable_line_count,
    ),
    decision_count: diagnosticDimension(248, batch?.decision_count),
    current_decision_count: diagnosticDimension(
      248,
      batch?.current_decision_count,
    ),
    adjustment_count: diagnosticDimension(1, batch?.adjustment_count),
    acceptance_count: diagnosticDimension(247, batch?.acceptance_count),
    invalid_decision_partition_count: diagnosticDimension(
      0,
      batch?.invalid_decision_partition_count,
    ),
    preflight: accepted(
      safelyAccepted(() =>
        preflightAccepted(snapshot?.preflight, "CURRENT", run?.id, batch?.id),
      ),
    ),
    preflight_batch_version: diagnosticDimension(
      3,
      snapshot?.preflight?.current_need?.confirmed_need_batch_version,
    ),
    source_fingerprints: accepted(
      sameJson(
        snapshot?.preflight?.source_date_fingerprints?.selected,
        EXPECTED_SOURCE_FINGERPRINTS,
      ),
    ),
    predecessor_release_contribution_count: diagnosticDimension(
      304,
      snapshot?.d046?.predecessor_release_contribution_count,
    ),
    successor_release_contribution_count: diagnosticDimension(
      304,
      snapshot?.d046?.successor_release_contribution_count,
    ),
    current_snapshot_pair_count: diagnosticDimension(
      248,
      snapshot?.d046?.current_snapshot_pair_count,
    ),
    decision_proposal_count: diagnosticDimension(
      248,
      snapshot?.d046?.decision_proposal_count,
    ),
    exact_decision_proposal_count: diagnosticDimension(
      248,
      snapshot?.d046?.exact_decision_proposal_count,
    ),
    invalid_decision_proposal_count: diagnosticDimension(
      0,
      snapshot?.d046?.invalid_decision_proposal_count,
    ),
    retained_pre_d046_null_pair_count: diagnosticDimension(
      248,
      snapshot?.d046?.retained_pre_d046_null_pair_count,
    ),
    allowed_unit_transition_count: diagnosticDimension(
      1,
      snapshot?.d046?.allowed_unit_transition_count,
    ),
    invalid_unit_transition_count: diagnosticDimension(
      0,
      snapshot?.d046?.invalid_unit_transition_count,
    ),
    current_raw_membership_count: diagnosticDimension(
      304,
      snapshot?.d046?.current_raw_membership_count,
    ),
    adoption_manifest: accepted(
      safelyAccepted(() => {
        classifyPlanningAdoptionManifest(
          snapshot?.adoption_manifest,
          "post-deploy",
        );
        return true;
      }),
    ),
  };
  return { checks, predecessor, run, batch };
}

export function classifyPostSavePlanningCloseout(snapshot) {
  const { checks, predecessor, run, batch } = postSaveCloseoutChecks(snapshot);
  if (Object.values(checks).some((check) => !check.pass))
    throw new Error(
      JSON.stringify({ status: "POST_SAVE_CLOSEOUT_REJECTED", checks }),
    );
  return {
    mode: "POST_SAVE_CLOSEOUT_RESUME",
    predecessorRunId: predecessor.id,
    currentRunId: run.id,
    batchId: batch.id,
    currentLineCount: batch.line_count,
    decisionFingerprint: snapshot.decision_fingerprint,
    fingerprints: snapshot.preflight.source_date_fingerprints.selected,
  };
}

export function classifyPlanningCloseoutBaseline(snapshot) {
  if (!planningCloseoutPoliciesAccepted(snapshot?.policies))
    throw new Error("PLANNING_CLOSEOUT_BASELINE_REJECTED");
  return classifyPlanningCheckpoint(snapshot);
}

function requireProtectedPlanningCloseoutBaseline(snapshot) {
  const baseline = classifyPlanningCloseoutBaseline(snapshot);
  if (baseline.mode !== "D046_CORRECTED_RESUME")
    throw new Error("PLANNING_CLOSEOUT_RESUME_REQUIRED");
  return baseline;
}

export async function startProtectedPlanningBrowserCloseout(
  snapshotOrOptions,
  legacyBrowserJourney,
) {
  if (legacyBrowserJourney)
    return legacyBrowserJourney(
      requireProtectedPlanningCloseoutBaseline(snapshotOrOptions),
    );
  const {
    snapshot,
    closeoutMode,
    persistRehearsal,
    readOnlyJourney,
    mutationJourney,
  } = snapshotOrOptions ?? {};
  if (closeoutMode === "post_save_resume") {
    if (persistRehearsal) throw new Error("POST_SAVE_RESUME_MUST_BE_READ_ONLY");
    return readOnlyJourney(classifyPostSavePlanningCloseout(snapshot));
  }
  if (closeoutMode === "pre_save_rehearsal") {
    if (!persistRehearsal) throw new Error("PERSIST_REHEARSAL_REQUIRED");
    return mutationJourney(requireProtectedPlanningCloseoutBaseline(snapshot));
  }
  throw new Error("PLANNING_CLOSEOUT_MODE_REQUIRED");
}

export function assertCertificationOnlyDelta(files) {
  const exact = new Set([
    "scripts/verify-staging-planning-closeout.mjs",
    "scripts/staging-planning-browser.mjs",
    "scripts/staging-planning-performance.test.mjs",
    ".github/workflows/atlas-staging-planning-closeout.yml",
    "docs/implementation-tasks/TASK-PLANNING-CLOSEOUT-POST-SAVE-VERIFIER.md",
  ]);
  if (
    !Array.isArray(files) ||
    files.length === 0 ||
    files.some(
      (file) =>
        typeof file !== "string" ||
        (!exact.has(file) &&
          !/^scripts\/staging-planning-(?:closeout|browser|preview).*\.test\.mjs$/.test(
            file,
          ) &&
          ![
            "scripts/test-local-planning-final-closeout.mjs",
            "scripts/test-local-planning-closeout-browser.mjs",
          ].includes(file)),
    )
  )
    throw new Error("PLANNING_PREVIEW_CERTIFICATION_DELTA_REJECTED");
}

export function assertCertificationOnlyComparison({
  verifierCommitSha,
  comparison,
}) {
  if (
    !/^[a-f0-9]{40}$/.test(verifierCommitSha ?? "") ||
    comparison?.status !== "ahead" ||
    comparison?.merge_base_commit?.sha !== CERTIFIED_PREVIEW_BASE_SHA ||
    !Array.isArray(comparison.commits) ||
    comparison.commits.length === 0 ||
    comparison.commits.at(-1)?.sha !== verifierCommitSha ||
    !Array.isArray(comparison.files)
  )
    throw new Error("PLANNING_PREVIEW_CERTIFICATION_DELTA_REJECTED");
  assertCertificationOnlyDelta(comparison.files.map((file) => file?.filename));
  return {
    verifierCommitSha,
    certifiedPreviewBaseSha: CERTIFIED_PREVIEW_BASE_SHA,
    previewSha: APPROVED_PREVIEW_SHA,
  };
}

export function assertCertifiedPreviewPullRequest(pr) {
  if (
    pr?.number !== 286 ||
    pr.state !== "open" ||
    pr.draft !== true ||
    pr.head?.sha !== APPROVED_PREVIEW_SHA ||
    pr.base?.ref !== "main"
  )
    throw new Error("PLANNING_PREVIEW_PROVENANCE_REJECTED");
}

async function verifyCertificationOnlyPreviewDelta({
  verifierCommitSha,
  githubToken,
  fetchImpl = fetch,
}) {
  if (!githubToken)
    throw new Error("PLANNING_PREVIEW_PROVENANCE_CONFIGURATION_REQUIRED");
  const request = (path) =>
    fetchImpl(
      `https://api.github.com/repos/longpsu-bot/thuonghao-ops-erp/${path}`,
      {
        headers: {
          Authorization: `Bearer ${githubToken}`,
          Accept: "application/vnd.github+json",
        },
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      },
    );
  const [comparisonResponse, pullRequestResponse] = await Promise.all([
    request(`compare/${CERTIFIED_PREVIEW_BASE_SHA}...${verifierCommitSha}`),
    request("pulls/286"),
  ]);
  if (!comparisonResponse.ok || !pullRequestResponse.ok)
    throw new Error("PLANNING_PREVIEW_PROVENANCE_FETCH_FAILED");
  const [comparison, pullRequest] = await Promise.all([
    comparisonResponse.json(),
    pullRequestResponse.json(),
  ]);
  assertCertifiedPreviewPullRequest(pullRequest);
  return assertCertificationOnlyComparison({
    verifierCommitSha,
    comparison,
  });
}

export function planningCloseoutSnapshotSql() {
  const approvedUnitCodes = [...APPROVED_COUNT_POLICIES.keys(), "kg"]
    .map((code) => `'${code}'`)
    .join(",");
  const adoptionManifest = planningAdoptionPostDeployQuerySql();
  return `begin read only;
with scoped_runs as (
  select * from atlas_planning.need_generation_runs
  where period_start <= '2026-09-20' and period_end >= '2026-09-14'
), scoped_batches as (
  select * from atlas_planning.confirmed_need_batches
  where period_start <= '2026-09-20' and period_end >= '2026-09-14'
), preflight as (
  select atlas_core.planning_contract_01_preflight_payload(
    '2026-09-17'::date, '2026-09-17'::date, null) as payload
), current_revisions as materialized (
  select revision.*
  from scoped_batches batch
  join atlas_planning.confirmed_need_lines line
    on line.confirmed_need_batch_id=batch.confirmed_need_batch_id
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id=line.confirmed_need_line_id
   and revision.is_current
), current_contributions as materialized (
  select contribution.*
  from current_revisions revision
  join atlas_planning.confirmed_need_line_revision_contributions contribution
    on contribution.confirmed_need_line_revision_id=revision.confirmed_need_line_revision_id
), current_decisions as materialized (
  select decision.*, revision.theoretical_quantity,
         revision.proposal_rounding_step,
         revision.proposal_rounding_ingredient_version,
         revision.unit_id revision_unit_id,
         ingredient.order_step ingredient_order_step,
         ingredient.version ingredient_version,
         ingredient.purchase_unit_id,
         policy.planning_step
  from scoped_batches batch
  join atlas_planning.confirmed_need_lines line
    on line.confirmed_need_batch_id=batch.confirmed_need_batch_id
  join atlas_planning.confirmed_need_line_decisions decision
    on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_revision_id=decision.confirmed_need_line_revision_id
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id=revision.ingredient_id
  join atlas_planning.planning_quantity_policy_revisions policy
    on policy.planning_quantity_policy_revision_id=decision.planning_quantity_policy_revision_id
), adoption_run_transitions as materialized (
  select predecessor.theoretical_need_line_id predecessor_line_id,
         successor.theoretical_need_line_id successor_line_id,
         predecessor.unit_id predecessor_unit_id,
         successor.unit_id successor_unit_id
  from scoped_batches batch
  join atlas_planning.theoretical_need_lines predecessor
    on predecessor.need_generation_run_id=batch.origin_need_generation_run_id
  join atlas_planning.theoretical_need_lines successor
    on successor.need_generation_run_id=batch.current_need_generation_run_id
   and successor.predecessor_need_generation_run_id=predecessor.need_generation_run_id
   and successor.predecessor_theoretical_need_line_id=predecessor.theoretical_need_line_id
  where predecessor.line_disposition='ACTIVE'
    and successor.line_disposition='ACTIVE'
), retained_adoption_workload as materialized (
  select theoretical.theoretical_need_line_id,
         line_mapping.legacy_id legacy_recipe_line_id,
         ingredient_mapping.legacy_id legacy_ingredient_id,
         theoretical.recipe_id theoretical_recipe_id,
         theoretical.recipe_line_id theoretical_recipe_line_id,
         theoretical.ingredient_id theoretical_ingredient_id,
         theoretical.recipe_version_id theoretical_recipe_version_id,
         theoretical.recipe_line_revision_id theoretical_recipe_line_revision_id,
         theoretical.unit_id theoretical_unit_id,
         evidence.evidence_kind,
         evidence.source_system,
         evidence.recipe_id evidence_recipe_id,
         evidence.recipe_line_id evidence_recipe_line_id,
         evidence.ingredient_id evidence_ingredient_id,
         evidence.predecessor_recipe_version_id,
         evidence.predecessor_recipe_line_revision_id,
         evidence.source_unit_id,
         evidence.target_recipe_version_id,
         evidence.target_recipe_line_revision_id,
         evidence.corrected_unit_id,
         evidence.quantity_per_basis::text evidence_quantity_per_basis,
         target_version.predecessor_recipe_version_id target_predecessor_recipe_version_id,
         target_version.recipe_version_status,
         target_revision.recipe_line_revision_id actual_target_recipe_line_revision_id,
         target_revision.recipe_version_id target_revision_recipe_version_id,
         target_revision.predecessor_recipe_line_revision_id target_predecessor_recipe_line_revision_id,
         target_revision.recipe_id target_recipe_id,
         target_revision.recipe_line_id target_recipe_line_id,
         target_revision.ingredient_id target_ingredient_id,
         target_revision.unit_id target_unit_id,
         target_revision.quantity_per_basis::text target_quantity_per_basis,
         target_revision.line_disposition target_line_disposition
  from scoped_batches batch
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.need_generation_run_id=batch.current_need_generation_run_id
   and theoretical.service_date='2026-09-17'
   and theoretical.line_disposition='ACTIVE'
  join atlas_legacy.recipe_unit_adoption_evidence evidence
    on evidence.evidence_kind='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
   and evidence.source_system='OPS_V1'
   and evidence.recipe_id=theoretical.recipe_id
   and evidence.recipe_line_id=theoretical.recipe_line_id
   and evidence.ingredient_id=theoretical.ingredient_id
  join atlas_admin.recipe_versions target_version
    on target_version.recipe_version_id=evidence.target_recipe_version_id
  join atlas_admin.recipe_line_revisions target_revision
    on target_revision.recipe_line_revision_id=evidence.target_recipe_line_revision_id
  join atlas_legacy.master_data_mappings line_mapping
    on line_mapping.source_system='OPS_V1' and line_mapping.object_type='RECIPE_LINE'
   and line_mapping.recipe_line_id=evidence.recipe_line_id
  join atlas_legacy.master_data_mappings ingredient_mapping
    on ingredient_mapping.source_system='OPS_V1' and ingredient_mapping.object_type='INGREDIENT'
   and ingredient_mapping.ingredient_id=evidence.ingredient_id
)
select jsonb_build_object(
  'runs', (select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.need_generation_run_id, 'period_start', r.period_start,
    'period_end', r.period_end, 'status', r.run_status, 'version', r.version,
    'predecessor_run_id', r.predecessor_need_generation_run_id,
    'generated_line_count', r.generated_line_count,
    'release_snapshot_line_count', (select count(*)::integer
      from atlas_planning.need_generation_release_snapshot_lines release_line
      where release_line.need_generation_run_id=r.need_generation_run_id),
    'blocking_issue_count', r.blocking_issue_count, 'warning_count', r.warning_count,
    'actor_id', r.generated_by_actor_id) order by r.attempt_ordinal), '[]'::jsonb)
    from scoped_runs r),
  'batches', (select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.confirmed_need_batch_id, 'period_start', b.period_start,
    'period_end', b.period_end, 'status', b.batch_status, 'version', b.version,
    'source_kind', b.source_kind, 'origin_run_id', b.origin_need_generation_run_id,
    'current_run_id', b.current_need_generation_run_id,
    'origin_run_version', b.origin_need_generation_run_version,
    'current_run_version', b.current_need_generation_run_version,
    'line_count', (select count(*) from atlas_planning.confirmed_need_lines l
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id and exists (
        select 1 from atlas_planning.confirmed_need_line_revisions revision
        where revision.confirmed_need_line_id=l.confirmed_need_line_id and revision.is_current)),
    'stable_line_count', (select count(*) from atlas_planning.confirmed_need_lines l
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id),
    'decision_count', (select count(*) from atlas_planning.confirmed_need_line_decisions d
      where d.confirmed_need_batch_id=b.confirmed_need_batch_id),
    'current_decision_count', (select count(*) from atlas_planning.confirmed_need_lines l
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id
        and l.current_confirmed_need_line_decision_id is not null),
    'adjustment_count', (select count(*) from current_decisions decision
      where decision.confirmed_need_batch_id=b.confirmed_need_batch_id
        and decision.decision_kind='ADJUSTED_QUANTITY_CONFIRMED'
        and decision.confirmed_quantity_after<>decision.proposed_quantity_before
        and decision.reason_code='OPERATIONAL_QUANTITY_ADJUSTMENT'
        and nullif(btrim(decision.reason_note),'') is not null
        and decision.planning_step>0
        and mod(decision.confirmed_quantity_after,decision.planning_step)=0),
    'acceptance_count', (select count(*) from current_decisions decision
      where decision.confirmed_need_batch_id=b.confirmed_need_batch_id
        and decision.decision_kind='UNCHANGED_PROPOSAL_ACCEPTED'
        and decision.confirmed_quantity_after=decision.proposed_quantity_before
        and decision.reason_code='PROPOSAL_ACCEPTED'),
    'invalid_decision_partition_count', (select count(*) from current_decisions decision
      where decision.confirmed_need_batch_id=b.confirmed_need_batch_id and not (
        (decision.decision_kind='UNCHANGED_PROPOSAL_ACCEPTED'
         and decision.confirmed_quantity_after=decision.proposed_quantity_before
         and decision.reason_code='PROPOSAL_ACCEPTED')
        or
        (decision.decision_kind='ADJUSTED_QUANTITY_CONFIRMED'
         and decision.confirmed_quantity_after<>decision.proposed_quantity_before
         and decision.reason_code='OPERATIONAL_QUANTITY_ADJUSTMENT'
         and nullif(btrim(decision.reason_note),'') is not null
         and decision.planning_step>0
         and mod(decision.confirmed_quantity_after,decision.planning_step)=0)))
  )), '[]'::jsonb) from scoped_batches b),
  'handoffs', (select count(*) from atlas_planning.purchase_handoff_batches h
    where h.period_start <= '2026-09-20' and h.period_end >= '2026-09-14'),
  'policies', (select coalesce(jsonb_agg(jsonb_build_object(
    'unit_code', u.unit_code, 'unit_name', u.unit_name,
    'dimension_code', u.dimension_code, 'unit_status', u.unit_status,
    'planning_step', r.planning_step, 'effective_from', r.effective_from,
    'effective_to', r.effective_to, 'policy_revision_status', r.policy_revision_status,
    'revision_number', r.revision_number) order by u.unit_code, r.revision_number), '[]'::jsonb)
    from atlas_admin.units u
    left join atlas_planning.planning_quantity_policies p on p.unit_id=u.unit_id
    left join atlas_planning.planning_quantity_policy_revisions r on r.planning_quantity_policy_id=p.planning_quantity_policy_id
      and r.policy_revision_status='ACTIVE'
    where u.unit_code in (${approvedUnitCodes})
      or (u.dimension_code='COUNT' and (u.unit_status='ACTIVE' or r.policy_revision_status='ACTIVE'))),
  'preflight', (select jsonb_build_object(
    'readiness_state', p.payload->'readiness_state',
    'downstream_currentness', p.payload->'downstream_currentness',
    'blocking_issue_count', p.payload->'blocking_issue_count',
    'current_need', p.payload->'current_need',
    'source_date_fingerprints', p.payload->'source_date_fingerprints'
  ) from preflight p),
  'receipts', (select coalesce(jsonb_agg(jsonb_build_object(
    'command_id', c.command_id, 'command_name', c.command_name, 'actor_id', c.actor_id,
    'expected_version', c.expected_version, 'idempotency_key', c.idempotency_key,
    'idempotency_status', c.response_payload->'idempotency_status',
    'outcome', c.outcome, 'success', c.response_payload->'success',
    'retryable', c.response_payload->'retryable', 'error_code', c.response_payload->'error_code',
    'affected_aggregate_ids', c.response_payload->'affected_aggregate_ids',
    'new_versions', c.response_payload->'new_versions')
    order by c.started_at,c.command_receipt_id), '[]'::jsonb)
    from atlas_core.command_receipts c where c.command_name='execute_need_generation'
      and (c.scope_key like '%:need-generation:2026-09-17:2026-09-17'
      or exists(select 1 from scoped_runs r where
        c.response_payload#>>'{affected_aggregate_ids,need_generation_run_id}'=r.need_generation_run_id::text)
      or exists(select 1 from scoped_batches b where
        c.response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}'=b.confirmed_need_batch_id::text))),
  'save_receipts', (select coalesce(jsonb_agg(jsonb_build_object(
    'command_name',c.command_name,'actor_id',c.actor_id,'scope_key',c.scope_key,
    'outcome',c.outcome,'request_contract_version',c.response_payload->>'contract_version',
    'requested_by_auth_subject',auth.auth_subject_id,
    'request_reason_code',audit.reason_code,
    'request_batch_id',audit.aggregate_id,
    'expected_version',c.expected_version,'success',c.response_payload->'success',
    'idempotency_status',c.response_payload->>'idempotency_status',
    'confirmed_need_batch_id',c.response_payload->>'confirmed_need_batch_id',
    'prior_batch_version',(c.response_payload->>'prior_batch_version')::integer,
    'resulting_batch_version',(c.response_payload->>'resulting_batch_version')::integer,
    'adjusted_line_count',(c.response_payload->>'adjusted_line_count')::integer,
    'unchanged_accepted_line_count',(c.response_payload->>'unchanged_accepted_line_count')::integer
  ) order by c.started_at,c.command_receipt_id),'[]'::jsonb)
    from atlas_core.command_receipts c
    join atlas_core.actor_auth_subjects auth on auth.actor_id=c.actor_id
      and auth.auth_provider='SUPABASE_AUTH' and auth.subject_status='ACTIVE'
    join atlas_audit.audit_events audit on audit.command_receipt_id=c.command_receipt_id
      and audit.event_type='ConfirmedNeedQuantitiesConfirmed'
      and audit.aggregate_type='ConfirmedNeedBatch'
    where c.command_name='save_confirmed_needs' and exists(
      select 1 from scoped_batches b where
        c.scope_key like '%:ConfirmedNeedBatch:' || b.confirmed_need_batch_id::text)),
  'save_receipt_count', (select count(*) from atlas_core.command_receipts c
    where c.command_name='save_confirmed_needs' and exists(
      select 1 from scoped_batches b where
        c.scope_key like '%:ConfirmedNeedBatch:' || b.confirmed_need_batch_id::text)),
  'decision_fingerprint', (select case when count(*)=0 then null else
    pg_catalog.encode(extensions.digest(pg_catalog.convert_to(
      string_agg(concat_ws('|',confirmed_need_line_id,
        confirmed_need_line_decision_id,decision_number,decision_kind,
        confirmed_need_line_revision_id,theoretical_quantity_before,
        proposed_quantity_before,confirmed_quantity_after,planning_tick_count,
        reason_code,coalesce(reason_note,''),planning_quantity_policy_revision_id,
        confirmed_need_batch_version),E'\\n' order by confirmed_need_line_id),
      'UTF8'),'sha256'),'hex') end from current_decisions),
  'adoption_workload', jsonb_build_object(
    'date','2026-09-17',
    'adoption_occurrence_count',(select count(distinct theoretical_need_line_id)::integer from retained_adoption_workload),
    'adoption_legacy_line_ids',(select coalesce(jsonb_agg(legacy_recipe_line_id order by legacy_recipe_line_id),'[]'::jsonb) from (select distinct legacy_recipe_line_id from retained_adoption_workload) ids),
    'adoption_ingredient_ids',(select coalesce(jsonb_agg(legacy_ingredient_id order by legacy_ingredient_id),'[]'::jsonb) from (select distinct legacy_ingredient_id from retained_adoption_workload) ids),
    'adoption_occurrences',(select coalesce(jsonb_agg(jsonb_build_object(
      'legacy_recipe_line_id', legacy_recipe_line_id,
      'legacy_ingredient_id', legacy_ingredient_id,
      'theoretical', jsonb_build_object(
        'recipe_id', theoretical_recipe_id,
        'recipe_line_id', theoretical_recipe_line_id,
        'ingredient_id', theoretical_ingredient_id,
        'recipe_version_id', theoretical_recipe_version_id,
        'recipe_line_revision_id', theoretical_recipe_line_revision_id,
        'unit_id', theoretical_unit_id),
      'evidence', jsonb_build_object(
        'evidence_kind', evidence_kind,
        'source_system', source_system,
        'recipe_id', evidence_recipe_id,
        'recipe_line_id', evidence_recipe_line_id,
        'ingredient_id', evidence_ingredient_id,
        'predecessor_recipe_version_id', predecessor_recipe_version_id,
        'predecessor_recipe_line_revision_id', predecessor_recipe_line_revision_id,
        'source_unit_id', source_unit_id,
        'target_recipe_version_id', target_recipe_version_id,
        'target_recipe_line_revision_id', target_recipe_line_revision_id,
        'corrected_unit_id', corrected_unit_id,
        'quantity_per_basis', evidence_quantity_per_basis),
      'target', jsonb_build_object(
        'recipe_id', target_recipe_id,
        'recipe_line_id', target_recipe_line_id,
        'ingredient_id', target_ingredient_id,
        'recipe_version_id', target_revision_recipe_version_id,
        'recipe_line_revision_id', actual_target_recipe_line_revision_id,
        'predecessor_recipe_version_id', target_predecessor_recipe_version_id,
        'predecessor_recipe_line_revision_id', target_predecessor_recipe_line_revision_id,
        'unit_id', target_unit_id,
        'quantity_per_basis', target_quantity_per_basis,
        'line_disposition', target_line_disposition,
        'recipe_version_status', recipe_version_status)
    ) order by theoretical_need_line_id,target_recipe_line_revision_id),'[]'::jsonb)
    from retained_adoption_workload)
  ),
  'd046', jsonb_build_object(
    'predecessor_release_contribution_count', (select count(*)::integer
      from atlas_planning.need_generation_release_snapshot_lines line
      where line.need_generation_run_id='${RETAINED_RUN}'::uuid),
    'successor_release_contribution_count', (select count(*)::integer
      from atlas_planning.need_generation_release_snapshot_lines line
      join scoped_runs run on run.need_generation_run_id=line.need_generation_run_id
      where run.predecessor_need_generation_run_id='${RETAINED_RUN}'::uuid),
    'current_snapshot_pair_count', (select count(*)::integer from current_revisions),
    'exact_proposal_count', (select count(*)::integer
      from current_revisions revision
      join atlas_admin.ingredients ingredient on ingredient.ingredient_id=revision.ingredient_id
      where revision.proposal_rounding_step=ingredient.order_step
        and revision.proposal_rounding_ingredient_version=ingredient.version
        and revision.unit_id=ingredient.purchase_unit_id
        and revision.confirmed_quantity=
          ceil(revision.theoretical_quantity/revision.proposal_rounding_step)
            * revision.proposal_rounding_step),
    'invalid_proposal_count', (select count(*)::integer
      from current_revisions revision
      left join atlas_admin.ingredients ingredient on ingredient.ingredient_id=revision.ingredient_id
      where revision.proposal_rounding_step is null
         or revision.proposal_rounding_ingredient_version is null
         or revision.proposal_rounding_step is distinct from ingredient.order_step
         or revision.proposal_rounding_ingredient_version is distinct from ingredient.version
         or revision.unit_id is distinct from ingredient.purchase_unit_id
         or revision.confirmed_quantity is distinct from
           ceil(revision.theoretical_quantity/revision.proposal_rounding_step)
             * revision.proposal_rounding_step),
    'decision_proposal_count', (select count(*)::integer from current_decisions),
    'exact_decision_proposal_count', (select count(*)::integer
      from current_decisions decision
      where decision.proposal_rounding_step=decision.ingredient_order_step
        and decision.proposal_rounding_ingredient_version=decision.ingredient_version
        and decision.revision_unit_id=decision.purchase_unit_id
        and decision.proposed_quantity_before=
          ceil(decision.theoretical_quantity/decision.proposal_rounding_step)
            * decision.proposal_rounding_step),
    'invalid_decision_proposal_count', (select count(*)::integer
      from current_decisions decision
      where decision.proposal_rounding_step is null
         or decision.proposal_rounding_ingredient_version is null
         or decision.proposal_rounding_step is distinct from decision.ingredient_order_step
         or decision.proposal_rounding_ingredient_version is distinct from decision.ingredient_version
         or decision.revision_unit_id is distinct from decision.purchase_unit_id
         or decision.proposed_quantity_before is distinct from
           ceil(decision.theoretical_quantity/decision.proposal_rounding_step)
             * decision.proposal_rounding_step),
    'retained_pre_d046_null_pair_count', (select count(*)::integer
      from atlas_planning.confirmed_need_line_revisions revision
      join scoped_batches batch
        on batch.confirmed_need_batch_id=revision.confirmed_need_batch_id
      where revision.need_generation_run_id='${RETAINED_RUN}'::uuid
        and revision.proposal_rounding_step is null
        and revision.proposal_rounding_ingredient_version is null),
    'allowed_unit_transition_count', (select count(*)::integer
      from adoption_run_transitions transition
      where transition.predecessor_unit_id<>transition.successor_unit_id
        and atlas_core.planning_legacy_adoption_unit_transition_allowed(
          transition.predecessor_line_id,transition.successor_line_id)),
    'invalid_unit_transition_count', (select count(*)::integer
      from adoption_run_transitions transition
      where transition.predecessor_unit_id<>transition.successor_unit_id
        and not atlas_core.planning_legacy_adoption_unit_transition_allowed(
          transition.predecessor_line_id,transition.successor_line_id)),
    'current_raw_membership_count', (select count(*)::integer from current_contributions)
  ),
  'adoption_manifest', (${adoptionManifest})
) as checkpoint;
rollback;`;
}
export function assertFinalPlanningCloseoutProof({
  baseline,
  browser,
  state,
  review,
  baselineFingerprints,
  finalFingerprints,
}) {
  if (baseline?.mode === "POST_SAVE_CLOSEOUT_RESUME") {
    let postStateAccepted = true;
    let adoptionAccepted = true;
    try {
      classifyPostSavePlanningCloseout(state);
    } catch {
      postStateAccepted = false;
    }
    try {
      classifyPlanningAdoptionManifest(state?.adoption_manifest, "post-deploy");
    } catch {
      adoptionAccepted = false;
    }
    const batch = state?.batches?.[0];
    const expectedBrowserMode =
      baseline.browserMode ?? "POST_SAVE_CLOSEOUT_RESUME";
    const expectedBrowserSaveClicks = baseline.browserSaveClicks ?? 0;
    const fingerprintsMatch =
      baselineFingerprints != null &&
      finalFingerprints != null &&
      sameJson(baselineFingerprints, finalFingerprints) &&
      sameJson(finalFingerprints, EXPECTED_SOURCE_FINGERPRINTS) &&
      sameJson(
        finalFingerprints,
        state?.preflight?.source_date_fingerprints?.current,
      );
    const dimension = (expected, actual) => ({
      expected,
      actual: actual ?? null,
      pass: sameJson(expected, actual),
    });
    const checks = {
      post_save_state: dimension(true, postStateAccepted),
      batch_version: dimension(3, batch?.version),
      current_lines: dimension(248, batch?.line_count),
      stable_line_identities: dimension(249, batch?.stable_line_count),
      decision_count: dimension(248, batch?.decision_count),
      current_decision_count: dimension(248, batch?.current_decision_count),
      exact_decision_proposal_count: dimension(
        248,
        state?.d046?.exact_decision_proposal_count,
      ),
      invalid_decision_proposal_count: dimension(
        0,
        state?.d046?.invalid_decision_proposal_count,
      ),
      adjustment_count: dimension(1, batch?.adjustment_count),
      acceptance_count: dimension(247, batch?.acceptance_count),
      save_receipt_count: dimension(1, state?.save_receipts?.length),
      purchase_handoffs: dimension(0, state?.handoffs),
      browser_mode: dimension(expectedBrowserMode, browser?.mode),
      browser_rows: dimension(248, browser?.renderedRows),
      browser_save_invocations: dimension(
        expectedBrowserSaveClicks,
        browser?.saveClicks,
      ),
      browser_generate_invocations: dimension(0, browser?.generateClicks),
      browser_handoff_invocations: dimension(0, browser?.handoffClicks),
      browser_batch_version: dimension(3, browser?.batchVersion),
      browser_batch_id: dimension(batch?.id, browser?.batchId),
      authoritative_reopen: dimension(true, browser?.authoritativeReopen),
      review_batch_id: dimension(batch?.id, review?.confirmed_need_batch_id),
      review_batch_version: dimension(3, review?.batch_version),
      review_lines: dimension(248, review?.lines?.length),
      review_has_more: dimension(false, review?.pagination?.has_more),
      review_blockers: dimension(0, review?.blockers?.length),
      review_editing_allowed: dimension(true, review?.editing_allowed),
      decision_fingerprint: dimension(
        state?.decision_fingerprint,
        browser?.decisionFingerprint,
      ),
      source_fingerprints_unchanged: dimension(true, fingerprintsMatch),
      adoption_manifest: dimension(true, adoptionAccepted),
    };
    if (Object.values(checks).some((check) => !check.pass))
      throw new Error(
        JSON.stringify({
          status: "FINAL_PLANNING_CLOSEOUT_PROOF_FAILED",
          mode: "POST_SAVE_CLOSEOUT_RESUME",
          checks,
        }),
      );
    return {
      status: "FINAL_PLANNING_CLOSEOUT_PASS",
      mode: "POST_SAVE_CLOSEOUT_RESUME",
      needGenerationRuns: state.runs.length,
      confirmedNeedBatchVersion: batch.version,
      currentLines: batch.line_count,
      stableLineIdentities: batch.stable_line_count,
      decisions: batch.decision_count,
      currentDecisions: batch.current_decision_count,
      proposalAcceptances: batch.acceptance_count,
      operationalAdjustments: batch.adjustment_count,
      exactDecisionProposals: state.d046.exact_decision_proposal_count,
      invalidDecisionProposals: state.d046.invalid_decision_proposal_count,
      saveReceipts: state.save_receipts.length,
      purchaseHandoffs: state.handoffs,
      sourceFingerprintsUnchanged: true,
      authoritativeReopen: true,
    };
  }
  const fingerprintsMatch =
    baselineFingerprints != null &&
    finalFingerprints != null &&
    sameJson(baselineFingerprints, finalFingerprints) &&
    sameJson(
      finalFingerprints,
      state?.preflight?.source_date_fingerprints?.current,
    );
  const predecessor = state?.runs?.find((run) => run.id === RETAINED_RUN);
  const run = state?.runs?.find((item) => item.id !== RETAINED_RUN);
  const batch = state?.batches?.[0];
  if (
    baseline?.mode !== "D046_CORRECTED_RESUME" ||
    !planningCloseoutPoliciesAccepted(state?.policies) ||
    state?.runs?.length !== 2 ||
    state?.batches?.length !== 1 ||
    state?.handoffs !== 0 ||
    !exactDate(predecessor) ||
    !exactDate(run) ||
    !exactDate(batch) ||
    predecessor.status !== "INVALIDATED" ||
    predecessor.version !== 4 ||
    predecessor.generated_line_count !== 304 ||
    predecessor.release_snapshot_line_count !== 304 ||
    predecessor.actor_id !== SYNTHETIC_ACTOR ||
    run.status !== "RELEASED_FOR_CONFIRMATION" ||
    run.version !== 3 ||
    run.predecessor_run_id !== predecessor.id ||
    run.generated_line_count !== 304 ||
    run.release_snapshot_line_count !== 304 ||
    run.actor_id !== SYNTHETIC_ACTOR ||
    run.blocking_issue_count !== 0 ||
    run.warning_count !== 0 ||
    batch.status !== "DRAFT_REVIEW" ||
    batch.version !== 3 ||
    batch.source_kind !== "NEED_GENERATION" ||
    batch.origin_run_id !== predecessor.id ||
    batch.current_run_id !== run.id ||
    batch.origin_run_version !== 3 ||
    batch.current_run_version !== run.version ||
    batch.line_count !== 248 ||
    batch.stable_line_count !== 249 ||
    batch.decision_count !== 248 ||
    batch.current_decision_count !== 248 ||
    batch.adjustment_count !== 1 ||
    batch.acceptance_count !== 247 ||
    !classifyPlanningGenerationReceipts(state.receipts, run.id) ||
    state.save_receipt_count !== 1 ||
    baseline.predecessorRunId !== predecessor.id ||
    baseline.currentRunId !== run.id ||
    baseline.batchId !== batch.id ||
    !preflightAccepted(state.preflight, "CURRENT", run.id, batch.id) ||
    state.preflight.current_need.confirmed_need_batch_version !== 3 ||
    state.d046?.predecessor_release_contribution_count !== 304 ||
    state.d046?.successor_release_contribution_count !== 304 ||
    state.d046?.current_snapshot_pair_count !== 248 ||
    state.d046?.exact_proposal_count !== 248 ||
    state.d046?.invalid_proposal_count !== 0 ||
    state.d046?.retained_pre_d046_null_pair_count !== 248 ||
    state.d046?.allowed_unit_transition_count !== 1 ||
    state.d046?.invalid_unit_transition_count !== 0 ||
    state.d046?.current_raw_membership_count !== 304 ||
    !browser?.batchId ||
    browser.batchId !== batch.id ||
    browser.generateClicks !== 0 ||
    browser.saveClicks !== 1 ||
    browser.newDecisions !== 248 ||
    browser.businessQuantityAdjustments !== 1 ||
    browser.proposalAcceptances !== 247 ||
    review?.confirmed_need_batch_id !== browser.batchId ||
    review?.batch_version !== browser.batchVersion ||
    review?.source_kind !== "NEED_GENERATION" ||
    review?.lines?.length !== 248 ||
    review?.pagination?.has_more ||
    review?.blockers?.length !== 0 ||
    !review?.editing_allowed ||
    !fingerprintsMatch
  )
    throw new Error("FINAL_PLANNING_CLOSEOUT_PROOF_FAILED");
  try {
    classifyPlanningAdoptionManifest(state.adoption_manifest, "post-deploy");
  } catch {
    throw new Error("FINAL_PLANNING_CLOSEOUT_PROOF_FAILED");
  }
  return {
    mode: baseline.mode,
    retainedRuns: state.runs.length,
    retainedBatches: state.batches.length,
    retainedLines: review.lines.length,
    humanDecisions: batch.decision_count,
    currentDecisions: batch.current_decision_count,
    purchaseHandoffs: state.handoffs,
    sourceFingerprintsUnchanged: true,
  };
}
export function nextCent(value) {
  if (!/^\d+(?:\.\d{1,6})?$/.test(value))
    throw new Error("INVALID_EXACT_QUANTITY");
  const [whole, decimal = ""] = value.split(".");
  const ticks =
    BigInt(whole) * 100n + BigInt((decimal + "00").slice(0, 2)) + 1n;
  return `${ticks / 100n}.${String(ticks % 100n).padStart(2, "0")}`;
}
export async function verifyPlanningCloseout({
  commitSha,
  closeoutMode,
  persist = false,
  environment = process.env,
} = {}) {
  const target = validateAtlasStagingPackageProtectedValues(environment);
  verifyPackageCheckout({ commitSha });
  const sql = async (query) =>
    JSON.parse(await executeAtlasStagingManagementSql(target, query));
  const readSnapshot = async () =>
    (await sql(planningCloseoutSnapshotSql()))[0]?.checkpoint;
  const initialSnapshot = await readSnapshot();
  let baseline;
  if (closeoutMode === "post_save_resume") {
    if (persist) throw new Error("POST_SAVE_RESUME_MUST_BE_READ_ONLY");
    baseline = classifyPostSavePlanningCloseout(initialSnapshot);
  } else if (closeoutMode === "pre_save_rehearsal") {
    if (!persist) throw new Error("PERSIST_REHEARSAL_REQUIRED");
    baseline = requireProtectedPlanningCloseoutBaseline(initialSnapshot);
  } else throw new Error("PLANNING_CLOSEOUT_MODE_REQUIRED");
  const baselineFingerprints = baseline.fingerprints;
  if (
    environment.ATLAS_PLANNING_PREVIEW_URL !== APPROVED_PREVIEW_URL ||
    environment.ATLAS_PLANNING_PREVIEW_SHA !== APPROVED_PREVIEW_SHA
  )
    throw new Error("PLANNING_PREVIEW_PROVENANCE_CONFIGURATION_REQUIRED");
  const certification = await verifyCertificationOnlyPreviewDelta({
    verifierCommitSha: commitSha,
    githubToken: environment.GITHUB_TOKEN,
  });
  const { verifyPlanningPreview } =
    await import("./staging-planning-preview.mjs");
  const preview = await verifyPlanningPreview({
    environment,
    requiredSha: certification.certifiedPreviewBaseSha,
  });
  if (
    preview.url !== APPROVED_PREVIEW_URL ||
    preview.commit !== APPROVED_PREVIEW_SHA ||
    preview.requiredMainCommit !== CERTIFIED_PREVIEW_BASE_SHA
  )
    throw new Error("PLANNING_PREVIEW_PROVENANCE_REJECTED");
  const client = createClient(target.supabaseUrl, target.publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    db: { retry: false },
  });
  const { data, error } = await client.auth.signInWithPassword({
    email: target.testEmail,
    password: target.testPassword,
  });
  if (error || data.user?.id !== SUBJECT || !data.session)
    throw new Error("STAGING_OPERATOR_AUTH_FAILED");
  const readReview = async () => {
    const rows = await sql(
      `begin read only; select confirmed_need_batch_id from atlas_planning.confirmed_need_batches where period_start='2026-09-17' and period_end='2026-09-17'; rollback;`,
    );
    if (
      rows.length !== 1 ||
      (baseline.batchId && rows[0].confirmed_need_batch_id !== baseline.batchId)
    )
      throw new Error("AUTHORITATIVE_BATCH_ID_REJECTED");
    const id = rows[0].confirmed_need_batch_id;
    const result = await client
      .schema("atlas_api")
      .rpc("get_confirmed_need_review", {
        request: {
          contract_version: "RMVP-05.v1",
          requested_by_auth_subject: SUBJECT,
          correlation_id: crypto.randomUUID(),
          payload: {
            confirmed_need_batch_id: id,
            filters: { service_date: "2026-09-17" },
            line_offset: 0,
            line_limit: 10000,
          },
        },
      });
    if (result.error || !result.data?.success)
      throw new Error("AUTHORITATIVE_REVIEW_FAILED");
    return result.data.workbench;
  };
  try {
    const browserJourney = async (beforeBrowser) => {
      if (
        beforeBrowser.predecessorRunId !== baseline.predecessorRunId ||
        beforeBrowser.currentRunId !== baseline.currentRunId ||
        beforeBrowser.batchId !== baseline.batchId ||
        !sameJson(beforeBrowser.fingerprints, baselineFingerprints)
      )
        throw new Error("PLANNING_CLOSEOUT_CHECKPOINT_CHANGED");
      const { verifyPlanningBrowser } =
        await import("./staging-planning-browser.mjs");
      return verifyPlanningBrowser({
        target,
        baseline: beforeBrowser,
        session: data.session,
        readReview,
        preview,
      });
    };
    const browser = await startProtectedPlanningBrowserCloseout({
      snapshot: await readSnapshot(),
      closeoutMode,
      persistRehearsal: persist,
      readOnlyJourney: browserJourney,
      mutationJourney: browserJourney,
    });
    const state = await readSnapshot();
    const review = await readReview();
    const proofBaseline =
      closeoutMode === "pre_save_rehearsal"
        ? {
            ...classifyPostSavePlanningCloseout(state),
            browserMode: "D046_CORRECTED_RESUME",
            browserSaveClicks: 1,
          }
        : baseline;
    const finalProof = assertFinalPlanningCloseoutProof({
      baseline: proofBaseline,
      browser,
      state,
      review,
      baselineFingerprints,
      finalFingerprints: state?.preflight?.source_date_fingerprints?.selected,
    });
    console.log(JSON.stringify({ final_planning_closeout_proof: finalProof }));
    return { ...browser, finalProof };
  } finally {
    client.auth.stopAutoRefresh();
  }
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const at = process.argv.indexOf("--commit-sha");
  const modeAt = process.argv.indexOf("--closeout-mode");
  verifyPlanningCloseout({
    commitSha: process.argv[at + 1],
    closeoutMode: process.argv[modeAt + 1],
    persist: process.argv.includes("--persist-rehearsal"),
  })
    .then((result) => console.log(JSON.stringify(result)))
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error.message));
      process.exitCode = 1;
    });
}
