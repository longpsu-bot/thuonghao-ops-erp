import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { canonicalMasterJson } from "./ops-v1-master-snapshot-contract.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import {
  validateApprovedAtlasStagingTarget,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";

const CONTRACT = "ATLAS-STAGING-RECIPE3529.v1";
const STAGING = "rnzxmxiiqgtdevzregff";
const SHA256 = /^[a-f0-9]{64}$/;
const UUID = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
export const RECIPE3529 = {
  dish: "278e8419-4b9a-77d2-2e5c-dcd0fc65f504",
  type2: "39bef77e-43a0-5bf7-89e6-c4bce06e1641",
  type1: "45fc3f4a-d48f-5bd2-ae3f-ac7c9df2bf27",
  recipe: "e26d4b4a-1901-7c2e-589b-9fc6570fa072",
  version: "aa023aaf-3092-eca4-bd88-a26266c8a9de",
  siblingRecipe: "527c4913-390a-8ed9-5785-79f852f96f78",
  siblingVersion: "cdeb6cfb-2ebd-6209-2b53-f91330e7e80f",
  line: "b72261a4-a7b1-5a0d-14ae-0b692dc52a13",
  beef: "f4c7852a-9a29-5eb4-b755-9720b3597224",
  pork: "1edd7b1a-c5c9-00aa-2132-635144259d32",
  unit: "a1020000-0000-4000-8000-000000000205",
  otherIngredients: [
    ["97c696ec-aca7-5d48-b126-738aeb2c3ff8", 2],
    ["bbfaac09-63c4-52f7-8f70-0eb48b8ff94d", 2],
    ["1789d578-0028-5920-b950-eb9dad6d460a", 1],
    ["f5f34dd6-8a64-517c-a8a6-8de369da96e1", 0.1],
  ],
};
const COMMAND_ID = "a3529000-2026-4000-8000-000000000001";
const CORRELATION_ID = "a3529000-2026-4000-8000-000000000002";
const same = (a, b) => canonicalMasterJson(a) === canonicalMasterJson(b);
const hash = (value) =>
  createHash("sha256").update(canonicalMasterJson(value)).digest("hex");
function fail(code) {
  throw Error(`RECIPE3529_${code}`);
}
function requireThat(condition, code) {
  if (!condition) fail(code);
}

export function recipe3529Proposal() {
  return {
    adjustment_id: "a3529000-2026-4000-8000-000000000003",
    revision_id: "a3529000-2026-4000-8000-000000000004",
    scope_kind: "SYSTEM_DISH",
    action_kind: "REPLACE",
    dish_id: RECIPE3529.dish,
    school_type_id: RECIPE3529.type2,
    school_id: null,
    target_ingredient_id: null,
    target_recipe_line_id: RECIPE3529.line,
    adjustment_line_id: null,
    substitute_ingredient_id: RECIPE3529.pork,
    quantity_per_basis: null,
    unit_id: null,
    effective_from: "2026-11-09",
    effective_to: null,
    reason_code: "OWNER_CONFIRMED_RECIPE3529_PORK",
    reason_note:
      "Chủ sở hữu xác nhận dùng thịt heo xay cho công thức 3529, món 2071, loại trường 2. Thay thịt bò bằng Nạc vai heo xay (1208) từ ngày 09/11/2026; giữ nguyên 5,5 kg/100 suất và các nguyên liệu còn lại.",
    source_evidence: {
      source_kind: "ATLAS_OPERATOR",
      decision_date: "2026-11-09",
      owner_confirmation: "thịt heo xay nha",
      decision_scope: "Recipe3529 / Dish2071 / SchoolType2",
      source_recipe_id: "3529",
      source_recipe_line_id: "14590",
      previous_ingredient_id: "1037",
      confirmed_ingredient_id: "1208",
      confirmation_basis:
        "New Owner decision; Type1 already uses current Ingredient1208. Source global order14 selected 1208 over retired1040.",
    },
  };
}

