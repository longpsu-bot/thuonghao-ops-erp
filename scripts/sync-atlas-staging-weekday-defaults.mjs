import { createHash, randomUUID } from "node:crypto";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { canonicalMasterJson } from "./ops-v1-master-snapshot-contract.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import {
  validateAtlasStagingProtectedValues,
  verifyExactHeadCertification,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";

const SOURCE = "qnthofvccilhnefdcxnz";
const CONTRACT = "ATLAS-STAGING-WEEKDAY-DEFAULT-SYNC.v1";
const SHA256 = /^[a-f0-9]{64}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAYS = ["1", "2", "3", "4", "5"];
const count = (value) =>
  Number.isInteger(value) && value >= 0 && value <= 2147483647;
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const hash = (value) =>
  createHash("sha256").update(canonicalMasterJson(value)).digest("hex");
const same = (left, right) =>
  canonicalMasterJson(left) === canonicalMasterJson(right);
function fail(code) {
  throw Error(`WEEKDAY_SYNC_${code}`);
}

function sourceConfigs(rows) {
  if (!Array.isArray(rows)) fail("SOURCE_ROWS_INVALID");
  const ids = new Set(),
    configured = [];
  for (const row of rows) {
    if (
      !/^[1-9]\d*$/.test(row?.id) ||
      typeof row.id !== "string" ||
      ids.has(row.id) ||
      typeof row.is_active !== "boolean"
    )
      fail("SOURCE_ROW_INVALID");
    ids.add(row.id);
    const weekdays = {};
    for (const [sourceField, field] of [
      ["default_students_weekday", "student_portions"],
      ["default_teachers_weekday", "teacher_portions"],
    ]) {
      const values = row[sourceField];
      if (values === null) continue;
      if (
        !Array.isArray(values) ||
        values.length !== 5 ||
        values.some((value) => value !== null && !count(value))
      )
        fail("SOURCE_ARRAY_INVALID");
      values.forEach((value, index) => {
        if (value !== null) (weekdays[DAYS[index]] ??= {})[field] = value;
      });
    }
    if (Object.keys(weekdays).length) {
      if (!row.is_active) fail("SOURCE_CONFIGURED_SCHOOL_INACTIVE");
      configured.push({
        id: row.id,
        is_active: true,
        weekday_portion_defaults: weekdays,
      });
    }
  }
  // This manual 5 November 2026 scope must be reviewed again if it grows or shrinks.
  if (configured.length !== 34) fail("SOURCE_CONFIGURED_SCOPE_DRIFT");
  return configured.sort((left, right) =>
    left.id.localeCompare(right.id, "en"),
  );
}

function validateTargetWeekdays(value) {
  if (!object(value)) fail("TARGET_WEEKDAY_SCHEMA_REQUIRED");
  for (const [day, portions] of Object.entries(value)) {
    if (
      !DAYS.includes(day) ||
      !object(portions) ||
      Object.entries(portions).some(
        ([key, amount]) =>
          !["student_portions", "teacher_portions"].includes(key) ||
          !count(amount),
      )
    )
      fail("TARGET_WEEKDAY_INVALID");
  }
}

export function buildWeekdaySyncPlan(sourceRows, schools) {
  const configs = sourceConfigs(sourceRows);
  if (!Array.isArray(schools)) fail("TARGET_ROWS_INVALID");
  const ids = schools.map((school) => school?.school_id);
  if (ids.some((id) => !UUID.test(id)) || new Set(ids).size !== ids.length)
    fail("TARGET_IDENTITIES_INVALID");
  const expected = [],
    changes = [];
  for (const source of configs) {
    const mapped = schools.filter(
      (school) => school.school_code === `v1-school-${source.id}`,
    );
    if (mapped.length !== 1 || mapped[0].school_status !== "ACTIVE")
      fail("TARGET_SCHOOL_MAPPING_INVALID");
    const school = mapped[0];
    if (
      !Number.isSafeInteger(school.version) ||
      school.version <= 0 ||
      !count(school.default_student_portions) ||
      !count(school.default_teacher_portions)
    )
      fail("TARGET_SCHOOL_FACTS_INVALID");
    validateTargetWeekdays(school.weekday_portion_defaults);
    expected.push({
      school_id: school.school_id,
      school_code: school.school_code,
      school_status: school.school_status,
      version: school.version,
      default_student_portions: school.default_student_portions,
      default_teacher_portions: school.default_teacher_portions,
      weekday_portion_defaults: school.weekday_portion_defaults,
    });
    if (!same(source.weekday_portion_defaults, school.weekday_portion_defaults))
      changes.push({
        school_id: school.school_id,
        expected_version: school.version,
        default_student_portions: school.default_student_portions,
        default_teacher_portions: school.default_teacher_portions,
        weekday_portion_defaults: source.weekday_portion_defaults,
      });
  }
  return {
    configured_count: configs.length,
    changes,
    source_checksum: hash(configs),
    target_checksum: hash(expected),
    plan_checksum: hash({
      contract_version: CONTRACT,
      source_project_ref: SOURCE,
      source: configs,
      expected,
    }),
  };
}

