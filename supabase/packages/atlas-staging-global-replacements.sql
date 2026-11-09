-- One approved Staging adoption; no permanent function, grant or importer changes.
create or replace function pg_temp.global_adoption_fingerprints(exclude_adoption boolean default false)
returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare item record; value text; predicate text; result jsonb:='{}';
begin
  for item in select n.nspname,c.relname from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind in('r','p')
    order by n.nspname,c.relname loop
    predicate:='';
    if exclude_adoption then
      if item.nspname='atlas_admin' and item.relname='recipe_composition_adjustments' then
        predicate:=' where recipe_composition_adjustment_id not in(select (md5(''OPS_V1_INGREDIENT_CHANGE_ORDER:''||id))::uuid from unnest(array[''7'',''11'',''12'',''14'']) id)';
      elsif item.nspname='atlas_admin' and item.relname='recipe_composition_adjustment_revisions' then
        predicate:=' where recipe_composition_adjustment_revision_id not in(select (md5(''OPS_V1_INGREDIENT_CHANGE_ORDER:''||id||'':revision:1''))::uuid from unnest(array[''7'',''11'',''12'',''14'']) id)';
      elsif item.nspname='atlas_legacy' and item.relname='import_batches' then
        predicate:=' where not(source_system=''OPS_V1_RECIPE_ADJUSTMENTS'' and snapshot_id=''atlas-global-adoption-20261109'')';
      end if;
    end if;
    execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb)::text) from %I.%I t%s',item.nspname,item.relname,predicate) into value;
    result:=result||jsonb_build_object(item.nspname||'.'||item.relname,value);
  end loop;
  return result;
end $$;

create or replace function pg_temp.run_global_replacements(history jsonb,expected_migrations jsonb,source_checksum text,apply_requested boolean,reviewed_checksum jsonb default 'null')
returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare item record; source_row jsonb; records jsonb:='[]'; payload jsonb; versions jsonb; source_rows jsonb;
  before_facts jsonb; protected_facts jsonb; plan_checksum text; actual_source_checksum text;
  v_actor_id constant uuid:='a217bdd5-2858-58c2-8964-45c465225a59';
  before_composition jsonb:='[]'; context jsonb; resolution jsonb; expected_resolution jsonb;
  old_line jsonb; new_line jsonb; expected_lines jsonb; rule jsonb; rules jsonb; applied jsonb; replay jsonb; result jsonb;
  roots_before bigint; revisions_before bigint; receipts_before bigint; mapped bigint; changed_lines bigint:=0;
  count_roots bigint; count_revisions bigint; count_receipts bigint; from_id uuid; to_id uuid;
