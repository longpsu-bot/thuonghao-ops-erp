import { randomUUID } from "node:crypto";
import { readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildSchoolDocumentConfiguration } from "./atlas-document-school-configuration.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIP = "20261010102603";
const schoolReadbackFields = [
  "school_id",
  "school_code",
  "school_name",
  "display_order",
  "cooking_location_id",
  "cooking_location_name",
  "cooking_location_kind",
  "cooking_location_host_school_id",
  "dispatch_group_id",
  "dispatch_group_name",
];
const validVersion = (value) => Number.isSafeInteger(value) && value > 0;
function fail(code) {
  throw new Error(code);
}
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, item]) => [key, canonical(item)]),
    );
  return value;
}
function same(left, right) {
  return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right));
}
function ordered(rows, key) {
  return [...rows].sort((a, b) => a[key].localeCompare(b[key]));
}
function sameState(left, right) {
  return ["schools", "cooking_groups", "dispatch_groups"].every((key) =>
    same(
      ordered(
        left[key],
        {
          schools: "school_id",
          cooking_groups: "cooking_group_id",
          dispatch_groups: "dispatch_group_id",
        }[key],
      ),
      ordered(
        right[key],
        {
          schools: "school_id",
          cooking_groups: "cooking_group_id",
          dispatch_groups: "dispatch_group_id",
        }[key],
      ),
    ),
  );
}
export function repositorySchoolConfigurationMigrationVersions(
  cwd = process.cwd(),
) {
  return readdirSync(resolve(cwd, "supabase/migrations"))
    .filter((file) => /^\d{14}_.+\.sql$/.test(file))
    .map((file) => file.slice(0, 14))
    .sort();
}
export function verifySchoolConfigurationMigrationParity(
  hostedVersions,
  repositoryVersions,
) {
  if (
    !Array.isArray(hostedVersions) ||
    !Array.isArray(repositoryVersions) ||
    hostedVersions.length !== 98 ||
    repositoryVersions.length !== 98 ||
    new Set(hostedVersions).size !== 98 ||
    new Set(repositoryVersions).size !== 98 ||
    hostedVersions.some((v) => typeof v !== "string" || !/^\d{14}$/.test(v)) ||
    [...hostedVersions].sort().at(-1) !== TIP ||
    !same([...hostedVersions].sort(), [...repositoryVersions].sort())
  )
    fail("SCHOOL_CONFIGURATION_MIGRATION_PARITY_REQUIRED");
}
function validateState(state) {
  for (const [key, idKey, nameKey] of [
    ["cooking_groups", "cooking_group_id", "cooking_group_name"],
    ["dispatch_groups", "dispatch_group_id", "dispatch_group_name"],
  ]) {
    if (
      !Array.isArray(state[key]) ||
      new Set(state[key].map((g) => g[idKey])).size !== state[key].length ||
      state[key].some(
        (g) =>
          !UUID.test(g[idKey]) ||
          typeof g[nameKey] !== "string" ||
          typeof g.active !== "boolean" ||
          !validVersion(g.version),
      )
    )
      fail("SCHOOL_GROUP_READ_CONTRACT_INVALID");
  }
  if (!Array.isArray(state.schools)) fail("SCHOOL_READ_CONTRACT_INVALID");
  for (const school of state.schools) {
    if (
      schoolReadbackFields.some((key) => !Object.hasOwn(school, key)) ||
      !validVersion(school.version) ||
      typeof school.school_status !== "string"
    )
      fail("SCHOOL_READ_CONTRACT_INVALID");
    const cooking = state.cooking_groups.find(
      (g) => g.cooking_group_id === school.cooking_location_id,
    );
    const dispatch = state.dispatch_groups.find(
      (g) => g.dispatch_group_id === school.dispatch_group_id,
    );
    if (
      school.cooking_group_id !== school.cooking_location_id ||
      school.cooking_group_name !== school.cooking_location_name ||
      (school.cooking_location_id === null
        ? [
            school.cooking_location_name,
            school.cooking_location_kind,
            school.cooking_location_host_school_id,
          ].some((v) => v !== null)
        : !cooking ||
          school.cooking_location_name !== cooking.cooking_group_name ||
          school.cooking_location_kind !== cooking.location_kind ||
          school.cooking_location_host_school_id !== cooking.host_school_id) ||
      (school.dispatch_group_id === null
        ? school.dispatch_group_name !== null
        : !dispatch ||
          school.dispatch_group_name !== dispatch.dispatch_group_name)
    )
      fail("SCHOOL_RELATIONSHIP_READ_CONTRACT_INVALID");
  }
}

