import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  APPROVED_ATLAS_STAGING_PROJECT_REF,
  defaultCommandRunner,
  executeAtlasStagingManagementSql,
  redactAtlasStagingDiagnostic,
  requireExactCommitSha,
  validateAtlasStagingPackageProtectedValues,
} from "./atlas-staging-contract.mjs";

const PACKAGE_FILES = Object.freeze({
  identity: "supabase/packages/atlas-staging-identity.v1.json",
  foundation: "supabase/packages/atlas-staging-foundation.v1.json",
});
const PACKAGE_CLASSIFICATIONS = Object.freeze({
  identity: "IDENTITY",
  foundation: "FOUNDATION_REFERENCE",
});
export const IDENTITY_CAPABILITY_CODES = Object.freeze([
  "master_data.read",
  "master_data.schools.write",
  "master_data.ingredients.write",
  "master_data.suppliers.write",
  "master_data.priorities.write",
  "master_data.recipes.read",
  "master_data.recipes.write",
  "planning.inputs.read",
  "planning.weekly_menu.write",
  "planning.attendance.write",
  "planning.pantry.write",
  "planning.need_generation.write",
  "confirmed_need_review.read",
  "confirmed_need_quantities.confirm",
  "confirmed_need_release.release",
]);
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CODE = /^[a-z][a-z0-9]*(?:[._][a-z0-9]+)*$/;

function sql(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function uuid(value, label) {
  if (!UUID.test(String(value)))
    throw new Error(`${label} is not a valid UUID.`);
  return `${sql(value)}::uuid`;
}

function code(value, label) {
  if (!CODE.test(String(value))) throw new Error(`${label} is invalid.`);
  return String(value);
}

function requireManifest(condition, message) {
  if (!condition) throw new Error(message);
}

function manifestContainsCredential(value) {
  if (Array.isArray(value)) return value.some(manifestContainsCredential);
  if (!value || typeof value !== "object") return false;
  return Object.entries(value).some(
    ([key, child]) =>
      /^(password|token|secret|key|credential)$/i.test(key) ||
      manifestContainsCredential(child),
  );
}

export function readAtlasStagingPackage(kind, cwd = process.cwd()) {
  const relativePath = PACKAGE_FILES[kind];
  if (!relativePath)
    throw new Error("An explicit Identity or Foundation package is required.");
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(`${cwd}/${relativePath}`, "utf8"));
  } catch {
    throw new Error(`The ${kind} package manifest is missing or malformed.`);
  }
  validatePackageManifest(kind, manifest);
  return manifest;
}

export function validatePackageManifest(kind, manifest) {
  requireManifest(
    manifest?.schema_version === 1,
    "Package schema version is unsupported.",
  );
  requireManifest(
    manifest?.package?.name === `atlas-staging-${kind}` &&
      manifest.package.version === "1.0.0" &&
      manifest.package.classification === PACKAGE_CLASSIFICATIONS[kind] &&
      manifest.package.environment === "staging" &&
      manifest.package.project_ref === APPROVED_ATLAS_STAGING_PROJECT_REF,
    "Package identity or environment qualification is invalid.",
  );
  const serialized = JSON.stringify(manifest);
  requireManifest(
    !manifestContainsCredential(manifest) &&
      !/(sb_secret_|service_role|postgres(?:ql)?:\/\/|eyJ[A-Za-z0-9_-]+\.)/i.test(
        serialized,
      ),
    "Package manifests must not contain credentials.",
  );

  if (kind === "identity") {
    requireManifest(
      manifest.auth_user?.email_env === "ATLAS_STAGING_TEST_EMAIL" &&
        manifest.auth_user?.password_env === "ATLAS_STAGING_TEST_PASSWORD",
      "Identity package credential references are invalid.",
    );
    uuid(manifest.auth_user.auth_subject_id, "Auth subject");
    uuid(manifest.actor?.actor_id, "Actor");
    uuid(manifest.actor?.actor_auth_subject_id, "Actor Auth subject mapping");
    uuid(manifest.role?.role_id, "Role");
    code(manifest.role?.role_code, "Role code");
    requireManifest(
      Array.isArray(manifest.role?.capabilities) &&
        manifest.role.capabilities.length === 15,
      "Identity package must contain the exact minimal capability set.",
    );
    const capabilityCodes = manifest.role.capabilities.map((item) =>
      code(item.capability_code, "Capability code"),
    );
    requireManifest(
      new Set(capabilityCodes).size === capabilityCodes.length,
      "Identity package capabilities are duplicated.",
    );
    requireManifest(
      JSON.stringify(capabilityCodes) ===
        JSON.stringify(IDENTITY_CAPABILITY_CODES),
      "Identity package capabilities differ from the reviewed minimal set.",
    );
    for (const item of manifest.role.capabilities) {
      uuid(item.role_capability_id, "Role capability");
    }
    uuid(manifest.membership?.actor_role_membership_id, "Role membership");
    requireManifest(
      Array.isArray(manifest.scopes) &&
        manifest.scopes.length === 1 &&
        manifest.scopes[0].scope_kind === "GLOBAL",
      "Identity package must contain the one reviewed GLOBAL scope.",
    );
    uuid(manifest.scopes[0].actor_scope_id, "Actor scope");
  } else if (kind === "foundation") {
    for (const [label, value] of [
      ["Identity Actor", manifest.identity_actor_id],
      ["Customer", manifest.customer?.customer_id],
      ["Delivery Location", manifest.delivery_location?.delivery_location_id],
      ["School Type", manifest.school_type?.school_type_id],
      ["School", manifest.school?.school_id],
      ["Unit", manifest.unit?.unit_id],
      [
        "Planning policy",
        manifest.planning_quantity_policy?.planning_quantity_policy_id,
      ],
      [
        "Planning policy revision",
        manifest.planning_quantity_policy?.planning_quantity_policy_revision_id,
      ],
      [
        "Need Generation calculation contract",
        manifest.need_generation_calculation_contract
          ?.need_generation_calculation_contract_id,
      ],
      [
        "Need Generation calculation contract revision",
        manifest.need_generation_calculation_contract
          ?.need_generation_calculation_contract_revision_id,
      ],
    ])
      uuid(value, label);
    requireManifest(
      Array.isArray(manifest.pantry_purposes) &&
        manifest.pantry_purposes.length === 2,
      "Foundation package must contain exactly the two approved Pantry purposes.",
    );
    for (const purpose of manifest.pantry_purposes) {
      uuid(purpose.pantry_need_purpose_id, "Pantry purpose");
      code(purpose.purpose_code, "Pantry purpose code");
    }
    requireManifest(
      JSON.stringify(
        manifest.pantry_purposes.map((item) => item.purpose_code),
      ) ===
        JSON.stringify([
          "school_requested_supplement",
          "planning_identified_supplement",
        ]) &&
        manifest.pantry_purposes.every((item) => item.note_rule === "REQUIRED"),
      "Foundation Pantry purposes differ from the approved set.",
    );
    requireManifest(
      manifest.customer?.customer_type === "SCHOOL_CATERING" &&
        manifest.unit?.unit_code === "kg" &&
        manifest.unit.dimension_code === "MASS" &&
        manifest.planning_quantity_policy?.planning_step === "0.010000" &&
        manifest.planning_quantity_policy.policy_revision_status === "ACTIVE",
      "Foundation package contains an unapproved reference-data shape.",
    );
    const calculationContract = manifest.need_generation_calculation_contract;
    requireManifest(
      calculationContract?.contract_code ===
        "school_catering_proportional_per_basis" &&
        calculationContract.revision_number === 1 &&
        calculationContract.formula_kind ===
          "STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS" &&
        calculationContract.quantity_precision === 20 &&
        calculationContract.quantity_scale === 6 &&
        calculationContract.factor_precision === 24 &&
        calculationContract.factor_scale === 12 &&
        calculationContract.final_coercion_mode ===
          "POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO" &&
        calculationContract.evidence_timestamp === "2026-08-22T00:00:00Z",
      "Foundation Need Generation calculation contract differs from the accepted H0A5b contract.",
    );
    requireManifest(
      JSON.stringify(manifest.required_migration_catalogs) ===
        JSON.stringify({
          ingredient_type_codes: ["khac"],
          ingredient_order_group_codes: ["daily_other"],
          dish_type_codes: ["savory"],
        }),
      "Foundation migration-catalog prerequisites differ from authority.",
    );
  }
  return manifest;
}