function validateResolution(r, type, date) {
  const second = type === RECIPE3529.type2,
    selected = r?.selected_recipe;
  requireThat(
    r?.status === "READY" &&
      r.historical === false &&
      r.as_of_date === date &&
      r.dish_id === RECIPE3529.dish &&
      r.school_type_id === type &&
      r.school_id === null &&
      Array.isArray(r.blockers) &&
      r.blockers.length === 0 &&
      Array.isArray(r.warnings) &&
      selected?.dish_id === RECIPE3529.dish &&
      selected.school_type_id === type &&
      selected.school_type_code ===
        (second ? "v1-school-type-2" : "v1-school-type-1") &&
      selected.recipe_id ===
        (second ? RECIPE3529.recipe : RECIPE3529.siblingRecipe) &&
      selected.recipe_version_id ===
        (second ? RECIPE3529.version : RECIPE3529.siblingVersion) &&
      selected.selection_scope === "SCHOOL_TYPE" &&
      selected.basis_portions === 100 &&
      Array.isArray(r.lines) &&
      r.lines.length === 5,
    "CANONICAL_CONTEXT_DRIFT",
  );
  const quantities = new Map([
    ...RECIPE3529.otherIngredients,
    [second ? RECIPE3529.beef : RECIPE3529.pork, 5.5],
  ]);
  const ids = new Set();
  for (const line of r.lines) {
    requireThat(
      typeof line.base_recipe_line_id === "string" &&
        !ids.has(line.base_recipe_line_id) &&
        line.selected_dish_id === RECIPE3529.dish &&
        line.selected_recipe_id === selected.recipe_id &&
        line.selected_recipe_version_id === selected.recipe_version_id &&
        line.basis_portions === 100 &&
        line.adjustment_line_id === null &&
        line.base_disposition === "PRESENT" &&
        line.final_disposition === "PRESENT" &&
        line.base_unit_id === RECIPE3529.unit &&
        line.final_unit_id === RECIPE3529.unit &&
        quantities.has(line.final_ingredient_id) &&
        line.base_ingredient_id === line.final_ingredient_id &&
        line.final_quantity_per_basis ===
          quantities.get(line.final_ingredient_id) &&
        line.base_quantity_per_basis === line.final_quantity_per_basis &&
        Array.isArray(line.lineage) &&
        Array.isArray(line.applied_adjustment_ids) &&
        Array.isArray(line.applied_revision_ids),
      "CANONICAL_LINE_DRIFT",
    );
    ids.add(line.base_recipe_line_id);
    quantities.delete(line.final_ingredient_id);
  }
  requireThat(
    quantities.size === 0 &&
      (!second ||
        r.lines.some(
          (line) =>
            line.base_recipe_line_id === RECIPE3529.line &&
            line.final_ingredient_id === RECIPE3529.beef &&
            line.lineage.length === 0 &&
            line.applied_adjustment_ids.length === 0 &&
            line.applied_revision_ids.length === 0 &&
            line.source_layer === "RELEASED_RECIPE_VERSION",
        )),
    "STABLE_TARGET_DRIFT",
  );
}

// This exact delta check validates backend output; it never selects or resolves a Recipe.
function expectedCorrection(before, isPreview) {
  const result = structuredClone(before),
    proposal = recipe3529Proposal();
  const line = result.lines.find(
    (l) => l.base_recipe_line_id === RECIPE3529.line,
  );
  requireThat(line, "STABLE_TARGET_MISSING");
  const values = (ingredient) => ({
    ingredient_id: ingredient,
    quantity_per_basis: 5.5,
    unit_id: RECIPE3529.unit,
    disposition: "PRESENT",
  });
  line.final_ingredient_id = RECIPE3529.pork;
  line.source_layer = "SYSTEM_DISH";
  line.applied_adjustment_ids.push(proposal.adjustment_id);
  line.applied_revision_ids.push(proposal.revision_id);
  line.lineage.push({
    adjustment_id: proposal.adjustment_id,
    revision_id: proposal.revision_id,
    revision_number: 1,
    scope_kind: "SYSTEM_DISH",
    action_kind: "REPLACE",
    before: values(RECIPE3529.beef),
    after: values(RECIPE3529.pork),
    reason_code: proposal.reason_code,
    reason_note: proposal.reason_note,
    effective_from: proposal.effective_from,
    effective_to: null,
    is_preview: isPreview,
  });
  return result;
}

export function buildRecipe3529Plan({ contexts, preview, subject, commitSha }) {
  requireThat(
    UUID.test(subject ?? "") && /^[a-f0-9]{40}$/.test(commitSha ?? ""),
    "PLAN_IDENTITY_INVALID",
  );
  requireThat(
    Array.isArray(contexts) && contexts.length === 4,
    "CONTEXTS_REQUIRED",
  );
  let index = 0;
  for (const type of [RECIPE3529.type1, RECIPE3529.type2])
    for (const date of ["2026-11-08", "2026-11-09"])
      validateResolution(contexts[index++], type, date);
  const proposal = recipe3529Proposal();
  requireThat(
    preview?.can_save === true &&
      preview.affected_line_count === 1 &&
      preview.as_of_date === "2026-11-09" &&
      preview.dish_id === RECIPE3529.dish &&
      preview.school_type_id === RECIPE3529.type2 &&
      preview.school_id === null &&
      Array.isArray(preview.blockers) &&
      preview.blockers.length === 0 &&
      same(preview.proposed_adjustment, proposal) &&
      same(preview.before, contexts[3]) &&
      same(preview.after, expectedCorrection(contexts[3], true)),
    "PREVIEW_DRIFT",
  );
  const { reason_code, reason_note, ...payload } = proposal;
  const command = {
    contract_version: "RMVP-02B.v1",
    command_id: COMMAND_ID,
    correlation_id: CORRELATION_ID,
    idempotency_key: "atlas-owner-recipe3529-pork-20261109",
    expected_version: 1,
    requested_by_auth_subject: subject,
    reason_code,
    reason_note,
    payload: {
      ...payload,
      as_of_date: "2026-11-09",
      preview_dish_id: RECIPE3529.dish,
      preview_school_type_id: RECIPE3529.type2,
      preview_school_id: null,
    },
  };
  return {
    command,
    plan_checksum: hash({
      contract_version: CONTRACT,
      target: STAGING,
      commit_sha: commitSha,
      command,
      contexts,
      preview,
    }),
  };
}

