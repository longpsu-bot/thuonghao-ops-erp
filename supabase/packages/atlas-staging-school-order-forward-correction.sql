-- Reviewed forward correction only. Session-local, postgres invoker, no permanent API.
create or replace function pg_temp.school_order_original_receipt_hash()
returns text language sql immutable set search_path='' as $$
select 'd40db1e5ee7512674c519bf60d4a21866a78935f3a16d43c2bb70d146750e2d9'::text $$;
create or replace function pg_temp.school_order_original_mapping_hash()
returns text language sql immutable set search_path='' as $$
select '2789ec47a4edadaf181e30b8931ae47044c608473ebfcfa5bcac4b16f56cf8b8'::text $$;

create or replace function pg_temp.school_order_all_school_fingerprints()
returns jsonb language sql stable set search_path='' as $$
select coalesce(jsonb_object_agg(s.school_id::text,atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read('SCHOOL',s.school_id))),'{}') from atlas_admin.schools s $$;

create or replace function pg_temp.school_order_platform_fingerprints()
returns jsonb language plpgsql stable set search_path='' as $$
declare t record; v jsonb; result jsonb:='{}'; expression text;
begin
 for t in select n.nspname,c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname like 'atlas\_%' escape '\'
 and c.relkind in ('r','p') and not (n.nspname='atlas_legacy' and c.relname='import_batches') order by 1,2 loop
  expression:=case when t.nspname='atlas_admin' and t.relname='schools' then 'to_jsonb(t)-''display_order''-''version''-''updated_at''' else 'to_jsonb(t)' end;
  execute format('select jsonb_build_object(''rows'',count(*),''sha256'',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(%s order by (%s)::text),''[]''::jsonb))) from %I.%I t',expression,expression,t.nspname,t.relname) into v;
  result:=result||jsonb_build_object(t.nspname||'.'||t.relname,v);
 end loop;
 select jsonb_build_object('rows',count(*),'sha256',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(b) order by b.source_system,b.snapshot_id),'[]')))
 into v from atlas_legacy.import_batches b where b.snapshot_id<>'ops-v1-school-order-forward-correction-38071834975-1-v1';
 return result||jsonb_build_object('atlas_legacy.historical_import_batches',v);
end $$;

