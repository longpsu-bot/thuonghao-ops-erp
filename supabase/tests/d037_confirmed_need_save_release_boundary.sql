begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;
select plan(33);

select has_function('atlas_api', 'save_confirmed_needs', array['jsonb'],
  'D037-01 Save v2 is public');
select has_function('atlas_api', 'release_confirmed_needs', array['jsonb'],
  'D037-02 Release v2 is public');
select is((select p.proowner::regrole::text from pg_proc p join pg_namespace n
  on n.oid = p.pronamespace where n.nspname = 'atlas_api'
  and p.proname = 'save_confirmed_needs'),
  'atlas_confirmed_need_review_runtime', 'D037-03 Save keeps the bounded runtime');
select is((select p.proowner::regrole::text from pg_proc p join pg_namespace n
  on n.oid = p.pronamespace where n.nspname = 'atlas_api'
  and p.proname = 'release_confirmed_needs'),
  'atlas_confirmed_need_review_runtime', 'D037-04 Release keeps the bounded runtime');
select ok(has_function_privilege('authenticated',
  'atlas_api.save_confirmed_needs(jsonb)', 'EXECUTE'),
  'D037-05 authenticated may execute Save');
select ok(has_function_privilege('authenticated',
  'atlas_api.release_confirmed_needs(jsonb)', 'EXECUTE'),
  'D037-06 authenticated may execute Release');
select ok(not has_function_privilege('anon',
  'atlas_api.save_confirmed_needs(jsonb)', 'EXECUTE')
  and not has_function_privilege('service_role',
  'atlas_api.release_confirmed_needs(jsonb)', 'EXECUTE'),
  'D037-07 anon and service role stay revoked');
select ok((select p.prosrc not like '%v_limit > 250%'
  and p.prosrc like '%v_limit > 10000%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core' and p.proname = 'rmvp_05_validate_read'),
  'D037-08 the normal workbench no longer exposes the 250-line read ceiling');
select has_function('atlas_api', 'confirm_need_quantities', array['jsonb'],
  'D037-09 RMVP-05 v1 stays callable');
select has_function('atlas_api', 'validate_confirmed_needs', array['jsonb'],
  'D037-10 RMVP-06 v1 stays callable');
select has_function('atlas_api', 'approve_confirmed_needs', array['jsonb'],
  'D037-11 RMVP-07 approval v1 stays callable');
select has_function('atlas_api', 'release_confirmed_needs_for_purchase_handoff',
  array['jsonb'], 'D037-12 RMVP-07 release v1 stays callable');

create temporary table d037_results(name text primary key, response jsonb not null);
grant select, insert on d037_results to authenticated;
create function pg_temp.d037_read() returns jsonb language sql stable
set search_path = '' as $$ select jsonb_build_object(
  'contract_version', 'RMVP-05.v1',
  'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101'::uuid,
  'correlation_id', gen_random_uuid(),
  'payload', jsonb_build_object(
    'confirmed_need_batch_id', 'b6500000-0000-0000-0000-000000000050'::uuid,
    'filters', '{}'::jsonb, 'line_offset', 0, 'line_limit', 10000)); $$;
create function pg_temp.d037_lines(p_workbench jsonb) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_agg(jsonb_build_object(
    'confirmed_need_line_id', line ->> 'confirmed_need_line_id',
    'expected_current_revision_id', line ->> 'current_revision_id',
    'expected_current_decision_id', line -> 'current_decision_id',
    'proposed_confirmed_quantity', line ->> 'proposed_confirmed_quantity',
    'reason_code', 'PROPOSAL_ACCEPTED', 'reason_note', null)
    order by line ->> 'confirmed_need_line_id')
  from jsonb_array_elements(p_workbench -> 'lines') line; $$;
create function pg_temp.d037_command(
  p_contract text, p_command uuid, p_key text, p_version bigint,
  p_reason text, p_lines jsonb default null
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', p_contract, 'command_id', p_command,
    'correlation_id', gen_random_uuid(), 'idempotency_key', p_key,
    'expected_version', p_version,
    'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', p_reason, 'reason_note', null,
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', 'b6500000-0000-0000-0000-000000000050'::uuid)
      || case when p_lines is null then '{}'::jsonb
        else jsonb_build_object('lines', p_lines) end); $$;
grant execute on function pg_temp.d037_read() to authenticated;
grant execute on function pg_temp.d037_lines(jsonb) to authenticated;
grant execute on function pg_temp.d037_command(text, uuid, text, bigint, text, jsonb)
to authenticated;

delete from atlas_core.role_capabilities role_capability
using atlas_core.capabilities capability
where role_capability.role_id = 'b6000000-0000-0000-0000-000000000003'
  and capability.capability_id = role_capability.capability_id
  and capability.capability_code in (
    'confirmed_need_quantities.confirm', 'confirmed_need_release.release');

create temporary table d037_before as select jsonb_build_object(
  'handoff', (select count(*) from atlas_planning.purchase_handoff_batches),
  'procurement', (select count(*) from atlas_procurement.fulfilment_allocations),
  'warehouse', (select count(*) from atlas_evidence.supplier_receiving_evidence),
  'dispatch', (select count(*) from atlas_dispatch.dispatch_plans)) as counts;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101', true);
