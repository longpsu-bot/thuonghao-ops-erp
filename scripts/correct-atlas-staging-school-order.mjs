import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
const SNAPSHOT_ID = "ops-v1-school-order-forward-correction-38071834975-1-v1";
export const ORIGINAL_RECEIPT_HASH =
  "d40db1e5ee7512674c519bf60d4a21866a78935f3a16d43c2bb70d146750e2d9";
const REVIEW = "SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW";
const SHA256 = /^[0-9a-f]{64}$/;
const fixture = JSON.parse(
  readFileSync(
    new URL(
      "./fixtures/atlas-school-order-forward-correction.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const reasons = new Set([
  "RESTORE_PRE_RECONCILIATION",
  "BINH_QUOI_BLOCK",
  "HUNG_VUONG_BLOCK",
  "SHIFT_FOR_BLOCK_COLLISION",
  "UNCHANGED",
  "NEW_CANONICAL_SCHOOL",
]);
function fail(detail) {
  throw new Error(`${REVIEW}:${detail}`);
}
// Object-key canonicalization does not emulate PostgreSQL's School comparator.
// School sequences are compared directly to the reviewed database-sorted fixture.
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonical(value[key])]),
    );
  return value;
}
function same(left, right) {
  return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right));
}
function credentials(environment) {
  const key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (
    typeof key !== "string" ||
    !key.startsWith("sb_publishable_") ||
    !environment.ATLAS_STAGING_TEST_EMAIL ||
    !environment.ATLAS_STAGING_TEST_PASSWORD
  )
    fail("AUTHENTICATED_READ_CREDENTIAL_REQUIRED");
  return key;
}
export function buildSchoolOrderCorrectionSql({
  targetProjectRef,
  apply = false,
  planChecksum,
} = {}) {
  if (targetProjectRef !== STAGING) fail("EXACT_STAGING_TARGET_REQUIRED");
  if (apply && !SHA256.test(String(planChecksum ?? "")))
    fail("REVIEWED_PLAN_CHECKSUM_REQUIRED");
  const packageSql = readFileSync(
    new URL(
      "../supabase/packages/atlas-staging-school-order-forward-correction.sql",
      import.meta.url,
    ),
    "utf8",
  );
  return `set statement_timeout='15min';\nset lock_timeout='30s';\n${packageSql}\nselect pg_temp.run_school_order_forward_correction(${apply ? "true" : "false"}, ${apply ? "'" + planChecksum + "'" : "null"}) as result;\n`;
}
export function validateSchoolOrderCorrectionPlan(plan) {
  const original = fixture.receipt;
  const ids = original.result_payload.target_school_order_ids;
  if (
    plan?.success !== true ||
    !["PREVIEW", "APPLIED", "REPLAYED"].includes(plan.status) ||
    plan.snapshot_id !== SNAPSHOT_ID ||
    plan.original_receipt_hash !== ORIGINAL_RECEIPT_HASH ||
    plan.original_snapshot_id !== original.snapshot_id ||
    plan.original_snapshot_checksum !== original.snapshot_checksum ||
    plan.original_plan_checksum !== original.plan_checksum ||
    !SHA256.test(String(plan.plan_checksum ?? "")) ||
    !Array.isArray(plan.report) ||
    plan.report.length !== 50 ||
    !same(plan.target_school_order_ids, ids) ||
    !same(plan.target_school_display_orders, fixture.expected_corrected_orders)
  )
    fail("PLAN_OR_RECEIPT_DRIFT");
  if (
    !plan.protected_fingerprints ||
    typeof plan.protected_fingerprints !== "object" ||
    Array.isArray(plan.protected_fingerprints) ||
    Object.keys(plan.protected_fingerprints).length === 0 ||
    Object.values(plan.protected_fingerprints).some(
      (f) =>
        !Number.isSafeInteger(f?.rows) ||
        f.rows < 0 ||
        !SHA256.test(f.sha256 ?? ""),
    )
  )
    fail("PROTECTED_FINGERPRINTS_INVALID");
  const corrected = fixture.expected_corrected_orders;
  if (
    !same(
      plan.report.map((s) => s.school_id),
      ids,
    ) ||
    new Set(plan.report.map((s) => s.school_id)).size !== 50
  )
    fail("COMPLETE_ORDER_REQUIRED");
  for (const [i, row] of plan.report.entries()) {
    const current = fixture.current_schools.find(
      (s) => s.school_id === row.school_id,
    );
    const old = original.result_payload.current_schools.find(
      (s) => s.school_id === row.school_id,
    );
    const legacy = fixture.current_mappings.find(
      (m) => m.school_id === row.school_id,
    )?.legacy_id;
    const block = ["52", "10"].includes(legacy)
      ? "BINH_QUOI"
      : ["47", "48", "49", "50", "53"].includes(legacy)
        ? "HUNG_VUONG"
        : null;
    if (
      !current ||
      row.school_code !== current.school_code ||
      row.school_name !== current.school_name ||
      row.pre_reconciliation_order !== (old?.display_order ?? null) ||
      row.current_dense_order !== current.display_order ||
      row.corrected_order !== corrected[i].display_order ||
      row.changed_by_forward_correction !==
        (current.display_order !== row.corrected_order) ||
      row.block !== block ||
      !reasons.has(row.reason)
    )
      fail("SCHOOL_REPORT_DRIFT");
  }
  // Valid global ties remain; scoped ACTIVE-Customer uniqueness is backend-owned.
  if (plan.report.every((row, i) => row.corrected_order === i))
    fail("GLOBAL_DENSE_RENUMBER_FORBIDDEN");
  return plan;
}
function validateOutcome(outcome, preview, status) {
  validateSchoolOrderCorrectionPlan(outcome);
  if (
    !status.includes(outcome.status) ||
    !same(outcome.report, preview.report) ||
    !same(outcome.target_school_order_ids, preview.target_school_order_ids) ||
    !same(
      outcome.target_school_display_orders,
      preview.target_school_display_orders,
    ) ||
    outcome.plan_checksum !== preview.plan_checksum ||
    !same(outcome.protected_fingerprints, preview.protected_fingerprints) ||
    [
      "reconciled",
      "operational_data_unchanged",
      "unrelated_master_facts_unchanged",
      "original_receipt_unchanged",
    ].some((key) => outcome[key] !== true)
  )
    fail("APPLY_OR_REPLAY_DRIFT");
}
async function authenticatedResponse(fetchImpl, url, options) {
  try {
    const response = await fetchImpl(url, options);
    return { ok: response.ok, body: await response.json() };
  } catch {
    fail("AUTHENTICATED_TRANSPORT_OR_RESPONSE_FAILED");
  }
}
async function signIn(authority, environment, fetchImpl) {
  const key = credentials(environment);
  const response = await authenticatedResponse(
    fetchImpl,
    authority.targetSupabaseUrl + "/auth/v1/token?grant_type=password",
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(45000),
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: environment.ATLAS_STAGING_TEST_EMAIL,
        password: environment.ATLAS_STAGING_TEST_PASSWORD,
      }),
    },
  );
  const session = response.body;
  if (!response.ok || !session.access_token || !session.user?.id)
    fail("AUTHENTICATED_SIGNIN_FAILED");
  return { key, token: session.access_token, userId: session.user.id };
}
async function readSchools(authority, session, fetchImpl) {
  const response = await authenticatedResponse(
    fetchImpl,
    authority.targetSupabaseUrl + "/rest/v1/rpc/get_school_master_data",
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(45000),
      headers: {
        apikey: session.key,
        Authorization: "Bearer " + session.token,
        "Content-Type": "application/json",
        "Content-Profile": "atlas_api",
      },
      body: JSON.stringify({
        request: {
          contract_version: "RMVP-01.v1",
          requested_by_auth_subject: session.userId,
          correlation_id: randomUUID(),
          payload: {},
        },
      }),
    },
  );
  const body = response.body;
  if (!response.ok || body?.success !== true || !Array.isArray(body.schools))
    fail("AUTHENTICATED_READBACK_FAILED");
  return body.schools;
}
function validateSchoolRead(schools, plan, corrected) {
  if (
    schools.length !== 50 ||
    !same(
      schools.map((s) => s.school_id),
      plan.target_school_order_ids,
    )
  )
    fail("AUTHENTICATED_RAW_ORDER_OR_COUNT_DRIFT");
  for (const [i, school] of schools.entries()) {
    const expected = plan.report[i];
    const scope = fixture.school_scope.find(
      (s) => s.school_id === school.school_id,
    );
    if (
      ["school_code", "school_name"].some(
        (key) => school[key] !== expected[key],
      ) ||
      school.display_order !==
        (corrected ? expected.corrected_order : expected.current_dense_order) ||
      !Number.isSafeInteger(school.version) ||
      school.version < 1 ||
      school.customer_id !== scope.customer_id ||
      school.school_status !== scope.school_status
    )
      fail("AUTHENTICATED_SCHOOL_FACT_DRIFT");
  }
}
function nonOrderFacts(school) {
  return Object.fromEntries(
    Object.entries(school).filter(
      ([key]) => !["display_order", "version", "updated_at"].includes(key),
    ),
  );
}
function verifyOnlyOrderChanged(before, after) {
  for (const [i, school] of after.entries()) {
    const old = before[i];
    const expectedVersion =
      old.version + Number(old.display_order !== school.display_order);
    if (
      !same(nonOrderFacts(old), nonOrderFacts(school)) ||
      school.version !== expectedVersion
    )
      fail("AUTHENTICATED_NON_ORDER_FACT_DRIFT");
  }
}
export async function runSchoolOrderForwardCorrection({
  commitSha,
  apply = false,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  executeTarget,
  fetchImpl = fetch,
  onProgress = () => {},
  onReport = (report) => console.log(JSON.stringify(report, null, 2)),
} = {}) {
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  if (apply) credentials(environment);
  await verifyCheckout({ commitSha, cwd });
  const target = {
    projectRef: authority.targetProjectRef,
    supabaseUrl: authority.targetSupabaseUrl,
    accessToken: authority.targetAccessToken,
  };
  const execute =
    executeTarget ??
    ((t, sql, options = {}) =>
      executeAtlasStagingPostgres(t, sql, { environment, cwd, ...options }));
  const read = async (sql, options) =>
    parseStagingMasterResult(await execute(target, sql, options));
  await onProgress("VERIFY_STAGING_97_BEFORE_FORWARD_CORRECTION");
  const migrations = await read(
    "select jsonb_build_object('migration_count',count(*),'tip',max(version)) as result from supabase_migrations.schema_migrations;",
    { timeoutMs: 45000 },
  );
  if (migrations.migration_count !== 97 || migrations.tip !== "20261010034834")
    fail("MIGRATION_GATE");
  const preview = validateSchoolOrderCorrectionPlan(
    await read(buildSchoolOrderCorrectionSql({ targetProjectRef: STAGING })),
  );
  if (
    preview.status !== "PREVIEW" ||
    typeof preview.correction_already_applied !== "boolean"
  )
    fail("PREVIEW_CONTRACT_DRIFT");
  await onReport({
    plan_checksum: preview.plan_checksum,
    report: preview.report,
  });
  const result = {
    snapshot_id: SNAPSHOT_ID,
    original_receipt_hash: ORIGINAL_RECEIPT_HASH,
    plan_checksum: preview.plan_checksum,
    report: preview.report,
    target_school_order_ids: preview.target_school_order_ids,
    target_school_display_orders: preview.target_school_display_orders,
  };
  if (!apply)
    return {
      ...result,
      status: "SCHOOL_ORDER_FORWARD_CORRECTION_PREVIEW",
      correction_already_applied: preview.correction_already_applied,
    };
  const session = await signIn(authority, environment, fetchImpl);
  const before = await readSchools(authority, session, fetchImpl);
  validateSchoolRead(before, preview, preview.correction_already_applied);
  await verifyCheckout({ commitSha, cwd });
  const sql = buildSchoolOrderCorrectionSql({
    targetProjectRef: STAGING,
    apply: true,
    planChecksum: preview.plan_checksum,
  });
  const applyOnce = async () => {
    try {
      return await read(sql);
    } catch {
      throw new Error(
        `SCHOOL_ORDER_FORWARD_CORRECTION_OUTCOME_UNCERTAIN: inspect receipt ${SNAPSHOT_ID} before further execution; do not retry or create a new key`,
      );
    }
  };
  const applied = await applyOnce();
  validateOutcome(applied, preview, ["APPLIED", "REPLAYED"]);
  const replay = await applyOnce();
  validateOutcome(replay, preview, ["REPLAYED"]);
  const after = await readSchools(authority, session, fetchImpl);
  validateSchoolRead(after, preview, true);
  verifyOnlyOrderChanged(before, after);
  return {
    ...result,
    status: "SCHOOL_ORDER_FORWARD_CORRECTION_PASS",
    receipt_id: applied.import_batch_id,
    replay_status: replay.status,
    authenticated_readback: {
      status: "AUTHENTICATED_FULL_SCHOOL_ORDER_PASS",
      school_count: 50,
      target_school_order_ids: after.map((s) => s.school_id),
      non_order_facts_unchanged: true,
    },
    operational_data_unchanged: true,
    unrelated_master_facts_unchanged: true,
    original_receipt_unchanged: true,
  };
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const flags = new Map();
    for (let i = 2; i < process.argv.length; i++) {
      const flag = process.argv[i];
      if (
        !["--commit-sha", "--target-project-ref", "--apply"].includes(flag) ||
        flags.has(flag)
      )
        fail("ARGUMENT_INVALID");
      if (flag === "--apply") flags.set(flag, true);
      else {
        const value = process.argv[++i];
        if (!value || value.startsWith("--")) fail("ARGUMENT_VALUE_REQUIRED");
        flags.set(flag, value);
      }
    }
    console.log(
      JSON.stringify(
        await runSchoolOrderForwardCorrection({
          commitSha: flags.get("--commit-sha"),
          apply: flags.has("--apply"),
          targetConfirmation: flags.get("--target-project-ref"),
          onProgress: (message) => console.log(message),
        }),
        null,
        2,
      ),
    );
  } catch (error) {
    console.error(redactAtlasStagingDiagnostic(error?.message ?? REVIEW));
    process.exitCode = 1;
  }
}
