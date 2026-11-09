// Reconstructs external snapshots only in newly created local Docker databases.
import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildStagingTestCleanupSql,
  CLEANUP_RECOVERY_SHA256,
  CLEANUP_SCHEMA_SHA256,
  CLEANUP_RESTORE_GUARDS_SHA256,
  CLEANUP_TARGET,
  readCleanupRecovery,
  cleanupCodeHashes,
  sha256,
} from "./cleanup-atlas-staging-test-data.mjs";

function checkedDocker(args, input) {
  const result = spawnSync("docker", args, {
    input,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 20 * 60 * 1000,
  });
  if (result.status !== 0 || result.error)
    throw Error(
      `LOCAL_REHEARSAL_FAILED: ${String(result.stderr || result.error?.message).slice(0, 1800)}`,
    );
  return result.stdout;
}
function loadRowsSql(tables, insertColumns) {
  return tables
    .filter((t) => t.row_texts.length)
    .map((t) => {
      if (
        !/^atlas_[a-z_]+\.[a-z_]+$/.test(t.table) ||
        !Array.isArray(t.row_texts)
      )
        throw Error("LOCAL_SNAPSHOT_TABLE_INVALID");
      const fields = insertColumns[t.table];
      if (!Array.isArray(fields) || fields.some((f) => !/^[_a-z0-9]+$/.test(f)))
        throw Error("LOCAL_SNAPSHOT_COLUMN_INVALID");
      const columns = fields.map((f) => `"${f}"`),
        data = Buffer.from("[" + t.row_texts.join(",") + "]").toString(
          "base64",
        );
      return `INSERT INTO ${t.table} (${columns.join(",")}) SELECT ${columns.map((c) => "r." + c).join(",")} FROM jsonb_populate_recordset(null::${t.table},convert_from(decode('${data}','base64'),'UTF8')::jsonb) r;`;
    })
    .join("\n");
}
export async function rehearseLocalCleanup({
  recoveryDirectory,
  protectedDependencies,
  schemaOverlay,
  restoreGuards,
  container = "supabase_db_atlas-master-rehearsal-01",
  commitSha,
  outputPath,
}) {
  if (
    !/^supabase_db_[a-z0-9_-]+$/.test(container) ||
    !/^[a-f0-9]{40}$/.test(commitSha ?? "")
  )
    throw Error("LOCAL_REHEARSAL_ARGUMENT_INVALID");
  const git = (args) => {
    const result = spawnSync("git", args, { encoding: "utf8" });
    if (result.status !== 0) throw Error("LOCAL_PROOF_SOURCE_CHECK_FAILED");
    return result.stdout.trim();
  };
  const sourcePaths = [
    "scripts/cleanup-atlas-staging-test-data.mjs",
    "scripts/rehearse-local-staging-test-cleanup.mjs",
    "supabase/packages/atlas-staging-test-cleanup.sql",
  ];
  if (
    git(["rev-parse", "HEAD"]) !== commitSha ||
    git(["status", "--porcelain", "--", ...sourcePaths])
  )
    throw Error("COMMITTED_EXACT_PROOF_SOURCES_REQUIRED");
  git(["ls-files", "--error-unmatch", "--", ...sourcePaths]);
  const sourceHashes = cleanupCodeHashes();
  const overlay = readFileSync(schemaOverlay, "utf8");
  if (
    sha256(overlay) !==
    "b0d0950664905879f20b58b6c0b8f15dd618f54926bf1c1cdcef05925b08fe3f"
  )
    throw Error("REVIEWED_LOCAL_SCHEMA_OVERLAY_REQUIRED");
  const recovery = readCleanupRecovery(recoveryDirectory);
  const seeds = JSON.parse(readFileSync(protectedDependencies));
  const guards = JSON.parse(readFileSync(restoreGuards));
  if (
    !Array.isArray(seeds) ||
    !Array.isArray(guards) ||
    guards.some(
      (g) =>
        !recovery.some((t) => t.table === g.table) ||
        !/^[_a-z0-9]+$/.test(g.trigger) ||
        !/^[a-f0-9]{64}$/.test(g.function_sha256),
    )
  )
    throw Error("LOCAL_RESTORE_GUARDS_INVALID");
  if (sha256(JSON.stringify(guards)) !== CLEANUP_RESTORE_GUARDS_SHA256)
    throw Error("REVIEWED_RESTORE_GUARDS_REQUIRED");
  const run = (database, sql, user = "postgres") =>
    checkedDocker(
      [
        "exec",
        "-i",
        container,
        "psql",
        "-X",
        "-qAt",
        "-U",
        user,
        "-d",
        database,
        "-v",
        "ON_ERROR_STOP=1",
      ],
      sql,
    );
  const packageSql = readFileSync(
    "supabase/packages/atlas-staging-test-cleanup.sql",
    "utf8",
  );
  const insertColumns = JSON.parse(
    run(
      "postgres",
      `SELECT jsonb_object_agg(table_name,columns) FROM (
    SELECT n.nspname||'.'||c.relname AS table_name,jsonb_agg(a.attname ORDER BY a.attnum) AS columns
    FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname LIKE 'atlas\\_%' ESCAPE '\\' AND c.relkind IN('r','p') AND a.attnum>0 AND NOT a.attisdropped AND a.attgenerated=''
    GROUP BY n.nspname,c.relname) t;`,
    ),
  );
  const versions = readdirSync("supabase/migrations")
    .filter((f) => /^\d{14}_/.test(f))
    .map((f) => f.slice(0, 14))
    .sort();
  const stem = `atlas_cleanup_proof_${Date.now()}`;
  const baseline = stem + "_purge",
    external = stem + "_external";
  const pre = checkedDocker([
    "exec",
    container,
    "pg_dump",
    "-U",
    "postgres",
    "-d",
    "postgres",
    "--schema-only",
    "--section=pre-data",
  ]);
  const post = checkedDocker([
    "exec",
    container,
    "pg_dump",
    "-U",
    "postgres",
    "-d",
    "postgres",
    "--schema-only",
    "--section=post-data",
  ]);
  const data =
    "BEGIN; SET LOCAL timezone='UTC';\n" +
    loadRowsSql([...seeds, ...recovery], insertColumns) +
    "\nINSERT INTO supabase_migrations.schema_migrations(version) VALUES " +
    versions.map((v) => `('${v}')`).join(",") +
    "; COMMIT;";
  const checks = `
DO $check$ BEGIN
IF EXISTS(SELECT 1 FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname LIKE 'atlas\\_%' ESCAPE '\\' AND c.contype='f' AND NOT c.convalidated) THEN RAISE EXCEPTION 'UNVALIDATED_FOREIGN_KEY'; END IF;
IF EXISTS(SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname LIKE 'atlas\\_%' ESCAPE '\\' AND t.tgenabled<>'O') THEN RAISE EXCEPTION 'DISABLED_OR_NONSTANDARD_TRIGGER'; END IF;
IF (SELECT count(*) FROM atlas_admin.recipe_composition_adjustments)<>12 THEN RAISE EXCEPTION 'TWELVE_NATIVE_ROOTS_REQUIRED'; END IF;
END $check$;
`;
  const describe =
    "SELECT jsonb_build_object('schema',pg_temp.cleanup_atlas_schema_checksum(),'catalog',atlas_legacy.master_snapshot_hash(pg_temp.cleanup_catalog(true)),'raw_catalog',atlas_legacy.master_snapshot_hash(pg_temp.cleanup_catalog()),'facts',pg_temp.cleanup_fingerprints());";
  for (const db of [baseline, external]) {
    // CREATE DATABASE fails on collision; no existing database is dropped or reset.
    run(
      "postgres",
      `CREATE DATABASE ${db} TEMPLATE template0;`,
      "supabase_admin",
    );
    run(db, pre, "supabase_admin");
    run(db, overlay, "supabase_admin");
    run(db, data, "supabase_admin");
    run(db, post, "supabase_admin");
  }
  const before = JSON.parse(run(baseline, packageSql + checks + describe));
  if (before.schema !== CLEANUP_SCHEMA_SHA256)
    throw Error(`LOCAL_SCHEMA_DIFFERS_FROM_REVIEWED_STAGING: ${before.schema}`);
  const reconstructed = JSON.parse(
    run(external, packageSql + checks + describe),
  );
  if (
    JSON.stringify({ ...before, raw_catalog: null }) !==
    JSON.stringify({ ...reconstructed, raw_catalog: null })
  )
    throw Error("EXTERNAL_RECONSTRUCTION_MISMATCH");
  const preview = JSON.parse(
    run(
      baseline,
      buildStagingTestCleanupSql({
        targetProjectRef: CLEANUP_TARGET,
        migrationVersions: versions,
        recovery: null,
        commitSha,
      }),
    ),
  );
  if (
    preview.status !== "PREVIEW" ||
    preview.deleted_rows !== 27431 ||
    !preview.rolled_back
  )
    throw Error("ACTUAL_PREVIEW_FAILED");
  const proof = {
    status: "LOCAL_REHEARSAL_PROVISIONAL",
    recovery_manifest_sha256: CLEANUP_RECOVERY_SHA256,
    commit_sha: commitSha,
    deleted_rows: 27431,
    restored_rows: 27431,
    atlas_schema_checksum: before.schema,
    purge_constraints_checked_before_restore: true,
    method: "LOCAL_EXACT_SCHEMA_EXTERNAL_RECONSTRUCTION_AND_IN_PLACE_RESTORE",
    baseline_database: baseline,
    external_database: external,
    source_hashes: sourceHashes,
  };
  const encode = (value) =>
    `convert_from(decode('${Buffer.from(JSON.stringify(value)).toString("base64")}','base64'),'UTF8')::jsonb`;
  // Server permits this provisional purge only over a local Unix socket in the newly created proof DB.
  const cleanupSql =
    packageSql +
    `\nBEGIN; SET LOCAL timezone='UTC'; SET LOCAL lock_timeout='15s'; SET LOCAL statement_timeout='15min'; SELECT pg_temp.run_staging_test_cleanup('null',${encode(versions)},true,${encode(preview.content_checksum)},${encode(proof)},${encode(commitSha)},${encode(sourceHashes)}); COMMIT;`;
  const purged = JSON.parse(run(baseline, cleanupSql));
  if (purged.status !== "APPLIED" || purged.deleted_rows !== 27431)
    throw Error("ACTUAL_PURGE_FAILED");
  const q = (value) => "'" + String(value).replaceAll("'", "''") + "'";
  let restore =
    packageSql +
    "\nBEGIN; SET LOCAL lock_timeout='15s'; SET LOCAL statement_timeout='15min'; SET LOCAL timezone='UTC';\n";
  restore += `DO $lock$ DECLARE r record; BEGIN FOR r IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname LIKE 'atlas\\_%' ESCAPE '\\' AND c.relkind IN('r','p') ORDER BY n.nspname,c.relname LOOP EXECUTE format('LOCK TABLE %I.%I IN ACCESS EXCLUSIVE MODE',r.nspname,r.relname); END LOOP; END $lock$;\n`;
  for (const g of guards) {
    restore += `DO $guard$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_trigger t WHERE t.tgrelid=${q(g.table)}::regclass AND t.tgname=${q(g.trigger)} AND NOT t.tgisinternal AND t.tgenabled='O' AND t.tgtype=${g.type} AND pg_get_triggerdef(t.oid,true)=${q(g.definition)} AND encode(extensions.digest(pg_get_functiondef(t.tgfoid),'sha256'),'hex')=${q(g.function_sha256)}) THEN RAISE EXCEPTION 'LOCAL_RESTORE_GUARD_DRIFT'; END IF; END $guard$; ALTER TABLE ${g.table} DISABLE TRIGGER "${g.trigger}";\n`;
  }
  const inserts = recovery.map(
    (t, i) =>
      `r${i} AS (${loadRowsSql([t], insertColumns).replace(/;$/, " ")} RETURNING 1)`,
  );
  restore +=
    "WITH " +
    inserts.join(",") +
    " SELECT " +
    inserts.map((_, i) => `(SELECT count(*) FROM r${i})`).join("+") +
    ";\nSET CONSTRAINTS ALL IMMEDIATE;\n";
  for (const g of guards)
    restore += `ALTER TABLE ${g.table} ENABLE TRIGGER "${g.trigger}";\n`;
  restore +=
    checks +
    `\nDO $exact_restore$ BEGIN
    IF pg_temp.cleanup_atlas_schema_checksum() IS DISTINCT FROM ${q(before.schema)}
      OR atlas_legacy.master_snapshot_hash(pg_temp.cleanup_catalog()) IS DISTINCT FROM ${q(before.raw_catalog)}
      OR pg_temp.cleanup_fingerprints() IS DISTINCT FROM ${encode(before.facts)}
    THEN RAISE EXCEPTION 'EXTERNAL_RESTORE_NOT_EXACT_BEFORE_COMMIT'; END IF;
  END $exact_restore$;\nCOMMIT;\n` +
    describe;
  const output = run(baseline, restore).trim().split(/\r?\n/);
  const after = JSON.parse(output.at(-1));
  if (output[0] !== "27431" || JSON.stringify(before) !== JSON.stringify(after))
    throw Error("IN_PLACE_EXTERNAL_RESTORE_MISMATCH");
  proof.preview = preview;
  proof.applied = purged;
  proof.restore_guards_sha256 = sha256(JSON.stringify(guards));
  proof.restore_trigger_count = guards.length;
  proof.all_foreign_keys_validated = true;
  proof.in_place_catalog_and_all_rows_equal = true;
  proof.external_reconstruction_catalog_and_all_rows_equal = true;
  proof.status = "RESTORED_EXACTLY";
  proof.local_data_scope = "PARTIAL_PROTECTED_FK_CLOSURE";
  proof.canonical_context_count = preview.canonical_context_count;
  proof.full_staging_resolver_restore_proven = false;
  proof.source_schema_overlay_sha256 = sha256(overlay);
  if (
    git(["rev-parse", "HEAD"]) !== commitSha ||
    git(["status", "--porcelain", "--", ...sourcePaths]) ||
    JSON.stringify(cleanupCodeHashes()) !== JSON.stringify(sourceHashes)
  )
    throw Error("PROOF_SOURCES_CHANGED_DURING_RUN");
  if (outputPath)
    writeFileSync(outputPath, JSON.stringify(proof, null, 2) + "\n", {
      flag: "wx",
    });
  return proof;
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const values = new Map(),
      args = process.argv.slice(2);
    for (let i = 0; i < args.length; i += 2) {
      if (
        ![
          "--recovery-directory",
          "--protected-dependencies",
          "--schema-overlay",
          "--restore-guards",
          "--container",
          "--commit-sha",
          "--output",
        ].includes(args[i]) ||
        !args[i + 1] ||
        values.has(args[i])
      )
        throw Error("INVALID_ARGUMENT");
      values.set(args[i], args[i + 1]);
    }
    const proof = await rehearseLocalCleanup({
      recoveryDirectory: values.get("--recovery-directory"),
      protectedDependencies: values.get("--protected-dependencies"),
      schemaOverlay: values.get("--schema-overlay"),
      restoreGuards: values.get("--restore-guards"),
      container: values.get("--container"),
      commitSha: values.get("--commit-sha"),
      outputPath: values.get("--output"),
    });
    console.log(JSON.stringify(proof, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
