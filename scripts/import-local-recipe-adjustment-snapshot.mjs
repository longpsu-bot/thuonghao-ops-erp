import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { runPinnedSupabase } from "./local-supabase-status.mjs";

const delimiter = "$rmvp_02b_snapshot$";

function snapshotPath(argv) {
  const fileIndex = argv.indexOf("--file");
  if (fileIndex === -1 || !argv[fileIndex + 1]) {
    throw new Error(
      "Provide one explicit OPS v1 adjustment snapshot with --file. Live legacy connections are not supported.",
    );
  }
  return resolve(argv[fileIndex + 1]);
}

function readSnapshot(filePath) {
  let snapshot;
  try {
    snapshot = JSON.parse(readFileSync(filePath, "utf8"));
  } catch {
    throw new Error(
      "The explicit Recipe adjustment snapshot is not valid JSON.",
    );
  }
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) {
    throw new Error("The Recipe adjustment snapshot must be a JSON object.");
  }
  const unsigned = { ...snapshot };
  delete unsigned.snapshot_checksum;
  const json = JSON.stringify(unsigned);
  if (json.includes(delimiter)) {
    throw new Error("The snapshot contains a reserved importer delimiter.");
  }
  return { unsigned, json };
}

function checksumFor(json, workingDirectory) {
  const sqlPath = join(workingDirectory, "checksum.sql");
  writeFileSync(
    sqlPath,
    [
      "select pg_catalog.encode(",
      "  extensions.digest(",
      `    pg_catalog.convert_to((${delimiter}${json}${delimiter}::jsonb)::text, 'UTF8'),`,
      "    'sha256'",
      "  ),",
      "  'hex'",
      ");",
      "",
    ].join("\n"),
    "utf8",
  );
  const output = runPinnedSupabase(
    ["db", "query", "--local", "--output-format", "json", "--file", sqlPath],
    {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "inherit"],
    },
  );
  const checksum = output.match(/\b[0-9a-f]{64}\b/i)?.[0]?.toLowerCase();
  if (!checksum) {
    throw new Error(
      "The local database could not calculate the canonical snapshot checksum.",
    );
  }
  return checksum;
}

function importResultFor(signedJson, workingDirectory) {
  const sqlPath = join(workingDirectory, "import.sql");
  writeFileSync(
    sqlPath,
    [
      "select atlas_legacy.import_recipe_adjustment_snapshot(",
      `  ${delimiter}${signedJson}${delimiter}::jsonb`,
      ") as result;",
      "",
    ].join("\n"),
    "utf8",
  );
  const output = runPinnedSupabase(
    ["db", "query", "--local", "--output-format", "json", "--file", sqlPath],
    {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "inherit"],
    },
  );
  let result;
  try {
    const envelope = JSON.parse(output);
    result = envelope.rows?.[0]?.result;
  } catch {
    throw new Error(
      "The local Recipe adjustment importer returned an unreadable result.",
    );
  }
  if (!result || typeof result !== "object" || Array.isArray(result)) {
    throw new Error(
      "The local Recipe adjustment importer returned no result object.",
    );
  }
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== "COMPLETED" && result.status !== "REPLAYED") {
    throw new Error(
      `The local Recipe adjustment import was rejected: ${result.validation_errors?.[0]?.code ?? "UNKNOWN"}.`,
    );
  }
}

function main() {
  const filePath = snapshotPath(process.argv.slice(2));
  const { unsigned, json } = readSnapshot(filePath);
  const workingDirectory = mkdtempSync(
    join(tmpdir(), "atlas-rmvp-02b-import-"),
  );
  try {
    const snapshot = {
      ...unsigned,
      snapshot_checksum: checksumFor(json, workingDirectory),
    };
    const signedJson = JSON.stringify(snapshot);
    importResultFor(signedJson, workingDirectory);
  } finally {
    rmSync(workingDirectory, { recursive: true, force: true });
  }
}

try {
  main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "The local Recipe adjustment import failed safely.",
  );
  process.exitCode = 1;
}
