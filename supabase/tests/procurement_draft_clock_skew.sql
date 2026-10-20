begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;
select plan(6);
insert into atlas_core.actors(actor_id,actor_type,display_name)
values('e0200000-0000-4000-8000-000000000001','HUMAN','Disposable draft clock regression');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('e0200000-0000-4000-8000-000000000001','e0200000-0000-4000-8000-000000000101');
create function pg_temp.draft_clock_request(at_time timestamptz) returns jsonb
language sql stable set search_path='' as $$
select jsonb_build_object(
 'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
 'command_id','e0200000-0000-4000-8000-000000000201',
 'correlation_id','e0200000-0000-4000-8000-000000000202',
 'idempotency_key','draft-clock-regression','expected_version',1,
 'requested_by_auth_subject','e0200000-0000-4000-8000-000000000101',
 'requested_at',at_time,'reason_code','SCHOOL_CATERING_PO_DRAFTS_CREATED',
 'reason_note',null,'payload',jsonb_build_object('date_start','2026-10-13','date_end','2026-10-13'));
$$;
grant execute on function pg_temp.draft_clock_request(timestamptz) to authenticated;
create temporary table draft_clock_result(response jsonb);
grant select,insert on draft_clock_result to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','e0200000-0000-4000-8000-000000000101',true);
insert into draft_clock_result select atlas_api.create_school_catering_purchase_order_drafts(
 pg_temp.draft_clock_request(transaction_timestamp()-interval '1 second'));
select isnt((select response->>'error_code' from draft_clock_result),'VALIDATION_FAILED',
 'valid past request reaches authorization without creating a document');
select is(atlas_api.create_school_catering_purchase_order_drafts(pg_temp.draft_clock_request(
 transaction_timestamp()+interval '1 second'))->>'error_code',
 (select response->>'error_code' from draft_clock_result),'one second browser skew reaches unchanged authorization');
select is(atlas_api.create_school_catering_purchase_order_drafts(pg_temp.draft_clock_request(
 transaction_timestamp()+interval '60 seconds'))->>'error_code',
 (select response->>'error_code' from draft_clock_result),'exact sixty-second skew reaches unchanged authorization');
select is(atlas_api.create_school_catering_purchase_order_drafts(pg_temp.draft_clock_request(
 transaction_timestamp()+interval '61 seconds'))->>'error_code','VALIDATION_FAILED','excessive skew remains invalid');
select is(atlas_api.create_school_catering_purchase_order_drafts(jsonb_set(
 pg_temp.draft_clock_request(transaction_timestamp()),'{command_id}','"bad"'))->>'error_code',
 'VALIDATION_FAILED','malformed identity remains invalid');
select is(atlas_api.create_school_catering_purchase_order_drafts(jsonb_set(
 pg_temp.draft_clock_request(transaction_timestamp()),'{payload,extra}','true'))->>'error_code',
 'VALIDATION_FAILED','extra payload remains invalid');
reset role;
select * from finish();
rollback;
