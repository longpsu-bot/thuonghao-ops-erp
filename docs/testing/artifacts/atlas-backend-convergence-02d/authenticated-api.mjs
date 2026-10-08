import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SUPABASE_FULL_INTEGRATION_COMMANDS } from "../../../../scripts/certify-supabase-full-integration.mjs";
import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
} from "../../../../scripts/atlas-staging-contract.mjs";
import { parseLocalSupabaseStatus } from "../../../../scripts/local-supabase-status.mjs";

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, "../../../..");
const cycle = process.argv[2];
assert.ok(["1", "2"].includes(cycle));
writeFileSync(path.join(directory, `authenticated-api-${cycle}.json`), "[]\n");
assert.equal(
  process.env.ATLAS_LOCAL_DB_CONTAINER,
  "supabase_db_atlas-backend-convergence-02d",
);
assert.match(
  readFileSync(
    path.join(process.env.SUPABASE_WORKDIR, "supabase/config.toml"),
    "utf8",
  ),
  /^project_id = "atlas-backend-convergence-02d"$/m,
);
const status = defaultCommandRunner(
  "pnpm",
  ["exec", "supabase", "status", "-o", "json"],
  { cwd: root, env: process.env },
);
assert.equal(status.status, 0, redactAtlasStagingDiagnostic(status.stderr));
assert.equal(
  parseLocalSupabaseStatus(status.stdout).apiUrl,
  "http://127.0.0.1:55521",
);
const scripts = new Set([
  "local:auth:provision",
  "local:connection:verify",
  "local:master-data:import",
  "local:rmvp01:verify",
  "local:rmvp02a:verify",
  "local:rmvp02b:verify",
  "local:rmvp03a:verify",
  "local:pantry02:verify",
  "local:rmvp04:verify",
  "local:rmvp05:verify",
  "local:rmvp06:verify",
  "verify:local:rmvp07",
  "local:planning-contract-01:verify",
  "local:school-catering-procurement:verify",
]);
const results = [];
for (const command of SUPABASE_FULL_INTEGRATION_COMMANDS.filter(
  (item) => item.command === "pnpm" && scripts.has(item.args[0]),
)) {
  const result = defaultCommandRunner(command.command, [...command.args], {
    cwd: root,
    env: { ...process.env, ...command.environment },
    shell: process.platform === "win32",
  });
  const diagnostic = redactAtlasStagingDiagnostic(
    `${result.stdout ?? ""}\n${result.stderr ?? ""}`,
  );
  writeFileSync(
    path.join(
      process.env.TEMP,
      "atlas-backend-convergence-02d",
      `api-${cycle}-${results.length}.log`,
    ),
    diagnostic,
  );
  const row = {
    command: [command.command, ...command.args],
    environment: command.environment ?? {},
    exit: result.status,
  };
  results.push(row);
  writeFileSync(
    path.join(directory, `authenticated-api-${cycle}.json`),
    JSON.stringify(results, null, 2) + "\n",
  );
  console.log(JSON.stringify(row));
  assert.equal(result.status, 0, diagnostic);
}
assert.equal(results.length, 15);
console.log(
  "Disposable real Auth/API registry commands PASS; no hosted acceptance claim",
);
