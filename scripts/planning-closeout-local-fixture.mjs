// Disposable LOCAL database only: construct real pre-D046 history with all
// constraints enabled, then let the versioned D047 migration adopt its Unit.
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

export function localSql(sql) {
  const result = spawnSync(
    "docker",
    [
      "exec",
      "-i",
      "supabase_db_thuonghao-ops-erp",
      "psql",
      "-X",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
      "-qAt",
    ],
    { input: sql, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 },
  );
  if (result.status !== 0) throw new Error(result.stderr || "LOCAL_SQL_FAILED");
  return result.stdout
    .trim()
    .split(/\r?\n/)
    .filter((row) => row.startsWith("{"))
    .map((row) => JSON.parse(row));
}

export function planningCloseoutLocalFixtureSql() {
  const scale = readFileSync(
    new URL(
      "../supabase/tests/need_generation_operational_scale.sql",
      import.meta.url,
    ),
    "utf8",
  );
  let setup = scale.slice(
    0,
    scale.indexOf("select set_config('request.jwt.claims'"),
  );
  setup = setup.replace("select plan(42);", "");
  setup = setup.replace(
    "pg_temp.ng_id(13),0.1",
    "case when i=14 then pg_temp.ng_id(15) else pg_temp.ng_id(13) end,0.1",
  );
  setup = setup.replace(
    "values(pg_temp.ng_id(13),'need-scale-kg','Need scale kilogram','mass');",
    "values(pg_temp.ng_id(13),'need-scale-kg','Need scale kilogram','mass'), (pg_temp.ng_id(15),'need-scale-target','Adopted Unit','mass');",
  );
  // The importer records raw composition; quantity remains unchanged.
  const mappings = [
    ["RECIPE", "recipe_id", 1108],
    ["RECIPE_VERSION", "recipe_version_id", 1208],
    ["RECIPE_LINE", "recipe_line_id", 3802],
    ["RECIPE_LINE_REVISION", "recipe_line_revision_id", 4802],
    ["INGREDIENT", "ingredient_id", 2014],
    ["UNIT", "unit_id", 13],
    ["UNIT", "unit_id", 15],
  ]
    .map(
      (
        [type, column, id],
        i,
      ) => `insert into atlas_legacy.master_data_mappings(master_data_mapping_id,import_batch_id,source_system,object_type,legacy_id,${column},last_seen_import_batch_id,last_source_fingerprint,last_target_version)
values(pg_temp.ng_id(${8001 + i}),pg_temp.ng_id(8000),'OPS_V1','${type}','${id}',pg_temp.ng_id(${id}),pg_temp.ng_id(8000),repeat('a',64),1);`,
    )
    .join("\n");
  return `${setup}
insert into atlas_planning.planning_quantity_policies(planning_quantity_policy_id,unit_id,created_by_actor_id)
values(pg_temp.ng_id(32),pg_temp.ng_id(15),pg_temp.ng_id(1));
insert into atlas_planning.planning_quantity_policy_revisions(planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,revision_number,planning_step,effective_from,policy_revision_status,created_by_actor_id)
values(pg_temp.ng_id(33),pg_temp.ng_id(32),pg_temp.ng_id(15),1,0.1,'2050-01-01','DRAFT',pg_temp.ng_id(1));
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='ACTIVE',approved_by_actor_id=pg_temp.ng_id(1),approved_at=now(),activated_by_actor_id=pg_temp.ng_id(1),activated_at=now() where planning_quantity_policy_revision_id=pg_temp.ng_id(33);
insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,source_counts,reconciliation,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version)
select pg_temp.ng_id(8000),'OPS_V1','closeout-local',repeat('b',64),now(),'COMPLETED','{}',jsonb_build_object('actions',jsonb_build_array(jsonb_build_object('object_type','RECIPE_LINE_REVISION','target_id',r.recipe_line_revision_id,'values',to_jsonb(r)))),now(),pg_temp.ng_id(1),'postgres',repeat('c',64),'OPS-V1-MASTER-SNAPSHOT.v1'
from atlas_admin.recipe_line_revisions r where r.recipe_line_revision_id=pg_temp.ng_id(4802);
${mappings}
set constraints all immediate;
set constraints all deferred;
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
set local role authenticated;
insert into ng_results select 'menu',atlas_api.save_weekly_menu(request),null from ng_requests where name='menu';
insert into ng_results select 'attendance',atlas_api.save_attendance(request),null from ng_requests where name='attendance';
insert into ng_results select 'pantry',atlas_api.save_pantry(request),null from ng_requests where name='pantry';
insert into ng_results select 'generate',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
reset role;
do $$ begin
 if exists(select 1 from ng_results where response->>'success' is distinct from 'true') then raise exception 'LOCAL_CLOSEOUT_FIXTURE_COMMAND_FAILED: %',(select jsonb_agg(jsonb_build_object('name',r.name,'code',r.response->>'error_code','message',r.response->>'safe_message')) from ng_results r where response->>'success' is distinct from 'true'); end if;
 if (select count(*) from atlas_planning.confirmed_need_line_revisions where is_current)<>248 then raise exception 'LOCAL_CLOSEOUT_FIXTURE_COUNT'; end if;
end $$;
-- Produce both immutable historical roles through the old public command.
-- Fault injection only affects this disposable pre-upgrade function body;
-- restore it before committing the fixture. No receipt is inserted or edited.
insert into ng_requests
select role_name,jsonb_build_object('contract_version','RMVP-04.v3',
 'command_id',id,'correlation_id',gen_random_uuid(),'idempotency_key','planning-d046-correction:'||id,
 'expected_version',3,'requested_by_auth_subject',pg_temp.ng_id(101),'requested_at',now(),
 'reason_code','NEED_GENERATION_EXECUTED','reason_note','Disposable historical closeout receipt',
 'payload',jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',
  (select need_generation_run_id from atlas_planning.need_generation_runs)))
from (select role_name,gen_random_uuid() id from unnest(array['benign','legacy_retryable_failure']) role_name) ids;
set local role authenticated;
insert into ng_results select 'benign',atlas_api.execute_need_generation(request),null from ng_requests where name='benign';
reset role;
create temp table closeout_old_command as select pg_get_functiondef('atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure) definition;
do $fault$ declare d text; needle text := '    if v_preflight ->> ''downstream_currentness'' = ''CURRENT'''; begin
 select definition into d from closeout_old_command;
 if position(needle in d)=0 then raise exception 'LOCAL_HISTORICAL_COMMAND_MARKER_MISSING'; end if;
 execute replace(d,needle,
  '    v_error := atlas_core.planning_contract_01_command_error(request,v_name,v_contract,''RETRYABLE_CONCURRENCY_FAILURE'',''Disposable nested transient fault'') || jsonb_build_object(''retryable'',true);
    raise sqlstate ''PC104'' using message=''Disposable nested transient fault'';
'||needle);
end $fault$;
set local role authenticated;
insert into ng_results select 'legacy_retryable_failure',atlas_api.execute_need_generation(request),null from ng_requests where name='legacy_retryable_failure';
reset role;
do $$ begin execute (select definition from closeout_old_command); end $$;
do $$ begin
 if (select response->>'idempotency_status' from ng_results where name='benign') is distinct from 'NO_CHANGE'
  or not exists(select 1 from atlas_core.command_receipts r join ng_requests q on r.command_id=(q.request->>'command_id')::uuid
    where q.name='legacy_retryable_failure' and r.outcome='FAILED_NON_RETRYABLE'
      and r.response_payload->>'success'='false' and r.response_payload->>'retryable'='true'
      and r.response_payload->>'error_code'='RETRYABLE_CONCURRENCY_FAILURE')
 then raise exception 'LOCAL_HISTORICAL_RECEIPT_PROOF_FAILED'; end if;
end $$;
set constraints all immediate;
commit;
`;
}