const SOURCE_SQL = `select jsonb_build_object(
'source_project_ref','${SOURCE}',
'source_access',(select jsonb_build_object('role_name',r.rolname,'superuser',r.rolsuper,
'create_role',r.rolcreaterole,'create_db',r.rolcreatedb,
'has_select',pg_catalog.has_table_privilege(r.oid,'public.schools','SELECT'),
'has_non_select',pg_catalog.has_table_privilege(r.oid,'public.schools','INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
 or pg_catalog.has_any_column_privilege(r.oid,'public.schools','INSERT,UPDATE,REFERENCES'))
from pg_catalog.pg_roles r where r.rolname=current_user),
'schools',(select coalesce(jsonb_agg(to_jsonb(s) order by s.id),'[]'::jsonb)
from (select id::text,is_active,default_students_weekday,default_teachers_weekday from public.schools) s)
) as snapshot;`;

async function jsonRequest(fetchImpl, url, options, failure) {
  try {
    const response = await fetchImpl(url, {
      ...options,
      redirect: "error",
      signal: AbortSignal.timeout(45_000),
    });
    if (!response.ok) fail(failure);
    return await response.json();
  } catch {
    fail(failure);
  }
}

export async function extractWeekdaySource({
  accessToken,
  fetchImpl = fetch,
} = {}) {
  if (!accessToken) fail("SOURCE_TOKEN_REQUIRED");
  const output = await jsonRequest(
    fetchImpl,
    `https://api.supabase.com/v1/projects/${SOURCE}/database/query/read-only`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ query: SOURCE_SQL }),
    },
    "SOURCE_READ_FAILED",
  );
  const raw =
    Array.isArray(output) && output.length === 1 ? output[0]?.snapshot : null;
  const access = raw?.source_access;
  if (
    raw?.source_project_ref !== SOURCE ||
    access?.role_name !== "supabase_read_only_user" ||
    access.superuser !== false ||
    access.create_role !== false ||
    access.create_db !== false ||
    access.has_select !== true ||
    access.has_non_select !== false
  )
    fail("SOURCE_READ_ONLY_PROOF_INVALID");
  sourceConfigs(raw.schools);
  return raw.schools;
}

function verifyReadback(before, after, changes) {
  if (!Array.isArray(after) || before.length !== after.length)
    fail("APPLY_READBACK_DRIFT");
  const updates = new Map(changes.map((change) => [change.school_id, change]));
  const seen = new Set();
  for (const school of before) {
    const matches = after.filter((row) => row.school_id === school.school_id);
    const change = updates.get(school.school_id);
    if (
      matches.length !== 1 ||
      seen.has(school.school_id) ||
      !same(
        matches[0],
        change
          ? {
              ...school,
              version: school.version + 1,
              weekday_portion_defaults: change.weekday_portion_defaults,
            }
          : school,
      )
    )
      fail("APPLY_READBACK_DRIFT");
    seen.add(school.school_id);
  }
}