function buildNeedGenerationCalculationContractReconciliation(manifest) {
  const contract = manifest.need_generation_calculation_contract;
  const contractId = uuid(
    contract.need_generation_calculation_contract_id,
    "Need Generation calculation contract",
  );
  const revisionId = uuid(
    contract.need_generation_calculation_contract_revision_id,
    "Need Generation calculation contract revision",
  );
  const actorId = uuid(manifest.identity_actor_id, "Identity Actor");
  const timestamp = `${sql(contract.evidence_timestamp)}::timestamptz`;
  return `
  if exists (
    select 1
    from atlas_planning.need_generation_calculation_contracts
    where need_generation_calculation_contract_id = ${contractId}
      and (
        contract_code <> ${sql(contract.contract_code)}
        or current_revision_id <> ${revisionId}
        or version <> ${Number(contract.revision_number)}
        or created_at <> ${timestamp}
        or updated_at <> ${timestamp}
      )
  ) or exists (
    select 1
    from atlas_planning.need_generation_calculation_contracts
    where contract_code = ${sql(contract.contract_code)}
      and need_generation_calculation_contract_id <> ${contractId}
  ) then
    raise exception 'ATLAS_STAGING_FOUNDATION_NEED_GENERATION_CONTRACT_MISMATCH';
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_calculation_contract_revisions
    where need_generation_calculation_contract_revision_id = ${revisionId}
      and (
        need_generation_calculation_contract_id <> ${contractId}
        or revision_number <> ${Number(contract.revision_number)}
        or predecessor_revision_id is not null
        or formula_kind <> ${sql(contract.formula_kind)}
        or quantity_precision <> ${Number(contract.quantity_precision)}
        or quantity_scale <> ${Number(contract.quantity_scale)}
        or factor_precision <> ${Number(contract.factor_precision)}
        or factor_scale <> ${Number(contract.factor_scale)}
        or final_coercion_mode <> ${sql(contract.final_coercion_mode)}
        or approved_by_actor_id <> ${actorId}
        or approved_at <> ${timestamp}
      )
  ) or exists (
    select 1
    from atlas_planning.need_generation_calculation_contract_revisions
    where need_generation_calculation_contract_id = ${contractId}
      and revision_number = ${Number(contract.revision_number)}
      and need_generation_calculation_contract_revision_id <> ${revisionId}
  ) then
    raise exception 'ATLAS_STAGING_FOUNDATION_NEED_GENERATION_CONTRACT_REVISION_MISMATCH';
  end if;

  if not exists (
    select 1
    from atlas_planning.need_generation_calculation_contracts
    where need_generation_calculation_contract_id = ${contractId}
  ) then
    insert into atlas_planning.need_generation_calculation_contracts (
      need_generation_calculation_contract_id,
      contract_code,
      current_revision_id,
      version,
      created_at,
      updated_at
    ) values (
      ${contractId},
      ${sql(contract.contract_code)},
      ${revisionId},
      ${Number(contract.revision_number)},
      ${timestamp},
      ${timestamp}
    );
  end if;

  if not exists (
    select 1
    from atlas_planning.need_generation_calculation_contract_revisions
    where need_generation_calculation_contract_revision_id = ${revisionId}
  ) then
    insert into atlas_planning.need_generation_calculation_contract_revisions (
      need_generation_calculation_contract_revision_id,
      need_generation_calculation_contract_id,
      revision_number,
      formula_kind,
      quantity_precision,
      quantity_scale,
      factor_precision,
      factor_scale,
      final_coercion_mode,
      approved_by_actor_id,
      approved_at
    ) values (
      ${revisionId},
      ${contractId},
      ${Number(contract.revision_number)},
      ${sql(contract.formula_kind)},
      ${Number(contract.quantity_precision)},
      ${Number(contract.quantity_scale)},
      ${Number(contract.factor_precision)},
      ${Number(contract.factor_scale)},
      ${sql(contract.final_coercion_mode)},
      ${actorId},
      ${timestamp}
    );
  end if;`;
}