insert into d037_results values ('read_no_write',
  atlas_api.get_confirmed_need_review(pg_temp.d037_read()));
reset role;

insert into atlas_core.role_capabilities(role_id, capability_id)
select 'b6000000-0000-0000-0000-000000000003', capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code = 'confirmed_need_quantities.confirm'
on conflict (role_id, capability_id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101', true);
insert into d037_results values ('read_save_only',
  atlas_api.get_confirmed_need_review(pg_temp.d037_read()));
reset role;

insert into atlas_core.role_capabilities(role_id, capability_id)
select 'b6000000-0000-0000-0000-000000000003', capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code = 'confirmed_need_release.release'
on conflict (role_id, capability_id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101', true);
insert into d037_results values ('read', atlas_api.get_confirmed_need_review(
  pg_temp.d037_read()));
insert into d037_results values ('incomplete_release',
  atlas_api.release_confirmed_needs(pg_temp.d037_command(
    'RMVP-07.v2', 'b6710000-0000-0000-0000-000000000001',
    'd037-incomplete', 1, 'CONFIRMED_NEED_RELEASED')));
insert into d037_results
select 'save', atlas_api.save_confirmed_needs(pg_temp.d037_command(
  'RMVP-05.v2', 'b6710000-0000-0000-0000-000000000002',
  'd037-save', 1, 'CONFIRMED_NEED_SAVED',
  pg_temp.d037_lines(response -> 'workbench')))
from d037_results where name = 'read';
insert into d037_results
select 'save_replay', atlas_api.save_confirmed_needs(pg_temp.d037_command(
  'RMVP-05.v2', 'b6710000-0000-0000-0000-000000000002',
  'd037-save', 1, 'CONFIRMED_NEED_SAVED',
  pg_temp.d037_lines((select response -> 'workbench'
    from d037_results where name = 'read'))));
reset role;

-- D-042 retains the invalidated school-catering Handoff root so the corrected
-- Planning release can reuse it. This fixture reproduces that retained state;
-- the following calls exercise both public commands across the boundary.
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id, confirmed_need_batch_id, period_start, period_end,
  handoff_status, version, created_by_actor_id)
values (
  'b6720000-0000-0000-0000-000000000001',
  'b6500000-0000-0000-0000-000000000050',
  (select period_start from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'),
  (select period_end from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'),
  'INVALIDATED', 2, 'b6000000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id, purchase_handoff_batch_id, revision_number,
  revision_kind, revision_status, is_current, released_by_actor_id, released_at,
  command_id)
values (
  'b6720000-0000-0000-0000-000000000002',
  'b6720000-0000-0000-0000-000000000001', 1, 'BASE', 'INVALIDATED', false,
  'b6000000-0000-0000-0000-000000000001', transaction_timestamp(),
  'b6720000-0000-0000-0000-000000000003');
update d037_before set counts = jsonb_set(
  counts, '{handoff}', to_jsonb((select count(*)
    from atlas_planning.purchase_handoff_batches)));

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101', true);
insert into d037_results values ('read_after_invalidated_handoff',
  atlas_api.get_confirmed_need_review(pg_temp.d037_read()));
insert into d037_results values ('release_stale',
  atlas_api.release_confirmed_needs(pg_temp.d037_command(
    'RMVP-07.v2', 'b6710000-0000-0000-0000-000000000003',
    'd037-stale', 1, 'CONFIRMED_NEED_RELEASED'))),
  ('release', atlas_api.release_confirmed_needs(pg_temp.d037_command(
    'RMVP-07.v2', 'b6710000-0000-0000-0000-000000000004',
    'd037-release', 2, 'CONFIRMED_NEED_RELEASED')));
insert into d037_results values ('release_replay',
  atlas_api.release_confirmed_needs(pg_temp.d037_command(
    'RMVP-07.v2', 'b6710000-0000-0000-0000-000000000004',
    'd037-release', 2, 'CONFIRMED_NEED_RELEASED')));
insert into d037_results values ('handoff_superseding',
  atlas_api.release_school_catering_purchase_handoff(pg_temp.d037_command(
    'SCHOOL-CATERING-HANDOFF.v1',
    'b6710000-0000-0000-0000-000000000005',
    'd037-handoff-superseding', 5,
    'SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED')));
reset role;

select is((select response ->> 'error_code' from d037_results
  where name = 'incomplete_release'), 'CONFIRMED_NEED_INCOMPLETE',
  'D037-13 Release requires complete saved decisions');
select ok((select response ->> 'success' = 'true'
  and response ->> 'contract_version' = 'RMVP-05.v2'
  and response #>> '{authoritative_readback,authoritative_batch_status}'
    = 'DRAFT_REVIEW' from d037_results where name = 'save'),
  'D037-14 Save persists authoritatively and remains editable');
select is((select response from d037_results where name = 'save_replay'),
  (select response from d037_results where name = 'save'),
  'D037-15 Save exact replay returns the original response');
select is((select response ->> 'error_code' from d037_results
  where name = 'release_stale'), 'STALE_CONFIRMED_NEED_BATCH',
  'D037-16 Release rejects a stale expected version');
select ok((select response ->> 'success' = 'true'
  and response ->> 'contract_version' = 'RMVP-07.v2'
  and response ->> 'resulting_batch_status' = 'RELEASED_FOR_PURCHASE_HANDOFF'
  from d037_results where name = 'release'),
  'D037-17 one Release command validates, approves, and releases');
select is((select response from d037_results where name = 'release_replay'),
  (select response from d037_results where name = 'release'),
  'D037-18 Release exact replay returns the original response');
select is((select count(*)::integer from atlas_planning.confirmed_need_validation_attempts
  where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    and outcome = 'VALIDATED'), 1,
  'D037-19 Release creates one immutable successful validation');
select is((select count(*)::integer from atlas_planning.confirmed_need_approval_snapshots
  where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    and source_kind = 'NEED_GENERATION'), 1,
  'D037-20 Release creates one immutable approval snapshot');
select is((select count(*)::integer from atlas_planning.confirmed_need_releases
  where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'), 1,
  'D037-21 Release creates one immutable release row');
select is((select batch_status from atlas_planning.confirmed_need_batches
  where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'),
  'RELEASED_FOR_PURCHASE_HANDOFF', 'D037-22 final lifecycle is released');
select is((select jsonb_build_object(
  'handoff', (select count(*) from atlas_planning.purchase_handoff_batches),
  'procurement', (select count(*) from atlas_procurement.fulfilment_allocations),
  'warehouse', (select count(*) from atlas_evidence.supplier_receiving_evidence),
  'dispatch', (select count(*) from atlas_dispatch.dispatch_plans))),
  (select counts from d037_before),
  'D037-23 Save and Release create zero downstream facts');
select ok((select response #>> '{authoritative_readback,release,current_release_id}'
  is not null and response #>> '{authoritative_readback,pagination,total_lines}' = '2'
  from d037_results where name = 'release'),
  'D037-24 Release returns authoritative full readback');
select ok((select response #>> '{workbench,allowed_actions,save_confirmed_needs}'
  = 'false' and response #>> '{workbench,allowed_actions,release_confirmed_needs}'
  = 'false' from d037_results where name = 'read_no_write'),
  'D037-25 an Actor without Save capability receives no v2 write eligibility');
select ok((select response #>> '{workbench,allowed_actions,save_confirmed_needs}'
  = 'true' and response #>> '{workbench,allowed_actions,release_confirmed_needs}'
  = 'false' and response #>>
    '{workbench,disabled_reason_codes,release_confirmed_needs}'
  = 'RELEASE_CAPABILITY_REQUIRED'
  from d037_results where name = 'read_save_only'),
  'D037-26 Save-only authority cannot promote Release');
select ok((select response #>> '{workbench,allowed_actions,save_confirmed_needs}'
  = 'true' and response #>> '{workbench,allowed_actions,release_confirmed_needs}'
  = 'false' and response #>>
    '{workbench,disabled_reason_codes,release_confirmed_needs}'
  = 'RELEASE_INCOMPLETE' from d037_results where name = 'read'),
  'D037-27 complete authority does not bypass incomplete saved decisions');
select ok((select response #>>
    '{authoritative_readback,allowed_actions,save_confirmed_needs}' = 'true'
  and response #>>
    '{authoritative_readback,allowed_actions,release_confirmed_needs}' = 'true'
  from d037_results where name = 'save'),
  'D037-28 a complete saved batch authorizes both editable Save and Release');
select ok((select response #>>
    '{authoritative_readback,allowed_actions,save_confirmed_needs}' = 'false'
  and response #>>
    '{authoritative_readback,allowed_actions,release_confirmed_needs}' = 'false'
  from d037_results where name = 'release'),
  'D037-29 a released batch authorizes neither v2 action');
select ok((select p.prosrc like '%capability.capability_code%'
  and p.prosrc not like '%role_name%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core' and p.proname = 'd037_extend_workbench'),
  'D037-30 eligibility uses capability assignments without role-name inference');
select is((select response ->> 'success' from d037_results
  where name = 'handoff_superseding'), 'true',
  'D037-31 corrected Planning release can cross into the public Handoff command');
select ok((select count(*) = 2
    and count(*) filter (where revision_kind = 'SUPERSEDING'
      and revision_status = 'RELEASED_TO_PROCUREMENT' and is_current) = 1
  from atlas_planning.purchase_handoff_revisions
  where purchase_handoff_batch_id = 'b6720000-0000-0000-0000-000000000001'),
  'D037-32 the retained Handoff root receives one current SUPERSEDING revision');
select ok((select response #>> '{workbench,allowed_actions,release_confirmed_needs}' = 'true'
    and response #>> '{workbench,disabled_reason_codes,release_confirmed_needs}' is null
  from d037_results where name = 'read_after_invalidated_handoff'),
  'D037-33 v2 eligibility does not classify invalidated Handoff history as a conflict');

select * from finish();
rollback;
