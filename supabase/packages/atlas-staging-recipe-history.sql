-- Session-local guarded archive import; no permanent schema or operational writes.
create or replace function pg_temp.recipe_history_protected_fingerprints(ignored_snapshot text)
returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare item record; value text; result jsonb:='{}'; predicate text;
begin
  for item in select n.nspname,c.relname from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind in('r','p')
    order by n.nspname,c.relname loop
    predicate:=case when item.nspname='atlas_legacy' and item.relname='import_batches'
      then ' where not(source_system=''OPS_V1_RECIPE_HISTORY'' and snapshot_id=$1)' else '' end;
    execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb)::text) from %I.%I t%s',item.nspname,item.relname,predicate)
      into value using ignored_snapshot;
    result:=result||jsonb_build_object(item.nspname||'.'||item.relname,value);
  end loop;
  return result;
end $$;

create or replace function pg_temp.run_recipe_history_archive(snapshot jsonb, expected_migrations jsonb, apply_requested boolean)
returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare before_facts jsonb; after_facts jsonb; preview jsonb; applied jsonb; replay jsonb;
  versions jsonb; v_actor_id constant uuid:='a217bdd5-2858-58c2-8964-45c465225a59'; matched bigint;
begin
  if current_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'STAGING_ARCHIVE_TARGET_DENIED'; end if;
  select coalesce(jsonb_agg(version order by version),'[]'::jsonb) into versions from supabase_migrations.schema_migrations;
  if versions is distinct from expected_migrations then raise exception 'MIGRATION_HISTORY_MISMATCH'; end if;
  if not exists(select 1 from atlas_core.actors a where a.actor_id=v_actor_id and a.actor_type='MIGRATION' and a.actor_status='ACTIVE')
    or exists(select 1 from atlas_core.actor_auth_subjects s where s.actor_id=v_actor_id) then raise exception 'IMPORT_ACTOR_PREREQUISITE_MISSING'; end if;
  perform pg_advisory_xact_lock(hashtextextended('OPS_V1_RECIPE_HISTORY',0));
  before_facts:=pg_temp.recipe_history_protected_fingerprints(snapshot->>'snapshot_id');
  preview:=atlas_legacy.import_recipe_change_order_history(snapshot,null,null);
  if preview->>'status'<>'PREVIEW' then raise exception 'ARCHIVE_PREVIEW_FAILED'; end if;
  if apply_requested then
    applied:=atlas_legacy.import_recipe_change_order_history(snapshot,v_actor_id,preview->>'plan_checksum');
    if applied->>'status' not in('IMPORTED','REPLAYED') then raise exception 'ARCHIVE_APPLY_FAILED'; end if;
    replay:=atlas_legacy.import_recipe_change_order_history(snapshot,v_actor_id,preview->>'plan_checksum');
    if replay->>'status'<>'REPLAYED' or replay->>'import_batch_id' is distinct from applied->>'import_batch_id' then raise exception 'REPLAY_FAILED'; end if;
    select count(*) into matched from jsonb_array_elements(snapshot->'records') source
      join jsonb_array_elements(atlas_legacy.recipe_change_order_history()) observed
        on observed=source-'source_record';
    if matched<>jsonb_array_length(snapshot->'records') then raise exception 'ARCHIVE_READBACK_MISMATCH'; end if;
  end if;
  after_facts:=pg_temp.recipe_history_protected_fingerprints(snapshot->>'snapshot_id');
  if after_facts is distinct from before_facts then raise exception 'NATIVE_OR_OPERATIONAL_FACTS_CHANGED'; end if;
  return coalesce(applied,preview)||jsonb_build_object('preserved',true,'protected_tables',(select count(*) from jsonb_object_keys(before_facts)),'matched_records',matched,'replay_status',replay->>'status');
end $$;
