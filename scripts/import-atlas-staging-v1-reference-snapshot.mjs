import { fileURLToPath } from "node:url";
import {
  defaultCommandRunner,
  executeAtlasStagingManagementSql,
  redactAtlasStagingDiagnostic,
  requireExactCommitSha,
} from "./atlas-staging-contract.mjs";
import { extractV1ReferenceSnapshot } from "./atlas-staging-v1-reference-source.mjs";
import {
  buildTargetApplySql,
  compareManifestToTarget,
  readV1ReferenceTargetState,
  validateV1ReferenceImportRequest,
} from "./atlas-staging-v1-reference-target.mjs";
import {
  formatImportReport,
  transformV1ReferenceSnapshot,
} from "./atlas-staging-v1-reference-transform.mjs";

function commandSuccess(runCommand, cwd, args, message) {
  const result = runCommand("git", args, { cwd, shell: false });
  if (result.status !== 0) throw new Error(message);
  return String(result.stdout ?? "").trim();
}

export function verifyExactMainCheckout({
  commitSha: commitShaValue,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
} = {}) {
  const commitSha = requireExactCommitSha(commitShaValue);
  commandSuccess(
    runCommand,
    cwd,
    ["fetch", "--no-tags", "origin", "main:refs/remotes/origin/main"],
    "The current origin/main cannot be fetched.",
  );
  commandSuccess(
    runCommand,
    cwd,
    ["cat-file", "-e", `${commitSha}^{commit}`],
    "The requested import commit is unavailable.",
  );
  const head = commandSuccess(
    runCommand,
    cwd,
    ["rev-parse", "HEAD"],
    "The import checkout cannot be verified.",
  );
  const currentMain = commandSuccess(
    runCommand,
    cwd,
    ["rev-parse", "origin/main"],
    "The current origin/main cannot be verified.",
  );
  if (head !== commitSha) {
    throw new Error(
      "The import checkout is not at the requested exact commit.",
    );
  }
  if (currentMain !== commitSha) {
    throw new Error("The requested import commit is not current origin/main.");
  }
  commandSuccess(
    runCommand,
    cwd,
    ["merge-base", "--is-ancestor", commitSha, "origin/main"],
    "The requested import commit is not contained in origin/main.",
  );
  const status = commandSuccess(
    runCommand,
    cwd,
    ["status", "--porcelain"],
    "The import worktree cannot be verified.",
  );
  if (status) throw new Error("The import worktree is not clean.");
  return commitSha;
}

async function executeTargetSql({ target, sql, fetchImpl }) {
  return executeAtlasStagingManagementSql(target, sql, fetchImpl);
}

export async function runAtlasStagingV1ReferenceImport({
  commitSha,
  apply = false,
  applyFlagPresent = false,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
  fetchImpl = fetch,
  verifyCheckout = verifyExactMainCheckout,
  extractSnapshot = extractV1ReferenceSnapshot,
  readTarget = readV1ReferenceTargetState,
  executeTargetSql: executeTarget = executeTargetSql,
} = {}) {
  const request = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent,
    targetConfirmation,
  });
  verifyCheckout({ commitSha, cwd, runCommand });
  const snapshot = await extractSnapshot({
    projectRef: request.sourceProjectRef,
    accessToken: request.targetAccessToken,
    fetchImpl,
  });
  const manifest = transformV1ReferenceSnapshot(snapshot);
  const target = {
    projectRef: request.targetProjectRef,
    supabaseUrl: request.targetSupabaseUrl,
    accessToken: request.targetAccessToken,
  };
  const before = await readTarget({ target, fetchImpl });
  const comparison = compareManifestToTarget(manifest, before);

  if (!apply) {
    return {
      status: "dry-run",
      manifest,
      comparison,
      report: formatImportReport({ manifest, comparison, mode: "dry-run" }),
    };
  }
  if (manifest.metadata.blockers.length) {
    throw new Error("The transformed manifest contains apply blockers.");
  }
  if (comparison.totals.conflicts) {
    throw new Error(
      "Atlas Staging target conflicts block the reference import.",
    );
  }
  await executeTarget({
    target,
    sql: buildTargetApplySql(manifest),
    fetchImpl,
  });
  const after = await readTarget({ target, fetchImpl });
  const verified = compareManifestToTarget(manifest, after);
  if (
    verified.totals.inserts ||
    verified.totals.updates ||
    verified.totals.conflicts
  ) {
    throw new Error("Atlas Staging post-apply verification did not reconcile.");
  }
  return {
    status: "applied",
    manifest,
    comparison: verified,
    report: formatImportReport({
      manifest,
      comparison: verified,
      mode: "apply",
    }),
  };
}

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function main() {
  const applyFlagPresent = process.argv.includes("--apply");
  const result = await runAtlasStagingV1ReferenceImport({
    commitSha: argument("--commit-sha"),
    apply: applyFlagPresent,
    applyFlagPresent,
    targetConfirmation: argument("--target-project-ref"),
  });
  console.log(result.report);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Atlas Staging OPS v1 reference import failed safely.",
        [process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN],
      ),
    );
    process.exitCode = 1;
  });
}