export function buildFoundationNeedGenerationContractSql(manifest) {
  validatePackageManifest("foundation", manifest);
  return `do $atlas_staging_foundation_need_generation_contract$
begin
  if not exists (select 1 from atlas_core.actors where actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")} and actor_status = 'ACTIVE') then raise exception 'ATLAS_STAGING_FOUNDATION_IDENTITY_PREREQUISITE_MISSING'; end if;
${buildNeedGenerationCalculationContractReconciliation(manifest)}
end;
$atlas_staging_foundation_need_generation_contract$;`;
}

export function verifyPackageCheckout({
  commitSha: commitShaValue,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
} = {}) {
  const commitSha = requireExactCommitSha(commitShaValue);
  const command = (args, message) => {
    const result = runCommand("git", args, { cwd });
    if (result.status !== 0) throw new Error(message);
    return String(result.stdout ?? "").trim();
  };
  command(
    ["cat-file", "-e", `${commitSha}^{commit}`],
    "Package commit is unavailable.",
  );
  if (
    command(["rev-parse", "HEAD"], "Package checkout cannot be verified.") !==
    commitSha
  ) {
    throw new Error("Package checkout is not at the requested exact commit.");
  }
  command(
    ["merge-base", "--is-ancestor", commitSha, "origin/main"],
    "Package commit is not contained in origin/main.",
  );
  if (
    command(["status", "--porcelain"], "Package worktree cannot be verified.")
  ) {
    throw new Error("Package worktree is not clean.");
  }
  return commitSha;
}

