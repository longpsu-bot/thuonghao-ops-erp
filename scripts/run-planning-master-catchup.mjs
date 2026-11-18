import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, writeSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import {
  checksumOpsV1MasterSnapshot,
  extractOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { verifyExactHeadCertification } from "./atlas-staging-contract.mjs";
import { deterministicV1Uuid } from "./atlas-staging-v1-reference-transform.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import {
  assertPlanningSource,
  buildPlanningCatchupSql,
  planningCatchupPreviewValidationPolicy,
  formatPlanningCatchupReport,
} from "./planning-master-catchup.mjs";

export function planningCatchupFailureCode(error) {
  return /^(?:(?!STAGING_POSTGRES_SQLSTATE_)[A-Z_]+|STAGING_POSTGRES_SQLSTATE_[0-9A-Z]{5})$/.test(
    error?.message ?? "",
  )
    ? error.message
    : "PLANNING_CATCHUP_FAILED";
}

export function verifyPlanningPreviewCheckout(commitSha, cwd = process.cwd()) {
  if (!/^[a-f0-9]{40}$/.test(commitSha ?? ""))
    throw new Error("EXACT_COMMIT_REQUIRED");
  const git = (...args) =>
    execFileSync("git", args, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  git("fetch", "--no-tags", "origin", "main:refs/remotes/origin/main");
  if (git("rev-parse", "HEAD") !== commitSha || git("status", "--porcelain"))
    throw new Error("EXACT_CLEAN_CHECKOUT_REQUIRED");
  git("merge-base", "--is-ancestor", "origin/main", commitSha);
}

function catchupReviewChecksum(commitSha, snapshot, preview) {
  const { snapshot_id, exported_at, extractor_version, ...source } = snapshot;
  const {
    snapshot_id: id,
    snapshot_checksum,
    plan_checksum,
    ...plan
  } = preview;
  // Keep the actual extraction ID in the native write plan. Ignore it for review.
  const stableEvidence = ({ snapshot_id, snapshot_checksum, ...business }) =>
    business;
  const actions = plan.actions.map((action) => {
    if (action.object_type === "RECIPE" && action.source_evidence)
      return {
        ...action,
        source_evidence: stableEvidence(action.source_evidence),
      };
    if (
      action.object_type === "RECIPE_VERSION" &&
      action.values?.source_evidence
    ) {
      const values = {
        ...action.values,
        source_evidence: stableEvidence(action.values.source_evidence),
      };
      return {
        ...action,
        values,
        source_fingerprint: checksumOpsV1MasterSnapshot(values),
      };
    }
    return action;
  });
  return checksumOpsV1MasterSnapshot({
    commitSha,
    source: checksumOpsV1MasterSnapshot(source),
    plan: { ...plan, actions },
  });
}

export async function runPlanningMasterCatchup({
  commitSha,
  apply = false,
  diagnosticBoundary = false,
  targetConfirmation,
  snapshotFile,
  snapshotOutput,
  planChecksum,
  actorId,
  dishLegacyIds,
  reviewedSync = false,
  reviewedPlanChecksum,
  environment = process.env,
  cwd = process.cwd(),
  verifyPreview = verifyPlanningPreviewCheckout,
  verifyApply = verifyExactMainCheckout,
  verifyCertification = verifyExactHeadCertification,
  extractSnapshot = extractOpsV1MasterSnapshot,
  executeTarget = executeAtlasStagingPostgres,
  onPhase = () => {},
} = {}) {
  if (
    reviewedSync &&
    (snapshotFile ||
      snapshotOutput ||
      planChecksum ||
      actorId ||
      dishLegacyIds ||
      diagnosticBoundary)
  )
    throw new Error("REVIEWED_SYNC_REQUIRES_FRESH_MISSING_DISH_SCOPE");
  if (diagnosticBoundary && apply)
    throw new Error("DIAGNOSTIC_BOUNDARY_PREVIEW_ONLY");
  if (diagnosticBoundary) onPhase("PLANNING_CATCHUP_DIAGNOSTIC_BOUNDARY_MODE");
  const phase = async (name, action) => {
    onPhase(`PLANNING_CATCHUP_${name}_START`);
    const value = await action();
    onPhase(`PLANNING_CATCHUP_${name}_DONE`);
    return value;
  };
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  if (apply) {
    if (reviewedSync) {
      if (!/^[a-f0-9]{64}$/.test(reviewedPlanChecksum ?? ""))
        throw new Error("REVIEWED_PLANNING_PLAN_REQUIRED");
    } else if (!snapshotFile || !planChecksum || !actorId)
      throw new Error("REVIEWED_IMMUTABLE_SNAPSHOT_PLAN_AND_ACTOR_REQUIRED");
    if (
      !reviewedSync &&
      (!/^[a-f0-9]{64}$/.test(planChecksum) || !/^[a-f0-9-]{36}$/.test(actorId))
    )
      throw new Error("REVIEWED_PLAN_AND_ACTOR_REQUIRED");
    await phase("CHECKOUT", () => verifyApply({ commitSha, cwd }));
    if (reviewedSync) {
      await verifyCertification({
        commitSha,
        certificationMode: "github",
        environment,
        cwd,
      });
      actorId = deterministicV1Uuid("atlas-staging-master-import-actor");
    }
  } else await phase("CHECKOUT", () => verifyPreview(commitSha, cwd));
  const snapshot = await phase("SOURCE_SNAPSHOT", () =>
    snapshotFile
      ? JSON.parse(readFileSync(resolve(snapshotFile), "utf8"))
      : extractSnapshot({
          accessToken: authority.targetAccessToken,
          snapshotId: `ops-v1-planning-catchup-${environment.GITHUB_RUN_ID ?? Date.now()}-${environment.GITHUB_RUN_ATTEMPT ?? 1}`,
          extractorVersion: commitSha,
        }),
  );
  await phase("SOURCE_VALIDATION", () => {
    assertPlanningSource(snapshot);
    if (snapshotOutput) {
      if (snapshotFile || apply)
        throw new Error("SNAPSHOT_OUTPUT_PREVIEW_ONLY");
      writeFileSync(resolve(snapshotOutput), JSON.stringify(snapshot) + "\n", {
        mode: 0o600,
        flag: "wx",
      });
    }
  });
  const target = {
    projectRef: authority.targetProjectRef,
    supabaseUrl: authority.targetSupabaseUrl,
  };
  const execute = async (sql, options = {}) =>
    parseStagingMasterResult(
      await executeTarget(target, sql, {
        environment,
        cwd,
        onPhase,
        ...options,
      }),
    );
  const migrationState = await phase("TARGET_MIGRATION_PREFLIGHT", () =>
    execute(
      "select jsonb_build_object('migrations',coalesce(jsonb_agg(version order by version),'[]'::jsonb)) as result from supabase_migrations.schema_migrations;",
      { timeoutMs: 45000 },
    ),
  );
  const expected = readdirSync(resolve(cwd, "supabase/migrations"))
    .filter((n) => /^\d{14}_.+\.sql$/.test(n))
    .sort()
    .map((n) => n.slice(0, 14));
  const installed = migrationState.migrations;
  if (
    !Array.isArray(installed) ||
    !installed.length ||
    installed.some((v, i) => v !== expected[i])
  )
    throw new Error("STAGING_MIGRATION_PREFIX_MISMATCH");
  if ((apply || reviewedSync) && installed.length !== expected.length)
    throw new Error("STAGING_FULL_MIGRATION_PARITY_REQUIRED");
  const executePlan = async (applyRequested) => {
    const planSql = await phase("PLAN_BUILD", () =>
      buildPlanningCatchupSql(snapshot, {
        targetProjectRef: target.projectRef,
        apply: applyRequested,
        diagnosticBoundary,
        planChecksum,
        actorId,
        dishLegacyIds,
        includeCatalog: reviewedSync,
      }),
    );
    return phase("PLAN_EXECUTION", () =>
      execute(planSql, diagnosticBoundary ? { timeoutMs: 60000 } : {}),
    );
  };
  let reviewChecksum;
  let result;
  if (reviewedSync) {
    const { dish_legacy_ids: mappedIds } = await phase("MAPPED_DISHES", () =>
      execute(
        "select jsonb_build_object('dish_legacy_ids',coalesce(jsonb_agg(legacy_id),'[]'::jsonb)) as result from atlas_legacy.master_data_mappings where source_system='OPS_V1' and object_type='DISH';",
        { timeoutMs: 45000 },
      ),
    );
    if (
      !Array.isArray(mappedIds) ||
      mappedIds.some((id) => typeof id !== "string")
    )
      throw new Error("STAGING_MAPPED_DISHES_INVALID");
    const mapped = new Set(mappedIds);
    dishLegacyIds = snapshot.records.dishes
      .filter(
        (dish) => dish.dish_status === "ACTIVE" && !mapped.has(dish.legacy_id),
      )
      .map((dish) => dish.legacy_id);
    result = await executePlan(false);
    if (result.success === true) {
      if (
        result.status !== "PREVIEW" ||
        result.snapshot_checksum !== snapshot.snapshot_checksum ||
        !/^[a-f0-9]{64}$/.test(result.plan_checksum ?? "") ||
        !Array.isArray(result.actions) ||
        result.actions.some(
          (action) =>
            ["SCHOOL", "CUSTOMER", "DELIVERY_LOCATION"].includes(
              action.object_type,
            ) ||
            (!["CREATE", "NO_CHANGE"].includes(action.action) &&
              !(
                action.action === "UPDATE" &&
                ["INGREDIENT", "SUPPLIER"].includes(action.object_type)
              )),
        )
      )
        throw new Error("REVIEWED_PLANNING_SCOPE_INVALID");
      if (
        !result.actions.some(
          ({ action }) => action === "CREATE" || action === "UPDATE",
        )
      ) {
        if (apply) throw new Error("REVIEWED_PLANNING_PLAN_MISMATCH");
        return { ...result, status: "NO_CHANGES" };
      }
      reviewChecksum = catchupReviewChecksum(commitSha, snapshot, result);
      if (apply) {
        if (reviewChecksum !== reviewedPlanChecksum)
          throw new Error("REVIEWED_PLANNING_PLAN_MISMATCH");
        planChecksum = result.plan_checksum;
        await phase("CHECKOUT", () => verifyApply({ commitSha, cwd }));
        result = await executePlan(true);
        if (
          result.success === true &&
          (result.status !== "APPLIED" ||
            result.operational_data_unchanged !== true ||
            result.unrelated_master_facts_unchanged !== true)
        )
          throw new Error("REVIEWED_PLANNING_READBACK_FAILED");
      }
    }
  } else result = await executePlan(apply);
  if (
    result.snapshot_checksum &&
    result.snapshot_checksum !== snapshot.snapshot_checksum
  )
    throw new Error("SOURCE_READBACK_MISMATCH");
  if (apply && result.success === true) {
    const replay = await phase("APPLY_REPLAY", () =>
      execute(
        buildPlanningCatchupSql(snapshot, {
          targetProjectRef: target.projectRef,
          apply: true,
          planChecksum,
          actorId,
          dishLegacyIds,
          includeCatalog: reviewedSync,
        }),
      ),
    );
    if (
      replay.success !== true ||
      replay.status !== "REPLAYED" ||
      replay.plan_checksum !== planChecksum
    )
      throw new Error("CATCHUP_REPLAY_FAILED");
    result.replay_status = replay.status;
  }
  if (!result.report && result.error_code === "SOURCE_DEPENDENCY_BLOCKED") {
    const kinds = {
      recipes: "RECIPE",
      ingredients: "INGREDIENT",
      recipe_lines: "RECIPE_LINE",
      schools: "SCHOOL",
      dishes: "DISH",
    };
    result.report = result.issues.map((issue) => {
      const row = snapshot.records[issue.entity]?.find(
        (r) => r.legacy_id === issue.legacy_id,
      );
      const dish = snapshot.records.dishes.find(
        (d) => d.legacy_id === row?.dish_legacy_id,
      );
      const ingredient = snapshot.records.ingredients.find(
        (i) => i.legacy_id === row?.ingredient_legacy_id,
      );
      return {
        SOURCE_SYSTEM: "OPS_V1",
        OBJECT_TYPE: kinds[issue.entity] ?? issue.entity,
        LEGACY_ID: issue.legacy_id,
        SOURCE_NAME:
          row?.ingredient_name ??
          row?.school_name ??
          row?.dish_name ??
          dish?.dish_name ??
          ingredient?.ingredient_name ??
          issue.legacy_id,
        CURRENT_ATLAS_ID: null,
        CURRENT_ATLAS_VALUE: null,
        PROPOSED_ATLAS_ID: null,
        ACTION: "BLOCKED",
        DEPENDENCY_REASON: `${issue.code}: ${issue.field}=${issue.detail ?? "—"}; target plan withheld until source resolution`,
      };
    });
  }
  return {
    ...result,
    ...(reviewChecksum ? { reviewed_plan_checksum: reviewChecksum } : {}),
    ...(diagnosticBoundary
      ? {
          diagnostic_boundary: true,
          execution_mode: "DIAGNOSTIC_PREVIEW",
          backend_status: result.status,
          status: "DIAGNOSTIC_PREVIEW",
        }
      : {}),
    commit_sha: commitSha,
    target_project_ref: target.projectRef,
    migration_count: installed.length,
    migration_tip: installed.at(-1),
    preview_validation_policy: apply
      ? null
      : planningCatchupPreviewValidationPolicy(),
    source: {
      snapshot_id: snapshot.snapshot_id,
      snapshot_checksum: snapshot.snapshot_checksum,
      exported_at: snapshot.exported_at,
      source_counts: snapshot.source_counts,
      empty_recipe_evidence: snapshot.source_diagnostics
        .filter(
          (issue) =>
            issue.severity === "INFO" &&
            issue.code === "SOURCE_RECIPE_EMPTY" &&
            issue.entity === "recipes",
        )
        .map((issue) => ({
          legacy_id: issue.legacy_id,
          source_record_id:
            snapshot.records.recipes.find(
              (r) => r.legacy_id === issue.legacy_id,
            )?.source_record_id ?? issue.detail,
          code: issue.code,
        })),
      canonical_counts: Object.fromEntries(
        Object.entries(snapshot.records).map(([k, v]) => [k, v.length]),
      ),
    },
  };
}

export function writePlanningCatchupReports(result, directory) {
  const dir = resolve(directory);
  writeFileSync(
    resolve(dir, "planning-master-plan.json"),
    JSON.stringify(result, null, 2) + "\n",
    { mode: 0o600, flag: "wx" },
  );
  writeFileSync(
    resolve(
      dir,
      result.diagnostic_boundary
        ? "planning-master-diagnostic-report.tsv"
        : "planning-master-report.tsv",
    ),
    formatPlanningCatchupReport(result),
    { mode: 0o600, flag: "wx" },
  );
}

async function main() {
  const args = process.argv.slice(2).filter((a) => a !== "--"),
    flags = new Map();
  for (let i = 0; i < args.length; i++) {
    const k = args[i];
    if (
      flags.has(k) ||
      ![
        "--commit-sha",
        "--apply",
        "--diagnostic-boundary",
        "--target-project-ref",
        "--snapshot-file",
        "--snapshot-output",
        "--plan-checksum",
        "--actor-id",
        "--dish-legacy-ids",
        "--report-dir",
        "--reviewed-sync",
        "--reviewed-plan-checksum",
      ].includes(k)
    )
      throw new Error("INVALID_ARGUMENT");
    if (["--apply", "--diagnostic-boundary", "--reviewed-sync"].includes(k))
      flags.set(k, true);
    else {
      const v = args[++i];
      if (!v || v.startsWith("--")) throw new Error("MISSING_ARGUMENT");
      flags.set(k, v);
    }
  }
  const result = await runPlanningMasterCatchup({
    commitSha: flags.get("--commit-sha"),
    apply: flags.has("--apply"),
    diagnosticBoundary: flags.has("--diagnostic-boundary"),
    targetConfirmation: flags.get("--target-project-ref"),
    snapshotFile: flags.get("--snapshot-file"),
    snapshotOutput: flags.get("--snapshot-output"),
    planChecksum: flags.get("--plan-checksum"),
    actorId: flags.get("--actor-id"),
    reviewedSync: flags.has("--reviewed-sync"),
    reviewedPlanChecksum: flags.get("--reviewed-plan-checksum"),
    dishLegacyIds: flags.has("--dish-legacy-ids")
      ? flags.get("--dish-legacy-ids").split(",")
      : undefined,
    // Flush fixed markers before spawnSync can block; never print phase data.
    onPhase: (marker) => writeSync(2, `${marker}\n`),
  });
  if (flags.has("--report-dir")) {
    writePlanningCatchupReports(result, flags.get("--report-dir"));
  }
  const { actions, report, protected: fingerprints, ...summary } = result;
  if (flags.has("--reviewed-sync")) {
    if (report)
      summary.planned_changes = report
        .filter(({ ACTION }) => ACTION !== "DEPENDENCY_ONLY")
        .map(({ OBJECT_TYPE, LEGACY_ID, ACTION }) => ({
          object_type: OBJECT_TYPE,
          legacy_id: LEGACY_ID,
          action: ACTION,
        }));
    if (summary.issues)
      summary.issues = summary.issues.map(
        ({ severity, code, entity, legacy_id, object_type, field }) => ({
          severity,
          code,
          entity,
          legacy_id,
          object_type,
          field,
        }),
      );
  }
  console.log(JSON.stringify(summary, null, 2));
  if (result.success !== true) process.exitCode = 2;
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main().catch((e) => {
    console.error(planningCatchupFailureCode(e));
    process.exitCode = 1;
  });
