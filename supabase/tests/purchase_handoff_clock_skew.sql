begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(6);

insert into atlas_core.actors(actor_id,actor_type,display_name)
values('90300000-0000-4000-8000-000000000001','HUMAN','Purchase review clock test');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('90300000-0000-4000-8000-000000000001','90300000-0000-4000-8000-000000000101');
create function pg_temp.handoff_request(at_time timestamptz) returns jsonb
language sql stable set search_path='' as $$
select jsonb_build_object(
  'contract_version','SCHOOL-CATERING-HANDOFF.v1',
  'command_id','90300000-0000-4000-8000-000000000201',
  'correlation_id','90300000-0000-4000-8000-000000000202',
  'idempotency_key','purchase-review-clock-test','expected_version',1,
  'requested_by_auth_subject','90300000-0000-4000-8000-000000000101',
  'requested_at',at_time,'reason_code','SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED',
  'reason_note',null,'payload',jsonb_build_object(
    'confirmed_need_batch_id','90300000-0000-4000-8000-000000000301'));
$$;
grant execute on function pg_temp.handoff_request(timestamptz) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','90300000-0000-4000-8000-000000000101',true);
select is(atlas_api.release_school_catering_purchase_handoff(pg_temp.handoff_request(
  transaction_timestamp()-interval '1 second'))->>'error_code','NOT_FOUND',
  'past browser timestamp reaches source validation');
select is(atlas_api.release_school_catering_purchase_handoff(pg_temp.handoff_request(
  transaction_timestamp()+interval '1 second'))->>'error_code','NOT_FOUND',
  'one second browser clock skew reaches source validation');
select is(atlas_api.release_school_catering_purchase_handoff(pg_temp.handoff_request(
  transaction_timestamp()+interval '60 seconds'))->>'error_code','NOT_FOUND',
  'exact sixty second boundary is accepted');
select is(atlas_api.release_school_catering_purchase_handoff(pg_temp.handoff_request(
  transaction_timestamp()+interval '61 seconds'))->>'error_code','VALIDATION_FAILED',
  'excessive future timestamp is rejected');
select is(atlas_api.release_school_catering_purchase_handoff(jsonb_set(
  pg_temp.handoff_request(transaction_timestamp()),'{command_id}','"bad"'))->>'error_code',
  'VALIDATION_FAILED','malformed command identity still rejected');
select is(atlas_api.release_school_catering_purchase_handoff(jsonb_set(
  pg_temp.handoff_request(transaction_timestamp()),'{payload,extra}','true'))->>'error_code',
  'VALIDATION_FAILED','unknown payload field still rejected');
reset role;
select * from finish();
rollback;
