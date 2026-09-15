-- Approved OPS v1 master-only rehearsal importer. No hosted seed or runtime API.
-- Actor attribution is execution context; the immutable source file remains portable.
set role atlas_owner;
alter table atlas_legacy.master_data_mappings
  add column last_seen_import_batch_id uuid references atlas_legacy.import_batches(import_batch_id) on delete restrict,
  add column last_source_fingerprint text check (last_source_fingerprint ~ '^[0-9a-f]{64}$'),
  add column last_target_version bigint check (last_target_version > 0),
  add column ingredient_type_id uuid references atlas_admin.ingredient_types(ingredient_type_id) on delete restrict,
  add column ingredient_order_group_id uuid references atlas_admin.ingredient_order_groups(ingredient_order_group_id) on delete restrict,
  add column dish_type_id uuid references atlas_admin.dish_types(dish_type_id) on delete restrict,
  add column supplier_eligibility_id uuid references atlas_admin.supplier_eligibilities(supplier_eligibility_id) on delete restrict;
alter table atlas_legacy.import_batches
  add column operator_actor_id uuid references atlas_core.actors(actor_id) on delete restrict,
  add column execution_database_principal text,
  add column plan_checksum text check (plan_checksum ~ '^[0-9a-f]{64}$'),
  add column snapshot_contract_version text;
alter table atlas_legacy.import_batches add constraint master_import_execution_attribution_check check (
  snapshot_contract_version is distinct from 'OPS-V1-MASTER-SNAPSHOT.v1' or
  (operator_actor_id is not null and nullif(btrim(execution_database_principal),'') is not null and plan_checksum is not null)
);
alter table atlas_legacy.master_data_mappings
  drop constraint master_data_mappings_object_type_check,
  drop constraint master_data_mappings_typed_target_check;
alter table atlas_legacy.master_data_mappings add constraint master_data_mappings_object_type_check check (object_type in ('CUSTOMER','DELIVERY_LOCATION','SCHOOL_TYPE','SCHOOL','UNIT','INGREDIENT','SUPPLIER','DISH','RECIPE','RECIPE_VERSION','RECIPE_LINE','RECIPE_LINE_REVISION','INGREDIENT_TYPE','INGREDIENT_ORDER_GROUP','DISH_TYPE','SUPPLIER_ELIGIBILITY'));
alter table atlas_legacy.master_data_mappings add constraint master_data_mappings_typed_target_check check (num_nonnulls(customer_id,delivery_location_id,school_type_id,school_id,unit_id,ingredient_id,supplier_id,dish_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,ingredient_type_id,ingredient_order_group_id,dish_type_id,supplier_eligibility_id) = 1 and case object_type when 'CUSTOMER' then customer_id is not null when 'DELIVERY_LOCATION' then delivery_location_id is not null when 'SCHOOL_TYPE' then school_type_id is not null when 'SCHOOL' then school_id is not null when 'UNIT' then unit_id is not null when 'INGREDIENT' then ingredient_id is not null when 'SUPPLIER' then supplier_id is not null when 'DISH' then dish_id is not null when 'RECIPE' then recipe_id is not null when 'RECIPE_VERSION' then recipe_version_id is not null when 'RECIPE_LINE' then recipe_line_id is not null when 'RECIPE_LINE_REVISION' then recipe_line_revision_id is not null when 'INGREDIENT_TYPE' then ingredient_type_id is not null when 'INGREDIENT_ORDER_GROUP' then ingredient_order_group_id is not null when 'DISH_TYPE' then dish_type_id is not null when 'SUPPLIER_ELIGIBILITY' then supplier_eligibility_id is not null else false end);

create function atlas_legacy.master_snapshot_canonical(value jsonb)
returns text language plpgsql immutable strict security invoker set search_path = '' as $$
declare result text;
begin
  case jsonb_typeof(value)
    when 'object' then
      select '{'||coalesce(string_agg(to_jsonb(e.key)::text||':'||atlas_legacy.master_snapshot_canonical(e.value),',' order by e.key collate "C"),'')||'}'
      into result from jsonb_each(value) e;
    when 'array' then
      select '['||coalesce(string_agg(atlas_legacy.master_snapshot_canonical(e.value),',' order by e.n),'')||']'
      into result from jsonb_array_elements(value) with ordinality e(value,n);
    else result := value::text;
  end case;
  return result;
end $$;
create function atlas_legacy.master_snapshot_hash(value jsonb)
returns text language sql immutable strict security invoker set search_path = '' as $$
  select encode(extensions.digest(convert_to(atlas_legacy.master_snapshot_canonical(value),'UTF8'),'sha256'),'hex')
