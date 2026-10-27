-- Session-local, exact-scope forward correction. This package is not a migration.
create or replace function pg_temp.ingredient_name_correction_protected_fingerprints()
returns jsonb language plpgsql stable set search_path='' as $$
declare t record; value jsonb; result jsonb:='{}'; expression text; predicate text;
begin
 for t in
  select n.nspname,c.relname
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','p')
  order by 1,2
 loop
  expression:='to_jsonb(t)'; predicate:='';
  if t.nspname='atlas_admin' and t.relname='ingredients' then
   expression:=$e$case when t.ingredient_code=any(array['v1-ingredient-931','v1-ingredient-962','v1-ingredient-1040','v1-ingredient-1041','v1-ingredient-1047','v1-ingredient-1053','v1-ingredient-1067','v1-ingredient-1154']) then to_jsonb(t)-'ingredient_name'-'version'-'updated_at' else to_jsonb(t) end$e$;
  elsif t.nspname='atlas_legacy' and t.relname='master_data_mappings' then
   expression:=$e$case when t.source_system='OPS_V1' and t.object_type='INGREDIENT' and t.legacy_id=any(array['931','962','1040','1041','1047','1053','1067','1154']) then to_jsonb(t)-'last_seen_import_batch_id'-'last_source_fingerprint'-'last_target_version'-'updated_at' else to_jsonb(t) end$e$;
  elsif t.nspname='atlas_legacy' and t.relname='import_batches' then
   predicate:=$p$ where t.snapshot_id<>'ops-v1-ingredient-name-forward-correction-20261027-v1'$p$;
  end if;
  execute format(
   'select jsonb_build_object(''rows'',count(*),''sha256'',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(%s order by (%s)::text),''[]''::jsonb))) from %I.%I t%s',
   expression,expression,t.nspname,t.relname,predicate
  ) into value;
  result:=result||jsonb_build_object(t.nspname||'.'||t.relname,value);
 end loop;
 return result;
end $$;

create or replace function pg_temp.ingredient_name_correction_target_fingerprints()
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
  'ingredients',atlas_legacy.master_snapshot_hash(coalesce((
   select jsonb_agg(to_jsonb(i)-'created_at'-'updated_at' order by i.ingredient_code)
   from atlas_admin.ingredients i
   where i.ingredient_code=any(array['v1-ingredient-931','v1-ingredient-962','v1-ingredient-1040','v1-ingredient-1041','v1-ingredient-1047','v1-ingredient-1053','v1-ingredient-1067','v1-ingredient-1154'])
  ),'[]'::jsonb)),
  'mappings',atlas_legacy.master_snapshot_hash(coalesce((
   select jsonb_agg(to_jsonb(m)-'created_at'-'updated_at' order by m.legacy_id)
   from atlas_legacy.master_data_mappings m
   where m.source_system='OPS_V1' and m.object_type='INGREDIENT'
    and m.legacy_id=any(array['931','962','1040','1041','1047','1053','1067','1154'])
  ),'[]'::jsonb))
 )
$$;

create or replace function pg_temp.run_ingredient_name_forward_correction(
 payload jsonb, apply_requested boolean, expected_plan_checksum text, requested_correction_id text
) returns jsonb language plpgsql volatile set search_path='' as $$
declare
 actor uuid:=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor');
 correction text:='ops-v1-ingredient-name-forward-correction-20261027-v1';
 receipt atlas_legacy.import_batches%rowtype; item jsonb; plan jsonb; report jsonb:='[]'; protected jsonb;
 target uuid; current_row atlas_admin.ingredients%rowtype; mapping atlas_legacy.master_data_mappings%rowtype;
 ids text[]; batch uuid:=gen_random_uuid(); changed integer:=0; mapped integer:=0; result jsonb; target_fingerprints jsonb;
 phase text:='INPUT';