async function jsonRequest(fetchImpl, url, options, failure) {
  try {
    const response = await fetchImpl(url, {
      ...options,
      redirect: "error",
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) fail(failure);
    return await response.json();
  } catch {
    fail(failure);
  }
}

export async function runRecipe3529Correction({
  commitSha,
  apply = false,
  planChecksum,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  fetchImpl = fetch,
  verifyCheckout = verifyExactMainCheckout,
  verifyCertification = verifyExactHeadCertification,
} = {}) {
  const target = validateApprovedAtlasStagingTarget(
    environment.ATLAS_STAGING_PROJECT_REF,
    environment.VITE_SUPABASE_URL,
  );
  const key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  requireThat(
    environment.VITE_ATLAS_ENVIRONMENT === "staging" &&
      typeof key === "string" &&
      /^sb_publishable_[A-Za-z0-9_-]{8,}$/.test(key) &&
      typeof environment.ATLAS_STAGING_TEST_EMAIL === "string" &&
      environment.ATLAS_STAGING_TEST_EMAIL.includes("@") &&
      typeof environment.ATLAS_STAGING_TEST_PASSWORD === "string" &&
      environment.ATLAS_STAGING_TEST_PASSWORD.length > 0,
    "PROTECTED_VALUES_INVALID",
  );
  requireThat(
    apply
      ? targetConfirmation === STAGING && SHA256.test(planChecksum ?? "")
      : planChecksum === undefined && targetConfirmation === undefined,
    "REVIEWED_APPLY_INPUTS_REQUIRED",
  );
  const certify = async () => {
    await verifyCheckout({ commitSha, cwd });
    await verifyCertification({
      commitSha,
      certificationMode: "github",
      environment,
      cwd,
    });
  };
  await certify();
  const base = target.supabaseUrl;
  const login = await jsonRequest(
    fetchImpl,
    `${base}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: environment.ATLAS_STAGING_TEST_EMAIL,
        password: environment.ATLAS_STAGING_TEST_PASSWORD,
      }),
    },
    "AUTH_SIGNIN_FAILED",
  );
  requireThat(
    typeof login?.access_token === "string" && login.access_token.length > 0,
    "AUTH_SIGNIN_FAILED",
  );
  const headers = {
    apikey: key,
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
    requireThat(
      UUID.test(user?.id ?? "") &&
        user.id === login.user?.id &&
        user.email?.toLowerCase() ===
          environment.ATLAS_STAGING_TEST_EMAIL.toLowerCase(),
      "AUTH_SUBJECT_MISMATCH",
    );
    const rpc = async (name, request, failure) => {
      const result = await jsonRequest(
        fetchImpl,
        `${base}/rest/v1/rpc/${name}`,
        {
          method: "POST",
          headers: { ...headers, "Content-Profile": "atlas_api" },
          body: JSON.stringify({ request }),
        },
        failure,
      );
      requireThat(
        result?.success === true,
        name === "create_recipe_composition_adjustment"
          ? "COMMAND_REJECTED"
          : failure,
      );
      return result;
    };
    const readRequest = (contract, payload) => ({
      contract_version: contract,
      correlation_id: CORRELATION_ID,
      requested_by_auth_subject: user.id,
      payload,
    });
    const readContexts = async () => {
      const rows = [];
      for (const type of [RECIPE3529.type1, RECIPE3529.type2])
        for (const date of ["2026-11-08", "2026-11-09"])
          rows.push(
            (
              await rpc(
                "resolve_system_effective_recipe_composition",
                readRequest("RECIPE-EFFECTIVE.v1", {
                  as_of_date: date,
                  dish_id: RECIPE3529.dish,
                  school_type_id: type,
                }),
                "CANONICAL_READ_FAILED",
              )
            ).resolution,
          );
      return rows;
    };
    const readPlan = async () => {
      const contexts = await readContexts();
      const result = await rpc(
        "preview_recipe_composition_adjustment",
        readRequest("RMVP-02B.v1", {
          as_of_date: "2026-11-09",
          dish_id: RECIPE3529.dish,
          school_type_id: RECIPE3529.type2,
          proposed_adjustment: recipe3529Proposal(),
        }),
        "PREVIEW_REJECTED",
      );
      return {
        contexts,
        ...buildRecipe3529Plan({
          contexts,
          preview: result.preview,
          subject: user.id,
          commitSha,
        }),
      };
    };
    const plan = await readPlan();
    const summary = {
      contract_version: CONTRACT,
      plan_checksum: plan.plan_checksum,
      command_id: COMMAND_ID,
      adjustment_id: recipe3529Proposal().adjustment_id,
      revision_id: recipe3529Proposal().revision_id,
      effective_from: "2026-11-09",
      context_count: 4,
      replacement: {
        source_recipe: "3529",
        dish: "2071",
        school_type: "2",
        stable_line: RECIPE3529.line,
        ingredient_before: "1037",
        ingredient_after: "1208",
        quantity_kg_per_100: 5.5,
      },
      owner_confirmation: "thịt heo xay nha",
    };
    if (!apply) return { status: "PREVIEW", ...summary };
    requireThat(plan.plan_checksum === planChecksum, "REVIEWED_PLAN_DRIFT");
    await certify();
    const fresh = await readPlan();
    requireThat(fresh.plan_checksum === planChecksum, "FRESH_PLAN_DRIFT");
    const request = {
      ...fresh.command,
      requested_at: new Date().toISOString(),
    };
    const applied = await rpc(
      "create_recipe_composition_adjustment",
      request,
      "APPLY_OUTCOME_UNKNOWN",
    );
    requireThat(
      applied.command_id === COMMAND_ID &&
        applied.correlation_id === CORRELATION_ID &&
        applied.contract_version === "RMVP-02B.v1" &&
        applied.idempotency_status === "COMPLETED" &&
        applied.affected_aggregate_ids?.recipe_composition_adjustment_id ===
          recipe3529Proposal().adjustment_id &&
        applied.new_versions?.aggregate_version === 1 &&
        Array.isArray(applied.emitted_event_ids) &&
        applied.emitted_event_ids.length === 1 &&
        UUID.test(applied.emitted_event_ids[0]) &&
        Array.isArray(applied.audit_event_ids) &&
        applied.audit_event_ids.length === 1 &&
        UUID.test(applied.audit_event_ids[0]),
      "APPLY_RECEIPT_INVALID",
    );
    // Replay only a known successful command; unknown transport outcomes require receipt investigation.
    const replay = await rpc(
      "create_recipe_composition_adjustment",
      request,
      "REPLAY_OUTCOME_UNKNOWN",
    );
    requireThat(same(applied, replay), "REPLAY_DRIFT");
    const after = await readContexts(),
      expected = structuredClone(plan.contexts);
    expected[3] = expectedCorrection(expected[3], false);
    requireThat(same(after, expected), "READBACK_DRIFT");
    return {
      status: "APPLIED",
      ...summary,
      replay_verified: true,
      readback_verified: true,
      emitted_event_ids: applied.emitted_event_ids,
      audit_event_ids: applied.audit_event_ids,
    };
  } catch (error) {
    primaryFailure = error;
    throw error;
  } finally {
    try {
      const response = await fetchImpl(`${base}/auth/v1/logout?scope=local`, {
        method: "POST",
        headers,
        redirect: "error",
        signal: AbortSignal.timeout(15_000),
      });
      requireThat(response.ok, "AUTH_SIGNOUT_FAILED");
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
    const flags = new Map(),
      args = process.argv.slice(2);
    for (let index = 0; index < args.length; index++) {
      const flag = args[index];
      requireThat(
        !flags.has(flag) &&
          [
            "--commit-sha",
            "--apply",
            "--plan-checksum",
            "--target-project-ref",
          ].includes(flag),
        "INVALID_ARGUMENT",
      );
      if (flag === "--apply") flags.set(flag, true);
      else {
        requireThat(
          args[index + 1] && !args[index + 1].startsWith("--"),
          "INVALID_ARGUMENT",
        );
        flags.set(flag, args[++index]);
      }
    }
    console.log(
      JSON.stringify(
        await runRecipe3529Correction({
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
    // Fixed diagnostics only: never print server bodies, credentials or session tokens.
    console.error(
      /^RECIPE3529_[A-Z_]+$/.test(error.message)
        ? error.message
        : "RECIPE3529_PRECONDITION_FAILED",
    );
    process.exitCode = 1;
  }
}