// All reuse/conflict checks run before the first command. Names select candidate
// groups only; School identity is resolved exclusively by the typed-ID builder.
export function preflightSchoolConfiguration(state, mappings) {
  validateState(state);
  const configuration = buildSchoolDocumentConfiguration({
    schools: state.schools,
    mappings,
  });
  if (
    !same(
      [...state.schools]
        .sort((a, b) => a.display_order - b.display_order)
        .map((school) => school.school_id),
      configuration.target_school_order_ids,
    )
  )
    fail("SCHOOL_MASTER_RECONCILIATION_REQUIRED:DISPLAY_ORDER");
  const groups = [];
  for (const [prefix, desired] of [
    ["cooking", configuration.cooking_locations],
    ["dispatch", configuration.dispatch_groups],
  ]) {
    for (const spec of desired) {
      const name =
        prefix === "cooking" ? spec.display_name : spec.dispatch_group_name;
      const candidates = state[`${prefix}_groups`].filter(
        (g) => g[`${prefix}_group_name`] === name,
      );
      if (candidates.length > 1) fail("SCHOOL_GROUP_CONFLICT:DUPLICATE_NAME");
      const existing = candidates[0];
      if (
        existing &&
        (!existing.active ||
          (prefix === "cooking" &&
            (existing.location_kind !== spec.location_kind ||
              existing.host_school_id !== spec.host_school_id)))
      )
        fail("SCHOOL_GROUP_CONFLICT:CANONICAL_FACTS");
      if (existing) {
        const members = state.schools
          .filter(
            (s) => s[`${prefix}_group_id`] === existing[`${prefix}_group_id`],
          )
          .map((s) => s.school_id)
          .sort();
        if (!same(members, [...spec.school_ids].sort()))
          fail("SCHOOL_GROUP_CONFLICT:EXACT_MEMBERSHIP_REQUIRED");
      }
      for (const id of spec.school_ids) {
        const school = state.schools.find((s) => s.school_id === id);
        if (school.school_status !== "ACTIVE")
          fail("SCHOOL_GROUP_CONFLICT:SCHOOL_INACTIVE");
        if (
          school[`${prefix}_group_id`] !== null &&
          school[`${prefix}_group_id`] !== existing?.[`${prefix}_group_id`]
        )
          fail("SCHOOL_GROUP_CONFLICT:EXISTING_ASSIGNMENT");
      }
      groups.push({
        prefix,
        name,
        spec,
        group_id: existing?.[`${prefix}_group_id`] ?? null,
      });
    }
  }
  // Owner's explicit independent example and PH3 exclusion; no order command.
  const lvt = configuration.cooking_locations[0].school_ids[1];
  return {
    configuration,
    groups,
    clearDispatchSchoolIds: [
      ...configuration.excluded_dispatch_school_ids,
      lvt,
    ],
  };
}