begin
  if current_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'STAGING_ADOPTION_TARGET_DENIED'; end if;
  if history->>'source_project_ref'<>'qnthofvccilhnefdcxnz' or history->>'contract_version'<>'OPS-V1-RECIPE-HISTORY.v1'
    or history->>'source_system'<>'OPS_V1_RECIPE_HISTORY'
    or history->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(history-'snapshot_checksum') then raise exception 'SOURCE_CHECKSUM_INVALID'; end if;
  select coalesce(jsonb_agg(version order by version),'[]') into versions from supabase_migrations.schema_migrations;
  if versions is distinct from expected_migrations then raise exception 'MIGRATION_HISTORY_MISMATCH'; end if;
  -- The same deterministic lock order protects reviewed state from every Atlas writer.
  for item in select n.nspname,c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind in('r','p') order by n.nspname,c.relname loop
    execute format('lock table %I.%I in share row exclusive mode',item.nspname,item.relname);
  end loop;
  if not exists(select 1 from atlas_core.actors a where a.actor_id=v_actor_id and a.actor_type='MIGRATION' and a.actor_status='ACTIVE')
    or exists(select 1 from atlas_core.actor_auth_subjects s where s.actor_id=v_actor_id) then raise exception 'IMPORT_ACTOR_PREREQUISITE_MISSING'; end if;
  select jsonb_agg(r order by r->>'legacy_id') into source_rows from jsonb_array_elements(history->'records') r where r->>'source_table'='ingredient_change_orders';
  if jsonb_array_length(source_rows) is distinct from 5 or (select count(distinct r->>'legacy_id') from jsonb_array_elements(source_rows) r)<>5
    or exists(select 1 from jsonb_array_elements(source_rows) r left join (values('7','1043','1039','2025-12-15'),('11','1029','1067','2026-03-03'),('12','836','904','2026-04-03'),('13','1042','1041',null),('14','1040','1208','2026-10-09')) p(id,old_id,new_id,source_date) on p.id=r->>'legacy_id'
      where p.id is null or r->>'scope_kind' is distinct from 'SYSTEM_INGREDIENT' or r->>'action' is distinct from 'REPLACE' or r->>'source_active' is distinct from 'true'
      or r->'source_record'->>'id' is distinct from p.id or r->'source_record'->>'is_active' is distinct from 'true'
      or r->'source_record'->>'old_ingredient_id' is distinct from p.old_id or r->'source_record'->>'new_ingredient_id' is distinct from p.new_id
      or (p.source_date is not null and (r->>'effective_from' is distinct from p.source_date or r->'source_record'->>'effective_date' is distinct from p.source_date))) then raise exception 'GLOBAL_SOURCE_DRIFT'; end if;
  -- Match the stable normalized source ordering, excluding technical extraction metadata.
  select jsonb_agg(r order by (r->>'legacy_id')::bigint) into source_rows from jsonb_array_elements(source_rows) r;
  actual_source_checksum:=atlas_legacy.master_snapshot_hash(jsonb_build_object('source_project_ref','qnthofvccilhnefdcxnz','adoption_date','2026-11-09','records',source_rows));
  if actual_source_checksum is distinct from source_checksum then raise exception 'SOURCE_CONTENT_CHECKSUM_INVALID'; end if;
  if exists(select 1 from atlas_admin.recipe_composition_adjustments where recipe_composition_adjustment_id in(select md5('OPS_V1_INGREDIENT_CHANGE_ORDER:'||id)::uuid from unnest(array['7','11','12','14']) id))
    or exists(select 1 from atlas_legacy.import_batches where source_system='OPS_V1_RECIPE_ADJUSTMENTS' and snapshot_id='atlas-global-adoption-20261109') then raise exception 'ADOPTION_ALREADY_PRESENT'; end if;
  if (select count(*) from atlas_legacy.master_data_mappings m join atlas_admin.school_types t on t.school_type_id=m.school_type_id
      and t.school_type_code='v1-school-type-'||m.legacy_id and t.school_type_status='ACTIVE'
      where m.source_system='OPS_V1' and m.object_type='SCHOOL_TYPE' and m.legacy_id in('1','2'))<>2
    or not exists(select 1 from atlas_legacy.master_data_mappings where source_system='OPS_V1' and object_type='DISH') then raise exception 'MAPPED_TYPED_CONTEXTS_REQUIRED'; end if;
  -- Later layers run after global replacement. A final-line substitution oracle is valid only without relevant later-layer rules.
  if exists(select 1 from atlas_admin.recipe_composition_adjustments a join atlas_admin.recipe_composition_adjustment_revisions r using(recipe_composition_adjustment_id)
    where r.revision_status='ACTIVE' and coalesce(r.effective_to,'infinity'::date)>'2026-11-09'::date
      and (a.scope_kind in('SYSTEM_INGREDIENT','SCHOOL') or (a.scope_kind in('SYSTEM_DISH','SCHOOL_DISH') and exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='DISH' and m.dish_id=a.dish_id)
        and (a.school_type_id is null or exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='SCHOOL_TYPE' and m.legacy_id in('1','2') and m.school_type_id=a.school_type_id))))) then raise exception 'NATIVE_INTERACTION_BLOCKED'; end if;
  before_facts:=pg_temp.global_adoption_fingerprints(); protected_facts:=pg_temp.global_adoption_fingerprints(true);
  plan_checksum:=atlas_legacy.master_snapshot_hash(jsonb_build_object('source_content_checksum',source_checksum,'target_state',before_facts,'migrations',versions,'actor',v_actor_id,'adoption_date','2026-11-09','orders',jsonb_build_array('7','11','12','14'),'excluded','13'));
  if apply_requested and (reviewed_checksum#>>'{}') is distinct from plan_checksum then raise exception 'TARGET_OR_SOURCE_DRIFT'; end if;
  for source_row in select r from jsonb_array_elements(source_rows) r where r->>'legacy_id'<>'13' order by (r->>'legacy_id')::bigint loop
    select count(*),min(m.ingredient_id::text)::uuid into mapped,from_id from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.legacy_id=source_row->'source_record'->>'old_ingredient_id';
    if mapped<>1 or from_id is null then raise exception 'INGREDIENT_MAPPING_REQUIRED'; end if;
    select count(*),min(m.ingredient_id::text)::uuid into mapped,to_id from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.legacy_id=source_row->'source_record'->>'new_ingredient_id';
    if mapped<>1 or to_id is null then raise exception 'INGREDIENT_MAPPING_REQUIRED'; end if;
    records:=records||jsonb_build_array(jsonb_build_object('legacy_id',source_row->>'legacy_id','action','REPLACE','target_ingredient_id',from_id,'substitute_ingredient_id',to_id,'effective_from','2026-11-09','is_active',true,
      'reason_note',jsonb_build_object('adoption','Atlas adoption effective 2026-11-09; original OPS issuance unattributed','source_project_ref','qnthofvccilhnefdcxnz','source_content_checksum',source_checksum,'original_source',source_row)::text));
  end loop;
  payload:=jsonb_build_object('source_system','OPS_V1_RECIPE_ADJUSTMENTS','snapshot_id','atlas-global-adoption-20261109','exported_at',history->>'exported_at','imported_by_actor_id',v_actor_id,'records',jsonb_build_object('ingredient_change_orders',records,'system_bom_change_orders','[]'::jsonb,'school_overrides','[]'::jsonb,'school_dish_overrides','[]'::jsonb));
  payload:=payload||jsonb_build_object('snapshot_checksum',encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex'));
  for item in select d.dish_id,t.school_type_id,day.as_of_date from atlas_legacy.master_data_mappings d cross join atlas_legacy.master_data_mappings t cross join (values('2026-11-08'::date),('2026-11-09'::date)) day(as_of_date)
    where d.source_system='OPS_V1' and t.source_system='OPS_V1' and d.object_type='DISH' and t.object_type='SCHOOL_TYPE' and t.legacy_id in('1','2') order by d.dish_id,t.school_type_id,day.as_of_date loop
    resolution:=atlas_core.recipe_effective_resolve_composition(item.as_of_date,null,item.dish_id,item.school_type_id);
    before_composition:=before_composition||jsonb_build_array(jsonb_build_object('dish_id',item.dish_id,'school_type_id',item.school_type_id,'date',item.as_of_date,'resolution',resolution));
  end loop;
  select count(*) into roots_before from atlas_admin.recipe_composition_adjustments;
  select count(*) into revisions_before from atlas_admin.recipe_composition_adjustment_revisions;
  select count(*) into receipts_before from atlas_legacy.import_batches;
  begin
    applied:=atlas_legacy.import_recipe_adjustment_snapshot(payload);
    if applied->>'status'<>'COMPLETED' or applied->'operation_counts' is distinct from '{"inserted":4,"updated":0,"skipped":0,"rejected":0}'::jsonb then raise exception 'ADOPTION_IMPORT_REJECTED: %',applied; end if;
    replay:=atlas_legacy.import_recipe_adjustment_snapshot(payload);
    if replay->>'status'<>'REPLAYED' or replay->>'import_batch_id' is distinct from applied->>'import_batch_id' then raise exception 'REPLAY_FAILED'; end if;
    select jsonb_agg(jsonb_build_object('adjustment_id',a.recipe_composition_adjustment_id,'revision_id',r.recipe_composition_adjustment_revision_id,'revision_number',1,'scope_kind','SYSTEM_INGREDIENT','action_kind','REPLACE','target_ingredient_id',a.target_ingredient_id,'substitute_ingredient_id',r.substitute_ingredient_id,'quantity_per_basis',null,'unit_id',null,'reason_code',r.reason_code,'reason_note',r.reason_note,'effective_from',r.effective_from,'effective_to',r.effective_to,'is_preview',false)) into rules
      from atlas_admin.recipe_composition_adjustments a join atlas_admin.recipe_composition_adjustment_revisions r on r.recipe_composition_adjustment_revision_id=a.current_revision_id
      where a.legacy_source='OPS_V1_INGREDIENT_CHANGE_ORDER' and a.legacy_record_id in('7','11','12','14');
    if jsonb_array_length(rules)<>4 or exists(select 1 from jsonb_array_elements(rules) r where r->>'effective_from'<>'2026-11-09' or r->>'effective_to' is not null) then raise exception 'ADOPTION_READBACK_MISMATCH'; end if;
    for context in select value from jsonb_array_elements(before_composition) loop
      resolution:=atlas_core.recipe_effective_resolve_composition((context->>'date')::date,null,(context->>'dish_id')::uuid,(context->>'school_type_id')::uuid);
      expected_resolution:=context->'resolution'; expected_lines:='[]';
      for old_line in select value from jsonb_array_elements(expected_resolution->'lines') loop
        new_line:=old_line;
        if context->>'date'='2026-11-09' and old_line->>'final_disposition'='PRESENT' then
          select r into rule from jsonb_array_elements(rules) r where r->>'target_ingredient_id'=old_line->>'final_ingredient_id';
          if found then
            new_line:=atlas_core.rmvp_02b_transform_line(old_line,rule);
            if new_line->'final_quantity_per_basis' is distinct from old_line->'final_quantity_per_basis' or new_line->'final_unit_id' is distinct from old_line->'final_unit_id'
              or (new_line-'final_ingredient_id'-'source_layer'-'applied_adjustment_ids'-'applied_revision_ids'-'lineage') is distinct from (old_line-'final_ingredient_id'-'source_layer'-'applied_adjustment_ids'-'applied_revision_ids'-'lineage')
              or new_line->'lineage' is distinct from (old_line->'lineage')||jsonb_build_array((new_line->'lineage')->-1) then raise exception 'STABLE_LINE_OR_LINEAGE_CHANGED'; end if;
            changed_lines:=changed_lines+1;
          end if;
        end if;
        expected_lines:=expected_lines||jsonb_build_array(new_line);
      end loop;
      expected_resolution:=jsonb_set(expected_resolution,'{lines}',expected_lines);
      if resolution is distinct from expected_resolution then raise exception 'CANONICAL_COMPOSITION_MISMATCH: dish %, type %, date %, blockers %',context->>'dish_id',context->>'school_type_id',context->>'date',resolution->'blockers'; end if;
    end loop;
    if changed_lines=0 then raise exception 'NO_PROVEN_EFFECTIVE_LINES'; end if;
    select count(*)-roots_before into count_roots from atlas_admin.recipe_composition_adjustments;
    select count(*)-revisions_before into count_revisions from atlas_admin.recipe_composition_adjustment_revisions;
    select count(*)-receipts_before into count_receipts from atlas_legacy.import_batches;
    if count_roots<>4 or count_revisions<>4 or count_receipts<>1 then raise exception 'ADOPTION_DELTA_MISMATCH'; end if;
    if pg_temp.global_adoption_fingerprints(true) is distinct from protected_facts then raise exception 'NATIVE_OR_OPERATIONAL_FACTS_CHANGED'; end if;
    result:=jsonb_build_object('status',case when apply_requested then 'APPLIED' else 'PREVIEW' end,'preserved',true,'roots',count_roots,'revisions',count_revisions,'receipts',count_receipts,'replay_status',replay->>'status','source_content_checksum',source_checksum,'content_checksum',plan_checksum,'target_state_checksum',atlas_legacy.master_snapshot_hash(before_facts),'import_snapshot_checksum',payload->>'snapshot_checksum','adoption_date','2026-11-09','orders',jsonb_build_array('7','11','12','14'),'excluded_order','13','contexts',jsonb_array_length(before_composition)/2,'changed_lines',changed_lines,'protected_tables',(select count(*) from jsonb_object_keys(protected_facts)),'import_batch_id',applied->>'import_batch_id');
    if not apply_requested then raise exception sqlstate 'P9001' using message='PREVIEW_ROLLBACK'; end if;
  exception when sqlstate 'P9001' then
    if apply_requested then raise; end if;
  end;
  if not apply_requested and pg_temp.global_adoption_fingerprints() is distinct from before_facts then raise exception 'PREVIEW_NOT_ROLLED_BACK'; end if;
  return result;
end $$;
