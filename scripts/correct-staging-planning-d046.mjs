import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";
import { classifyPlanningAdoptionManifest } from "./verify-staging-planning-adoption-manifest.mjs";
import {
  certifyCorrectionRollback,
  correctionRollbackSql,
  correctionPersistenceSql,
} from "./staging-planning-correction-performance.mjs";
import {
  classifyPlanningCheckpoint,
  classifyPlanningGenerationReceipts,
  planningCloseoutSnapshotSql,
  retainedAdoptionLineageSide,
} from "./verify-staging-planning-closeout.mjs";

const SUBJECT = "a1010000-0000-4000-8000-000000000101";
const SYNTHETIC_ACTOR = "a1010000-0000-4000-8000-000000000001";
export const RETAINED_RUN = "0c83b440-8fb2-4a77-9735-804ef4c89ea0";
export const RETAINED_BATCH = "a0311e0a-a4de-48b9-a529-fe7464a3352b";
const RETAINED_ADOPTION_LEGACY_LINE =
  "recipe:dish:1483:school-type:1:ingredient:1045";
const RETAINED_ADOPTION_INGREDIENT = "1045";
const SOURCE_FINGERPRINT_KEYS = ["attendance", "pantry", "weekly_menu"];

const canonicalJson = (value) => {
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  return value;
};
const sameJson = (left, right) =>
  JSON.stringify(canonicalJson(left)) === JSON.stringify(canonicalJson(right));

const correctionSourceFingerprintsAccepted = (source) =>
  source?.service_date === "2026-09-17" &&
  sameJson(
    Object.keys(source.selected ?? {}).sort(),
    SOURCE_FINGERPRINT_KEYS,
  ) &&
  SOURCE_FINGERPRINT_KEYS.every(
    (key) =>
      typeof source.selected[key] === "string" &&
      source.selected[key].length > 0,
  ) &&
  sameJson(source.selected, source.current);

const correctionTargetAccepted = (evidence, target) =>
  evidence?.source_unit_id !== evidence?.corrected_unit_id &&
  target?.recipe_version_status === "RELEASED_FOR_PLANNING" &&
  target.line_disposition === "PRESENT" &&
  target.recipe_version_id === evidence.target_recipe_version_id &&
  target.recipe_line_revision_id === evidence.target_recipe_line_revision_id &&
  target.predecessor_recipe_version_id ===
    evidence.predecessor_recipe_version_id &&
  target.predecessor_recipe_line_revision_id ===
    evidence.predecessor_recipe_line_revision_id &&
  target.recipe_id === evidence.recipe_id &&
  target.recipe_line_id === evidence.recipe_line_id &&
  target.ingredient_id === evidence.ingredient_id &&
  target.unit_id === evidence.corrected_unit_id &&
  target.quantity_per_basis === evidence.quantity_per_basis;

const correctionAdoptionWorkloadAccepted = (workload) => {
  if (
    workload?.date !== "2026-09-17" ||
    workload.adoption_occurrence_count !== 1 ||
    !sameJson(workload.adoption_legacy_line_ids, [
      RETAINED_ADOPTION_LEGACY_LINE,
    ]) ||
    !sameJson(workload.adoption_ingredient_ids, [
      RETAINED_ADOPTION_INGREDIENT,
    ]) ||
    !Array.isArray(workload.adoption_occurrences) ||
    workload.adoption_occurrences.length !== 1
  )
    return false;
  const occurrence = workload.adoption_occurrences[0];
  return (
    occurrence?.legacy_recipe_line_id === RETAINED_ADOPTION_LEGACY_LINE &&
    occurrence.legacy_ingredient_id === RETAINED_ADOPTION_INGREDIENT &&
    retainedAdoptionLineageSide(occurrence.evidence, occurrence.theoretical) ===
      "PREDECESSOR" &&
    correctionTargetAccepted(occurrence.evidence, occurrence.target)
  );
};

export function classifyD046CorrectionBaseline(snapshot) {
  const reject = () => {
    throw new Error("D046_CORRECTION_BASELINE_REJECTED");
  };
  if (
    !Array.isArray(snapshot?.runs) ||
    snapshot.runs.length !== 1 ||
    !Array.isArray(snapshot?.batches) ||
    snapshot.batches.length !== 1 ||
    !Array.isArray(snapshot?.receipts) ||
    !classifyPlanningGenerationReceipts(snapshot.receipts) ||
    snapshot.handoffs !== 0 ||
    snapshot.save_receipt_count !== 0
  )
    reject();
  const run = snapshot.runs[0];
  const batch = snapshot.batches[0];
  const source = snapshot.preflight?.source_date_fingerprints;
  if (
    run.id !== RETAINED_RUN ||
    run.period_start !== "2026-09-17" ||
    run.period_end !== "2026-09-17" ||
    run.status !== "RELEASED_FOR_CONFIRMATION" ||
    run.version !== 3 ||
    run.generated_line_count !== 304 ||
    run.release_snapshot_line_count !== 304 ||
    run.blocking_issue_count !== 0 ||
    run.warning_count !== 0 ||
    run.actor_id !== SYNTHETIC_ACTOR ||
    batch.id !== RETAINED_BATCH ||
    batch.period_start !== "2026-09-17" ||
    batch.period_end !== "2026-09-17" ||
    batch.status !== "DRAFT_REVIEW" ||
    batch.version !== 1 ||
    batch.source_kind !== "NEED_GENERATION" ||
    batch.origin_run_id !== RETAINED_RUN ||
    batch.current_run_id !== RETAINED_RUN ||
    batch.origin_run_version !== 3 ||
    batch.current_run_version !== 3 ||
    batch.line_count !== 248 ||
    batch.stable_line_count !== 248 ||
    batch.decision_count !== 0 ||
    batch.current_decision_count !== 0 ||
    batch.adjustment_count !== 0 ||
    batch.acceptance_count !== 0 ||
    snapshot.preflight?.readiness_state !== "READY" ||
    snapshot.preflight?.downstream_currentness !== "CURRENT" ||
    snapshot.preflight?.blocking_issue_count !== 0 ||
    snapshot.preflight?.current_need?.need_generation_run_id !== RETAINED_RUN ||
    snapshot.preflight?.current_need?.confirmed_need_batch_id !==
      RETAINED_BATCH ||
    snapshot.preflight?.current_need?.need_generation_run_version !== 3 ||
    snapshot.preflight?.current_need?.confirmed_need_batch_version !== 1 ||
    !correctionSourceFingerprintsAccepted(source) ||
    !correctionAdoptionWorkloadAccepted(snapshot.adoption_workload)
  )
    reject();
  try {
    classifyPlanningAdoptionManifest(snapshot.adoption_manifest, "post-deploy");
  } catch {
    reject();
  }
  return {
    mode: "D046_CORRECTION_ELIGIBLE",
    predecessorRunId: run.id,
    batchId: batch.id,
    expectedVersion: run.version,
    currentLineCount: batch.line_count,
    fingerprints: source.selected,
  };
}

