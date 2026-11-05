import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { randomUUID } from "node:crypto";
import {
  canonicalMasterJson,
  checksumOpsV1MasterSnapshot,
  extractOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import {
  verifyExactHeadCertification,
  validateAtlasStagingProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import { migrationVersionsFromFilenames } from "./verify-atlas-staging.mjs";
const STAGING = "rnzxmxiiqgtdevzregff",
  SOURCE = "qnthofvccilhnefdcxnz",
  SHA256 = /^[a-f0-9]{64}$/;
const fail = (code) => {
  throw Error(`SCHOOL54_${code}`);
};
export function school54ContentChecksum(snapshot) {
  if (
    snapshot?.contract_version !== "OPS-V1-MASTER-SNAPSHOT.v1" ||
    snapshot.source_system !== "OPS_V1" ||
    snapshot.source_project_ref !== SOURCE ||
    snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot)
  )
    fail("SNAPSHOT_INVALID");
  const entities = [
    "customers",
    "delivery_locations",
    "dish_types",
    "dishes",
    "ingredient_order_groups",
    "ingredient_types",
    "ingredients",
    "recipe_lines",
    "recipes",
    "school_types",
    "schools",
    "supplier_eligibilities",
    "suppliers",
    "units",
  ];
  if (
    !snapshot.snapshot_id ||
    !snapshot.extractor_version ||
    !Number.isFinite(Date.parse(snapshot.exported_at)) ||
    !snapshot.records ||
    !Array.isArray(snapshot.complete_entities) ||
    canonicalMasterJson(Object.keys(snapshot.records).sort()) !==
      canonicalMasterJson(entities) ||
    canonicalMasterJson(snapshot.complete_entities) !==
      canonicalMasterJson(entities) ||
    !Array.isArray(snapshot.source_diagnostics)
  )
    fail("SNAPSHOT_ENVELOPE_INVALID");
  const proof = snapshot.source_access;
  if (
    proof?.role_name !== "supabase_read_only_user" ||
    proof.has_required_select !== true ||
    proof.has_non_select_privilege !== false ||
    proof.bypass_rls !== true ||
    proof.superuser !== false ||
    proof.create_role !== false ||
    proof.create_db !== false
  )
    fail("SNAPSHOT_READ_ONLY_PROOF_INVALID");
  for (const entity of entities) {
    const rows = snapshot.records[entity];
    if (
      !Array.isArray(rows) ||
      rows.some(
        (row) =>
          !row || typeof row.legacy_id !== "string" || !row.legacy_id.trim(),
      ) ||
      new Set(rows.map((row) => row.legacy_id)).size !== rows.length
    )
      fail("SNAPSHOT_IDENTITIES_INVALID");
  }
  const selected = (entity, id) => {
    const rows = snapshot.records[entity].filter((row) => row.legacy_id === id);
    if (rows.length !== 1) fail("SNAPSHOT_CLOSURE_REQUIRED");
    return rows;
  };
  const schools = selected("schools", "54");
  return checksumOpsV1MasterSnapshot({
    contract_version: snapshot.contract_version,
    source_system: snapshot.source_system,
    source_project_ref: snapshot.source_project_ref,
    source_access: proof,
    records: {
      customers: selected("customers", "school:54:customer"),
      delivery_locations: selected(
        "delivery_locations",
        "school:54:delivery-location",
      ),
      schools,
      school_types: selected("school_types", schools[0].school_type_legacy_id),
    },
  });
}
export function buildSchool54Sql(
  snapshot,
  {
    targetProjectRef,
    apply = false,
    planChecksum,
    migrationVersions = migrationVersionsFromFilenames(
      readdirSync(resolve("supabase/migrations")),
    ),
  } = {},
) {
  if (targetProjectRef !== STAGING) fail("EXACT_STAGING_REQUIRED");
  if (apply && !SHA256.test(planChecksum ?? "")) fail("REVIEWED_PLAN_REQUIRED");
  const contentChecksum = school54ContentChecksum(snapshot);
  if (
    migrationVersions.length !== 138 ||
    migrationVersions.at(-1) !== "20261105090000"
  )
    fail("REPOSITORY_MIGRATION_DRIFT");
  const encode = (value) =>
    `convert_from(decode('${Buffer.from(JSON.stringify(value)).toString("base64")}','base64'),'UTF8')::jsonb`;
  return `set statement_timeout='2min';\nset lock_timeout='15s';\n${readFileSync(new URL("../supabase/packages/atlas-staging-school54.sql", import.meta.url), "utf8")}\n${apply ? "begin;" : "begin read only;"}\nselect pg_temp.run_staging_school54(${encode(snapshot)},${encode(migrationVersions)},${apply ? "true" : "false"},${apply ? `'${planChecksum}'` : "null"},'${contentChecksum}') as result;\ncommit;`;
}
async function schoolReadSession(authority, environment, fetchImpl) {
  const { publishableKey, testEmail, testPassword } =
    validateAtlasStagingProtectedValues(environment);
  const base = authority.targetSupabaseUrl;
  const request = async (path, options, json = true) => {
    try {
      const r = await fetchImpl(base + path, {
        ...options,
        redirect: "error",
        signal: AbortSignal.timeout(45000),
      });
      if (!r.ok) fail("AUTH_REQUEST_FAILED");
      return json ? await r.json() : null;
    } catch {
      fail("AUTH_REQUEST_FAILED");
    }
  };
  const login = await request("/auth/v1/token?grant_type=password", {
    method: "POST",
    headers: { apikey: publishableKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email: testEmail, password: testPassword }),
  });
  if (
    typeof login?.access_token !== "string" ||
    !login.access_token ||
    !login.user?.id
  )
    fail("AUTH_SIGNIN_FAILED");
  const headers = {
    apikey: publishableKey,
    Authorization: `Bearer ${login.access_token}`,
    "Content-Type": "application/json",
  };
  return {
    async read() {
      const user = await request("/auth/v1/user", { headers });
      if (
        user.id !== login.user.id ||
        user.email?.toLowerCase() !== testEmail.toLowerCase()
      )
        fail("AUTH_SUBJECT_MISMATCH");
      const result = await request("/rest/v1/rpc/get_school_master_data", {
        method: "POST",
        headers: { ...headers, "Content-Profile": "atlas_api" },
        body: JSON.stringify({
          request: {
            contract_version: "RMVP-01.v1",
            requested_by_auth_subject: user.id,
            correlation_id: randomUUID(),
            payload: {},
          },
        }),
      });
      if (result?.success !== true || !Array.isArray(result.schools))
        fail("AUTH_READ_DENIED");
      return result.schools;
    },
    signOut: () =>
      request(
        "/auth/v1/logout?scope=local",
        { method: "POST", headers },
        false,
      ),
  };
}
export async function runSchool54Backfill({
  commitSha,
  apply = false,
  planChecksum,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  verifyCertification = verifyExactHeadCertification,
  extractSnapshot = extractOpsV1MasterSnapshot,
  executeTarget,
  createReadSession = schoolReadSession,
  fetchImpl = fetch,
} = {}) {
  if (apply && !SHA256.test(planChecksum ?? "")) fail("REVIEWED_PLAN_REQUIRED");
  if (!apply && planChecksum !== undefined) fail("PLAN_APPLY_ONLY");
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  validateAtlasStagingProtectedValues(environment);
  await verifyCheckout({ commitSha, cwd });
  await verifyCertification({
    commitSha,
    certificationMode: "github",
    environment,
    cwd,
  });
  const snapshot = await extractSnapshot({
    projectRef: SOURCE,
    accessToken: authority.targetAccessToken,
    snapshotId: `school54-${environment.GITHUB_RUN_ID ?? Date.now()}`,
    extractorVersion: commitSha,
    fetchImpl,
  });
  const contentChecksum = school54ContentChecksum(snapshot),
    target = { projectRef: STAGING, supabaseUrl: authority.targetSupabaseUrl };
  const execute =
    executeTarget ??
    ((t, sql) => executeAtlasStagingPostgres(t, sql, { environment, cwd }));
  const call = async (requestedApply) => {
    const result = parseStagingMasterResult(
      await execute(
        target,
        buildSchool54Sql(snapshot, {
          targetProjectRef: STAGING,
          apply: requestedApply,
          planChecksum,
          migrationVersions: migrationVersionsFromFilenames(
            readdirSync(resolve(cwd, "supabase/migrations")),
          ),
        }),
      ),
    );
    if (result?.success !== true)
      fail(
        /^[A-Z0-9_]+$/.test(result?.error_code ?? "")
          ? result.error_code
          : "TARGET_REJECTED",
      );
    if (
      result.content_checksum !== contentChecksum ||
      !SHA256.test(result.plan_checksum ?? "")
    )
      fail("TARGET_RESULT_DRIFT");
    return result;
  };
  let session, primary;
  try {
    session = await createReadSession(authority, environment, fetchImpl);
    const before = await session.read();
    await verifyCheckout({ commitSha, cwd });
    const preview = await call(false);
    if (!apply) return preview;
    if (preview.status !== "PREVIEW" || preview.plan_checksum !== planChecksum)
      fail("REVIEWED_PLAN_CHANGED");
    await verifyCheckout({ commitSha, cwd });
    const applied = await call(true);
    if (
      applied.status !== "APPLIED" ||
      applied.reconciled !== true ||
      applied.protected_unchanged !== true ||
      applied.plan_checksum !== planChecksum
    )
      fail("APPLY_READBACK_DRIFT");
    const replay = await call(true);
    if (
      replay.status !== "REPLAYED" ||
      canonicalMasterJson({ ...replay, status: "APPLIED" }) !==
        canonicalMasterJson(applied)
    )
      fail("REPLAY_DRIFT");
    const after = await session.read(),
      rows = after.filter((r) => r.school_code === "v1-school-54");
    if (
      rows.length !== 1 ||
      rows[0].school_id !== applied.root_ids.school_id ||
      Object.entries(applied.school).some(
        ([k, v]) => canonicalMasterJson(rows[0][k]) !== canonicalMasterJson(v),
      ) ||
      canonicalMasterJson(
        after.filter((r) => r.school_code !== "v1-school-54"),
      ) !==
        canonicalMasterJson(
          before.filter((r) => r.school_code !== "v1-school-54"),
        )
    )
      fail("AUTH_READBACK_DRIFT");
    return {
      ...applied,
      replay_status: replay.status,
      authenticated_readback: "PASS",
    };
  } catch (error) {
    primary = error;
    throw error;
  } finally {
    if (session)
      try {
        await session.signOut();
      } catch (error) {
        if (!primary) throw error;
      }
  }
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const main = async () => {
    const flags = new Map(),
      args = process.argv.slice(2);
    for (let i = 0; i < args.length; i++) {
      const key = args[i];
      if (
        flags.has(key) ||
        ![
          "--commit-sha",
          "--apply",
          "--plan-checksum",
          "--target-project-ref",
        ].includes(key)
      )
        fail("INVALID_ARGUMENT");
      if (key === "--apply") flags.set(key, true);
      else {
        const value = args[++i];
        if (!value || value.startsWith("--")) fail("INVALID_ARGUMENT");
        flags.set(key, value);
      }
    }
    console.log(
      JSON.stringify(
        await runSchool54Backfill({
          commitSha: flags.get("--commit-sha"),
          apply: flags.has("--apply"),
          planChecksum: flags.get("--plan-checksum"),
          targetConfirmation: flags.get("--target-project-ref"),
        }),
        null,
        2,
      ),
    );
  };
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error ? error.message : "SCHOOL54_FAILED",
        [
          process.env.ATLAS_STAGING_TEST_PASSWORD,
          process.env.ATLAS_STAGING_DB_PASSWORD,
          process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN,
        ].filter(Boolean),
      ),
    );
    process.exitCode = 1;
  });
}
