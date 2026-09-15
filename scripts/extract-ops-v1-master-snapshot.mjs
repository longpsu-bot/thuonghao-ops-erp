import { open, unlink } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import {
  extractOpsV1MasterSnapshot,
  checksumOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";

export async function exportOpsV1MasterSnapshotFile({
  output,
  snapshotId,
  extractorVersion,
  accessToken,
  extract = extractOpsV1MasterSnapshot,
} = {}) {
  if (
    typeof output !== "string" ||
    !output.trim() ||
    typeof snapshotId !== "string" ||
    !snapshotId.trim() ||
    typeof extractorVersion !== "string" ||
    !extractorVersion.trim()
  )
    throw new Error("EXPLICIT_OUTPUT_AND_SNAPSHOT_ID_REQUIRED");
  const path = resolve(output);
  let handle;
  try {
    handle = await open(path, "wx", 0o600);
  } catch (error) {
    throw new Error(
      error?.code === "EEXIST" ? "OUTPUT_EXISTS" : "OUTPUT_UNAVAILABLE",
    );
  }
  try {
    const snapshot = await extract({
      accessToken,
      snapshotId,
      extractorVersion,
    });
    if (snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot))
      throw new Error("SNAPSHOT_CHECKSUM_MISMATCH");
    await handle.writeFile(`${JSON.stringify(snapshot, null, 2)}\n`, "utf8");
    await handle.sync();
    return {
      snapshot_id: snapshot.snapshot_id,
      snapshot_checksum: snapshot.snapshot_checksum,
      source_counts: snapshot.source_counts,
      blockers: snapshot.source_diagnostics.filter(
        (d) => d.severity === "BLOCKER",
      ).length,
    };
  } catch (error) {
    await handle.close();
    handle = null;
    await unlink(path);
    throw error;
  } finally {
    if (handle) await handle.close();
  }
}
async function main() {
  const args = process.argv.slice(2).filter((a) => a !== "--");
  if (
    args.length !== 4 ||
    !args.includes("--output") ||
    !args.includes("--snapshot-id")
  )
    throw new Error(
      "Usage: ops:v1:master:snapshot -- --output PATH --snapshot-id ID",
    );
  const value = (name) => args[args.indexOf(name) + 1];
  const extractorVersion = execFileSync("git", ["rev-parse", "HEAD"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
  const result = await exportOpsV1MasterSnapshotFile({
    output: value("--output"),
    snapshotId: value("--snapshot-id"),
    extractorVersion,
    accessToken: process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN,
  });
  console.log(JSON.stringify(result, null, 2));
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main().catch((error) => {
    // Only controlled error codes are printed; upstream bodies/credentials never are.
    const message =
      error instanceof Error && /^[A-Z_0-9: ]+$/.test(error.message)
        ? error.message
        : "SOURCE_EXPORT_FAILED";
    console.error(message);
    process.exitCode = 1;
  });
}
