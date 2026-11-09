import { spawnSync } from "node:child_process";
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";

const sql =
  readFileSync("supabase/packages/atlas-staging-test-cleanup.sql", "utf8") +
  `
BEGIN;
SELECT plan(2);
DO $probe$
DECLARE rejected boolean:=false; before_catalog jsonb; before_facts jsonb;
BEGIN
  before_catalog:=pg_temp.cleanup_catalog(); before_facts:=pg_temp.cleanup_fingerprints();
  IF jsonb_array_length(pg_temp.cleanup_fixed_manifest())<>67 OR jsonb_array_length(pg_temp.cleanup_delete_guards())<>53 OR jsonb_array_length(pg_temp.cleanup_operational_manifest())<>76 THEN RAISE EXCEPTION 'FIXED_SCOPE_CHANGED'; END IF;
  BEGIN
    PERFORM pg_temp.run_staging_test_cleanup('[]','[]',false,'null','null','null');
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm<>'RECOVERY_REQUIRED' THEN RAISE; END IF;
    rejected:=true;
  END;
  IF NOT rejected OR before_catalog IS DISTINCT FROM pg_temp.cleanup_catalog() OR before_facts IS DISTINCT FROM pg_temp.cleanup_fingerprints() THEN RAISE EXCEPTION 'REJECTED_CLEANUP_CHANGED_STATE'; END IF;
END $probe$;
SELECT pass('Missing external recovery is rejected without changing protected facts or security catalog');
SELECT ok(NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(pg_temp.cleanup_delete_guards()) g
  LEFT JOIN pg_trigger t ON t.tgrelid=(g->>'table')::regclass AND t.tgname=g->>'trigger'
  WHERE t.oid IS NULL OR t.tgisinternal OR t.tgenabled<>'O'
    OR pg_get_triggerdef(t.oid,true) IS DISTINCT FROM g->>'definition'
    OR t.tgtype IS DISTINCT FROM (g->>'type')::smallint
    OR encode(extensions.digest(pg_get_functiondef(t.tgfoid),'sha256'),'hex') IS DISTINCT FROM g->>'function_sha256'
),'All 53 exact business exceptions match active trigger definitions and function hashes; no FK trigger is admitted');
SELECT * FROM finish();
ROLLBACK;
`;
const work = mkdtempSync(join(tmpdir(), "atlas-staging-cleanup-control-"));
try {
  const file = join(work, "cleanup.sql");
  writeFileSync(file, sql);
  const invocation = repositorySupabaseCliInvocation([
    "test",
    "db",
    file,
    "--local",
  ]);
  const result = spawnSync(invocation.command, invocation.args, {
    stdio: "inherit",
    shell: invocation.shell,
  });
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(work, { recursive: true, force: true });
}
