-- Exact Owner-approved Unit vocabulary, exercised without importing hosted data.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path=pg_catalog,public,extensions;
select plan(18);

create function pg_temp.unit_values(label text) returns jsonb language sql immutable as $$
 select jsonb_build_object(
   'unit_code',case when label='kg' then 'kg' else 'v1-unit-'||substr(encode(extensions.digest(convert_to(label,'UTF8'),'sha256'),'hex'),1,12) end,
   'unit_name',case when label='kg' then 'Kilogram' else label end,
   'dimension_code',case when label='kg' then 'MASS' else 'COUNT' end,
   'decimal_scale',case when label='kg' then 6 else 0 end,
   'unit_status','ACTIVE');
$$;
select is(pg_temp.unit_values('Túi')->>'unit_code','v1-unit-67df33ade68a','existing SHA256 algorithm derives exact Túi identity');
select is(atlas_legacy.master_import_validate_values('UNIT','Túi','{}',pg_temp.unit_values('Túi')),'[]'::jsonb,'Túi is accepted as its own active COUNT Unit at scale zero');
select is((select count(*) from unnest(array['kg','Hũ','Gói','Cái','Bịch']) label where atlas_legacy.master_import_validate_values('UNIT',label,'{}',pg_temp.unit_values(label))='[]'::jsonb),5::bigint,'existing canonical Unit meanings remain accepted');
select is(atlas_legacy.master_import_validate_values('UNIT','Bao','{}',pg_temp.unit_values('Bao')),'[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb,'unknown future COUNT labels remain unsupported');
select is(atlas_legacy.master_import_validate_values('UNIT','Tui','{}',pg_temp.unit_values('Tui')),'[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb,'unapproved spelling is not a new alias');
select is(atlas_legacy.master_import_validate_values('UNIT','Túi','{}',pg_temp.unit_values('Gói')),'[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb,'Túi cannot resolve to Gói');
select is(atlas_legacy.master_import_validate_values('UNIT','Túi','{}',jsonb_set(pg_temp.unit_values('Túi'),'{dimension_code}','"MASS"')),'[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb,'Túi cannot change dimension');
select is(atlas_legacy.master_import_validate_values('UNIT','Túi','{}',jsonb_set(pg_temp.unit_values('Túi'),'{decimal_scale}','6')),'[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb,'Túi cannot change decimal scale');
select is((select count(distinct pg_temp.unit_values(label)->>'unit_code') from unnest(array['Túi','Gói','Cái','Bịch']) label),4::bigint,'Túi identity remains distinct from Gói, Cái and Bịch');

-- Model the preview overlay solely in pg_temp. The JavaScript builder test
-- checks its exact candidate migration source; this test checks SQL semantics.
create temp table validator_before as
select pg_get_functiondef(p.oid) definition,to_jsonb(p) metadata
from pg_proc p
where p.oid='atlas_legacy.master_import_validate_values(text,text,jsonb,jsonb)'::regprocedure;
do $temporary_validators$
declare definition text; candidate text; old_definition text; token text:=',''Túi''';
begin
 select b.definition into strict definition from validator_before b;
 if (length(definition)-length(replace(definition,token,'')))/length(token)<>1
  or (length(definition)-length(replace(definition,'atlas_legacy.master_import_validate_values','')))/length('atlas_legacy.master_import_validate_values')<>1 then
  raise exception 'VALIDATOR_FIXTURE_STRUCTURE_CHANGED';
 end if;
 candidate:=replace(definition,'atlas_legacy.master_import_validate_values','pg_temp.planning_catchup_preview_validate_values');
 old_definition:=replace(replace(definition,token,''),'atlas_legacy.master_import_validate_values','pg_temp.planning_catchup_old_validate_values');
 execute candidate;
 execute old_definition;
end $temporary_validators$;

create temp table approved_unit_labels(label text primary key);
insert into approved_unit_labels values
 ('kg'),('Bịch'),('Bó'),('Cái'),('Cây'),('Chai'),('Cốc'),('Gói'),('Hộp'),('Hũ'),('Lon'),('Miếng'),('Ổ'),('Quả'),('Trái'),('Túi');
create temp table unit_validation_cases as
select label,variant,case variant
 when 'valid' then pg_temp.unit_values(label)
 when 'code' then jsonb_set(pg_temp.unit_values(label),'{unit_code}','"unapproved-code"')
 when 'name' then jsonb_set(pg_temp.unit_values(label),'{unit_name}','"Unapproved name"')
 when 'dimension' then jsonb_set(pg_temp.unit_values(label),'{dimension_code}',to_jsonb(case when label='kg' then 'COUNT' else 'MASS' end))
 when 'scale' then jsonb_set(pg_temp.unit_values(label),'{decimal_scale}',to_jsonb(case when label='kg' then 0 else 6 end))
 when 'lifecycle' then jsonb_set(pg_temp.unit_values(label),'{unit_status}','"UNAPPROVED"')
 end vals
from approved_unit_labels cross join unnest(array['valid','code','name','dimension','scale','lifecycle']) variant;

select is(pg_temp.planning_catchup_old_validate_values('UNIT','Túi','{}',pg_temp.unit_values('Túi')),'[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb,'pre-migration vocabulary rejects Túi without changing the authoritative function');
select is(pg_temp.planning_catchup_preview_validate_values('UNIT','Túi','{}',pg_temp.unit_values('Túi')),'[]'::jsonb,'session-local candidate accepts exact Túi before deployment');
select is((select count(*) from unit_validation_cases where pg_temp.planning_catchup_preview_validate_values('UNIT',label,'{}',vals) is distinct from atlas_legacy.master_import_validate_values('UNIT',label,'{}',vals)),0::bigint,'candidate matches deployed validation across all 16 labels and six value variants');
select is((select count(*) from approved_unit_labels where pg_temp.planning_catchup_preview_validate_values('UNIT',label,'{}',pg_temp.unit_values(label))='[]'::jsonb),16::bigint,'candidate accepts every approved canonical Unit');
select is((select count(*) from unit_validation_cases where variant<>'valid' and pg_temp.planning_catchup_preview_validate_values('UNIT',label,'{}',vals)='[]'::jsonb),0::bigint,'candidate rejects invalid code, name, dimension, scale and lifecycle for every label');
select is((select count(*) from unnest(array['Bao','Tui','Hủ','KG']) label where pg_temp.planning_catchup_preview_validate_values('UNIT',label,'{}',pg_temp.unit_values(label))='[{"code":"UNSUPPORTED_UNIT","field":"unit"}]'::jsonb),4::bigint,'candidate does not add future labels or perform aliases at the backend boundary');
select is((select count(*) from unit_validation_cases where label<>'Túi' and pg_temp.planning_catchup_preview_validate_values('UNIT',label,'{}',vals) is distinct from pg_temp.planning_catchup_old_validate_values('UNIT',label,'{}',vals)),0::bigint,'candidate preserves all pre-existing Unit validation outcomes');
select is((select count(*) from unnest(array['Túi','Gói','Cái','Bịch']) source_label cross join unnest(array['Túi','Gói','Cái','Bịch']) code_label where source_label<>code_label and pg_temp.planning_catchup_preview_validate_values('UNIT',source_label,'{}',jsonb_set(pg_temp.unit_values(source_label),'{unit_code}',pg_temp.unit_values(code_label)->'unit_code'))='[]'::jsonb),0::bigint,'backend rejects cross-assignment of Túi, Gói, Cái and Bịch codes');
select is((select jsonb_build_object('definition',pg_get_functiondef(p.oid),'metadata',to_jsonb(p)) from pg_proc p where p.oid='atlas_legacy.master_import_validate_values(text,text,jsonb,jsonb)'::regprocedure),(select jsonb_build_object('definition',definition,'metadata',metadata) from validator_before),'temporary preview preserves authoritative definition, owner, ACL and configuration');
select * from finish();
rollback;