export async function runWeekdayDefaultSync({
  commitSha,
  apply = false,
  planChecksum,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  verifyCertification = verifyExactHeadCertification,
  fetchImpl = fetch,
} = {}) {
  if (apply && !SHA256.test(planChecksum ?? "")) fail("REVIEWED_PLAN_REQUIRED");
  if (!apply && planChecksum !== undefined) fail("PLAN_CHECKSUM_APPLY_ONLY");
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  const protectedValues = validateAtlasStagingProtectedValues(environment, {
    requireDatabasePassword: false,
  });
  await verifyCheckout({ commitSha, cwd });
  await verifyCertification({
    commitSha,
    certificationMode: "github",
    environment,
    cwd,
  });
  const source = await extractWeekdaySource({
    accessToken: authority.targetAccessToken,
    fetchImpl,
  });
  const base = authority.targetSupabaseUrl;
  const login = await jsonRequest(
    fetchImpl,
    `${base}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: {
        apikey: protectedValues.publishableKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: protectedValues.testEmail,
        password: protectedValues.testPassword,
      }),
    },
    "AUTH_SIGNIN_FAILED",
  );
  if (typeof login?.access_token !== "string" || !login.access_token)
    fail("AUTH_SIGNIN_FAILED");
  const headers = {
    apikey: protectedValues.publishableKey,
    Authorization: `Bearer ${login.access_token}`,
    "Content-Type": "application/json",
  };
  let primaryFailure;
  try {
    const user = await jsonRequest(
      fetchImpl,
      `${base}/auth/v1/user`,
      { headers },
      "AUTH_USER_FAILED",
    );
    if (
      !UUID.test(user?.id) ||
      user.id !== login.user?.id ||
      user.email?.toLowerCase() !== protectedValues.testEmail.toLowerCase()
    )
      fail("AUTH_SUBJECT_MISMATCH");
    const correlationId = randomUUID();
    const rpc = (name, request, failure) =>
      jsonRequest(
        fetchImpl,
        `${base}/rest/v1/rpc/${name}`,
        {
          method: "POST",
          headers: { ...headers, "Content-Profile": "atlas_api" },
          body: JSON.stringify({ request }),
        },
        failure,
      );
    const read = async () => {
      const result = await rpc(
        "get_school_master_data",
        {
          contract_version: "RMVP-01.v1",
          requested_by_auth_subject: user.id,
          correlation_id: correlationId,
          payload: {},
        },
        "AUTHENTICATED_SCHOOL_READ_FAILED",
      );
      if (result?.success !== true || !Array.isArray(result.schools))
        fail("AUTHENTICATED_SCHOOL_READ_FAILED");
      return result.schools;
    };
    const before = await read();
    const plan = buildWeekdaySyncPlan(source, before);
    const summary = {
      contract_version: CONTRACT,
      configured_count: plan.configured_count,
      update_count: plan.changes.length,
      no_change_count: plan.configured_count - plan.changes.length,
      source_checksum: plan.source_checksum,
      target_checksum: plan.target_checksum,
      plan_checksum: plan.plan_checksum,
    };
    if (!apply) return { status: "PREVIEW", ...summary };
    if (planChecksum !== plan.plan_checksum) fail("REVIEWED_PLAN_DRIFT");
    await verifyCheckout({ commitSha, cwd });
    await verifyCertification({
      commitSha,
      certificationMode: "github",
      environment,
      cwd,
    });
    const freshSource = await extractWeekdaySource({
      accessToken: authority.targetAccessToken,
      fetchImpl,
    });
    const fresh = await read();
    if (
      buildWeekdaySyncPlan(freshSource, fresh).plan_checksum !== planChecksum ||
      !same(
        [...before].sort((a, b) => a.school_id.localeCompare(b.school_id)),
        [...fresh].sort((a, b) => a.school_id.localeCompare(b.school_id)),
      )
    )
      fail("FRESH_PLAN_DRIFT");
    if (!plan.changes.length) return { status: "NO_CHANGE", ...summary };
    const commandId = randomUUID();
    const request = {
      contract_version: "RMVP-01.v2",
      command_id: commandId,
      correlation_id: correlationId,
      idempotency_key: `weekday-default-sync:${commandId}`,
      requested_by_auth_subject: user.id,
      requested_at: new Date().toISOString(),
      reason_code: "OPS_V1_WEEKDAY_DEFAULT_SYNC",
      reason_note: `Reviewed ${CONTRACT} plan ${planChecksum}`,
      payload: { changes: plan.changes },
    };
    const applied = await rpc(
      "update_school_portion_defaults_bulk",
      request,
      "APPLY_OUTCOME_UNKNOWN",
    );
    if (
      applied?.success !== true ||
      applied.command_id !== commandId ||
      applied.correlation_id !== correlationId
    )
      fail("APPLY_COMMAND_REJECTED");
    // Verify the receipt only after known success; never retry an unknown command outcome.
    const replay = await rpc(
      "update_school_portion_defaults_bulk",
      request,
      "REPLAY_OUTCOME_UNKNOWN",
    );
    if (!same(applied, replay)) fail("REPLAY_DRIFT");
    verifyReadback(before, await read(), plan.changes);
    return {
      status: "APPLIED",
      ...summary,
      replay_verified: true,
      readback_verified: true,
    };
  } catch (error) {
    primaryFailure = error;
    throw error;
  } finally {
    try {
      const logout = await fetchImpl(`${base}/auth/v1/logout?scope=local`, {
        method: "POST",
        headers,
        redirect: "error",
        signal: AbortSignal.timeout(15_000),
      });
      if (!logout.ok) fail("AUTH_SIGNOUT_FAILED");
    } catch {
      if (!primaryFailure) fail("AUTH_SIGNOUT_FAILED");
    }
  }
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const args = process.argv.slice(2),
      flags = new Map();
    for (let index = 0; index < args.length; index++) {
      const key = args[index];
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
        if (!args[index + 1] || args[index + 1].startsWith("--"))
          fail("INVALID_ARGUMENT");
        flags.set(key, args[++index]);
      }
    }
    console.log(
      JSON.stringify(
        await runWeekdayDefaultSync({
          commitSha: flags.get("--commit-sha"),
          apply: flags.has("--apply"),
          planChecksum: flags.get("--plan-checksum"),
          targetConfirmation: flags.get("--target-project-ref"),
        }),
        null,
        2,
      ),
    );
  } catch (error) {
    console.error(
      redactAtlasStagingDiagnostic(
        error.message,
        [
          process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN,
          process.env.ATLAS_STAGING_TEST_PASSWORD,
        ].filter(Boolean),
      ),
    );
    process.exitCode = 1;
  }
}
