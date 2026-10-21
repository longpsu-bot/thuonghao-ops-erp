begin;
grant atlas_read_runtime,authenticated to postgres with set true;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(25);

select has_function('atlas_core','school_fulfilment_compare',array['jsonb','jsonb']);
select has_function('atlas_core','school_fulfilment_reconciliation_scope',array['date','uuid','uuid']);
select has_function('atlas_api','get_school_fulfilment_reconciliation_workbench',array['jsonb']);
select function_owner_is('atlas_api','get_school_fulfilment_reconciliation_workbench',array['jsonb'],'atlas_read_runtime');
select function_privs_are('atlas_api','get_school_fulfilment_reconciliation_workbench',array['jsonb'],'authenticated',array['EXECUTE']);
select function_privs_are('atlas_api','get_school_fulfilment_reconciliation_workbench',array['jsonb'],'anon',array[]::text[]);
select function_privs_are('atlas_api','get_school_fulfilment_reconciliation_workbench',array['jsonb'],'service_role',array[]::text[]);

create temporary table reconciliation_cases(name text primary key,response jsonb not null);
grant select,insert on reconciliation_cases to atlas_read_runtime;
set role atlas_read_runtime;
insert into reconciliation_cases values
('no_po',atlas_core.school_fulfilment_compare('[]','[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10"}]')),
('no_pxk',atlas_core.school_fulfilment_compare('[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10"}]','[]')),
('ingredient_changed',atlas_core.school_fulfilment_compare('[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10"}]','[{"ingredient_id":"10000000-0000-4000-8000-000000000002","ingredient_name":"Beans","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10"}]')),
('mismatch',atlas_core.school_fulfilment_compare('[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10.123456"}]','[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10.123455"}]')),
('multi_supplier_ok',atlas_core.school_fulfilment_compare('[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"4.250000"},{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"5.750000"}]','[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10.000000"}]')),
('mixed_units',atlas_core.school_fulfilment_compare('[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"10"},{"ingredient_id":"10000000-0000-4000-8000-000000000002","ingredient_name":"Egg","unit_id":"20000000-0000-4000-8000-000000000002","unit_code":"piece","quantity":"20"}]','[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Rice","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"kg","quantity":"20"},{"ingredient_id":"10000000-0000-4000-8000-000000000002","ingredient_name":"Egg","unit_id":"20000000-0000-4000-8000-000000000002","unit_code":"piece","quantity":"10"}]'));

select is((select response->>'comparison_status' from reconciliation_cases where name='no_po'),'NO_PO','missing PO wins first');
select is((select response->>'comparison_status' from reconciliation_cases where name='no_pxk'),'NO_PXK','missing PXK follows PO presence');
select is((select response->>'comparison_status' from reconciliation_cases where name='ingredient_changed'),'INGREDIENT_CHANGED','different Ingredient/Unit key sets are detected');
select is((select response->>'comparison_status' from reconciliation_cases where name='mismatch'),'MISMATCH','exact numeric differences are detected without display rounding');
select is((select response->>'comparison_status' from reconciliation_cases where name='multi_supplier_ok'),'OK','multiple supplier contributions sum exactly at School detail grain');
select is((select response->>'comparison_status' from reconciliation_cases where name='mixed_units'),'MISMATCH','equal naive cross-unit totals cannot manufacture equality');
select is((select jsonb_array_length(response->'quantity_totals_by_unit') from reconciliation_cases where name='mixed_units'),2,'mixed units remain two independent summary totals');
select is((select response#>>'{details,0,po_quantity}' from reconciliation_cases where name='mismatch'),'10.123456','quantities remain lossless strings at the JSON boundary');
insert into reconciliation_cases values ('captured_name',atlas_core.school_fulfilment_compare(
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Mutable preview","quantity":"100"}]',
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Gói","quantity":"100"}]')),
 ('legacy_name',atlas_core.school_fulfilment_compare(
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Mutable preview","quantity":"100"}]',
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","quantity":"100"}]'));
select is((select response#>>'{details,0,unit_name}' from reconciliation_cases where name='captured_name'),'Gói','detail uses captured dispatch Unit name');
select is((select response#>>'{quantity_totals_by_unit,0,unit_name}' from reconciliation_cases where name='captured_name'),'Gói','summary carries the same human Unit name');
select is((select response#>>'{details,0,unit_name}' from reconciliation_cases where name='legacy_name'),null::text,'missing historical Unit name is never filled from mutable preview');
select is((select response->>'comparison_status' from reconciliation_cases where name='captured_name'),'OK','different descriptive labels do not affect exact Unit identity or quantities');
insert into reconciliation_cases values ('mixed_name_source',atlas_core.school_fulfilment_compare(
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Preview","quantity":"100"},{"ingredient_id":"10000000-0000-4000-8000-000000000002","ingredient_name":"Added cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Gói","quantity":"10"}]',
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","quantity":"100"}]')),
 ('mixed_captured_source',atlas_core.school_fulfilment_compare(
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Preview","quantity":"100"},{"ingredient_id":"10000000-0000-4000-8000-000000000002","ingredient_name":"Added cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Different preview","quantity":"10"}]',
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","ingredient_name":"Cake","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"v1-unit-packet","unit_name":"Gói","quantity":"100"}]'));
select is((select response#>>'{quantity_totals_by_unit,0,unit_name}' from reconciliation_cases where name='mixed_name_source'),null::text,'PO-only preview cannot name an issued Unit total with missing captured metadata');
select is((select response#>>'{quantity_totals_by_unit,0,unit_name}' from reconciliation_cases where name='mixed_captured_source'),'Gói','PO-only preview cannot suppress the captured issued Unit total name');
insert into reconciliation_cases
select 'same_names_distinct_units',atlas_core.school_fulfilment_compare(jsonb_agg(line),'[]')
from (select jsonb_build_object('ingredient_id','10000000-0000-4000-8000-000000000001',
  'unit_id',unit_id,'unit_code','technical-'||unit_id,'unit_name','Gói','quantity','10') line
  from (values('20000000-0000-4000-8000-000000000001'),('20000000-0000-4000-8000-000000000002')) units(unit_id)) lines;
select is((select jsonb_array_length(response->'quantity_totals_by_unit') from reconciliation_cases
  where name='same_names_distinct_units'),2,'equal human names never combine distinct Unit identities');
select ok((select bool_and(total->>'unit_name'='Gói') from reconciliation_cases,
  lateral jsonb_array_elements(response->'quantity_totals_by_unit') total
  where name='same_names_distinct_units'),'prospective Unit totals use explicit preview names');
select is((atlas_core.school_fulfilment_compare('[]',
 '[{"ingredient_id":"10000000-0000-4000-8000-000000000001","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"technical","unit_name":"Gói","quantity":"1"},{"ingredient_id":"10000000-0000-4000-8000-000000000001","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"technical","unit_name":"Other captured name","quantity":"1"},{"ingredient_id":"10000000-0000-4000-8000-000000000002","unit_id":"20000000-0000-4000-8000-000000000001","unit_code":"technical","unit_name":"Gói","quantity":"1"}]')
 #>>'{quantity_totals_by_unit,0,unit_name}'),null::text,'conflicting captured names remain unavailable at Unit total grain');
reset role;
set role authenticated;
select is((atlas_api.get_school_fulfilment_reconciliation_workbench('{}'::jsonb)->>'error_code'),'VALIDATION_FAILED','malformed requests fail closed');
reset role;

select * from finish();
rollback;
