import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";

export function buildCountPolicySql({
  dryRun = false,
  cwd = process.cwd(),
} = {}) {
  const body = readFileSync(
    resolve(cwd, "supabase/packages/staging-count-unit-policies.v1.sql"),
    "utf8",
  );
  return `begin; set local lock_timeout='2s'; set local statement_timeout='8s';
${body}
select jsonb_build_object('policy_count',count(*),'effective_from','2026-09-14') as count_policy_result from atlas_planning.planning_quantity_policy_revisions where planning_step=1 and effective_from='2026-09-14' and policy_revision_status='ACTIVE';
${dryRun ? "rollback" : "commit"};`;
}
export async function installCountPolicies({
  commitSha,
  environment = process.env,
  cwd = process.cwd(),
  dryRun = false,
  executeSql = executeAtlasStagingManagementSql,
} = {}) {
  const target = validateAtlasStagingPackageProtectedValues(environment);
  verifyPackageCheckout({ commitSha, cwd });
  const result = await executeSql(target, buildCountPolicySql({ dryRun, cwd }));
  const rows = JSON.parse(result);
  if (rows?.[0]?.count_policy_result?.policy_count !== 14)
    throw new Error("STAGING_COUNT_POLICY_READBACK_MISMATCH");
  return {
    status: dryRun ? "verified-rollback" : "installed",
    policies: 14,
    effectiveFrom: "2026-09-14",
  };
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const pos = process.argv.indexOf("--commit-sha");
  installCountPolicies({
    commitSha: process.argv[pos + 1],
    dryRun: process.argv.includes("--dry-run"),
  })
    .then((result) => console.log(JSON.stringify(result)))
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error.message));
      process.exitCode = 1;
    });
}