$$;
create function atlas_legacy.master_import_entity(kind text)
returns text language sql immutable strict security invoker set search_path = '' as $$ select case kind
when 'INGREDIENT_TYPE' then 'ingredient_types'
when 'INGREDIENT_ORDER_GROUP' then 'ingredient_order_groups'
when 'DISH_TYPE' then 'dish_types'
when 'SCHOOL_TYPE' then 'school_types'
when 'CUSTOMER' then 'customers'
when 'DELIVERY_LOCATION' then 'delivery_locations'
when 'SCHOOL' then 'schools'
when 'UNIT' then 'units'
when 'INGREDIENT' then 'ingredients'
when 'SUPPLIER' then 'suppliers'
when 'SUPPLIER_ELIGIBILITY' then 'supplier_eligibilities'
when 'DISH' then 'dishes' when 'RECIPE' then 'recipes' when 'RECIPE_LINE' then 'recipe_lines' else null end $$;
create function atlas_legacy.master_import_mapping_column(kind text) returns text language sql immutable strict security invoker set search_path='' as $$ select case kind
when 'CUSTOMER' then 'customer_id'
when 'DELIVERY_LOCATION' then 'delivery_location_id'
when 'SCHOOL_TYPE' then 'school_type_id'
when 'SCHOOL' then 'school_id'
when 'UNIT' then 'unit_id'
when 'INGREDIENT' then 'ingredient_id'
when 'SUPPLIER' then 'supplier_id'
when 'DISH' then 'dish_id'
when 'RECIPE' then 'recipe_id'
when 'RECIPE_VERSION' then 'recipe_version_id'
when 'RECIPE_LINE' then 'recipe_line_id'
when 'RECIPE_LINE_REVISION' then 'recipe_line_revision_id'
when 'INGREDIENT_TYPE' then 'ingredient_type_id'
when 'INGREDIENT_ORDER_GROUP' then 'ingredient_order_group_id'
when 'DISH_TYPE' then 'dish_type_id'
when 'SUPPLIER_ELIGIBILITY' then 'supplier_eligibility_id' else null end $$;
create function atlas_legacy.master_import_read(kind text, target uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$ declare result jsonb; begin case kind
when 'INGREDIENT_TYPE' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.ingredient_types r where r.ingredient_type_id=target;
when 'INGREDIENT_ORDER_GROUP' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.ingredient_order_groups r where r.ingredient_order_group_id=target;
when 'DISH_TYPE' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.dish_types r where r.dish_type_id=target;
when 'SCHOOL_TYPE' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.school_types r where r.school_type_id=target;
when 'CUSTOMER' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.customers r where r.customer_id=target;
when 'DELIVERY_LOCATION' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.delivery_locations r where r.delivery_location_id=target;
when 'SCHOOL' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.schools r where r.school_id=target;
when 'UNIT' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.units r where r.unit_id=target;
when 'INGREDIENT' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.ingredients r where r.ingredient_id=target;
when 'SUPPLIER' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.suppliers r where r.supplier_id=target;
when 'SUPPLIER_ELIGIBILITY' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.supplier_eligibilities r where r.supplier_eligibility_id=target;
when 'DISH' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.dishes r where r.dish_id=target;

when 'RECIPE' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.recipes r where r.recipe_id=target;

when 'RECIPE_VERSION' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.recipe_versions r where r.recipe_version_id=target;

when 'RECIPE_LINE' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.recipe_lines r where r.recipe_line_id=target;

when 'RECIPE_LINE_REVISION' then select to_jsonb(r)-'created_at'-'updated_at' into result from atlas_admin.recipe_line_revisions r where r.recipe_line_revision_id=target;
else raise exception 'UNSUPPORTED_IMPORT_OBJECT'; end case; return result; end $$;

create function atlas_legacy.master_import_target_id(snapshot jsonb, kind text, legacy text)
returns uuid language plpgsql stable security invoker set search_path='' as $$
declare source_row jsonb; target uuid; col text := atlas_legacy.master_import_mapping_column(kind);
begin
  if legacy is null or col is null then return null; end if;
  select e.value into source_row from jsonb_array_elements(snapshot #> array['records',atlas_legacy.master_import_entity(kind)]) e
  where e.value->>'legacy_id'=legacy limit 1;
  if source_row is null then return null; end if;
  select (to_jsonb(m)->>col)::uuid into target from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1' and m.object_type=kind and m.legacy_id=legacy;
  if found then return target; end if;
  case kind
    when 'INGREDIENT_TYPE' then select ingredient_type_id into target from atlas_admin.ingredient_types where ingredient_type_name=source_row->>'ingredient_type_name' and ingredient_type_status='ACTIVE'; return target;
    when 'INGREDIENT_ORDER_GROUP' then select ingredient_order_group_id into target from atlas_admin.ingredient_order_groups where ingredient_order_group_name=source_row->>'ingredient_order_group_name' and ingredient_order_group_status='ACTIVE'; return target;
    when 'DISH_TYPE' then select dish_type_id into target from atlas_admin.dish_types where dish_type_code=source_row->>'dish_type_code' and dish_type_status='ACTIVE'; return target;
    when 'UNIT' then select unit_id into target from atlas_admin.units where unit_code=source_row->>'unit_code';
    else null;
  end case;
  return coalesce(target,md5('OPS_V1:'||kind||':'||legacy)::uuid);
end $$;
create function atlas_legacy.master_import_values(snapshot jsonb, kind text, r jsonb, target uuid)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb; current_values jsonb := atlas_legacy.master_import_read(kind,target);
begin
  case kind
    when 'INGREDIENT_TYPE' then return current_values - 'ingredient_type_id';
    when 'INGREDIENT_ORDER_GROUP' then return current_values - 'ingredient_order_group_id';
    when 'DISH_TYPE' then return current_values - 'dish_type_id' - 'version';
    when 'SCHOOL_TYPE' then result:=jsonb_build_object('school_type_code',r->>'school_type_code','school_type_name',r->>'school_type_name','school_type_status',r->>'school_type_status');
    when 'CUSTOMER' then result:=jsonb_build_object('customer_code',r->>'customer_code','customer_name',r->>'customer_name','customer_type','SCHOOL_CATERING','customer_status',r->>'customer_status');
    when 'DELIVERY_LOCATION' then result:=jsonb_build_object('customer_id',atlas_legacy.master_import_target_id(snapshot,'CUSTOMER',r->>'customer_legacy_id'),'location_code',r->>'location_code','location_name',r->>'location_name','address_text',r->>'address_text','delivery_instructions',r->>'delivery_instructions','timezone_name','Asia/Ho_Chi_Minh','location_status',r->>'location_status');
    when 'SCHOOL' then result:=jsonb_build_object('customer_id',atlas_legacy.master_import_target_id(snapshot,'CUSTOMER',r->>'customer_legacy_id'),'customer_type','SCHOOL_CATERING','school_code',r->>'school_code','school_name',r->>'school_name','school_type_id',atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id'),'default_delivery_location_id',atlas_legacy.master_import_target_id(snapshot,'DELIVERY_LOCATION',r->>'delivery_location_legacy_id'),'school_status',r->>'school_status','display_order',(r->>'display_order')::integer,'default_student_portions',(r->>'default_student_portions')::integer,'default_teacher_portions',(r->>'default_teacher_portions')::integer,'dispatch_document_issuer_name',r->>'dispatch_document_issuer_name','dispatch_document_issuer_address',r->>'dispatch_document_issuer_address');
    when 'UNIT' then result:=jsonb_build_object('unit_code',r->>'unit_code','unit_name',r->>'unit_name','dimension_code',r->>'dimension_code','decimal_scale',(r->>'decimal_scale')::integer,'unit_status',r->>'unit_status');
    when 'INGREDIENT' then result:=jsonb_build_object('ingredient_code',r->>'ingredient_code','ingredient_name',r->>'ingredient_name','ingredient_type_id',atlas_legacy.master_import_target_id(snapshot,'INGREDIENT_TYPE',r->>'ingredient_type_legacy_id'),'ingredient_order_group_id',atlas_legacy.master_import_target_id(snapshot,'INGREDIENT_ORDER_GROUP',r->>'ingredient_order_group_legacy_id'),'purchase_unit_id',atlas_legacy.master_import_target_id(snapshot,'UNIT',r->>'purchase_unit_legacy_id'),'order_step',(r->>'order_step')::numeric,'ingredient_status',r->>'ingredient_status');
    when 'SUPPLIER' then result:=jsonb_build_object('supplier_code',r->>'supplier_code','supplier_name',r->>'supplier_name','supplier_status',r->>'supplier_status');
    when 'SUPPLIER_ELIGIBILITY' then result:=jsonb_build_object('supplier_id',atlas_legacy.master_import_target_id(snapshot,'SUPPLIER',r->>'supplier_legacy_id'),'ingredient_id',atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',r->>'ingredient_legacy_id'),'eligibility_status','ACTIVE','priority',(r->>'priority')::smallint,'effective_from',coalesce(current_values->>'effective_from',((snapshot->>'exported_at')::timestamptz at time zone 'UTC')::date::text),'effective_to',null,'reason_note','Current membership imported from an explicit OPS v1 master snapshot; source has no effective dating.');
    else raise exception 'UNSUPPORTED_CORE_IMPORT_OBJECT';
  end case;
  return result;
end $$;

create function atlas_legacy.master_import_validate_values(kind text, legacy text, source_row jsonb, v jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare result jsonb:='[]'; f text; status text;
begin
  if v is null then return result; end if;
  for f in select key from jsonb_each(v) e where e.key not in ('delivery_instructions','effective_to') and (e.value='null'::jsonb or (jsonb_typeof(e.value)='string' and nullif(btrim(e.value #>> '{}'),'') is null)) loop
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_REQUIRED_VALUE','field',f));
  end loop;
  status:=coalesce(v->>'school_type_status',v->>'customer_status',v->>'location_status',v->>'school_status',v->>'unit_status',v->>'ingredient_status',v->>'supplier_status',v->>'eligibility_status');
  if status is not null and status not in ('ACTIVE','INACTIVE','ARCHIVED','SUSPENDED') then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_LIFECYCLE','field','status'));
  end if;
  if kind='SCHOOL_TYPE' and (legacy not in ('1','2') or v->>'school_type_code'<>'v1-school-type-'||legacy or v->>'school_type_name'<>case legacy when '1' then 'TIỂU HỌC' when '2' then 'TRUNG HỌC' end) then
    result:=result||jsonb_build_array(jsonb_build_object('code','UNKNOWN_SCHOOL_TYPE','field','school_type_code'));
  end if;
  if kind='SCHOOL' and ((v->>'display_order')::integer<0 or (v->>'default_student_portions')::integer<0 or (v->>'default_teacher_portions')::integer<0 or v->>'school_code'<>'v1-school-'||legacy or v->>'dispatch_document_issuer_name' not in ('CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO','CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO')) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_SCHOOL_VALUE','field','school'));
  end if;
  if kind='UNIT' then
    if legacy not in ('kg','Bịch','Bó','Cái','Cây','Chai','Cốc','Gói','Hộp','Hũ','Lon','Miếng','Ổ','Quả','Trái') or
      v->>'unit_name'<>(case when legacy='kg' then 'Kilogram' else legacy end) or
      v->>'unit_code'<>(case when legacy='kg' then 'kg' else 'v1-unit-'||substr(encode(extensions.digest(convert_to(legacy,'UTF8'),'sha256'),'hex'),1,12) end) or
      v->>'dimension_code'<>(case when legacy='kg' then 'MASS' else 'COUNT' end) or
      (v->>'decimal_scale')::integer<>(case when legacy='kg' then 6 else 0 end) then
      result:=result||jsonb_build_array(jsonb_build_object('code','UNSUPPORTED_UNIT','field','unit'));
    end if;
  end if;
  if kind='INGREDIENT' and (coalesce(source_row->>'order_step','') !~ '^\d{1,14}(\.\d{1,6})?$' or (v->>'order_step')::numeric<=0 or v->>'ingredient_code'<>'v1-ingredient-'||legacy) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_INGREDIENT_VALUE','field','order_step'));
  end if;
  if kind='SUPPLIER_ELIGIBILITY' and ((v->>'priority')::integer not between 1 and 6) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_PRIORITY','field','priority'));
  end if;
  return result;
end $$;
create function atlas_legacy.master_import_collision(kind text, target uuid, v jsonb) returns boolean language plpgsql stable security invoker set search_path='' as $$ declare result boolean:=false; begin case kind
when 'SCHOOL_TYPE' then select exists(select 1 from atlas_admin.school_types r where r.school_type_id<>target and r.school_type_code::text=v->>'school_type_code') into result;
when 'CUSTOMER' then select exists(select 1 from atlas_admin.customers r where r.customer_id<>target and r.customer_code::text=v->>'customer_code') into result;
when 'DELIVERY_LOCATION' then select exists(select 1 from atlas_admin.delivery_locations r where r.delivery_location_id<>target and r.customer_id::text=v->>'customer_id' and r.location_code::text=v->>'location_code') into result;
when 'SCHOOL' then select exists(select 1 from atlas_admin.schools r where r.school_id<>target and r.customer_id::text=v->>'customer_id' and r.school_code::text=v->>'school_code') into result;
when 'UNIT' then select exists(select 1 from atlas_admin.units r where r.unit_id<>target and r.unit_code::text=v->>'unit_code') into result;
when 'INGREDIENT' then select exists(select 1 from atlas_admin.ingredients r where r.ingredient_id<>target and r.ingredient_code::text=v->>'ingredient_code') into result;
when 'SUPPLIER' then select exists(select 1 from atlas_admin.suppliers r where r.supplier_id<>target and r.supplier_code::text=v->>'supplier_code') into result;
when 'SUPPLIER_ELIGIBILITY' then select exists(select 1 from atlas_admin.supplier_eligibilities r where r.supplier_eligibility_id<>target and r.supplier_id::text=v->>'supplier_id' and r.ingredient_id::text=v->>'ingredient_id' and r.effective_from::text=v->>'effective_from') into result;
else null; end case; return result; end $$;

create function atlas_legacy.master_import_recipe_plan(snapshot jsonb)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('actions','[]'::jsonb,'issues',case when jsonb_array_length(snapshot#>'{records,recipes}')>0 or jsonb_array_length(snapshot#>'{records,dishes}')>0 or jsonb_array_length(snapshot#>'{records,recipe_lines}')>0 then jsonb_build_array(jsonb_build_object('code','RECIPE_EXTENSION_REQUIRED','severity','BLOCKER')) else '[]'::jsonb end)
$$;
create function atlas_legacy.master_import_counts()
returns jsonb language sql stable security invoker set search_path='' as $$ select jsonb_build_object(
'ingredient_types',(select count(*) from atlas_admin.ingredient_types),
'ingredient_order_groups',(select count(*) from atlas_admin.ingredient_order_groups),
'dish_types',(select count(*) from atlas_admin.dish_types),
'school_types',(select count(*) from atlas_admin.school_types),
'customers',(select count(*) from atlas_admin.customers),
'delivery_locations',(select count(*) from atlas_admin.delivery_locations),
'schools',(select count(*) from atlas_admin.schools),
'units',(select count(*) from atlas_admin.units),
'ingredients',(select count(*) from atlas_admin.ingredients),
'suppliers',(select count(*) from atlas_admin.suppliers),
'supplier_eligibilities',(select count(*) from atlas_admin.supplier_eligibilities),'dishes',(select count(*) from atlas_admin.dishes),'recipes',(select count(*) from atlas_admin.recipes),'recipe_versions',(select count(*) from atlas_admin.recipe_versions),'recipe_lines',(select count(*) from atlas_admin.recipe_lines),'recipe_line_revisions',(select count(*) from atlas_admin.recipe_line_revisions)) $$;

create function atlas_legacy.preview_master_data_snapshot(snapshot jsonb)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare
  kinds text[]:=array['INGREDIENT_TYPE','INGREDIENT_ORDER_GROUP','DISH_TYPE','SCHOOL_TYPE','CUSTOMER','DELIVERY_LOCATION','SCHOOL','UNIT','INGREDIENT','SUPPLIER','SUPPLIER_ELIGIBILITY'];
  entities text[]:=array['customers','delivery_locations','dish_types','dishes','ingredient_order_groups','ingredient_types','ingredients','recipe_lines','recipes','school_types','schools','supplier_eligibilities','suppliers','units'];
  kind text; entity text; r jsonb; vals jsonb; current_values jsonb; projected jsonb; row_errors jsonb;
  key text; target uuid; act text; fp text; prior_fps jsonb; expected_fp text;
  actions jsonb:='[]'; issues jsonb:='[]'; plan jsonb; extension jsonb; m record; e record; mapping_counts jsonb;
begin
  if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
  if snapshot is null or jsonb_typeof(snapshot)<>'object' or snapshot->>'contract_version' is distinct from 'OPS-V1-MASTER-SNAPSHOT.v1'
    or snapshot->>'source_system' is distinct from 'OPS_V1' or snapshot->>'source_project_ref' is distinct from 'qnthofvccilhnefdcxnz'
    or nullif(btrim(snapshot->>'snapshot_id'),'') is null or nullif(btrim(snapshot->>'extractor_version'),'') is null
    or atlas_core.pa_05b_safe_timestamptz(snapshot->>'exported_at') is null
    or jsonb_typeof(snapshot->'records') is distinct from 'object'
    or jsonb_typeof(snapshot->'source_diagnostics') is distinct from 'array'
    or snapshot->'complete_entities' is distinct from to_jsonb(entities)
    or (select array_agg(x order by x) from jsonb_object_keys(snapshot->'records') x) is distinct from entities
    or exists(select 1 from jsonb_each(snapshot->'records') x where jsonb_typeof(x.value)<>'array') then
    return jsonb_build_object('success',false,'status','REJECTED','error_code','INVALID_FULL_SNAPSHOT_ENVELOPE','issues',jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','INVALID_FULL_SNAPSHOT_ENVELOPE')));
  end if;
  if snapshot->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum') then
    return jsonb_build_object('success',false,'status','REJECTED','error_code','SNAPSHOT_CHECKSUM_MISMATCH','issues',jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','SNAPSHOT_CHECKSUM_MISMATCH')));
  end if;
  if snapshot#>>'{source_access,role_name}' is distinct from 'supabase_read_only_user'
    or snapshot#>'{source_access,has_required_select}' is distinct from 'true'::jsonb
    or snapshot#>'{source_access,has_non_select_privilege}' is distinct from 'false'::jsonb
    or snapshot#>'{source_access,bypass_rls}' is distinct from 'true'::jsonb
    or snapshot#>'{source_access,superuser}' is distinct from 'false'::jsonb
    or snapshot#>'{source_access,create_role}' is distinct from 'false'::jsonb
    or snapshot#>'{source_access,create_db}' is distinct from 'false'::jsonb then
    issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','SOURCE_NOT_PROVEN_READ_ONLY'));
  end if;
  issues:=issues||(snapshot->'source_diagnostics');
  select b.reconciliation->'target_fingerprints' into prior_fps from atlas_legacy.import_batches b
    where b.source_system='OPS_V1' and b.snapshot_contract_version='OPS-V1-MASTER-SNAPSHOT.v1' and b.import_status='COMPLETED'
    order by b.completed_at desc,b.import_batch_id desc limit 1;
  -- A complete successful readback is retained in the existing receipt, including non-versioned Units/catalogues.
  -- It detects target edits even when a caller omitted a version increment. No extra lifecycle table is needed.
  for m in select mm.*,to_jsonb(mm) as mapped from atlas_legacy.master_data_mappings mm where mm.source_system='OPS_V1' order by mm.object_type,mm.legacy_id loop
    target:=(m.mapped->>atlas_legacy.master_import_mapping_column(m.object_type))::uuid;
    current_values:=atlas_legacy.master_import_read(m.object_type,target);
    expected_fp:=prior_fps #>> array[m.object_type,m.legacy_id];
    if expected_fp is null or current_values is null or expected_fp<>atlas_legacy.master_snapshot_hash(current_values) then
      issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','TARGET_DRIFT','object_type',m.object_type,'legacy_id',m.legacy_id,'target_id',target));
    end if;
  end loop;
  for e in select x.key as entity,y.value->>'legacy_id' as legacy,count(*) as occurrences
    from jsonb_each(snapshot->'records') x cross join lateral jsonb_array_elements(x.value) y
    group by x.key,y.value->>'legacy_id' having nullif(btrim(y.value->>'legacy_id'),'') is null or count(*)>1 loop
    issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','DUPLICATE_OR_MISSING_IDENTITY','entity',e.entity,'legacy_id',e.legacy));
  end loop;
  foreach kind in array kinds loop
    entity:=atlas_legacy.master_import_entity(kind);
    for r in select x.value from jsonb_array_elements(snapshot#>array['records',entity]) x order by x.value->>'legacy_id' collate "C" loop
      key:=r->>'legacy_id';
      begin
        target:=atlas_legacy.master_import_target_id(snapshot,kind,key);
        current_values:=atlas_legacy.master_import_read(kind,target);
        vals:=atlas_legacy.master_import_values(snapshot,kind,r,target);
        row_errors:=atlas_legacy.master_import_validate_values(kind,key,r,vals);
        if target is null or vals is null then row_errors:=row_errors||jsonb_build_array(jsonb_build_object('code','UNRESOLVED_CATALOG','field','reference')); end if;
        if atlas_legacy.master_import_collision(kind,target,vals) then row_errors:=row_errors||jsonb_build_array(jsonb_build_object('code','TARGET_IDENTITY_CONFLICT','field','identity')); end if;
        if current_values is not null and kind not in ('UNIT','INGREDIENT_TYPE','INGREDIENT_ORDER_GROUP','DISH_TYPE') and not exists(select 1 from atlas_legacy.master_data_mappings mm where mm.source_system='OPS_V1' and mm.object_type=kind and mm.legacy_id=key) then
          row_errors:=row_errors||jsonb_build_array(jsonb_build_object('code','UNOWNED_EXISTING_TARGET','field','identity'));
        end if;
        select coalesce(jsonb_object_agg(x.key,current_values->x.key),'{}'::jsonb) into projected from jsonb_each(vals) x;
        if kind in ('UNIT','INGREDIENT_TYPE','INGREDIENT_ORDER_GROUP','DISH_TYPE') and current_values is not null and projected is distinct from vals then
          row_errors:=row_errors||jsonb_build_array(jsonb_build_object('code','CATALOG_CANONICALIZATION_REQUIRED','field','catalogue'));
        end if;
        if jsonb_array_length(row_errors)>0 then act:='BLOCKED';
        elsif exists(select 1 from jsonb_array_elements(issues) i where i->>'code'='TARGET_DRIFT' and i->>'object_type'=kind and i->>'legacy_id'=key) then act:='TARGET_DRIFT';
        elsif current_values is null then act:='CREATE';
        elsif projected=vals then act:='NO_CHANGE';
        elsif coalesce(vals->>'school_status',vals->>'ingredient_status',vals->>'supplier_status',vals->>'customer_status',vals->>'location_status',vals->>'school_type_status') in ('INACTIVE','ARCHIVED') then act:='EXPLICIT_INACTIVATE';
        else act:='UPDATE'; end if;
        for e in select x.value as value from jsonb_array_elements(row_errors) x loop
          issues:=issues||jsonb_build_array(e.value||jsonb_build_object('severity','BLOCKER','object_type',kind,'legacy_id',key));
        end loop;
        fp:=atlas_legacy.master_snapshot_hash(r-'source_record_id');
        actions:=actions||jsonb_build_array(jsonb_build_object('object_type',kind,'legacy_id',key,'action',act,'target_id',target,'values',vals,'source_fingerprint',fp,'target_fingerprint',atlas_legacy.master_snapshot_hash(current_values),'target_version',current_values->'version'));
      exception when invalid_text_representation or numeric_value_out_of_range or invalid_parameter_value then
        actions:=actions||jsonb_build_array(jsonb_build_object('object_type',kind,'legacy_id',key,'action','BLOCKED'));
        issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','INVALID_ROW_VALUE','object_type',kind,'legacy_id',key));
      end;
    end loop;
  end loop;
  for m in select mm.*,to_jsonb(mm) as mapped from atlas_legacy.master_data_mappings mm where mm.source_system='OPS_V1' and mm.object_type=any(kinds) order by mm.object_type,mm.legacy_id loop
    if exists(select 1 from jsonb_array_elements(snapshot#>array['records',atlas_legacy.master_import_entity(m.object_type)]) x where x.value->>'legacy_id'=m.legacy_id) then continue; end if;
    target:=(m.mapped->>atlas_legacy.master_import_mapping_column(m.object_type))::uuid;
    current_values:=atlas_legacy.master_import_read(m.object_type,target);
    act:='MISSING_FROM_SOURCE'; vals:=null;
    if m.object_type='SUPPLIER_ELIGIBILITY' and exists(select 1 from jsonb_array_elements(actions) a where a->>'object_type'='INGREDIENT' and a->>'target_id'=current_values->>'ingredient_id') and exists(select 1 from jsonb_array_elements(actions) a where a->>'object_type'='SUPPLIER' and a->>'target_id'=current_values->>'supplier_id') then
      act:=case when current_values->>'eligibility_status'='INACTIVE' then 'NO_CHANGE' else 'REMOVE_RELATIONSHIP' end;
      vals:=(current_values-'supplier_eligibility_id'-'version')||jsonb_build_object('eligibility_status','INACTIVE');
    end if;
    actions:=actions||jsonb_build_array(jsonb_build_object('object_type',m.object_type,'legacy_id',m.legacy_id,'action',act,'target_id',target,'values',vals,'source_fingerprint',case when act='MISSING_FROM_SOURCE' then m.last_source_fingerprint else atlas_legacy.master_snapshot_hash(jsonb_build_object('membership','ABSENT','legacy_id',m.legacy_id)) end,'target_fingerprint',atlas_legacy.master_snapshot_hash(current_values),'target_version',current_values->'version','absent_from_source',true));
  end loop;
  extension:=atlas_legacy.master_import_recipe_plan(snapshot);
  actions:=actions||coalesce(extension->'actions','[]'); issues:=issues||coalesce(extension->'issues','[]');
  select coalesce(jsonb_object_agg(x.object_type,x.n),'{}') into mapping_counts from (select object_type,count(*) n from atlas_legacy.master_data_mappings where source_system='OPS_V1' group by object_type) x;
  plan:=jsonb_build_object('success',not exists(select 1 from jsonb_array_elements(issues) x where x->>'severity'='BLOCKER'),
    'snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','actions',actions,'issues',issues,
    'source_counts',snapshot->'source_counts','target_counts',atlas_legacy.master_import_counts(),'mapping_counts',mapping_counts);
  return plan||jsonb_build_object('plan_checksum',atlas_legacy.master_snapshot_hash(plan));
end $$;

create function atlas_legacy.master_import_write_core(a jsonb)
returns void language plpgsql volatile security invoker set search_path='' as $$
declare target uuid:=(a->>'target_id')::uuid; v jsonb:=a->'values';
begin
  if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
  if a->>'action' not in ('CREATE','UPDATE','EXPLICIT_INACTIVATE','REMOVE_RELATIONSHIP') then return; end if;
  case a->>'object_type'
when 'SCHOOL_TYPE' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.school_types (school_type_id,school_type_code,school_type_name,school_type_status) select target,r.school_type_code,r.school_type_name,r.school_type_status from jsonb_populate_record(null::atlas_admin.school_types,v) r;
 else
 update atlas_admin.school_types t set school_type_code=r.school_type_code,school_type_name=r.school_type_name,school_type_status=r.school_type_status,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.school_types,v) r where t.school_type_id=target;
 end if;
when 'CUSTOMER' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.customers (customer_id,customer_code,customer_name,customer_type,customer_status) select target,r.customer_code,r.customer_name,r.customer_type,r.customer_status from jsonb_populate_record(null::atlas_admin.customers,v) r;
 else
 update atlas_admin.customers t set customer_code=r.customer_code,customer_name=r.customer_name,customer_type=r.customer_type,customer_status=r.customer_status,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.customers,v) r where t.customer_id=target;
 end if;
when 'DELIVERY_LOCATION' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.delivery_locations (delivery_location_id,customer_id,location_code,location_name,address_text,delivery_instructions,timezone_name,location_status) select target,r.customer_id,r.location_code,r.location_name,r.address_text,r.delivery_instructions,r.timezone_name,r.location_status from jsonb_populate_record(null::atlas_admin.delivery_locations,v) r;
 else
 update atlas_admin.delivery_locations t set customer_id=r.customer_id,location_code=r.location_code,location_name=r.location_name,address_text=r.address_text,delivery_instructions=r.delivery_instructions,timezone_name=r.timezone_name,location_status=r.location_status,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.delivery_locations,v) r where t.delivery_location_id=target;
 end if;
when 'SCHOOL' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.schools (school_id,customer_id,customer_type,school_code,school_name,school_type_id,default_delivery_location_id,school_status,display_order,default_student_portions,default_teacher_portions,dispatch_document_issuer_name,dispatch_document_issuer_address) select target,r.customer_id,r.customer_type,r.school_code,r.school_name,r.school_type_id,r.default_delivery_location_id,r.school_status,r.display_order,r.default_student_portions,r.default_teacher_portions,r.dispatch_document_issuer_name,r.dispatch_document_issuer_address from jsonb_populate_record(null::atlas_admin.schools,v) r;
 else
 update atlas_admin.schools t set customer_id=r.customer_id,customer_type=r.customer_type,school_code=r.school_code,school_name=r.school_name,school_type_id=r.school_type_id,default_delivery_location_id=r.default_delivery_location_id,school_status=r.school_status,display_order=r.display_order,default_student_portions=r.default_student_portions,default_teacher_portions=r.default_teacher_portions,dispatch_document_issuer_name=r.dispatch_document_issuer_name,dispatch_document_issuer_address=r.dispatch_document_issuer_address,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.schools,v) r where t.school_id=target;
 end if;
when 'UNIT' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code,decimal_scale,unit_status) select target,r.unit_code,r.unit_name,r.dimension_code,r.decimal_scale,r.unit_status from jsonb_populate_record(null::atlas_admin.units,v) r;
 else
 update atlas_admin.units t set unit_code=r.unit_code,unit_name=r.unit_name,dimension_code=r.dimension_code,decimal_scale=r.decimal_scale,unit_status=r.unit_status from jsonb_populate_record(null::atlas_admin.units,v) r where t.unit_id=target;
 end if;
when 'INGREDIENT' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name,ingredient_type_id,ingredient_order_group_id,purchase_unit_id,order_step,ingredient_status) select target,r.ingredient_code,r.ingredient_name,r.ingredient_type_id,r.ingredient_order_group_id,r.purchase_unit_id,r.order_step,r.ingredient_status from jsonb_populate_record(null::atlas_admin.ingredients,v) r;
 else
 update atlas_admin.ingredients t set ingredient_code=r.ingredient_code,ingredient_name=r.ingredient_name,ingredient_type_id=r.ingredient_type_id,ingredient_order_group_id=r.ingredient_order_group_id,purchase_unit_id=r.purchase_unit_id,order_step=r.order_step,ingredient_status=r.ingredient_status,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.ingredients,v) r where t.ingredient_id=target;
 end if;
when 'SUPPLIER' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.suppliers (supplier_id,supplier_code,supplier_name,supplier_status) select target,r.supplier_code,r.supplier_name,r.supplier_status from jsonb_populate_record(null::atlas_admin.suppliers,v) r;
 else
 update atlas_admin.suppliers t set supplier_code=r.supplier_code,supplier_name=r.supplier_name,supplier_status=r.supplier_status,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.suppliers,v) r where t.supplier_id=target;
 end if;
when 'SUPPLIER_ELIGIBILITY' then
 if a->>'action'='CREATE' then
 insert into atlas_admin.supplier_eligibilities (supplier_eligibility_id,supplier_id,ingredient_id,eligibility_status,priority,effective_from,effective_to,reason_note) select target,r.supplier_id,r.ingredient_id,r.eligibility_status,r.priority,r.effective_from,r.effective_to,r.reason_note from jsonb_populate_record(null::atlas_admin.supplier_eligibilities,v) r;
 else
 update atlas_admin.supplier_eligibilities t set supplier_id=r.supplier_id,ingredient_id=r.ingredient_id,eligibility_status=r.eligibility_status,priority=r.priority,effective_from=r.effective_from,effective_to=r.effective_to,reason_note=r.reason_note,version=t.version+1,updated_at=clock_timestamp() from jsonb_populate_record(null::atlas_admin.supplier_eligibilities,v) r where t.supplier_eligibility_id=target;
 end if;
else raise exception 'UNSUPPORTED_CORE_IMPORT_WRITE'; end case; end $$;

create function atlas_legacy.master_import_apply_recipes(snapshot jsonb, plan jsonb, actor uuid)
returns void language plpgsql volatile security invoker set search_path='' as $$ begin
  if jsonb_array_length(snapshot#>'{records,recipes}')>0 then raise exception 'RECIPE_EXTENSION_REQUIRED'; end if;
end $$;
create function atlas_legacy.master_import_record_mapping(a jsonb,batch uuid)
returns void language plpgsql volatile security invoker set search_path='' as $$
declare target uuid:=(a->>'target_id')::uuid; current_values jsonb;
begin
  if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
  if a->>'action' in ('MISSING_FROM_SOURCE','BLOCKED','TARGET_DRIFT') then return; end if;
  current_values:=atlas_legacy.master_import_read(a->>'object_type',target);
  if current_values is null then raise exception 'MAPPING_TARGET_MISSING'; end if;
  insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,
customer_id,delivery_location_id,school_type_id,school_id,unit_id,ingredient_id,supplier_id,dish_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,ingredient_type_id,ingredient_order_group_id,dish_type_id,supplier_eligibility_id,last_seen_import_batch_id,last_source_fingerprint,last_target_version)
values (batch,'OPS_V1',a->>'object_type',a->>'legacy_id',
case when a->>'object_type'='CUSTOMER' then target end,case when a->>'object_type'='DELIVERY_LOCATION' then target end,case when a->>'object_type'='SCHOOL_TYPE' then target end,case when a->>'object_type'='SCHOOL' then target end,case when a->>'object_type'='UNIT' then target end,case when a->>'object_type'='INGREDIENT' then target end,case when a->>'object_type'='SUPPLIER' then target end,case when a->>'object_type'='DISH' then target end,case when a->>'object_type'='RECIPE' then target end,case when a->>'object_type'='RECIPE_VERSION' then target end,case when a->>'object_type'='RECIPE_LINE' then target end,case when a->>'object_type'='RECIPE_LINE_REVISION' then target end,case when a->>'object_type'='INGREDIENT_TYPE' then target end,case when a->>'object_type'='INGREDIENT_ORDER_GROUP' then target end,case when a->>'object_type'='DISH_TYPE' then target end,case when a->>'object_type'='SUPPLIER_ELIGIBILITY' then target end,batch,a->>'source_fingerprint',(current_values->>'version')::bigint)
on conflict (source_system,object_type,legacy_id) do update set
 last_seen_import_batch_id=case when (a->>'absent_from_source')::boolean is true then master_data_mappings.last_seen_import_batch_id else excluded.last_seen_import_batch_id end,
 last_source_fingerprint=excluded.last_source_fingerprint,last_target_version=excluded.last_target_version,updated_at=clock_timestamp();
end $$;

create function atlas_legacy.master_import_capture_fingerprints()
returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_object_agg(s.object_type,s.fps),'{}') from (
 select m.object_type,jsonb_object_agg(m.legacy_id,atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read(m.object_type,(to_jsonb(m)->>atlas_legacy.master_import_mapping_column(m.object_type))::uuid))) fps
 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' group by m.object_type) s
$$;
create function atlas_legacy.apply_master_data_snapshot(snapshot jsonb, expected_plan_checksum text, operator_actor_id uuid)
returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare p jsonb; a jsonb; b atlas_legacy.import_batches%rowtype; batch uuid:=gen_random_uuid(); result jsonb; after_plan jsonb;
  counts jsonb; target_before jsonb; fps jsonb;
begin
  if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
  if operator_actor_id is null then return jsonb_build_object('success',false,'status','REJECTED','error_code','IMPORT_ACTOR_REQUIRED'); end if;
  perform 1 from atlas_core.actors actor where actor.actor_id=operator_actor_id and actor.actor_status='ACTIVE' for share;
  if not found then return jsonb_build_object('success',false,'status','REJECTED','error_code','IMPORT_ACTOR_INACTIVE_OR_MISSING'); end if;
  -- Explicit, deterministic table locking also protects uncreated identities and immutable Menu-use evidence.
  -- No hosted execution is authorized by installing these private functions.
  lock table atlas_admin.customers,atlas_admin.delivery_locations,atlas_admin.dish_types,atlas_admin.dishes,
    atlas_admin.ingredient_order_groups,atlas_admin.ingredient_types,atlas_admin.ingredients,
    atlas_admin.recipe_line_revisions,atlas_admin.recipe_lines,atlas_admin.recipe_versions,atlas_admin.recipes,
    atlas_admin.school_types,atlas_admin.schools,atlas_admin.supplier_eligibilities,atlas_admin.suppliers,atlas_admin.units,
    atlas_legacy.import_batches,atlas_legacy.master_data_mappings in share row exclusive mode;
  p:=atlas_legacy.preview_master_data_snapshot(snapshot);
  if p->>'success' is distinct from 'true' then
    return jsonb_build_object('success',false,'status','REJECTED','error_code',case when exists(select 1 from jsonb_array_elements(coalesce(p->'issues','[]')) i where i->>'code'='TARGET_DRIFT') then 'TARGET_DRIFT' else coalesce(p->>'error_code','SNAPSHOT_BLOCKED') end,'preview',p);
  end if;
  select * into b from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id=snapshot->>'snapshot_id';
  if found then
    if b.snapshot_checksum is distinct from snapshot->>'snapshot_checksum' then return jsonb_build_object('success',false,'status','REJECTED','error_code','SNAPSHOT_ID_CONFLICT'); end if;
    if b.operator_actor_id is distinct from operator_actor_id then return jsonb_build_object('success',false,'status','REJECTED','error_code','IMPORT_ACTOR_REPLAY_CONFLICT'); end if;
    if expected_plan_checksum is null or (expected_plan_checksum<>b.plan_checksum and expected_plan_checksum<>p->>'plan_checksum') then return jsonb_build_object('success',false,'status','REJECTED','error_code','PLAN_CHECKSUM_MISMATCH'); end if;
    return b.result_payload||jsonb_build_object('status','REPLAYED','current_preview',p);
  end if;
  if expected_plan_checksum is null or expected_plan_checksum is distinct from p->>'plan_checksum' then return jsonb_build_object('success',false,'status','REJECTED','error_code','PLAN_CHECKSUM_MISMATCH'); end if;
  target_before:=atlas_legacy.master_import_counts();
  insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
  values(batch,'OPS_V1',snapshot->>'snapshot_id',snapshot->>'snapshot_checksum',(snapshot->>'exported_at')::timestamptz,'COMPLETED',clock_timestamp(),operator_actor_id,session_user,expected_plan_checksum,'OPS-V1-MASTER-SNAPSHOT.v1',snapshot->'source_counts');
  for a in select x.value from jsonb_array_elements(p->'actions') x where x.value->>'object_type' not in ('DISH','RECIPE','RECIPE_VERSION','RECIPE_LINE','RECIPE_LINE_REVISION') loop
    perform atlas_legacy.master_import_write_core(a);
  end loop;
  -- Membership/priority change is part of the Ingredient master aggregate's versioned state.
  update atlas_admin.ingredients i set version=i.version+1,updated_at=clock_timestamp()
    where i.ingredient_id in (select distinct (x.value#>>'{values,ingredient_id}')::uuid from jsonb_array_elements(p->'actions') x where x.value->>'object_type'='SUPPLIER_ELIGIBILITY' and x.value->>'action' in ('CREATE','UPDATE','REMOVE_RELATIONSHIP'));
  perform atlas_legacy.master_import_apply_recipes(snapshot,p,operator_actor_id);
  for a in select x.value from jsonb_array_elements(p->'actions') x loop
    perform atlas_legacy.master_import_record_mapping(a,batch);
  end loop;
  fps:=atlas_legacy.master_import_capture_fingerprints();
  select coalesce(jsonb_object_agg(s.action,s.n),'{}') into counts from (select x.value->>'action' action,count(*) n from jsonb_array_elements(p->'actions') x group by 1) s;
  result:=jsonb_build_object('success',true,'status','COMPLETED','gate','REHEARSAL_ACCEPTED','import_batch_id',batch,'operator_actor_id',operator_actor_id,
    'snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','plan_checksum',expected_plan_checksum,
    'source_counts',snapshot->'source_counts','operation_counts',counts,'target_counts_before',target_before,'target_counts_after',atlas_legacy.master_import_counts(),'issues',p->'issues');
  update atlas_legacy.import_batches set target_counts=result->'target_counts_after',operation_counts=counts,
    reconciliation=jsonb_build_object('target_fingerprints',fps,'actions',p->'actions','issues',p->'issues'),result_payload=result,completed_at=clock_timestamp()
    where import_batch_id=batch;
  after_plan:=atlas_legacy.preview_master_data_snapshot(snapshot);
  if after_plan->>'success' is distinct from 'true' or exists(select 1 from jsonb_array_elements(after_plan->'actions') x where x.value->>'action' not in ('NO_CHANGE','MISSING_FROM_SOURCE')) then
    raise exception using errcode='23514',message='IMPORT_READBACK_DID_NOT_RECONCILE';
  end if;
  return result;
exception
  when serialization_failure or deadlock_detected then return jsonb_build_object('success',false,'status','REJECTED','error_code','RETRYABLE_CONCURRENCY_FAILURE');
  when check_violation or foreign_key_violation or unique_violation or not_null_violation then return jsonb_build_object('success',false,'status','REJECTED','error_code','APPLY_INVARIANT_FAILURE','constraint_state',sqlstate);
end $$;
revoke all on function atlas_legacy.master_snapshot_canonical(jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_snapshot_hash(jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_entity(text) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_mapping_column(text) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_read(text,uuid) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_target_id(jsonb,text,text) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_values(jsonb,text,jsonb,uuid) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_validate_values(text,text,jsonb,jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_collision(text,uuid,jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_recipe_plan(jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_counts() from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.preview_master_data_snapshot(jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_write_core(jsonb) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_apply_recipes(jsonb,jsonb,uuid) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_record_mapping(jsonb,uuid) from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.master_import_capture_fingerprints() from public, anon, authenticated, service_role;
revoke all on function atlas_legacy.apply_master_data_snapshot(jsonb,text,uuid) from public, anon, authenticated, service_role;
reset role;
