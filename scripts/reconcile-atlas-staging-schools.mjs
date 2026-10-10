import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import {
  checksumOpsV1MasterSnapshot,
  extractOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";
import {
  buildSchoolMasterReconciliationReport,
  buildSchoolDocumentConfiguration,
} from "./atlas-document-school-configuration.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
const SHA256 = /^[0-9a-f]{64}$/;
function requireSchoolReadCredentials(environment) {
  const key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (
    !key ||
    !String(key).startsWith("sb_publishable_") ||
    !environment.ATLAS_STAGING_TEST_EMAIL ||
    !environment.ATLAS_STAGING_TEST_PASSWORD
  )
    throw new Error("STAGING_READ_CREDENTIAL_MISSING");
  return key;
}

export function buildSchoolReconciliationSql(
  snapshot,
  { targetProjectRef, apply = false, planChecksum, order } = {},
) {
  if (targetProjectRef !== STAGING)
    throw new Error("EXACT_STAGING_TARGET_REQUIRED");
  if (
    !snapshot ||
    snapshot.contract_version !== "OPS-V1-MASTER-SNAPSHOT.v1" ||
    snapshot.source_project_ref !== "qnthofvccilhnefdcxnz" ||
    snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot)
  )
    throw new Error("SNAPSHOT_CHECKSUM_OR_CONTRACT_INVALID");
  if (
    apply &&
    (!SHA256.test(String(planChecksum ?? "")) || !Array.isArray(order))
  )
    throw new Error("REVIEWED_PLAN_AND_ORDER_REQUIRED");
  const packageSql = readFileSync(
    new URL(
      "../supabase/packages/atlas-staging-school-reconciliation.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const literal = `convert_from(decode('${Buffer.from(JSON.stringify(snapshot)).toString("base64")}','base64'),'UTF8')::jsonb`;
  const orderLiteral = apply
    ? `convert_from(decode('${Buffer.from(JSON.stringify(order)).toString("base64")}','base64'),'UTF8')::jsonb`
    : "null";
  return `set statement_timeout='15min';\nset lock_timeout='30s';\n${packageSql}\nselect pg_temp.run_staging_school_reconciliation(${literal}, ${apply ? "true" : "false"}, ${apply ? "'" + planChecksum + "'" : "null"}, ${orderLiteral}) as result;\n`;
}
export async function runSchoolReconciliation({
  commitSha,
  apply = false,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  extractSnapshot = extractOpsV1MasterSnapshot,
  executeTarget,
  fetchImpl = fetch,
  onProgress = () => {},
  onReport = (report) =>
    console.log(JSON.stringify({ reconciliation_report: report }, null, 2)),
} = {}) {
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  if (apply) requireSchoolReadCredentials(environment);
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
  await onProgress("VERIFY_STAGING_97_BEFORE_SOURCE_EXTRACTION");
  const migrations = await read(
    "select jsonb_build_object('migration_count',count(*),'tip',max(version)) as result from supabase_migrations.schema_migrations;",
    { timeoutMs: 45000 },
  );
  if (migrations.migration_count !== 97 || migrations.tip !== "20261010034834")
    throw new Error("SCHOOL_RECONCILIATION_MIGRATION_GATE");
  await onProgress("EXTRACT_READ_ONLY_IMMUTABLE_SOURCE");
  const snapshot = await extractSnapshot({
    accessToken: authority.targetAccessToken,
    snapshotId: `ops-v1-school-reconciliation-${environment.GITHUB_RUN_ID ?? Date.now()}-${environment.GITHUB_RUN_ATTEMPT ?? "1"}`,
    extractorVersion: commitSha,
    fetchImpl,
  });
  await onProgress("PREVIEW_SCOPED_SCHOOL_IMPORT_NO_BUSINESS_WRITES");
  const preview = await read(
    buildSchoolReconciliationSql(snapshot, { targetProjectRef: STAGING }),
  );
  if (preview.success !== true)
    throw new Error(
      `SCHOOL_MASTER_RECONCILIATION_REQUIRED:${/^[A-Z_]+$/.test(preview.error_code ?? "") ? preview.error_code : "PREVIEW_REJECTED"}`,
    );
  if (
    !SHA256.test(String(preview.plan_checksum ?? "")) ||
    preview.snapshot_checksum !== snapshot.snapshot_checksum
  )
    throw new Error("SCHOOL_PREVIEW_CONTRACT_MISMATCH");
  const report = buildSchoolMasterReconciliationReport({
    source: snapshot.records.schools.map((s) => ({
      legacy_school_id: s.legacy_id,
      source_name: s.school_name,
    })),
    schools: preview.current_schools,
    mappings: preview.current_mappings,
  });
  await onReport(report);
  if (
    report.some((r) =>
      ["DUPLICATE_MAPPING", "WRONG_MAPPING"].includes(r.status),
    )
  )
    throw new Error("SCHOOL_MASTER_RECONCILIATION_REQUIRED");
  const configuration = buildSchoolDocumentConfiguration({
    schools: preview.projected_schools,
    mappings: preview.projected_mappings,
  });
  if (
    JSON.stringify(configuration.target_school_order_ids) !==
    JSON.stringify(preview.target_school_order_ids)
  )
    throw new Error("SCHOOL_OWNER_ORDER_ASSERTION_FAILED");
  const identities = report.map((r) => {
    const m = preview.projected_mappings.find(
      (m) =>
        m.source_system === "OPS_V1" &&
        m.object_type === "SCHOOL" &&
        m.legacy_id === r.legacy_school_id,
    );
    return {
      legacy_school_id: r.legacy_school_id,
      school_id: m.school_id,
      school_code: `v1-school-${r.legacy_school_id}`,
      school_name: r.source_name,
      display_order: preview.target_school_display_orders.find(
        (o) => o.school_id === m.school_id,
      )?.display_order,
    };
  });
  const source = {
    snapshot_id: snapshot.snapshot_id,
    snapshot_checksum: snapshot.snapshot_checksum,
    exported_at: snapshot.exported_at,
  };
  if (!apply)
    return {
      status: "SCHOOL_RECONCILIATION_PREVIEW",
      source,
      reconciliation_report: report,
      plan_checksum: preview.plan_checksum,
      target_school_order_ids: configuration.target_school_order_ids,
    };
  const sql = buildSchoolReconciliationSql(snapshot, {
    targetProjectRef: STAGING,
    apply: true,
    planChecksum: preview.plan_checksum,
    order: configuration.target_school_order_ids,
  });
  let applied;
  try {
    applied = await read(sql);
  } catch {
    throw new Error(
      `SCHOOL_APPLY_OUTCOME_UNCERTAIN: inspect receipt for ${source.snapshot_id} / ${source.snapshot_checksum} before any further execution`,
    );
  }
  if (
    applied.success !== true ||
    applied.status !== "APPLIED" ||
    applied.reconciled !== true ||
    applied.operational_data_unchanged !== true ||
    applied.unrelated_master_facts_unchanged !== true
  )
    throw new Error(
      `SCHOOL_MASTER_RECONCILIATION_REQUIRED:${/^[A-Z_]+$/.test(applied.error_code ?? "") ? applied.error_code : "APPLY_REJECTED"}`,
    );
  const replay = await read(sql);
  if (
    replay.success !== true ||
    replay.status !== "REPLAYED" ||
    replay.reconciled !== true ||
    replay.operational_data_unchanged !== true ||
    replay.unrelated_master_facts_unchanged !== true
  )
    throw new Error("SCHOOL_REPLAY_DID_NOT_RECONCILE");
  return {
    status: "SCHOOL_MASTER_RECONCILED",
    source,
    reconciliation_report: report,
    plan_checksum: preview.plan_checksum,
    target_school_order_ids: configuration.target_school_order_ids,
    canonical_school_identities: identities,
    receipt_id: applied.import_batch_id,
    replay_status: replay.status,
    operational_data_unchanged: true,
    unrelated_master_facts_unchanged: true,
  };
}
export async function verifyReconciledSchoolVisibility(
  result,
  { environment = process.env, fetchImpl = fetch } = {},
) {
  const { targetSupabaseUrl } = validateV1ReferenceImportRequest({
    environment,
  });
  const key = requireSchoolReadCredentials(environment);
  const login = await fetchImpl(
    targetSupabaseUrl + "/auth/v1/token?grant_type=password",
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
  const session = await login.json();
  if (!login.ok || !session.access_token || !session.user?.id)
    throw new Error("STAGING_READ_SIGNIN_FAILED");
  const response = await fetchImpl(
    targetSupabaseUrl + "/rest/v1/rpc/get_school_master_data",
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(45000),
      headers: {
        apikey: key,
        Authorization: "Bearer " + session.access_token,
        "Content-Type": "application/json",
        "Content-Profile": "atlas_api",
      },
      body: JSON.stringify({
        request: {
          contract_version: "RMVP-01.v1",
          requested_by_auth_subject: session.user.id,
          correlation_id: crypto.randomUUID(),
          payload: {},
        },
      }),
    },
  );
  const body = await response.json();
  if (
    !response.ok ||
    body?.success !== true ||
    !Array.isArray(body.schools) ||
    !Array.isArray(result.canonical_school_identities) ||
    result.canonical_school_identities.length !== 15
  )
    throw new Error("SCHOOL_AUTHENTICATED_READBACK_FAILED");
  for (const expected of result.canonical_school_identities) {
    const matches = body.schools.filter(
      (s) => s.school_id === expected.school_id,
    );
    if (
      matches.length !== 1 ||
      ["school_code", "school_name", "display_order"].some(
        (k) => matches[0][k] !== expected[k],
      )
    )
      throw new Error("SCHOOL_AUTHENTICATED_READBACK_FAILED");
  }
  if (
    JSON.stringify(
      [...body.schools]
        .sort((a, b) => a.display_order - b.display_order)
        .map((s) => s.school_id),
    ) !== JSON.stringify(result.target_school_order_ids)
  )
    throw new Error("SCHOOL_AUTHENTICATED_ORDER_READBACK_FAILED");
  return {
    status: "AUTHENTICATED_SCHOOL_READBACK_PASS",
    schools: result.canonical_school_identities,
  };
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const flags = new Map();
  try {
    for (let i = 2; i < process.argv.length; i++) {
      const flag = process.argv[i];
      if (
        !["--commit-sha", "--target-project-ref", "--apply"].includes(flag) ||
        flags.has(flag)
      )
        throw new Error("SCHOOL_RECONCILIATION_ARGUMENT_INVALID");
      if (flag === "--apply") flags.set(flag, true);
      else flags.set(flag, process.argv[++i]);
    }
    const result = await runSchoolReconciliation({
      onProgress: (message) => console.log(message),
      commitSha: flags.get("--commit-sha"),
      apply: flags.has("--apply"),
      targetConfirmation: flags.get("--target-project-ref"),
    });
    console.log(JSON.stringify(result, null, 2));
    if (flags.has("--apply"))
      console.log(
        JSON.stringify(await verifyReconciledSchoolVisibility(result), null, 2),
      );
  } catch (error) {
    console.error(
      redactAtlasStagingDiagnostic(
        error?.message ?? "SCHOOL_RECONCILIATION_FAILED",
      ),
    );
    process.exitCode = 1;
  }
}