export async function runAtlasStagingSchoolConfiguration({
  commitSha,
  apply = false,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  executeTarget,
  fetchImpl = fetch,
  readRepositoryVersions = repositorySchoolConfigurationMigrationVersions,
  uuid = randomUUID,
  now = () => new Date().toISOString(),
  onCommand = () => {},
} = {}) {
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  const key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (
    !key ||
    !environment.ATLAS_STAGING_TEST_EMAIL ||
    !environment.ATLAS_STAGING_TEST_PASSWORD
  )
    fail("SCHOOL_CONFIGURATION_CREDENTIAL_MISSING");
  // Reject privileged key substitution before authentication.
  if (!String(key).startsWith("sb_publishable_"))
    fail("SCHOOL_CONFIGURATION_PUBLISHABLE_KEY_REQUIRED");
  await verifyCheckout({ commitSha, cwd });
  const target = {
    projectRef: authority.targetProjectRef,
    supabaseUrl: authority.targetSupabaseUrl,
    accessToken: authority.targetAccessToken,
  };
  const execute =
    executeTarget ??
    ((t, sql) => executeAtlasStagingPostgres(t, sql, { environment, cwd }));
  const readSql = async (sql) =>
    parseStagingMasterResult(await execute(target, sql));
  const hosted = await readSql(
    "select jsonb_build_object('versions',coalesce(jsonb_agg(version order by version),'[]'::jsonb)) as result from supabase_migrations.schema_migrations;",
  );
  verifySchoolConfigurationMigrationParity(
    hosted.versions,
    readRepositoryVersions(cwd),
  );
  const { mappings } = await readSql(
    "select jsonb_build_object('mappings',coalesce(jsonb_agg(jsonb_build_object('source_system',source_system,'object_type',object_type,'legacy_id',legacy_id,'school_id',school_id) order by legacy_id),'[]'::jsonb)) as result from atlas_legacy.master_data_mappings where source_system='OPS_V1' and object_type='SCHOOL';",
  );
  let session;
  try {
    const login = await fetchImpl(
      `${target.supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        redirect: "error",
        headers: { apikey: key, "Content-Type": "application/json" },
        body: JSON.stringify({
          email: environment.ATLAS_STAGING_TEST_EMAIL,
          password: environment.ATLAS_STAGING_TEST_PASSWORD,
        }),
      },
    );
    session = await login.json();
    if (
      !login.ok ||
      typeof session.access_token !== "string" ||
      !session.access_token ||
      !UUID.test(session.user?.id)
    )
      fail("SCHOOL_CONFIGURATION_SIGNIN_FAILED");
  } catch {
    fail("SCHOOL_CONFIGURATION_SIGNIN_FAILED");
  }
  const commandIdentities = [];
  const invoke = async (name, request, command = false) => {
    let body, response;
    const uncertain = () =>
      fail(
        `SCHOOL_COMMAND_OUTCOME_UNCERTAIN:${name}:${request.command_id}:${request.correlation_id}:${request.idempotency_key}`,
      );
    try {
      response = await fetchImpl(`${target.supabaseUrl}/rest/v1/rpc/${name}`, {
        method: "POST",
        redirect: "error",
        headers: {
          apikey: key,
          Authorization: `Bearer ${session.access_token}`,
          "Content-Type": "application/json",
          "Content-Profile": "atlas_api",
        },
        body: JSON.stringify({ request }),
      });
      body = await response.json();
    } catch {
      if (command) uncertain();
      fail(`SCHOOL_CONFIGURATION_READ_FAILED:${name}`);
    }
    if (!response.ok) {
      if (command) uncertain();
      fail(`SCHOOL_CONFIGURATION_READ_FAILED:${name}`);
    }
    if (body?.success !== true) {
      if (command && body?.success !== false) uncertain();
      fail(
        `SCHOOL_CONFIGURATION_API_REJECTED:${name}:${/^[A-Z_]+$/.test(body?.error_code ?? "") ? body.error_code : "INVALID_RESPONSE"}`,
      );
    }
    if (body.contract_version !== "RMVP-01.v1") {
      if (command) uncertain();
      fail("SCHOOL_CONFIGURATION_API_CONTRACT_INVALID");
    }
    if (
      command &&
      (body.command_id !== request.command_id ||
        body.correlation_id !== request.correlation_id ||
        !validVersion(body.new_versions?.aggregate_version))
    )
      uncertain();
    return body;
  };
  const read = async (name, keyName) => {
    const body = await invoke(name, {
      contract_version: "RMVP-01.v1",
      requested_by_auth_subject: session.user.id,
      correlation_id: uuid(),
      payload: {},
    });
    if (!Array.isArray(body[keyName]))
      fail("SCHOOL_CONFIGURATION_API_CONTRACT_INVALID");
    return body[keyName];
  };
  const readState = async () => {
    const state = {
      schools: await read("get_school_master_data", "schools"),
      cooking_groups: await read("get_cooking_groups", "cooking_groups"),
      dispatch_groups: await read("get_dispatch_groups", "dispatch_groups"),
    };
    validateState(state);
    return state;
  };
  let state = await readState();
  const plan = preflightSchoolConfiguration(state, mappings);
  const baseline = structuredClone(state);
  const summary = () => ({
    schools: state.schools.map((s) =>
      Object.fromEntries(schoolReadbackFields.map((k) => [k, s[k]])),
    ),
    command_identities: commandIdentities,
  });
  if (!apply)
    return {
      status: "SCHOOL_CONFIGURATION_PREVIEW",
      groups: plan.groups.map((g) => ({
        kind: g.prefix,
        group_id: g.group_id,
        school_ids: g.spec.school_ids,
      })),
      clear_dispatch_school_ids: plan.clearDispatchSchoolIds,
      ...summary(),
    };
  const command = async (name, reason, payload, expectedVersion, project) => {
    const before = await readState();
    if (!sameState(before, state))
      fail("SCHOOL_CONFIGURATION_STATE_CHANGED_BEFORE_COMMAND");
    const request = {
      contract_version: "RMVP-01.v1",
      command_id: uuid(),
      correlation_id: uuid(),
      idempotency_key: uuid(),
      expected_version: expectedVersion,
      requested_by_auth_subject: session.user.id,
      requested_at: now(),
      reason_code: reason,
      reason_note: "Owner-approved Atlas Staging School configuration",
      payload,
    };
    const identity = {
      function_name: name,
      command_id: request.command_id,
      correlation_id: request.correlation_id,
      idempotency_key: request.idempotency_key,
    };
    // Emit identities before transport; never emit the envelope or session.
    await onCommand(identity);
    commandIdentities.push(identity);
    const result = await invoke(name, request, true);
    const expected = structuredClone(state);
    project(expected, result);
    const after = await readState();
    if (!sameState(after, expected))
      fail(
        `SCHOOL_CONFIGURATION_READBACK_FAILED:${name}:${request.command_id}`,
      );
    state = after;
    return result;
  };
  const assign = async (prefix, schoolId, groupId) => {
    const school = state.schools.find((s) => s.school_id === schoolId);
    if (school[`${prefix}_group_id`] === groupId) return;
    await command(
      `set_school_${prefix}_group`,
      prefix === "cooking"
        ? "SCHOOL_COOKING_GROUP_SET"
        : "SCHOOL_DISPATCH_GROUP_SET",
      { school_id: schoolId, [`${prefix}_group_id`]: groupId },
      school.version,
      (expected, result) => {
        if (
          result.affected_aggregate_ids?.school_id !== schoolId ||
          result.new_versions.aggregate_version !== school.version + 1
        )
          fail("SCHOOL_COMMAND_RESULT_IDENTITY_INVALID");
        const row = expected.schools.find((s) => s.school_id === schoolId);
        const group = expected[`${prefix}_groups`].find(
          (g) => g[`${prefix}_group_id`] === groupId,
        );
        row.version = result.new_versions.aggregate_version;
        row[`${prefix}_group_id`] = groupId;
        row[`${prefix}_group_name`] = group?.[`${prefix}_group_name`] ?? null;
        if (prefix === "cooking")
          Object.assign(row, {
            cooking_location_id: groupId,
            cooking_location_name: group?.cooking_group_name ?? null,
            cooking_location_kind: group?.location_kind ?? null,
            cooking_location_host_school_id: group?.host_school_id ?? null,
          });
      },
    );
  };
  for (const group of plan.groups) {
    if (group.group_id === null) {
      const { prefix } = group;
      const payload = {
        [`${prefix}_group_id`]: null,
        [`${prefix}_group_name`]: group.name,
        active: true,
        ...(prefix === "cooking"
          ? {
              location_kind: group.spec.location_kind,
              host_school_id: group.spec.host_school_id,
            }
          : {}),
      };
      await command(
        `upsert_${prefix}_group`,
        prefix === "cooking" ? "COOKING_GROUP_SAVED" : "DISPATCH_GROUP_SAVED",
        payload,
        1,
        (expected, result) => {
          const id = result.affected_aggregate_ids?.[`${prefix}_group_id`];
          if (
            !UUID.test(id) ||
            result.new_versions.aggregate_version !== 1 ||
            expected[`${prefix}_groups`].some(
              (g) => g[`${prefix}_group_id`] === id,
            )
          )
            fail("SCHOOL_COMMAND_RESULT_IDENTITY_INVALID");
          group.group_id = id;
          expected[`${prefix}_groups`].push({
            ...payload,
            [`${prefix}_group_id`]: id,
            version: 1,
          });
        },
      );
    }
    for (const id of group.spec.school_ids)
      await assign(group.prefix, id, group.group_id);
  }
  for (const id of plan.clearDispatchSchoolIds)
    await assign("dispatch", id, null);
  const final = await readState();
  if (!sameState(final, state))
    fail("SCHOOL_CONFIGURATION_FINAL_READBACK_FAILED");
  preflightSchoolConfiguration(final, mappings);
  for (const original of baseline.schools) {
    const current = final.schools.find(
      (s) => s.school_id === original.school_id,
    );
    if (
      !current ||
      ["school_id", "school_code", "school_name", "display_order"].some(
        (key) => !same(original[key], current[key]),
      )
    )
      fail("SCHOOL_CONFIGURATION_IDENTITY_OR_ORDER_CHANGED");
  }
  for (const id of plan.clearDispatchSchoolIds)
    if (
      final.schools.find((s) => s.school_id === id).dispatch_group_id !== null
    )
      fail("SCHOOL_CONFIGURATION_INDEPENDENCE_FAILED");
  state = final;
  return {
    status: "SCHOOL_CONFIGURATION_VERIFIED",
    independent_relationships_verified: true,
    ...summary(),
  };
}

export function parseSchoolConfigurationArguments(args) {
  const flags = new Map();
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (
      !["--commit-sha", "--target-project-ref", "--apply"].includes(flag) ||
      flags.has(flag)
    )
      fail("SCHOOL_CONFIGURATION_ARGUMENT_INVALID");
    if (flag === "--apply") flags.set(flag, true);
    else {
      const value = args[++i];
      if (!value || value.startsWith("--"))
        fail("SCHOOL_CONFIGURATION_ARGUMENT_INVALID");
      flags.set(flag, value);
    }
  }
  return {
    commitSha: flags.get("--commit-sha"),
    apply: flags.has("--apply"),
    targetConfirmation: flags.get("--target-project-ref"),
  };
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    console.log(
      JSON.stringify(
        await runAtlasStagingSchoolConfiguration({
          ...parseSchoolConfigurationArguments(process.argv.slice(2)),
          onCommand: (identity) =>
            console.log(JSON.stringify({ command_identity: identity })),
        }),
        null,
        2,
      ),
    );
  } catch (error) {
    // Never forward untrusted transport diagnostics (keys, emails, tokens).
    const message = String(error?.message ?? "");
    console.error(
      /^SCHOOL_[A-Z_]+(?::[A-Za-z0-9_-]+)*$/.test(message)
        ? message
        : "SCHOOL_CONFIGURATION_FAILED",
    );
    process.exitCode = 1;
  }
}
