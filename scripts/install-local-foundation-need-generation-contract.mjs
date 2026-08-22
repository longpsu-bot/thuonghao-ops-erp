import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  buildFoundationNeedGenerationContractSql,
  readAtlasStagingPackage,
} from "./install-atlas-staging-package.mjs";
import { runPinnedSupabase } from "./local-supabase-status.mjs";

function runLocalSql(statement) {
  const temporaryDirectory = mkdtempSync(
    join(tmpdir(), "atlas-foundation-need-generation-"),
  );
  const sqlPath = join(temporaryDirectory, "query.sql");
  try {
    writeFileSync(sqlPath, statement, { encoding: "utf8", flag: "wx" });
    runPinnedSupabase(["db", "query", "--local", "--file", sqlPath], {
      stdio: "inherit",
    });
  } finally {
    rmSync(temporaryDirectory, { force: true, recursive: true });
  }
}

function localApprovalActorSql(identityManifest) {
  const actor = identityManifest.actor;
  return `do $atlas_staging_foundation_local_actor$
begin
  if exists (
    select 1
    from atlas_core.actors
    where actor_id = '${actor.actor_id}'::uuid
      and (
        actor_type <> '${actor.actor_type}'
        or display_name <> '${actor.display_name}'
        or actor_status <> 'ACTIVE'
        or deactivated_at is not null
      )
  ) then
    raise exception 'ATLAS_STAGING_FOUNDATION_LOCAL_ACTOR_MISMATCH';
  end if;
  if not exists (
    select 1 from atlas_core.actors where actor_id = '${actor.actor_id}'::uuid
  ) then
    insert into atlas_core.actors (actor_id, actor_type, display_name)
    values ('${actor.actor_id}'::uuid, '${actor.actor_type}', '${actor.display_name}');
  end if;
end;
$atlas_staging_foundation_local_actor$;`;
}

export function installLocalFoundationNeedGenerationContract(
  cwd = process.cwd(),
) {
  const identity = readAtlasStagingPackage("identity", cwd);
  const foundation = readAtlasStagingPackage("foundation", cwd);
  runLocalSql(localApprovalActorSql(identity));
  runLocalSql(buildFoundationNeedGenerationContractSql(foundation));
}