export async function reconcileManagedAuthUser({
  manifest,
  email,
  password,
  supabaseUrl,
  secretKey,
  createClientFactory = createClient,
}) {
  const client = createClientFactory(supabaseUrl, secretKey, {
    db: { retry: false },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const users = [];
  const perPage = 1000;
  for (let page = 1; ; page += 1) {
    const { data, error } = await client.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error)
      throw new Error("Protected Auth users could not be inspected safely.");
    users.push(...data.users);
    if (data.users.length < perPage) break;
  }
  const subjectId = manifest.auth_user.auth_subject_id;
  const byId = users.find((user) => user.id === subjectId);
  const byEmail = users.find(
    (user) =>
      user.email?.toLocaleLowerCase("en") === email.toLocaleLowerCase("en"),
  );
  if (
    (byId &&
      byId.email?.toLocaleLowerCase("en") !== email.toLocaleLowerCase("en")) ||
    (byEmail && byEmail.id !== subjectId)
  ) {
    throw new Error(
      "The managed staging Auth identity conflicts with existing state.",
    );
  }
  const attributes = {
    email,
    password,
    email_confirm: manifest.auth_user.email_confirm,
    user_metadata: manifest.auth_user.user_metadata,
    app_metadata: manifest.auth_user.app_metadata,
  };
  const result = byId
    ? await client.auth.admin.updateUserById(subjectId, attributes)
    : await client.auth.admin.createUser({ id: subjectId, ...attributes });
  if (result.error || result.data.user?.id !== subjectId) {
    throw new Error(
      "The managed staging Auth identity could not be reconciled safely.",
    );
  }
  return { authSubjectId: subjectId, replay: Boolean(byId) };
}

export function buildIdentityPackageSql(manifest) {
  validatePackageManifest("identity", manifest);
  const actor = manifest.actor;
  const role = manifest.role;
  const membership = manifest.membership;
  const scope = manifest.scopes[0];
  const capabilityCodes = role.capabilities.map((item) => item.capability_code);
  const capabilityArray = `array[${capabilityCodes.map(sql).join(", ")}]::text[]`;
  const capabilityReconciliations = role.capabilities
    .map(
      (item) => `
  if exists (
    select 1 from atlas_core.role_capabilities role_capability
    join atlas_core.capabilities capability using (capability_id)
    where role_capability.role_capability_id = ${uuid(item.role_capability_id, "Role capability")}
      and (role_capability.role_id <> ${uuid(role.role_id, "Role")}
        or capability.capability_code <> ${sql(item.capability_code)}
        or role_capability.granted_by_actor_id is distinct from ${uuid(actor.actor_id, "Actor")})
  ) or exists (
    select 1 from atlas_core.role_capabilities role_capability
    join atlas_core.capabilities capability using (capability_id)
    where role_capability.role_id = ${uuid(role.role_id, "Role")}
      and capability.capability_code = ${sql(item.capability_code)}
      and role_capability.role_capability_id <> ${uuid(item.role_capability_id, "Role capability")}
  ) then raise exception 'ATLAS_STAGING_IDENTITY_ROLE_CAPABILITY_MISMATCH'; end if;
  if not exists (select 1 from atlas_core.role_capabilities where role_capability_id = ${uuid(item.role_capability_id, "Role capability")}) then
    insert into atlas_core.role_capabilities (
      role_capability_id, role_id, capability_id, granted_by_actor_id
    ) select ${uuid(item.role_capability_id, "Role capability")}, ${uuid(role.role_id, "Role")}, capability_id, ${uuid(actor.actor_id, "Actor")}
      from atlas_core.capabilities where capability_code = ${sql(item.capability_code)} and capability_status = 'ACTIVE';
  end if;`,
    )
    .join("\n");

  return `do $atlas_staging_identity$
begin
  if (select count(*) from atlas_core.capabilities where capability_code = any(${capabilityArray}) and capability_status = 'ACTIVE') <> ${capabilityCodes.length} then
    raise exception 'ATLAS_STAGING_IDENTITY_CAPABILITY_CATALOG_MISMATCH';
  end if;

  if exists (select 1 from atlas_core.actors where actor_id = ${uuid(actor.actor_id, "Actor")} and (actor_type <> ${sql(actor.actor_type)} or display_name <> ${sql(actor.display_name)} or actor_status <> 'ACTIVE' or deactivated_at is not null)) then
    raise exception 'ATLAS_STAGING_IDENTITY_ACTOR_MISMATCH';
  end if;
  if not exists (select 1 from atlas_core.actors where actor_id = ${uuid(actor.actor_id, "Actor")}) then
    insert into atlas_core.actors (actor_id, actor_type, display_name) values (${uuid(actor.actor_id, "Actor")}, ${sql(actor.actor_type)}, ${sql(actor.display_name)});
  end if;

  if exists (select 1 from atlas_core.actor_auth_subjects where actor_auth_subject_id = ${uuid(actor.actor_auth_subject_id, "Actor Auth subject mapping")} and (actor_id <> ${uuid(actor.actor_id, "Actor")} or auth_subject_id <> ${uuid(manifest.auth_user.auth_subject_id, "Auth subject")} or auth_provider <> 'SUPABASE_AUTH' or subject_status <> 'ACTIVE' or revoked_at is not null))
    or exists (select 1 from atlas_core.actor_auth_subjects where auth_provider = 'SUPABASE_AUTH' and auth_subject_id = ${uuid(manifest.auth_user.auth_subject_id, "Auth subject")} and actor_auth_subject_id <> ${uuid(actor.actor_auth_subject_id, "Actor Auth subject mapping")}) then
    raise exception 'ATLAS_STAGING_IDENTITY_AUTH_MAPPING_MISMATCH';
  end if;
  if not exists (select 1 from atlas_core.actor_auth_subjects where actor_auth_subject_id = ${uuid(actor.actor_auth_subject_id, "Actor Auth subject mapping")}) then
    insert into atlas_core.actor_auth_subjects (actor_auth_subject_id, actor_id, auth_subject_id) values (${uuid(actor.actor_auth_subject_id, "Actor Auth subject mapping")}, ${uuid(actor.actor_id, "Actor")}, ${uuid(manifest.auth_user.auth_subject_id, "Auth subject")});
  end if;

  if exists (select 1 from atlas_core.roles where role_id = ${uuid(role.role_id, "Role")} and (role_code <> ${sql(role.role_code)} or role_name <> ${sql(role.role_name)} or role_status <> 'ACTIVE'))
    or exists (select 1 from atlas_core.roles where role_code = ${sql(role.role_code)} and role_id <> ${uuid(role.role_id, "Role")}) then
    raise exception 'ATLAS_STAGING_IDENTITY_ROLE_MISMATCH';
  end if;
  if not exists (select 1 from atlas_core.roles where role_id = ${uuid(role.role_id, "Role")}) then
    insert into atlas_core.roles (role_id, role_code, role_name) values (${uuid(role.role_id, "Role")}, ${sql(role.role_code)}, ${sql(role.role_name)});
  end if;
${capabilityReconciliations}

  if exists (select 1 from atlas_core.actor_role_memberships where actor_role_membership_id = ${uuid(membership.actor_role_membership_id, "Role membership")} and (actor_id <> ${uuid(actor.actor_id, "Actor")} or role_id <> ${uuid(role.role_id, "Role")} or granted_by_actor_id is distinct from ${uuid(actor.actor_id, "Actor")} or membership_status <> 'ACTIVE' or effective_to is not null or reason_note is distinct from ${sql(membership.reason_note)})) then
    raise exception 'ATLAS_STAGING_IDENTITY_MEMBERSHIP_MISMATCH';
  end if;
  if not exists (select 1 from atlas_core.actor_role_memberships where actor_role_membership_id = ${uuid(membership.actor_role_membership_id, "Role membership")}) then
    insert into atlas_core.actor_role_memberships (actor_role_membership_id, actor_id, role_id, granted_by_actor_id, reason_note) values (${uuid(membership.actor_role_membership_id, "Role membership")}, ${uuid(actor.actor_id, "Actor")}, ${uuid(role.role_id, "Role")}, ${uuid(actor.actor_id, "Actor")}, ${sql(membership.reason_note)});
  end if;

  if exists (select 1 from atlas_core.actor_scopes where actor_scope_id = ${uuid(scope.actor_scope_id, "Actor scope")} and (actor_id <> ${uuid(actor.actor_id, "Actor")} or scope_kind <> 'GLOBAL' or customer_id is not null or delivery_location_id is not null or dispatch_trip_id is not null or school_id is not null or granted_by_actor_id is distinct from ${uuid(actor.actor_id, "Actor")} or scope_status <> 'ACTIVE' or effective_to is not null or reason_note is distinct from ${sql(scope.reason_note)})) then
    raise exception 'ATLAS_STAGING_IDENTITY_SCOPE_MISMATCH';
  end if;
  if not exists (select 1 from atlas_core.actor_scopes where actor_scope_id = ${uuid(scope.actor_scope_id, "Actor scope")}) then
    insert into atlas_core.actor_scopes (actor_scope_id, actor_id, scope_kind, granted_by_actor_id, reason_note) values (${uuid(scope.actor_scope_id, "Actor scope")}, ${uuid(actor.actor_id, "Actor")}, 'GLOBAL', ${uuid(actor.actor_id, "Actor")}, ${sql(scope.reason_note)});
  end if;

  if (select count(*) from atlas_core.actor_auth_subjects where actor_id = ${uuid(actor.actor_id, "Actor")} and subject_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_core.actor_role_memberships where actor_id = ${uuid(actor.actor_id, "Actor")} and membership_status = 'ACTIVE' and effective_from <= transaction_timestamp() and (effective_to is null or effective_to > transaction_timestamp())) <> 1
    or (select count(*) from atlas_core.actor_scopes where actor_id = ${uuid(actor.actor_id, "Actor")} and scope_status = 'ACTIVE' and effective_from <= transaction_timestamp() and (effective_to is null or effective_to > transaction_timestamp())) <> 1
    or (select count(*) from atlas_core.role_capabilities where role_id = ${uuid(role.role_id, "Role")}) <> ${capabilityCodes.length} then
    raise exception 'ATLAS_STAGING_IDENTITY_EXACT_STATE_MISMATCH';
  end if;
end;
$atlas_staging_identity$;`;
}

export function buildFoundationPackageSql(manifest) {
  validatePackageManifest("foundation", manifest);
  const customer = manifest.customer;
  const location = manifest.delivery_location;
  const schoolType = manifest.school_type;
  const school = manifest.school;
  const unit = manifest.unit;
  const policy = manifest.planning_quantity_policy;
  const calculationContractReconciliation =
    buildNeedGenerationCalculationContractReconciliation(manifest);
  const purposeRows = manifest.pantry_purposes
    .map(
      (purpose) => `
  if exists (select 1 from atlas_planning.pantry_need_purposes where pantry_need_purpose_id = ${uuid(purpose.pantry_need_purpose_id, "Pantry purpose")} and (purpose_code <> ${sql(purpose.purpose_code)} or purpose_name_vi <> ${sql(purpose.purpose_name_vi)} or purpose_description <> ${sql(purpose.purpose_description)} or note_rule <> ${sql(purpose.note_rule)} or purpose_status <> 'ACTIVE' or display_order <> ${Number(purpose.display_order)}))
    or exists (select 1 from atlas_planning.pantry_need_purposes where purpose_code = ${sql(purpose.purpose_code)} and pantry_need_purpose_id <> ${uuid(purpose.pantry_need_purpose_id, "Pantry purpose")}) then raise exception 'ATLAS_STAGING_FOUNDATION_PANTRY_PURPOSE_MISMATCH'; end if;
  if not exists (select 1 from atlas_planning.pantry_need_purposes where pantry_need_purpose_id = ${uuid(purpose.pantry_need_purpose_id, "Pantry purpose")}) then
    insert into atlas_planning.pantry_need_purposes (pantry_need_purpose_id, purpose_code, purpose_name_vi, purpose_description, note_rule, display_order) values (${uuid(purpose.pantry_need_purpose_id, "Pantry purpose")}, ${sql(purpose.purpose_code)}, ${sql(purpose.purpose_name_vi)}, ${sql(purpose.purpose_description)}, ${sql(purpose.note_rule)}, ${Number(purpose.display_order)});
  end if;`,
    )
    .join("\n");
  const ingredientTypes =
    manifest.required_migration_catalogs.ingredient_type_codes
      .map(sql)
      .join(", ");
  const orderGroups =
    manifest.required_migration_catalogs.ingredient_order_group_codes
      .map(sql)
      .join(", ");
  const dishTypes = manifest.required_migration_catalogs.dish_type_codes
    .map(sql)
    .join(", ");

  return `do $atlas_staging_foundation$
begin
  if not exists (select 1 from atlas_core.actors where actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")} and actor_status = 'ACTIVE') then raise exception 'ATLAS_STAGING_FOUNDATION_IDENTITY_PREREQUISITE_MISSING'; end if;
  if (select count(*) from atlas_admin.ingredient_types where ingredient_type_code in (${ingredientTypes}) and ingredient_type_status = 'ACTIVE') <> ${manifest.required_migration_catalogs.ingredient_type_codes.length}
    or (select count(*) from atlas_admin.ingredient_order_groups where ingredient_order_group_code in (${orderGroups}) and ingredient_order_group_status = 'ACTIVE') <> ${manifest.required_migration_catalogs.ingredient_order_group_codes.length}
    or (select count(*) from atlas_admin.dish_types where dish_type_code in (${dishTypes}) and dish_type_status = 'ACTIVE') <> ${manifest.required_migration_catalogs.dish_type_codes.length} then raise exception 'ATLAS_STAGING_FOUNDATION_MIGRATION_CATALOG_MISMATCH'; end if;

  if exists (select 1 from atlas_admin.customers where customer_id = ${uuid(customer.customer_id, "Customer")} and (customer_code <> ${sql(customer.customer_code)} or customer_name <> ${sql(customer.customer_name)} or customer_type <> ${sql(customer.customer_type)} or customer_status <> 'ACTIVE'))
    or exists (select 1 from atlas_admin.customers where customer_code = ${sql(customer.customer_code)} and customer_id <> ${uuid(customer.customer_id, "Customer")}) then raise exception 'ATLAS_STAGING_FOUNDATION_CUSTOMER_MISMATCH'; end if;
  if not exists (select 1 from atlas_admin.customers where customer_id = ${uuid(customer.customer_id, "Customer")}) then insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type) values (${uuid(customer.customer_id, "Customer")}, ${sql(customer.customer_code)}, ${sql(customer.customer_name)}, ${sql(customer.customer_type)}); end if;

  if exists (select 1 from atlas_admin.delivery_locations where delivery_location_id = ${uuid(location.delivery_location_id, "Delivery Location")} and (customer_id <> ${uuid(customer.customer_id, "Customer")} or location_code <> ${sql(location.location_code)} or location_name <> ${sql(location.location_name)} or address_text <> ${sql(location.address_text)} or delivery_instructions is distinct from ${sql(location.delivery_instructions)} or timezone_name <> ${sql(location.timezone_name)} or location_status <> 'ACTIVE'))
    or exists (select 1 from atlas_admin.delivery_locations where customer_id = ${uuid(customer.customer_id, "Customer")} and location_code = ${sql(location.location_code)} and delivery_location_id <> ${uuid(location.delivery_location_id, "Delivery Location")}) then raise exception 'ATLAS_STAGING_FOUNDATION_LOCATION_MISMATCH'; end if;
  if not exists (select 1 from atlas_admin.delivery_locations where delivery_location_id = ${uuid(location.delivery_location_id, "Delivery Location")}) then insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text, delivery_instructions, timezone_name) values (${uuid(location.delivery_location_id, "Delivery Location")}, ${uuid(customer.customer_id, "Customer")}, ${sql(location.location_code)}, ${sql(location.location_name)}, ${sql(location.address_text)}, ${sql(location.delivery_instructions)}, ${sql(location.timezone_name)}); end if;

  if exists (select 1 from atlas_admin.school_types where school_type_id = ${uuid(schoolType.school_type_id, "School Type")} and (school_type_code <> ${sql(schoolType.school_type_code)} or school_type_name <> ${sql(schoolType.school_type_name)} or school_type_status <> 'ACTIVE'))
    or exists (select 1 from atlas_admin.school_types where school_type_code = ${sql(schoolType.school_type_code)} and school_type_id <> ${uuid(schoolType.school_type_id, "School Type")}) then raise exception 'ATLAS_STAGING_FOUNDATION_SCHOOL_TYPE_MISMATCH'; end if;
  if not exists (select 1 from atlas_admin.school_types where school_type_id = ${uuid(schoolType.school_type_id, "School Type")}) then insert into atlas_admin.school_types (school_type_id, school_type_code, school_type_name) values (${uuid(schoolType.school_type_id, "School Type")}, ${sql(schoolType.school_type_code)}, ${sql(schoolType.school_type_name)}); end if;

  if exists (select 1 from atlas_admin.schools where school_id = ${uuid(school.school_id, "School")} and (customer_id <> ${uuid(customer.customer_id, "Customer")} or school_code <> ${sql(school.school_code)} or school_name <> ${sql(school.school_name)} or school_type_id is distinct from ${uuid(schoolType.school_type_id, "School Type")} or default_delivery_location_id <> ${uuid(location.delivery_location_id, "Delivery Location")} or school_status <> 'ACTIVE' or display_order <> ${Number(school.display_order)} or operational_notes is distinct from ${sql(school.operational_notes)}))
    or exists (select 1 from atlas_admin.schools where customer_id = ${uuid(customer.customer_id, "Customer")} and school_code = ${sql(school.school_code)} and school_id <> ${uuid(school.school_id, "School")}) then raise exception 'ATLAS_STAGING_FOUNDATION_SCHOOL_MISMATCH'; end if;
  if not exists (select 1 from atlas_admin.schools where school_id = ${uuid(school.school_id, "School")}) then insert into atlas_admin.schools (school_id, customer_id, school_code, school_name, school_type_id, default_delivery_location_id, display_order, operational_notes, default_student_portions, default_teacher_portions) values (${uuid(school.school_id, "School")}, ${uuid(customer.customer_id, "Customer")}, ${sql(school.school_code)}, ${sql(school.school_name)}, ${uuid(schoolType.school_type_id, "School Type")}, ${uuid(location.delivery_location_id, "Delivery Location")}, ${Number(school.display_order)}, ${sql(school.operational_notes)}, ${Number(school.default_student_portions)}, ${Number(school.default_teacher_portions)}); end if;

  if exists (select 1 from atlas_admin.units where unit_id = ${uuid(unit.unit_id, "Unit")} and (unit_code <> ${sql(unit.unit_code)} or unit_name <> ${sql(unit.unit_name)} or dimension_code <> ${sql(unit.dimension_code)} or decimal_scale <> ${Number(unit.decimal_scale)} or unit_status <> 'ACTIVE'))
    or exists (select 1 from atlas_admin.units where unit_code = ${sql(unit.unit_code)} and unit_id <> ${uuid(unit.unit_id, "Unit")}) then raise exception 'ATLAS_STAGING_FOUNDATION_UNIT_MISMATCH'; end if;
  if not exists (select 1 from atlas_admin.units where unit_id = ${uuid(unit.unit_id, "Unit")}) then insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code, decimal_scale) values (${uuid(unit.unit_id, "Unit")}, ${sql(unit.unit_code)}, ${sql(unit.unit_name)}, ${sql(unit.dimension_code)}, ${Number(unit.decimal_scale)}); end if;
${purposeRows}
${calculationContractReconciliation}

  if exists (select 1 from atlas_planning.planning_quantity_policies where planning_quantity_policy_id = ${uuid(policy.planning_quantity_policy_id, "Planning policy")} and (unit_id <> ${uuid(unit.unit_id, "Unit")} or created_by_actor_id <> ${uuid(manifest.identity_actor_id, "Identity Actor")}))
    or exists (select 1 from atlas_planning.planning_quantity_policies where unit_id = ${uuid(unit.unit_id, "Unit")} and planning_quantity_policy_id <> ${uuid(policy.planning_quantity_policy_id, "Planning policy")}) then raise exception 'ATLAS_STAGING_FOUNDATION_POLICY_MISMATCH'; end if;
  if not exists (select 1 from atlas_planning.planning_quantity_policies where planning_quantity_policy_id = ${uuid(policy.planning_quantity_policy_id, "Planning policy")}) then insert into atlas_planning.planning_quantity_policies (planning_quantity_policy_id, unit_id, created_by_actor_id, created_at) values (${uuid(policy.planning_quantity_policy_id, "Planning policy")}, ${uuid(unit.unit_id, "Unit")}, ${uuid(manifest.identity_actor_id, "Identity Actor")}, ${sql(policy.evidence_timestamp)}::timestamptz); end if;

  if exists (select 1 from atlas_planning.planning_quantity_policy_revisions where planning_quantity_policy_revision_id = ${uuid(policy.planning_quantity_policy_revision_id, "Planning policy revision")} and (planning_quantity_policy_id <> ${uuid(policy.planning_quantity_policy_id, "Planning policy")} or unit_id <> ${uuid(unit.unit_id, "Unit")} or revision_number <> ${Number(policy.revision_number)} or predecessor_policy_revision_id is not null or planning_step <> ${sql(policy.planning_step)}::numeric or effective_from <> ${sql(policy.effective_from)}::date or effective_to is not null or created_by_actor_id <> ${uuid(manifest.identity_actor_id, "Identity Actor")} or created_at <> ${sql(policy.evidence_timestamp)}::timestamptz or not ((policy_revision_status = 'DRAFT' and approved_by_actor_id is null and approved_at is null and activated_by_actor_id is null and activated_at is null and retired_by_actor_id is null and retired_at is null) or (policy_revision_status = ${sql(policy.policy_revision_status)} and approved_by_actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")} and approved_at = ${sql(policy.evidence_timestamp)}::timestamptz and activated_by_actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")} and activated_at = ${sql(policy.evidence_timestamp)}::timestamptz and retired_by_actor_id is null and retired_at is null))))
    or exists (select 1 from atlas_planning.planning_quantity_policy_revisions where planning_quantity_policy_id = ${uuid(policy.planning_quantity_policy_id, "Planning policy")} and revision_number = ${Number(policy.revision_number)} and planning_quantity_policy_revision_id <> ${uuid(policy.planning_quantity_policy_revision_id, "Planning policy revision")}) then raise exception 'ATLAS_STAGING_FOUNDATION_POLICY_REVISION_MISMATCH'; end if;
  if not exists (select 1 from atlas_planning.planning_quantity_policy_revisions where planning_quantity_policy_revision_id = ${uuid(policy.planning_quantity_policy_revision_id, "Planning policy revision")}) then
    insert into atlas_planning.planning_quantity_policy_revisions (planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id, revision_number, planning_step, effective_from, policy_revision_status, created_by_actor_id, created_at) values (${uuid(policy.planning_quantity_policy_revision_id, "Planning policy revision")}, ${uuid(policy.planning_quantity_policy_id, "Planning policy")}, ${uuid(unit.unit_id, "Unit")}, ${Number(policy.revision_number)}, ${sql(policy.planning_step)}::numeric, ${sql(policy.effective_from)}::date, 'DRAFT', ${uuid(manifest.identity_actor_id, "Identity Actor")}, ${sql(policy.evidence_timestamp)}::timestamptz);
  end if;
  update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status = ${sql(policy.policy_revision_status)}, approved_by_actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")}, approved_at = ${sql(policy.evidence_timestamp)}::timestamptz, activated_by_actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")}, activated_at = ${sql(policy.evidence_timestamp)}::timestamptz
    where planning_quantity_policy_revision_id = ${uuid(policy.planning_quantity_policy_revision_id, "Planning policy revision")} and planning_quantity_policy_id = ${uuid(policy.planning_quantity_policy_id, "Planning policy")} and unit_id = ${uuid(unit.unit_id, "Unit")} and revision_number = ${Number(policy.revision_number)} and predecessor_policy_revision_id is null and planning_step = ${sql(policy.planning_step)}::numeric and effective_from = ${sql(policy.effective_from)}::date and effective_to is null and policy_revision_status = 'DRAFT' and created_by_actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")} and created_at = ${sql(policy.evidence_timestamp)}::timestamptz and approved_by_actor_id is null and approved_at is null and activated_by_actor_id is null and activated_at is null and retired_by_actor_id is null and retired_at is null;
end;
$atlas_staging_foundation$;
`;
}

export function buildIdentityVerificationSql(manifest) {
  validatePackageManifest("identity", manifest);
  const actorId = uuid(manifest.actor.actor_id, "Actor");
  const authSubjectId = uuid(
    manifest.auth_user.auth_subject_id,
    "Auth subject",
  );
  const roleId = uuid(manifest.role.role_id, "Role");
  const capabilities = `array[${manifest.role.capabilities
    .map((item) => sql(item.capability_code))
    .join(", ")}]::text[]`;
  return `do $atlas_staging_identity_verify$
declare actual_capabilities text[];
begin
  if (select count(*) from atlas_core.actors where actor_id = ${actorId} and actor_type = ${sql(manifest.actor.actor_type)} and display_name = ${sql(manifest.actor.display_name)} and actor_status = 'ACTIVE' and deactivated_at is null) <> 1
    or (select count(*) from atlas_core.actor_auth_subjects where actor_id = ${actorId} and auth_subject_id = ${authSubjectId} and auth_provider = 'SUPABASE_AUTH' and subject_status = 'ACTIVE' and revoked_at is null) <> 1
    or (select count(*) from atlas_core.roles where role_id = ${roleId} and role_code = ${sql(manifest.role.role_code)} and role_name = ${sql(manifest.role.role_name)} and role_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_core.actor_role_memberships where actor_id = ${actorId} and role_id = ${roleId} and membership_status = 'ACTIVE' and effective_to is null) <> 1
    or (select count(*) from atlas_core.actor_scopes where actor_id = ${actorId} and scope_kind = 'GLOBAL' and scope_status = 'ACTIVE' and customer_id is null and school_id is null and delivery_location_id is null and dispatch_trip_id is null and effective_to is null) <> 1 then
    raise exception 'ATLAS_STAGING_IDENTITY_VERIFICATION_MISMATCH';
  end if;
  select array_agg(capability.capability_code order by capability.capability_code)
    into actual_capabilities
    from atlas_core.role_capabilities role_capability
    join atlas_core.capabilities capability using (capability_id)
    where role_capability.role_id = ${roleId} and capability.capability_status = 'ACTIVE';
  if actual_capabilities is distinct from (select array_agg(code order by code) from unnest(${capabilities}) code) then
    raise exception 'ATLAS_STAGING_IDENTITY_CAPABILITY_VERIFICATION_MISMATCH';
  end if;
end;
$atlas_staging_identity_verify$;`;
}

export function buildFoundationVerificationSql(manifest) {
  validatePackageManifest("foundation", manifest);
  const customer = manifest.customer;
  const location = manifest.delivery_location;
  const schoolType = manifest.school_type;
  const school = manifest.school;
  const unit = manifest.unit;
  const policy = manifest.planning_quantity_policy;
  const contract = manifest.need_generation_calculation_contract;
  const purposeCodes = `array[${manifest.pantry_purposes.map((item) => sql(item.purpose_code)).join(", ")}]::text[]`;
  return `do $atlas_staging_foundation_verify$
declare actual_purposes text[];
begin
  if (select count(*) from atlas_admin.customers where customer_id = ${uuid(customer.customer_id, "Customer")} and customer_code = ${sql(customer.customer_code)} and customer_type = 'SCHOOL_CATERING' and customer_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_admin.delivery_locations where delivery_location_id = ${uuid(location.delivery_location_id, "Delivery Location")} and customer_id = ${uuid(customer.customer_id, "Customer")} and location_code = ${sql(location.location_code)} and location_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_admin.school_types where school_type_id = ${uuid(schoolType.school_type_id, "School Type")} and school_type_code = ${sql(schoolType.school_type_code)} and school_type_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_admin.schools where school_id = ${uuid(school.school_id, "School")} and customer_id = ${uuid(customer.customer_id, "Customer")} and school_code = ${sql(school.school_code)} and default_delivery_location_id = ${uuid(location.delivery_location_id, "Delivery Location")} and school_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_admin.units where unit_id = ${uuid(unit.unit_id, "Unit")} and unit_code = 'kg' and dimension_code = 'MASS' and unit_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_planning.planning_quantity_policies where planning_quantity_policy_id = ${uuid(policy.planning_quantity_policy_id, "Planning policy")} and unit_id = ${uuid(unit.unit_id, "Unit")}) <> 1
    or (select count(*) from atlas_planning.planning_quantity_policy_revisions where planning_quantity_policy_revision_id = ${uuid(policy.planning_quantity_policy_revision_id, "Planning policy revision")} and planning_quantity_policy_id = ${uuid(policy.planning_quantity_policy_id, "Planning policy")} and planning_step = ${sql(policy.planning_step)}::numeric and policy_revision_status = 'ACTIVE') <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contracts where need_generation_calculation_contract_id = ${uuid(contract.need_generation_calculation_contract_id, "Need Generation calculation contract")} and contract_code = ${sql(contract.contract_code)} and current_revision_id = ${uuid(contract.need_generation_calculation_contract_revision_id, "Need Generation calculation contract revision")} and version = ${Number(contract.revision_number)} and created_at = ${sql(contract.evidence_timestamp)}::timestamptz and updated_at = ${sql(contract.evidence_timestamp)}::timestamptz) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions where need_generation_calculation_contract_revision_id = ${uuid(contract.need_generation_calculation_contract_revision_id, "Need Generation calculation contract revision")} and need_generation_calculation_contract_id = ${uuid(contract.need_generation_calculation_contract_id, "Need Generation calculation contract")} and revision_number = ${Number(contract.revision_number)} and predecessor_revision_id is null and formula_kind = ${sql(contract.formula_kind)} and quantity_precision = ${Number(contract.quantity_precision)} and quantity_scale = ${Number(contract.quantity_scale)} and factor_precision = ${Number(contract.factor_precision)} and factor_scale = ${Number(contract.factor_scale)} and final_coercion_mode = ${sql(contract.final_coercion_mode)} and approved_by_actor_id = ${uuid(manifest.identity_actor_id, "Identity Actor")} and approved_at = ${sql(contract.evidence_timestamp)}::timestamptz) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions where need_generation_calculation_contract_id = ${uuid(contract.need_generation_calculation_contract_id, "Need Generation calculation contract")}) <> 1 then
    raise exception 'ATLAS_STAGING_FOUNDATION_VERIFICATION_MISMATCH';
  end if;
  select array_agg(purpose_code order by purpose_code) into actual_purposes
    from atlas_planning.pantry_need_purposes where pantry_need_purpose_id in (${manifest.pantry_purposes.map((item) => uuid(item.pantry_need_purpose_id, "Pantry purpose")).join(", ")}) and purpose_status = 'ACTIVE' and note_rule = 'REQUIRED';
  if actual_purposes is distinct from (select array_agg(code order by code) from unnest(${purposeCodes}) code) then
    raise exception 'ATLAS_STAGING_FOUNDATION_PURPOSE_VERIFICATION_MISMATCH';
  end if;
end;
$atlas_staging_foundation_verify$;`;
}

export function planAtlasStagingPackage({
  kind,
  environment = process.env,
  cwd = process.cwd(),
}) {
  const manifest = readAtlasStagingPackage(kind, cwd);
  const target = validateAtlasStagingPackageProtectedValues(environment, {
    identity: kind === "identity",
  });
  return {
    kind,
    packageName: manifest.package.name,
    packageVersion: manifest.package.version,
    target,
    commands: [
      ...(kind === "identity"
        ? [["Supabase Auth Admin", "reconcile one protected synthetic user"]]
        : []),
      ["Management API", "POST", `<${kind}-package-reconciliation-sql>`],
      ["Management API", "POST", `<${kind}-package-verification-sql>`],
    ],
    mutatesHostedState: true,
    deploysMigrations: false,
    installsRehearsalFacts: false,
  };
}

export async function installAtlasStagingPackage({
  kind,
  commitSha,
  environment = process.env,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
  createClientFactory = createClient,
  fetchImpl = fetch,
  dryRun = false,
} = {}) {
  const plan = planAtlasStagingPackage({ kind, environment, cwd });
  if (dryRun) return { status: "dry-run", plan };
  verifyPackageCheckout({ commitSha, cwd, runCommand });
  const manifest = readAtlasStagingPackage(kind, cwd);
  if (kind === "identity") {
    await reconcileManagedAuthUser({
      manifest,
      email: plan.target.testEmail,
      password: plan.target.testPassword,
      supabaseUrl: plan.target.supabaseUrl,
      secretKey: plan.target.secretKey,
      createClientFactory,
    });
  }
  const packageSql =
    kind === "identity"
      ? buildIdentityPackageSql(manifest)
      : buildFoundationPackageSql(manifest);
  const verificationSql =
    kind === "identity"
      ? buildIdentityVerificationSql(manifest)
      : buildFoundationVerificationSql(manifest);
  await executeAtlasStagingManagementSql(plan.target, packageSql, fetchImpl);
  await executeAtlasStagingManagementSql(
    plan.target,
    verificationSql,
    fetchImpl,
  );
  return { status: "installed", plan };
}

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function main() {
  const kind = argument("--package");
  const result = await installAtlasStagingPackage({
    kind,
    commitSha: argument("--commit-sha"),
    dryRun: process.argv.includes("--dry-run"),
  });
  console.log(
    result.status === "dry-run"
      ? `${result.plan.packageName}@${result.plan.packageVersion} dry-run passed without process or network execution.`
      : `${result.plan.packageName}@${result.plan.packageVersion} reconciled on approved Atlas Staging.`,
  );
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Atlas Staging package failed safely.",
      ),
    );
    process.exitCode = 1;
  });
}
