import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import path from "node:path";
import {
  buildPreparationProbe,
  buildDualOperationalAcceptance,
  snapshotSql,
} from "./diagnose-confirmed-need-preparation.mjs";
import {
  completePurchaseReviewTap,
  expand,
} from "./test-local-purchase-review.mjs";

const container = "atlas-c395-option-a";
const mode = process.argv[2];
const directory = process.env.C395_EVIDENCE_DIR;
if (
  !directory ||
  !["baseline", "focused", "operational", "stress"].includes(mode)
)
  throw new Error(
    "Set C395_EVIDENCE_DIR and choose a bounded certification gate.",
  );
const config = JSON.parse(
  execFileSync("docker", ["inspect", container], { encoding: "utf8" }),
)[0];
if (
  config.HostConfig.NetworkMode !== "none" ||
  Object.keys(config.NetworkSettings.Ports ?? {}).some(
    (key) => config.NetworkSettings.Ports[key],
  )
)
  throw new Error(
    "Require the task-owned network-isolated container without published ports.",
  );
mkdirSync(directory, { recursive: true });
const hash = (text) => createHash("sha256").update(text).digest("hex");
const save = (name, value) =>
  writeFileSync(
    path.join(directory, name),
    typeof value === "string" ? value : JSON.stringify(value, null, 2),
  );
const args = (db) => [
  "exec",
  "-i",
  container,
  "psql",
  "-X",
  "-qAt",
  "-v",
  "ON_ERROR_STOP=1",
  "-U",
  "postgres",
  "-d",
  db,
];
function sql(text, db, name) {
  const result = spawnSync("docker", args(db), {
    input: text,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 600000,
  });
  save(`${name}.log`, (result.stdout ?? "") + (result.stderr ?? ""));
  return result;
}
function snapshot(db, name) {
  const result = sql(snapshotSql, db, name);
  if (result.status !== 0) throw new Error(`${name} snapshot failed`);
  const image = JSON.parse(result.stdout.trim());
  save(`${name}.json`, image);
  return image;
}
function run(name, text, db, assertions) {
  const before = snapshot(db, `${name}-before`);
  save(`${name}.sql`, text);
  const began = performance.now();
  const result = sql(text, db, name);
  const wallMs = performance.now() - began;
  const after = snapshot(db, `${name}-after`);
  const parity = ["roles", "memberships", "schemas", "functions", "rows"].every(
    (key) => JSON.stringify(before[key]) === JSON.stringify(after[key]),
  );
  const output = result.stdout ?? "";
  const count = output
    .split(/\r?\n/)
    .filter((line) => /^ok\s+\d+\b/.test(line)).length;
  const complete =
    assertions === 0
      ? result.status === 0
      : completePurchaseReviewTap(output, result.status) &&
        count === assertions;
  const item = {
    name,
    sqlSha256: hash(text),
    exitCode: result.status,
    wallMs,
    assertions: count,
    complete,
    rollbackAndCatalogParity: parity,
    pass: complete && parity,
  };
  save(`${name}-result.json`, item);
  console.log(JSON.stringify(item));
  return item;
}

if (mode === "baseline") {
  const name = "baseline-preparation";
  if (existsSync(path.join(directory, `${name}-result.json`)))
    throw new Error("Baseline already measured; no automatic rerun.");
  run(name, buildPreparationProbe("baseline").sql, "c395_baseline", 0);
} else if (mode === "focused") {
  const results = [];
  for (const [name, assertions] of [
    ["confirmed_need_correction", 103],
    ["confirmed_need_correction_continuity", 137],
    ["confirmed_need_correction_consumers", 58],
    ["atlas_current_platform_security_catalog", 31],
    ["school_catering_purchase_orders", 155],
    ["rmvp_07_connected_confirmed_need_approval_release", 67],
    ["d037_confirmed_need_save_release_boundary", 37],
    ["issue_395_phase_context_parity", 9],
  ]) {
    const recorded = path.join(directory, `${name}-result.json`);
    if (existsSync(recorded)) {
      const previous = JSON.parse(readFileSync(recorded));
      if (previous.pass) {
        results.push(previous);
        continue;
      }
    }
    let text = expand(`supabase/tests/${name}.sql`);
    if (
      [
        "rmvp_07_connected_confirmed_need_approval_release",
        "d037_confirmed_need_save_release_boundary",
      ].includes(name)
    )
      text = text.replace(
        /^begin;/m,
        `begin;\n${expand("supabase/local/pa_06b_synthetic_identity.sql")}\n${expand("supabase/local/rmvp_05_browser_fixture.sql")}\nset constraints all deferred;`,
      );
    const result = run(name, text, "c395_candidate", assertions);
    results.push(result);
    if (!result.pass) break;
  }
  save("focused-summary.json", {
    pass: results.length === 8 && results.every((result) => result.pass),
    assertions: results.reduce((sum, result) => sum + result.assertions, 0),
    results,
  });
} else if (mode === "operational") {
  if (
    !JSON.parse(readFileSync(path.join(directory, "focused-summary.json"))).pass
  )
    throw new Error("Focused gate must pass first.");
  if (existsSync(path.join(directory, "dual-operational-result.json")))
    throw new Error("Operational strategy already measured; stop for Owner.");
  const { sql: text } = buildDualOperationalAcceptance();
  run("dual-operational", text, "c395_candidate", 36);
} else {
  if (
    !JSON.parse(readFileSync(path.join(directory, "focused-summary.json")))
      .pass ||
    !JSON.parse(
      readFileSync(path.join(directory, "dual-operational-result.json")),
    ).pass
  )
    throw new Error(
      "Both operational corrections and focused suites must pass before stress.",
    );
  if (existsSync(path.join(directory, "historical-stress-result.json")))
    throw new Error("Stress oracle already attempted; no automatic rerun.");
  const text = expand("supabase/tests/confirmed_need_correction_scale.sql");
  if (
    hash(text) !==
    "be82e771b059fe78c2b6353642a820c8a824257c9fe441241fa92963751589cb"
  )
    throw new Error("Original stress hash drifted.");
  run("historical-stress", text, "c395_candidate", 20);
}
