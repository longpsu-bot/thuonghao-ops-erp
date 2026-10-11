import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, writeSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { extractOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
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

export async function runPlanningMasterCatchup({
  commitSha,
  apply = false,
  targetConfirmation,
  snapshotFile,
  snapshotOutput,
  planChecksum,
  actorId,
  environment = process.env,
  cwd = process.cwd(),
  verifyPreview = verifyPlanningPreviewCheckout,
  verifyApply = verifyExactMainCheckout,
  extractSnapshot = extractOpsV1MasterSnapshot,
  executeTarget = executeAtlasStagingPostgres,
  onPhase = () => {},
} = {}) {
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
    if (!snapshotFile || !planChecksum || !actorId)
      throw new Error("REVIEWED_IMMUTABLE_SNAPSHOT_PLAN_AND_ACTOR_REQUIRED");
    if (
      !/^[a-f0-9]{64}$/.test(planChecksum) ||
      !/^[a-f0-9-]{36}$/.test(actorId)
    )
      throw new Error("REVIEWED_PLAN_AND_ACTOR_REQUIRED");
    await phase("CHECKOUT", () => verifyApply({ commitSha, cwd }));
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
  if (apply && installed.length !== expected.length)
    throw new Error("STAGING_FULL_MIGRATION_PARITY_REQUIRED");
  const planSql = await phase("PLAN_BUILD", () =>
    buildPlanningCatchupSql(snapshot, {
      targetProjectRef: target.projectRef,
      apply,
      planChecksum,
      actorId,
    }),
  );
  const result = await phase("PLAN_EXECUTION", () => execute(planSql));
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
        "--target-project-ref",
        "--snapshot-file",
        "--snapshot-output",
        "--plan-checksum",
        "--actor-id",
        "--report-dir",
      ].includes(k)
    )
      throw new Error("INVALID_ARGUMENT");
    if (k === "--apply") flags.set(k, true);
    else {
      const v = args[++i];
      if (!v || v.startsWith("--")) throw new Error("MISSING_ARGUMENT");
      flags.set(k, v);
    }
  }
  const result = await runPlanningMasterCatchup({
    commitSha: flags.get("--commit-sha"),
    apply: flags.has("--apply"),
    targetConfirmation: flags.get("--target-project-ref"),
    snapshotFile: flags.get("--snapshot-file"),
    snapshotOutput: flags.get("--snapshot-output"),
    planChecksum: flags.get("--plan-checksum"),
    actorId: flags.get("--actor-id"),
    // Flush fixed markers before spawnSync can block; never print phase data.
    onPhase: (marker) => writeSync(2, `${marker}\n`),
  });
  if (flags.has("--report-dir")) {
    const dir = resolve(flags.get("--report-dir"));
    writeFileSync(
      resolve(dir, "planning-master-plan.json"),
      JSON.stringify(result, null, 2) + "\n",
      { mode: 0o600, flag: "wx" },
    );
    writeFileSync(
      resolve(dir, "planning-master-report.tsv"),
      formatPlanningCatchupReport(result),
      { mode: 0o600, flag: "wx" },
    );
  }
  const { actions, report, protected: fingerprints, ...summary } = result;
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