begin
 begin
  if current_user<>'postgres' or session_user<>'postgres' or requested_correction_id is distinct from correction
   or payload->>'contract_version' is distinct from 'OPS-V1-INGREDIENT-NAME-FORWARD-CORRECTION.v1'
   or payload->>'source_project_ref' is distinct from 'qnthofvccilhnefdcxnz'
   or payload->>'correction_id' is distinct from correction
   or payload->>'source_snapshot_checksum' !~ '^[0-9a-f]{64}$'
   or jsonb_typeof(payload->'records') is distinct from 'array'
   or jsonb_array_length(payload->'records')<>8
  then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  select array_agg(r.value->>'legacy_id' order by (r.value->>'legacy_id')::integer) into ids
  from jsonb_array_elements(payload->'records') r;
  if ids is distinct from array['931','962','1040','1041','1047','1053','1067','1154']
   or exists(select 1 from jsonb_array_elements(payload->'records') r
    where r.value->>'expected_after_name' is distinct from r.value#>>'{source_record,ingredient_name}'
     or r.value#>>'{source_record,legacy_id}' is distinct from r.value->>'legacy_id'
     or r.value#>>'{source_record,ingredient_code}' is distinct from 'v1-ingredient-'||(r.value->>'legacy_id')
     or r.value->>'source_fingerprint' is distinct from atlas_legacy.master_snapshot_hash(r.value->'source_record')
     or nullif(btrim(r.value->>'expected_before_name'),'') is null
     or nullif(btrim(r.value->>'expected_after_name'),'') is null)
  then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  phase:='LOCK';
  perform pg_advisory_xact_lock(hashtextextended('atlas-staging-master-load',0));
  for item in select to_jsonb(x) from (
   select n.nspname,c.relname from pg_catalog.pg_class c
   join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','p') order by 1,2
  ) x loop
   execute format('lock table %I.%I in share row exclusive mode',item->>'nspname',item->>'relname');
  end loop;
  lock table supabase_migrations.schema_migrations in share mode;
  if (select count(*) from supabase_migrations.schema_migrations)<>135
   or (select max(version) from supabase_migrations.schema_migrations)<>'20261023122829'
   or not exists(select 1 from atlas_core.actors where actor_id=actor and actor_type='MIGRATION' and actor_status='ACTIVE')
  then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  phase:='RECEIPT';
  protected:=pg_temp.ingredient_name_correction_protected_fingerprints();
  select * into receipt from atlas_legacy.import_batches
   where source_system='OPS_V1' and snapshot_id=correction;
  if found then
   if receipt.import_status is distinct from 'COMPLETED'
    or receipt.snapshot_contract_version is distinct from payload->>'contract_version'
    or receipt.snapshot_checksum is distinct from payload->>'source_snapshot_checksum'
    or receipt.operator_actor_id is distinct from actor
    or receipt.execution_database_principal is distinct from 'postgres'
    or receipt.plan_checksum !~ '^[0-9a-f]{64}$'
    or receipt.reconciliation->'protected_fingerprints' is distinct from protected
    or receipt.reconciliation->'target_fingerprints' is distinct from pg_temp.ingredient_name_correction_target_fingerprints()
    or (apply_requested and expected_plan_checksum is distinct from receipt.plan_checksum)
   then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
   return receipt.result_payload||jsonb_build_object(
    'status',case when apply_requested then 'REPLAYED' else 'PREVIEW' end,
    'correction_already_applied',true,'reconciled',true,
    'operational_data_unchanged',true,'unrelated_master_facts_unchanged',true
   );
  end if;
  phase:='TARGETS';
  for item in select value from jsonb_array_elements(payload->'records') loop
   select m.* into mapping from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.legacy_id=item->>'legacy_id';
   if not found or mapping.ingredient_id is null then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
   target:=mapping.ingredient_id;
   select * into current_row from atlas_admin.ingredients i where i.ingredient_id=target;
   if not found or current_row.ingredient_code is distinct from 'v1-ingredient-'||(item->>'legacy_id')
    or current_row.ingredient_name is distinct from item->>'expected_before_name'
    or mapping.last_target_version is distinct from current_row.version
    or current_row.order_step is distinct from (item#>>'{source_record,order_step}')::numeric
    or current_row.ingredient_status is distinct from item#>>'{source_record,ingredient_status}'
    or ((item#>>'{source_record,ingredient_type_legacy_id}') is null and current_row.ingredient_type_id is not null)
    or ((item#>>'{source_record,ingredient_type_legacy_id}') is not null and not exists(
     select 1 from atlas_legacy.master_data_mappings x where x.source_system='OPS_V1'
      and x.object_type='INGREDIENT_TYPE' and x.legacy_id=item#>>'{source_record,ingredient_type_legacy_id}'
      and x.ingredient_type_id=current_row.ingredient_type_id))
    or ((item#>>'{source_record,ingredient_order_group_legacy_id}') is null and current_row.ingredient_order_group_id is not null)
    or ((item#>>'{source_record,ingredient_order_group_legacy_id}') is not null and not exists(
     select 1 from atlas_legacy.master_data_mappings x where x.source_system='OPS_V1'
      and x.object_type='INGREDIENT_ORDER_GROUP' and x.legacy_id=item#>>'{source_record,ingredient_order_group_legacy_id}'
      and x.ingredient_order_group_id=current_row.ingredient_order_group_id))
    or not exists(select 1 from atlas_legacy.master_data_mappings x where x.source_system='OPS_V1'
     and x.object_type='UNIT' and x.legacy_id=item#>>'{source_record,purchase_unit_legacy_id}'
     and x.unit_id=current_row.purchase_unit_id)
   then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
   report:=report||jsonb_build_array(jsonb_build_object(
    'legacy_id',item->>'legacy_id','ingredient_id',target,
    'current_name',current_row.ingredient_name,'proposed_name',item->>'expected_after_name',
    'current_version',current_row.version,'source_fingerprint',item->>'source_fingerprint','action','UPDATE'
   ));
  end loop;
  phase:='PLAN';
  plan:=jsonb_build_object(
   'success',true,'status','PREVIEW','correction_id',correction,
   'source_snapshot_checksum',payload->>'source_snapshot_checksum',
   'update_count',8,'no_change_count',0,'report',report,
   'protected_fingerprints',protected
  );
  plan:=plan||jsonb_build_object('plan_checksum',atlas_legacy.master_snapshot_hash(plan));
  if not apply_requested then return plan||jsonb_build_object('correction_already_applied',false); end if;
  if expected_plan_checksum is distinct from plan->>'plan_checksum' then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  insert into atlas_legacy.import_batches(
   import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,
   operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts,operation_counts,result_payload
  ) values(
   batch,'OPS_V1',correction,payload->>'source_snapshot_checksum',transaction_timestamp(),'COMPLETED',clock_timestamp(),
   actor,session_user,expected_plan_checksum,payload->>'contract_version','{"ingredients":8}',
   '{"INGREDIENT_NAME_UPDATE":8,"MAPPING_REFRESH":8}',plan
  );
  for item in select value from jsonb_array_elements(payload->'records') loop
   update atlas_admin.ingredients i
    set ingredient_name=item->>'expected_after_name',version=i.version+1,updated_at=clock_timestamp()
    from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.legacy_id=item->>'legacy_id'
     and i.ingredient_id=m.ingredient_id and i.ingredient_name=item->>'expected_before_name';
   get diagnostics mapped=row_count; changed:=changed+mapped;
  end loop;
  if changed<>8 then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  update atlas_legacy.master_data_mappings m set
   last_seen_import_batch_id=batch,last_source_fingerprint=r.value->>'source_fingerprint',
   last_target_version=i.version,updated_at=clock_timestamp()
  from jsonb_array_elements(payload->'records') r
  join atlas_admin.ingredients i on i.ingredient_code='v1-ingredient-'||(r.value->>'legacy_id')
  where m.source_system='OPS_V1' and m.object_type='INGREDIENT'
   and m.legacy_id=r.value->>'legacy_id' and m.ingredient_id=i.ingredient_id;
  get diagnostics mapped=row_count;
  if mapped<>8 or exists(
   select 1 from jsonb_array_elements(payload->'records') r
   left join atlas_legacy.master_data_mappings m on m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.legacy_id=r.value->>'legacy_id'
   left join atlas_admin.ingredients i on i.ingredient_id=m.ingredient_id
   where i.ingredient_name is distinct from r.value->>'expected_after_name'
    or m.last_source_fingerprint is distinct from r.value->>'source_fingerprint'
    or m.last_target_version is distinct from i.version
  ) then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  if pg_temp.ingredient_name_correction_protected_fingerprints() is distinct from protected
  then raise exception 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  target_fingerprints:=pg_temp.ingredient_name_correction_target_fingerprints();
  result:=plan||jsonb_build_object(
   'status','APPLIED','import_batch_id',batch,'updated_count',changed,
   'reconciled',true,'operational_data_unchanged',true,'unrelated_master_facts_unchanged',true
  );
  update atlas_legacy.import_batches set
   reconciliation=jsonb_build_object('protected_fingerprints',protected,'target_fingerprints',target_fingerprints),
   result_payload=result,target_counts=jsonb_build_object('corrected_ingredients',8),
   mapping_counts=jsonb_build_object('refreshed_ingredient_mappings',8)
  where import_batch_id=batch;
  return result;
 exception when others then
  return jsonb_build_object('success',false,'status','REJECTED',
   'error_code','INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','apply_phase',phase,'sqlstate',sqlstate);
 end;
end $$;
