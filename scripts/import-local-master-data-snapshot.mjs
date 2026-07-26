import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { runPinnedSupabase } from "./local-supabase-status.mjs";

function snapshotPath(argv) {
  const fileIndex = argv.indexOf("--file");
  if (fileIndex === -1 || !argv[fileIndex + 1]) {
    throw new Error(
      "Provide one explicit snapshot path with --file. Live legacy connections are not supported.",
    );
  }
  return resolve(argv[fileIndex + 1]);
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function preparedSnapshot(filePath) {
  let snapshot;
  try {
    snapshot = JSON.parse(readFileSync(filePath, "utf8"));
  } catch {
    throw new Error("The explicit master-data snapshot is not valid JSON.");
  }
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) {
    throw new Error("The master-data snapshot must be a JSON object.");
  }
  const unsigned = { ...snapshot };
  delete unsigned.snapshot_checksum;
  const canonicalJson = JSON.stringify(canonicalize(unsigned));
  const checksum = createHash("sha256").update(canonicalJson).digest("hex");
  return { ...unsigned, snapshot_checksum: checksum };
}

function main() {
  const filePath = snapshotPath(process.argv.slice(2));
  const snapshot = preparedSnapshot(filePath);
  const json = JSON.stringify(snapshot);
  if (json.includes("$rmvp_snapshot$")) {
    throw new Error("The snapshot contains a reserved importer delimiter.");
  }

  const workingDirectory = mkdtempSync(join(tmpdir(), "atlas-rmvp-01-"));
  const sqlPath = join(workingDirectory, "import.sql");
  try {
    writeFileSync(
      sqlPath,
      [
        "select pg_catalog.jsonb_pretty(",
        "  atlas_legacy.import_master_data_snapshot(",
        `    $rmvp_snapshot$${json}$rmvp_snapshot$::jsonb`,
        "  )",
        ");",
        "",
      ].join("\n"),
      "utf8",
    );
    runPinnedSupabase(["db", "query", "--local", "--file", sqlPath], {
      stdio: "inherit",
    });
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
      : "The local master-data snapshot import failed safely.",
  );
  process.exitCode = 1;
}