export function buildD046CorrectionRequest(snapshot, commandId) {
  const baseline = classifyD046CorrectionBaseline(snapshot);
  if (snapshot.receipts.some((receipt) => receipt.command_id === commandId))
    throw new Error("D046_CORRECTION_COMMAND_ID_REUSED");
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      commandId,
    )
  )
    throw new Error("D046_CORRECTION_COMMAND_ID_REJECTED");
  return {
    contract_version: "RMVP-04.v3",
    command_id: commandId,
    correlation_id: randomUUID(),
    idempotency_key: `planning-d046-correction:${commandId}`,
    expected_version: baseline.expectedVersion,
    requested_by_auth_subject: SUBJECT,
    requested_at: new Date().toISOString(),
    reason_code: "NEED_GENERATION_EXECUTED",
    reason_note:
      "Owner-approved one-shot D-046 legacy adoption Unit correction.",
    payload: {
      service_date: "2026-09-17",
      expected_current_need_generation_run_id: baseline.predecessorRunId,
    },
  };
}

export async function executeD046Correction({
  invoke,
  readSnapshot,
  commandId,
}) {
  const before = await readSnapshot();
  const baseline = classifyD046CorrectionBaseline(before);
  const request = buildD046CorrectionRequest(before, commandId);
  let response;
  let invocationError;
  try {
    response = await invoke(request);
  } catch (error) {
    invocationError = error;
  }
  const after = await readSnapshot();
  let corrected;
  try {
    corrected = classifyPlanningCheckpoint(after);
  } catch (error) {
    throw new Error("D046_CORRECTION_OUTCOME_REJECTED", {
      cause: invocationError ?? error,
    });
  }
  const correctionReceipt = classifyPlanningGenerationReceipts(
    after.receipts,
    corrected.currentRunId,
  )?.correction;
  if (
    corrected.mode !== "D046_CORRECTED_RESUME" ||
    corrected.predecessorRunId !== baseline.predecessorRunId ||
    corrected.batchId !== baseline.batchId ||
    !sameJson(corrected.fingerprints, baseline.fingerprints) ||
    correctionReceipt?.command_id !== commandId ||
    (response?.success === true &&
      (response.affected_aggregate_ids?.need_generation_run_id !==
        corrected.currentRunId ||
        response.affected_aggregate_ids?.confirmed_need_batch_id !==
          corrected.batchId))
  )
    throw new Error("D046_CORRECTION_OUTCOME_REJECTED", {
      cause: invocationError,
    });
  return corrected;
}

export async function correctStagingPlanningD046({
  commitSha,
  persist = false,
  commandId = randomUUID(),
  environment = process.env,
} = {}) {
  const target = validateAtlasStagingPackageProtectedValues(environment);
  verifyPackageCheckout({ commitSha });
  const sql = async (query) =>
    JSON.parse(await executeAtlasStagingManagementSql(target, query));
  const readSnapshot = async () =>
    (await sql(planningCloseoutSnapshotSql()))[0]?.checkpoint;
  const before = await readSnapshot();
  const baseline = classifyD046CorrectionBaseline(before);
  console.log(
    JSON.stringify({ status: "D046_CORRECTION_ELIGIBLE", ...baseline }),
  );
  const certification = await certifyCorrectionRollback({
    readSnapshot,
    makeRequest: (snapshot) =>
      buildD046CorrectionRequest(snapshot, randomUUID()),
    runProbe: async (request) =>
      (await sql(correctionRollbackSql(request)))[0]?.probe,
  });
  console.log(JSON.stringify(certification));
  if (!persist) return certification;

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
  try {
    return await executeD046Correction({
      commandId,
      readSnapshot,
      invoke: async (request) => {
        return (await sql(correctionPersistenceSql(request)))[0]?.response;
      },
    });
  } finally {
    client.auth.stopAutoRefresh();
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const shaAt = process.argv.indexOf("--commit-sha");
  const commandAt = process.argv.indexOf("--command-id");
  correctStagingPlanningD046({
    commitSha: process.argv[shaAt + 1],
    commandId: commandAt >= 0 ? process.argv[commandAt + 1] : randomUUID(),
    persist: process.argv.includes("--persist-correction"),
  })
    .then((result) => console.log(JSON.stringify(result)))
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error.message));
      process.exitCode = 1;
    });
}
