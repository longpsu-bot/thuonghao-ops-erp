import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// A single rolled-back SQL session keeps shared fixtures out of durable local state.
// Supabase's pgTAP container mounts test files but not their ../local includes.
export function expand(relativeFile) {
  const root = fileURLToPath(new URL("../", import.meta.url));
  const file = path.resolve(root, relativeFile);
  if (!file.startsWith(path.join(root, "supabase") + path.sep)) {
    throw new Error(
      "Test includes must stay inside this repository supabase directory.",
    );
  }
  return readFileSync(file, "utf8").replace(/^\\ir\s+(.+)$/gm, (_, included) =>
    expand(
      path.relative(root, path.resolve(path.dirname(file), included.trim())),
    ),
  );
}
export function completePurchaseReviewTap(output, status) {
  if (status !== 0) return false;
  let expected = null;
  let count = 0;
  let complete = 0;
  for (const raw of output.split(/\r?\n/)) {
    const line = raw.trim();
    if (/^(?:not ok\b|Bail out!)/i.test(line)) return false;
    const plan = /^1\.\.([1-9]\d*)$/.exec(line);
    if (line.startsWith("1..") && !plan) return false;
    if (plan) {
      const size = Number(plan[1]);
      if (expected !== null) {
        if (count !== expected) return false;
        complete++;
        count = 0;
        expected = null;
      }
      if (count > 0) {
        if (count !== size) return false;
        complete++;
        count = 0;
      } else expected = size;
      continue;
    }
    const assertion = /^ok\s+(\d+)\b/.exec(line);
    if (/^ok\b/.test(line) && !assertion) return false;
    if (!assertion) continue;
    if (expected !== null && count === expected) {
      complete++;
      count = 0;
      expected = null;
    }
    if (Number(assertion[1]) !== count + 1) return false;
    count++;
  }
  if (expected !== null) {
    if (count !== expected) return false;
    complete++;
    count = 0;
  }
  return complete > 0 && count === 0;
}

function main() {
  const suite = process.argv[2] ?? "purchase_review_confirm_release.sql";
  if (!/^[a-z0-9_]+\.sql$/.test(suite))
    throw new Error("Use a test filename, not a path.");
  let sql = expand(`supabase/tests/${suite}`);
  if (process.argv[3] && process.argv[3] !== "--existing-fixture")
    throw new Error("Unknown test option.");
  if (
    process.argv[3] !== "--existing-fixture" &&
    [
      "d037_confirmed_need_save_release_boundary.sql",
      "rmvp_06_connected_confirmed_need_validation.sql",
      "rmvp_07_connected_confirmed_need_approval_release.sql",
    ].includes(suite)
  ) {
    const fixtures =
      expand("supabase/local/pa_06b_synthetic_identity.sql") +
      "\n" +
      expand("supabase/local/rmvp_05_browser_fixture.sql");
    sql = sql.replace(
      /^begin;/m,
      `begin;\n${fixtures}\nset constraints all deferred;`,
    );
  }
  const result = spawnSync(
    "docker",
    [
      "exec",
      "-i",
      process.env.ATLAS_LOCAL_DB_CONTAINER ?? "supabase_db_thuonghao-ops-erp",
      "psql",
      "-X",
      "-qAt",
      "-v",
      "ON_ERROR_STOP=1",
      "-U",
      "postgres",
      "-d",
      "postgres",
    ],
    { input: sql, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 },
  );
  const output = result.stdout ?? "";
  process.stdout.write(output);
  if (result.stderr) process.stderr.write(result.stderr);
  if (!completePurchaseReviewTap(output, result.status)) process.exitCode = 1;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
)
  main();
