begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(6);

select ok(to_regprocedure('atlas_api.prepare_planning_source_correction(jsonb)') is not null,
  'D-042 keeps the existing public correction command');
select ok(to_regprocedure('atlas_api.get_planning_source_correction_impact(jsonb)') is not null,
  'D-042 keeps the existing public impact read');
select ok(to_regprocedure('atlas_api.release_school_catering_purchase_handoff(jsonb)') is not null,
  'corrected Planning release has a school-catering Handoff command');
select ok(to_regclass('atlas_procurement.school_catering_allocation_family_revisions') is not null,
  'school-catering allocation revisions can remain as historical evidence');
select ok(to_regprocedure('atlas_core.issue_222_chain_payload(uuid)') is not null,
  'the D-042 chain classifier remains available to its governed wrappers');
select ok(to_regprocedure('atlas_core.school_catering_purchase_handoff_source_kind(uuid)') is not null,
  'D-042 has a source-aware Handoff classifier for school catering versus WHOLESALE');

select * from finish();
rollback;
