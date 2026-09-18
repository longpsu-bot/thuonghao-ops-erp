-- Rolled-back tests of the exact owner-approved Staging configuration package.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path=pg_catalog,public,extensions;
select plan(8);
insert into atlas_core.actors(actor_id,actor_type,display_name)
values('a1010000-0000-4000-8000-000000000001','HUMAN','Staging policy test');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000101');
insert into atlas_admin.units(unit_code,unit_name,dimension_code) values
('v1-unit-034ce34d3ff3','Qu?','COUNT'),
('v1-unit-2d183c73d76a','B?','COUNT'),
('v1-unit-469606e98b7e','G?i','COUNT'),
('v1-unit-46bab433cc1a','C?c','COUNT'),
('v1-unit-83bea5cf6378','Mi?ng','COUNT'),
('v1-unit-91a0b1c14124','C?i','COUNT'),
('v1-unit-9837090d3b3f','H?','COUNT'),
('v1-unit-b1e160b3fbfb','Chai','COUNT'),
('v1-unit-c854d71627b2','C?y','COUNT'),
('v1-unit-cac06658f903','Lon','COUNT'),
('v1-unit-cad1515b85c4','?','COUNT'),
('v1-unit-dafac3b7da11','B?ch','COUNT'),
('v1-unit-ea9046ea54e4','H?p','COUNT'),
('v1-unit-eb0ce03e77fa','Tr?i','COUNT');
-- The package may not guess a policy for this unapproved COUNT unit.
insert into atlas_admin.units(unit_code,unit_name,dimension_code)
values('unapproved-count','Unapproved count','COUNT'),('policy-test-kg','Policy test kilogram','MASS');
-- The existing kilogram policy is kept as an independent fixture.
with p as (insert into atlas_planning.planning_quantity_policies(unit_id,created_by_actor_id)
 select unit_id,'a1010000-0000-4000-8000-000000000001' from atlas_admin.units where unit_code='policy-test-kg'
 returning planning_quantity_policy_id,unit_id)
insert into atlas_planning.planning_quantity_policy_revisions(planning_quantity_policy_id,unit_id,revision_number,planning_step,effective_from,created_by_actor_id)
select planning_quantity_policy_id,unit_id,1,0.01,'2026-01-01','a1010000-0000-4000-8000-000000000001' from p;
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='ACTIVE',
 approved_by_actor_id='a1010000-0000-4000-8000-000000000001',approved_at=now(),
 activated_by_actor_id='a1010000-0000-4000-8000-000000000001',activated_at=now();
create temp table before_kg as select md5(to_jsonb(r)::text) fingerprint from atlas_planning.planning_quantity_policy_revisions r;
-- PACKAGE_INSTALL
select is((select count(*) from atlas_planning.planning_quantity_policies),15::bigint,'14 exact policy roots plus the unchanged kg root');
select is((select count(*) from atlas_planning.planning_quantity_policy_revisions where planning_step=1 and effective_from='2026-09-14' and effective_to is null and policy_revision_status='ACTIVE'),14::bigint,'14 approved count policies active on the rehearsal boundary');
select is((select count(*) from atlas_planning.planning_quantity_policies p join atlas_admin.units u using(unit_id) where u.unit_code='unapproved-count'),0::bigint,'COUNT dimension is not a fallback');
select is((select md5(to_jsonb(r)::text) from atlas_planning.planning_quantity_policy_revisions r where planning_step=0.01),(select fingerprint from before_kg),'kg policy fingerprint unchanged');
create temp table policy_first as select md5(jsonb_agg(to_jsonb(r) order by planning_quantity_policy_revision_id)::text) fingerprint from atlas_planning.planning_quantity_policy_revisions r;
-- PACKAGE_INSTALL
select is((select md5(jsonb_agg(to_jsonb(r) order by planning_quantity_policy_revision_id)::text) from atlas_planning.planning_quantity_policy_revisions r),(select fingerprint from policy_first),'exact replay does not rewrite timestamps or revisions');
-- Test conflict rejection with the exact package body inside a test function.
-- PACKAGE_TEST_FUNCTION
update atlas_admin.units set unit_name='Unexpected rename' where unit_code='v1-unit-034ce34d3ff3';
select throws_ok('select pg_temp.run_policy_package()','P0001','STAGING_COUNT_POLICY_UNIT_MISMATCH','unexpected unit meaning fails closed');
update atlas_admin.units set unit_name='Qu?' where unit_code='v1-unit-034ce34d3ff3';
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='RETIRED',effective_to='2026-09-21',
 retired_by_actor_id='a1010000-0000-4000-8000-000000000001',retired_at=now()
where unit_id=(select unit_id from atlas_admin.units where unit_code='v1-unit-034ce34d3ff3');
select throws_ok('select pg_temp.run_policy_package()','P0001','STAGING_COUNT_POLICY_CONFLICT','existing conflicting effectivity is not overwritten');
select is((select count(*) from atlas_planning.planning_quantity_policy_revisions),15::bigint,'failure does not create replacement policies');
select * from finish();
rollback;