-- Pure PostgreSQL allocator: order facts come exclusively from the immutable receipt.
create or replace function pg_temp.school_order_corrected_positions(original jsonb,schools jsonb,mappings jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare item record; previous jsonb; row_value jsonb; old_order integer; candidate integer; legacy text;
 block_ids jsonb; baseline_ids jsonb; target_other jsonb; expected_other jsonb; result jsonb:='[]'; reason text; block_name text;
 previous_order integer:=-1; bp_ids jsonb; hv_ids jsonb; sorted_ids jsonb;
begin
 select jsonb_agg(m.value->'school_id' order by b.ordinality) into bp_ids from jsonb_array_elements_text('["52","10"]') with ordinality b
 join jsonb_array_elements(mappings) m on m.value->>'legacy_id'=b.value and m.value->>'object_type'='SCHOOL' and m.value->>'source_system'='OPS_V1';
 select jsonb_agg(m.value->'school_id' order by b.ordinality) into hv_ids from jsonb_array_elements_text('["47","48","49","50","53"]') with ordinality b
 join jsonb_array_elements(mappings) m on m.value->>'legacy_id'=b.value and m.value->>'object_type'='SCHOOL' and m.value->>'source_system'='OPS_V1';
 if coalesce(jsonb_array_length(bp_ids),0)<>2 or coalesce(jsonb_array_length(hv_ids),0)<>5 then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
 block_ids:=bp_ids||hv_ids;
 if jsonb_array_length(original->'target_school_order_ids')<>jsonb_array_length(schools)
 or (select count(distinct value) from jsonb_array_elements(original->'target_school_order_ids'))<>jsonb_array_length(schools)
 or exists(select 1 from jsonb_array_elements(schools) s where not original->'target_school_order_ids' @> jsonb_build_array(s.value->'school_id'))
 then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
 select jsonb_agg(r.value order by r.ordinality) into target_other from jsonb_array_elements(original->'target_school_order_ids') with ordinality r where not block_ids @> jsonb_build_array(r.value);
 select jsonb_agg(r.value->'school_id' order by (r.value->>'display_order')::integer,r.value->>'school_name',(r.value->>'school_id')::uuid)
 into expected_other from jsonb_array_elements(original->'current_schools') r where not block_ids @> jsonb_build_array(r.value->'school_id');
 if target_other is distinct from expected_other then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
 if not exists(select 1 from generate_series(0,jsonb_array_length(original->'target_school_order_ids')-2) i where (original->'target_school_order_ids')->i=bp_ids->0 and (original->'target_school_order_ids')->(i+1)=bp_ids->1)
 or not exists(select 1 from generate_series(0,jsonb_array_length(original->'target_school_order_ids')-5) i where (select jsonb_agg((original->'target_school_order_ids')->(i+j) order by j) from generate_series(0,4) j)=hv_ids)
 then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
 for item in select value id,ordinality from jsonb_array_elements(original->'target_school_order_ids') with ordinality loop
  select value into row_value from jsonb_array_elements(schools) s where s.value->'school_id'=item.id;
  select (value->>'display_order')::integer into old_order from jsonb_array_elements(original->'current_schools') b where b.value->'school_id'=item.id;
  select value->>'legacy_id' into legacy from jsonb_array_elements(mappings) m where m.value->'school_id'=item.id and m.value->>'object_type'='SCHOOL' and m.value->>'source_system'='OPS_V1';
  block_name:=case when legacy in ('52','10') then 'BINH_QUOI' when legacy in ('47','48','49','50','53') then 'HUNG_VUONG' end;
  -- A new canonical row has no pre-reconciliation numeric fact. Start at zero
  -- and let the preceding PostgreSQL comparator determine its minimum position.
  candidate:=case when legacy in ('48','49','50','53') then previous_order+1 when legacy='10' then previous_order else coalesce(old_order,0) end;
  if candidate is null then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  if legacy not in ('48','49','50','53') or legacy is null then
   candidate:=greatest(candidate,previous_order+case when previous is null or (previous->>'school_name',(previous->>'school_id')::uuid)<(row_value->>'school_name',(row_value->>'school_id')::uuid) then 0 else 1 end);
   while row_value->>'school_status'='ACTIVE' and exists(select 1 from jsonb_array_elements(result) r where (r.value->>'display_order')::integer=candidate and r.value->>'customer_id'=row_value->>'customer_id' and r.value->>'school_status'='ACTIVE') loop candidate:=candidate+1; end loop;
  elsif exists(select 1 from jsonb_array_elements(result) r where (r.value->>'display_order')::integer=candidate and r.value->>'customer_id'=row_value->>'customer_id' and r.value->>'school_status'='ACTIVE') then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  reason:=case when old_order is null then 'NEW_CANONICAL_SCHOOL' when legacy='10' then 'BINH_QUOI_BLOCK' when block_name='HUNG_VUONG' then 'HUNG_VUONG_BLOCK' when candidate<>old_order then 'SHIFT_FOR_BLOCK_COLLISION' when candidate=(row_value->>'display_order')::integer then 'UNCHANGED' else 'RESTORE_PRE_RECONCILIATION' end;
  result:=result||jsonb_build_array(row_value||jsonb_build_object('display_order',candidate,'pre_reconciliation_order',old_order,'current_dense_order',(row_value->>'display_order')::integer,'corrected_order',candidate,'changed_by_forward_correction',candidate<>(row_value->>'display_order')::integer,'reason',reason,'block',block_name));
  previous:=row_value; previous_order:=candidate;
 end loop;
 select jsonb_agg(r.value->'school_id' order by (r.value->>'display_order')::integer,r.value->>'school_name',(r.value->>'school_id')::uuid) into sorted_ids from jsonb_array_elements(result) r;
 if sorted_ids is distinct from original->'target_school_order_ids'
 or exists(select 1 from jsonb_array_elements(result) r where r.value->>'school_status'='ACTIVE' group by r.value->>'customer_id',r.value->>'display_order' having count(*)>1)
 or not exists(select 1 from jsonb_array_elements(result) with ordinality r where (r.value->>'display_order')::integer<>r.ordinality-1)
 then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
 return result;
end $$;

create or replace function pg_temp.run_school_order_forward_correction(apply_requested boolean,expected_plan_checksum text)
returns jsonb language plpgsql volatile set search_path='' as $$
declare original atlas_legacy.import_batches%rowtype; receipt atlas_legacy.import_batches%rowtype; t record;
 snapshot text:='ops-v1-school-order-forward-correction-38071834975-1-v1';
 actor uuid:=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor');
 full_schools jsonb; maps jsonb; map_hash text; positions jsonb; report jsonb; orders jsonb; plan jsonb; protected jsonb;
 oldhash text; before_schools jsonb; offset_order bigint; changed integer; batch uuid:=gen_random_uuid();
begin
 begin
  if current_user<>'postgres' or session_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  perform pg_advisory_xact_lock(hashtextextended('atlas-staging-master-load',0));
  -- Freeze every protected fact, including mappings and historical receipts.
  for t in select n.nspname,c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','p') order by 1,2 loop
   execute format('lock table %I.%I in share row exclusive mode',t.nspname,t.relname);
  end loop;
  lock table supabase_migrations.schema_migrations in share mode;
  if (select count(*) from supabase_migrations.schema_migrations)<>97 or (select max(version) from supabase_migrations.schema_migrations)<>'20261010034834'
  or not exists(select 1 from atlas_core.actors where actor_id=actor and actor_type='MIGRATION' and actor_status='ACTIVE' and display_name='Atlas Staging OPS v1 Master Import (GitHub Actions)') then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  select * into original from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id='ops-v1-school-reconciliation-38071834975-1';
  oldhash:=atlas_legacy.master_snapshot_hash(to_jsonb(original));
  if oldhash is distinct from pg_temp.school_order_original_receipt_hash() or original.import_status is distinct from 'COMPLETED'
  or original.snapshot_checksum is distinct from 'fe88da258a81e890f3a521de4334062e29080309ccd032189b0e1c5176959945'
  or original.plan_checksum is distinct from '56565d5c34312f10f54fb3a4861cc16410f885a19bb2563c6decdcd3a21a1518' then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  protected:=pg_temp.school_order_platform_fingerprints();
  select atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(m) order by source_system,object_type,legacy_id),'[]')) into map_hash from atlas_legacy.master_data_mappings m;
  if map_hash is distinct from pg_temp.school_order_original_mapping_hash() then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  select * into receipt from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id=snapshot;
  if found then
   if receipt.import_status is distinct from 'COMPLETED' or receipt.snapshot_contract_version is distinct from 'OPS-V1-SCHOOL-ORDER-FORWARD-CORRECTION.v1'
   or receipt.operator_actor_id is distinct from actor or receipt.execution_database_principal is distinct from 'postgres'
   or receipt.reconciliation->>'original_receipt_hash' is distinct from oldhash
   or receipt.reconciliation->'protected_fingerprints' is distinct from protected
   or receipt.reconciliation->'all_school_fingerprints' is distinct from pg_temp.school_order_all_school_fingerprints()
   or receipt.snapshot_checksum is distinct from atlas_legacy.master_snapshot_hash(receipt.result_payload-'plan_checksum')
   or receipt.plan_checksum is distinct from receipt.snapshot_checksum then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
   if apply_requested and expected_plan_checksum is distinct from receipt.plan_checksum then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
   return receipt.result_payload||jsonb_build_object('status',case when apply_requested then 'REPLAYED' else 'PREVIEW' end,'import_batch_id',receipt.import_batch_id,'correction_already_applied',true,'reconciled',true,'operational_data_unchanged',true,'unrelated_master_facts_unchanged',true,'original_receipt_unchanged',true);
  end if;
  if pg_temp.school_order_all_school_fingerprints() is distinct from original.reconciliation->'all_school_fingerprints'
  or (select count(*) from atlas_admin.schools)<>50 or jsonb_array_length(original.result_payload->'current_schools')<>44
  or exists(select 1 from jsonb_array_elements(original.result_payload->'target_school_display_orders') o left join atlas_admin.schools s on s.school_id=(o.value->>'school_id')::uuid where s.school_id is null or s.display_order is distinct from (o.value->>'display_order')::integer)
  then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  select jsonb_agg(jsonb_build_object('source_system',m.source_system,'object_type',m.object_type,'legacy_id',m.legacy_id,'school_id',m.school_id) order by m.legacy_id) into maps from atlas_legacy.master_data_mappings m where source_system='OPS_V1' and object_type='SCHOOL';
  if (select jsonb_agg(value order by value->>'legacy_id') from jsonb_array_elements(original.result_payload->'projected_mappings')) is distinct from maps then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  select jsonb_agg(to_jsonb(s) order by display_order,school_name,school_id) into full_schools from atlas_admin.schools s;
  positions:=pg_temp.school_order_corrected_positions(original.result_payload,full_schools,maps);
  select jsonb_agg(jsonb_build_object('school_id',r.value->'school_id','school_code',r.value->'school_code','school_name',r.value->'school_name','pre_reconciliation_order',r.value->'pre_reconciliation_order','current_dense_order',r.value->'current_dense_order','corrected_order',r.value->'corrected_order','changed_by_forward_correction',r.value->'changed_by_forward_correction','reason',r.value->'reason','block',r.value->'block') order by r.ordinality),
   jsonb_agg(jsonb_build_object('school_id',r.value->'school_id','display_order',r.value->'corrected_order') order by r.ordinality) into report,orders from jsonb_array_elements(positions) with ordinality r;
  if (select count(*) from jsonb_array_elements(report) r where (r.value->>'pre_reconciliation_order')::integer is not null and r.value->'pre_reconciliation_order'<>r.value->'corrected_order')<>5
  or (select count(*) from jsonb_array_elements(report) r where (r.value->>'changed_by_forward_correction')::boolean)<>49 then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  plan:=jsonb_build_object('success',true,'status','PREVIEW','snapshot_id',snapshot,'original_receipt_hash',oldhash,'original_snapshot_id',original.snapshot_id,'original_snapshot_checksum',original.snapshot_checksum,'original_plan_checksum',original.plan_checksum,'report',report,'target_school_order_ids',original.result_payload->'target_school_order_ids','target_school_display_orders',orders,'protected_fingerprints',protected,'correction_already_applied',false);
  plan:=plan||jsonb_build_object('plan_checksum',atlas_legacy.master_snapshot_hash(plan));
  if not apply_requested then return plan; end if;
  if expected_plan_checksum is distinct from plan->>'plan_checksum' then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  before_schools:=full_schools;
  select max(display_order)::bigint+100 into offset_order from atlas_admin.schools;
  if offset_order+50>2147483647 then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  -- Unique high positions avoid transient ACTIVE Customer collisions; versions advance once.
  update atlas_admin.schools s set display_order=(offset_order+r.ordinality)::integer from jsonb_array_elements(report) with ordinality r where s.school_id=(r.value->>'school_id')::uuid and (r.value->>'changed_by_forward_correction')::boolean;
  update atlas_admin.schools s set display_order=(r.value->>'corrected_order')::integer,version=s.version+1,updated_at=clock_timestamp() from jsonb_array_elements(report) r where s.school_id=(r.value->>'school_id')::uuid and (r.value->>'changed_by_forward_correction')::boolean;
  get diagnostics changed=row_count;
  if changed<>49 or pg_temp.school_order_platform_fingerprints() is distinct from protected
  or exists(select 1 from jsonb_array_elements(before_schools) b join atlas_admin.schools s on s.school_id=(b.value->>'school_id')::uuid join jsonb_array_elements(report) r on r.value->'school_id'=b.value->'school_id' where s.version<>(b.value->>'version')::bigint+case when (r.value->>'changed_by_forward_correction')::boolean then 1 else 0 end or s.display_order<>(r.value->>'corrected_order')::integer)
  then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts,operation_counts,reconciliation,result_payload)
  values(batch,'OPS_V1',snapshot,expected_plan_checksum,original.exported_at,'COMPLETED',clock_timestamp(),actor,session_user,expected_plan_checksum,'OPS-V1-SCHOOL-ORDER-FORWARD-CORRECTION.v1',jsonb_build_object('schools',50),jsonb_build_object('OWNER_ORDER_UPDATE',changed),jsonb_build_object('original_receipt_hash',oldhash,'protected_fingerprints',protected,'all_school_fingerprints',pg_temp.school_order_all_school_fingerprints()),plan);
  if pg_temp.school_order_platform_fingerprints() is distinct from protected then raise exception 'SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW'; end if;
  return plan||jsonb_build_object('status','APPLIED','import_batch_id',batch,'owner_order_update_count',changed,'reconciled',true,'operational_data_unchanged',true,'unrelated_master_facts_unchanged',true,'original_receipt_unchanged',true);
 exception when others then return jsonb_build_object('success',false,'status','REJECTED','error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','sqlstate',sqlstate);
 end;
end $$;
