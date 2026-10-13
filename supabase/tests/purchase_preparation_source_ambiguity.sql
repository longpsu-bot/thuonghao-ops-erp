begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(9);
\ir ../local/purchase_preparation_scale_fixture.sql

-- Two real, independently guarded Planning chains share School/Ingredient
-- identities. Batch filtering must never hide the second current source.
select pg_temp.seed_purchase_preparation_scale('overlap-a','overlap-a',date '2027-02-01');
select pg_temp.seed_purchase_preparation_scale('overlap-b','overlap-b',date '2027-02-01','overlap-a');
insert into scale_requests(name,request)
select seed,pg_temp.scale_confirmed_need_save_command(seed,md5(seed||':confirmed-need-batch')::uuid)
from (values ('overlap-a'),('overlap-b')) seeds(seed);
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into scale_results(name,response)
select name,atlas_api.save_confirmed_needs(request) from scale_requests;
reset role;
set constraints all immediate;
select ok((select bool_and(response->>'success'='true') from scale_results),
  'both overlapping current chains save real Confirmed Need decisions');
select is((select count(*) from atlas_core.purchase_review_confirmed_sources('2027-02-01','2027-02-01')),472::bigint,
  'the full date contains both batches, including all 236 overlaps');
select is((select count(*) from atlas_core.purchase_review_confirmed_batch_sources(md5('overlap-a:confirmed-need-batch')::uuid)),236::bigint,
  'batch-only resolution hides half of the overlapping universe');
select is(atlas_core.purchase_review_confirmed_projection('2027-02-01',
  md5('overlap-a:location:1')::uuid,md5('overlap-a:ingredient:1')::uuid,
  (select purchase_unit_id from atlas_admin.ingredients where ingredient_id=md5('overlap-a:ingredient:1')::uuid))->>'blocker',
  'CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING','the compatibility projection rejects overlapping current families');
select is(pg_catalog.jsonb_array_length(atlas_core.purchase_review_confirmed_source_universe(
  md5('overlap-a:confirmed-need-batch')::uuid)),472,
  'the preparation universe preserves other current batches');
insert into scale_results(name,response) values('materialize',
  atlas_core.purchase_review_materialize_default_allocations(md5('overlap-a:confirmed-need-batch')::uuid,
    'b6000000-0000-0000-0000-000000000001',gen_random_uuid()));
select is((select response->>'error_code' from scale_results where name='materialize'),'CONFIRMED_NEED_INCOMPLETE',
  'resolved persistence rejects the same overlap instead of choosing a batch');
select is((select count(*) from atlas_procurement.school_catering_allocation_families where service_date='2027-02-01'),0::bigint,
  'ambiguous materialization writes no partial family');
select function_privs_are('atlas_core','purchase_review_confirmed_source_universe',array['uuid'],
  'authenticated',array[]::text[]);
select function_privs_are('atlas_core','purchase_review_persist_resolved_allocation',
  array['uuid','uuid','bigint','jsonb','jsonb','text','text','jsonb'],'authenticated',array[]::text[]);
select * from finish();
rollback;
