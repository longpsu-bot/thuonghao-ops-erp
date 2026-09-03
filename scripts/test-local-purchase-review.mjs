import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

// A single rolled-back SQL session keeps shared fixtures out of durable local state.
// Supabase's pgTAP container mounts test files but not their ../local includes.
const root = fileURLToPath(new URL("../", import.meta.url));
function expand(relativeFile) {
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
    "supabase_db_thuonghao-ops-erp",
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
if (
  result.status !== 0 ||
  /^not ok\b/m.test(output) ||
  !/^1\.\.[1-9]\d*$/m.test(output)
)
  process.exitCode = 1;
