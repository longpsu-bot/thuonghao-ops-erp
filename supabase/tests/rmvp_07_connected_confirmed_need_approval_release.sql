begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(67);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Exact public surface, persistence, and security.
select is(
  (select array_agg(p.proname order by p.proname)::text[]
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api'
     and p.proname in (
       'approve_confirmed_needs',
       'release_confirmed_needs_for_purchase_handoff'
     )),
  array[
    'approve_confirmed_needs',
    'release_confirmed_needs_for_purchase_handoff'
  ]::text[],
  'RMVP07-01 exactly the two accepted public APIs exist'
);
select is(
  (select count(*)::integer
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api'
     and p.proname in (
       'approve_confirmed_needs',
       'release_confirmed_needs_for_purchase_handoff'
     )),
  2,
  'RMVP07-02 neither public API has an overload'
);
select ok(
  (select bool_and(
     pg_get_userbyid(p.proowner) = 'atlas_confirmed_need_review_runtime'
     and p.prosecdef
     and p.proconfig = array['search_path=""']::text[]
   )
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api'
     and p.proname in (
       'approve_confirmed_needs',
       'release_confirmed_needs_for_purchase_handoff'
     )),
  'RMVP07-03 both APIs have the exact owner and fixed definer boundary'
);
select ok(
  (select bool_and(
     has_function_privilege('authenticated', p.oid, 'EXECUTE')
     and not has_function_privilege('anon', p.oid, 'EXECUTE')
     and not has_function_privilege('service_role', p.oid, 'EXECUTE')
     and not exists (
       select 1
       from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
       where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
     )
   )
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api'
     and p.proname in (
       'approve_confirmed_needs',
       'release_confirmed_needs_for_purchase_handoff'
     )),
  'RMVP07-04 execute is authenticated-only with PUBLIC anon and service_role revoked'
);
select is(
  (select array_agg(capability_code order by capability_code)::text[]
   from atlas_core.capabilities
   where capability_code in (
     'confirmed_need_approval.approve',
     'confirmed_need_release.release'
   ) and capability_status = 'ACTIVE'),
  array[
    'confirmed_need_approval.approve',
    'confirmed_need_release.release'
  ]::text[],
  'RMVP07-05 exactly two active lifecycle capabilities exist'
);
select is(
  (select count(*)::integer
   from atlas_core.role_capabilities role_capability
   join atlas_core.capabilities capability using (capability_id)
   where capability.capability_code in (
     'confirmed_need_approval.approve',
     'confirmed_need_release.release'
   )),
  0,
  'RMVP07-06 both production capabilities remain unbound'
);
select is(
  (select count(*)::integer from pg_roles
   where rolname like 'atlas\_%' escape '\'),
  11,
  'RMVP07-07 no database or runtime role was added'
);
select has_table(
  'atlas_planning', 'confirmed_need_releases',
  'RMVP07-08 the one accepted private release relation exists'
);
select is(
  (select pg_get_userbyid(c.relowner)
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'atlas_planning'
     and c.relname = 'confirmed_need_releases'),
  'atlas_owner',
  'RMVP07-09 atlas_owner owns release evidence'
);
select ok(
  (select c.relrowsecurity and c.relforcerowsecurity
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'atlas_planning'
     and c.relname = 'confirmed_need_releases'),
  'RMVP07-10 release evidence forces RLS'
);
select ok(
  not has_table_privilege(
    'authenticated', 'atlas_planning.confirmed_need_releases', 'SELECT'
  ) and not has_table_privilege(
    'authenticated', 'atlas_planning.confirmed_need_releases',
    'INSERT,UPDATE,DELETE'
  ) and not has_table_privilege(
    'authenticated',
    'atlas_planning.confirmed_need_approval_snapshots', 'SELECT'
  ),
  'RMVP07-11 browser roles have zero direct lifecycle evidence access'
);
select is(
  (select count(*)::integer from pg_policy policy
   join pg_class relation on relation.oid = policy.polrelid
   where relation.oid = 'atlas_planning.confirmed_need_releases'::regclass
     and policy.polroles = array[
       'atlas_confirmed_need_review_runtime'::regrole::oid
     ]),
  3,
  'RMVP07-12 release evidence has exact runtime select insert and lock policies'
);
select ok(
  not exists (
    select 1 from information_schema.role_table_grants grant_row
    where grant_row.grantee = 'atlas_confirmed_need_review_runtime'
      and grant_row.table_schema in (
        'atlas_procurement', 'atlas_evidence', 'atlas_dispatch'
      )
  ),
  'RMVP07-13 the runtime has no downstream domain privilege'
);
select is(
  (select count(*)::integer from pg_trigger
   where tgname in (
     'confirmed_need_approval_snapshots_rmvp07_immutable',
     'confirmed_need_snapshot_lines_rmvp07_immutable',
     'confirmed_need_releases_rmvp07_immutable'
   ) and not tgisinternal),
  3,
  'RMVP07-14 all approval and release evidence is immutable and undeletable'
);
select is(
  (select count(*)::integer from pg_trigger
   where tgname like '%rmvp07_integrity' and not tgisinternal),
  4,
  'RMVP07-15 four deferred guards enforce the source and pointer matrix'
);
select ok(
  (select pg_get_constraintdef(oid) like
     '%FOREIGN KEY (confirmed_need_batch_id, source_kind)%'
   from pg_constraint
   where conname = 'confirmed_need_approval_snapshots_batch_source_fkey')
  and
  (select pg_get_constraintdef(oid) like
     '%confirmed_need_validation_attempt_id, confirmed_need_batch_id, source_kind%'
   from pg_constraint
   where conname = 'confirmed_need_approval_snapshots_validation_fkey')
  and
  (select pg_get_constraintdef(oid) like
     '%confirmed_need_approval_snapshot_id, confirmed_need_batch_id, source_kind, source_approved_batch_version%'
   from pg_constraint
   where conname = 'confirmed_need_releases_snapshot_fkey'),
  'RMVP07-16 source-qualified snapshot validation and release ownership is relational'
);
select ok(
  (select pg_get_userbyid(p.proowner)
       = 'atlas_confirmed_need_review_runtime'
     and p.prosecdef
     and p.proconfig = array['search_path=""']::text[]
     and pg_get_functiondef(p.oid) like '%source_kind = ''WHOLESALE''%'
     and pg_get_functiondef(p.oid) like
       '%current_confirmed_need_approval_snapshot_id is not null%'
     and pg_get_functiondef(p.oid) like
       '%RELEASED_FOR_PURCHASE_HANDOFF%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_planning'
     and p.proname = 'rmvp_07_approval_release_integrity'),
  'RMVP07-17 the fixed-definer deferred guard encodes WHOLESALE compatibility and the exact Need Generation pointer matrix'
);
select is(
  (select column_default
   from information_schema.columns
   where table_schema = 'atlas_planning'
     and table_name = 'confirmed_need_approval_snapshots'
     and column_name = 'source_kind'),
  '''WHOLESALE''::text',
  'RMVP07-18 existing PA-05D snapshot inserts default to WHOLESALE'
);
select ok(
  (select pg_get_constraintdef(oid) like
     '%source_kind = ''WHOLESALE''%confirmed_need_validation_attempt_id IS NULL%validated_fact_fingerprint IS NULL%'
   from pg_constraint
   where conname = 'confirmed_need_approval_snapshots_rmvp07_shape_check'),
  'RMVP07-19 WHOLESALE snapshots require null RMVP-07 lineage and fingerprint'
);
select ok(
  (select pg_get_constraintdef(oid) like
     '%source_kind = ''NEED_GENERATION''%'
   from pg_constraint where conname = 'confirmed_need_releases_source_check'),
  'RMVP07-20 WHOLESALE release rows are prohibited'
);
select is(
  (select
     (select count(*) from pg_views
      where schemaname in ('atlas_api', 'atlas_core', 'atlas_planning')
        and viewname like '%confirmed_need_release%')
     +
     (select count(*) from pg_matviews
      where schemaname in ('atlas_api', 'atlas_core', 'atlas_planning')
        and matviewname like '%confirmed_need_release%')
  )::integer,
  0,
  'RMVP07-21 no view or materialized read surface was added'
);
select ok(
  (select pg_get_constraintdef(oid) =
    'CHECK ((batch_status = ANY (ARRAY[''DRAFT_REVIEW''::text, ''VALIDATED''::text, ''APPROVED''::text, ''RELEASED_FOR_PURCHASE_HANDOFF''::text, ''REOPENED''::text])))'
   from pg_constraint where conname = 'confirmed_need_batches_status_check'),
  'RMVP07-22 the accepted five-state lifecycle remains unchanged'
);
select ok(
  (select pg_get_constraintdef(oid) not like '%APPROVAL%'
     and pg_get_constraintdef(oid) not like '%RELEASE%'
   from pg_constraint where conname = 'actor_scopes_kind_check'),
  'RMVP07-23 no scope kind was added'
);

-- Projection identity is one fixed, lifecycle-neutral algorithm.
select ok(
  (select pg_get_functiondef(p.oid) like '%RMVP-07-VALIDATED-FACTS.v1%'
     and pg_get_functiondef(p.oid) like '%service_date%'
     and pg_get_functiondef(p.oid) like '%customer_id%'
     and pg_get_functiondef(p.oid) like '%school_id%'
     and pg_get_functiondef(p.oid) like '%delivery_location_id%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-24 projection includes version identity and stable operational identity'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%ingredient_id%'
     and pg_get_functiondef(p.oid) like '%controlled_unit_id%'
     and pg_get_functiondef(p.oid) like '%current_confirmed_need_line_revision_id%'
     and pg_get_functiondef(p.oid) like '%current_confirmed_need_line_decision_id%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-25 projection includes exact Ingredient Unit revision and decision identity'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%planning_quantity_policy_id%'
     and pg_get_functiondef(p.oid) like '%planning_quantity_policy_revision_id%'
     and pg_get_functiondef(p.oid) like '%planning_tick_count%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-26 projection includes policy root revision and exact Planning ticks'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%need_generation_run_id%'
     and pg_get_functiondef(p.oid) like '%need_generation_run_version%'
     and pg_get_functiondef(p.oid) like '%need_generation_release_snapshot_id%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-27 projection includes exact Need Generation source authority'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%theoretical_quantity%'
     and pg_get_functiondef(p.oid) like '%confirmed_quantity%'
     and pg_get_functiondef(p.oid) like '%source_membership_count%'
     and pg_get_functiondef(p.oid) like '%source_membership_total%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-28 projection includes exact quantities and membership totals'
);
select ok(
  (select pg_get_functiondef(p.oid) like
       '%confirmed_need_line_revision_contribution_id%'
     and pg_get_functiondef(p.oid) like
       '%need_generation_release_snapshot_line_id%'
     and pg_get_functiondef(p.oid) like '%theoretical_need_line_id%'
     and pg_get_functiondef(p.oid) like '%ordered_source_members%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-29 projection includes exact ordered contribution and source-line identities'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%ordered_issues%'
     and pg_get_functiondef(p.oid) like '%issue_sort_position%'
     and pg_get_functiondef(p.oid) like '%severity%'
     and pg_get_functiondef(p.oid) like '%issue_code%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_projection'),
  'RMVP07-30 projection includes the closed ordered blocker and warning set'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%trim_scale%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_canonical_decimal')
  and
  (select pg_get_functiondef(p.oid) like '%sha256%'
     and pg_get_functiondef(p.oid) like '%projection::text%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_07_validated_facts_fingerprint'),
  'RMVP07-31 decimal and lowercase SHA-256 canonicalization are fixed'
);

-- CI installs pa_06b_synthetic_identity.sql and rmvp_05_browser_fixture.sql
-- before this suite. Bind only disposable test-role capabilities in this
-- transaction; rollback restores the production-unbound catalog.
create temporary table rmvp07_results (
  result_name text primary key,
  response jsonb not null
);
grant select, insert on rmvp07_results to authenticated;

create function pg_temp.rmvp07_command(
  p_name text,
  p_command_id uuid,
  p_expected_version bigint,
  p_key text,
  p_reason text
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-07.v1',
    'command_id', p_command_id,
    'correlation_id', 'b6700000-0000-0000-0000-000000000099'::uuid,
    'idempotency_key', p_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject',
      'b6000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', p_reason,
    'reason_note', null,
    'payload', jsonb_build_object(
      'confirmed_need_batch_id',
      'b6500000-0000-0000-0000-000000000050'::uuid
    )
  );
$$;
create function pg_temp.rmvp07_read()
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject',
      'b6000000-0000-0000-0000-000000000101'::uuid,
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id',
        'b6500000-0000-0000-0000-000000000050'::uuid,
      'filters', '{}'::jsonb,
      'line_offset', 0,
      'line_limit', 100
    )
  );
$$;
create function pg_temp.rmvp07_validation(
  p_command_id uuid,
  p_expected_version bigint,
  p_key text
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-06.v1',
    'command_id', p_command_id,
    'correlation_id', gen_random_uuid(),
    'idempotency_key', p_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject',
      'b6000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'BATCH_VALIDATION_REQUESTED',
    'reason_note', null,
    'payload', jsonb_build_object(
      'confirmed_need_batch_id',
        'b6500000-0000-0000-0000-000000000050'::uuid
    )
  );
$$;
create function pg_temp.rmvp07_lines(p_workbench jsonb)
returns jsonb language sql stable set search_path = '' as $$
  with ordered as (
    select line, row_number() over (
      order by line ->> 'confirmed_need_line_id'
    ) as ordinal
    from jsonb_array_elements(p_workbench -> 'lines') line
  )
  select jsonb_agg(jsonb_build_object(
    'confirmed_need_line_id', line ->> 'confirmed_need_line_id',
    'expected_current_revision_id', line ->> 'current_revision_id',
    'expected_current_decision_id', line -> 'current_decision_id',
    'proposed_confirmed_quantity', case when ordinal = 1
      then '0.000000' else line ->> 'proposed_confirmed_quantity' end,
    'reason_code', case when ordinal = 1
      then 'PLANNING_STEP_ADJUSTMENT' else 'PROPOSAL_ACCEPTED' end,
    'reason_note', null
  ) order by line ->> 'confirmed_need_line_id')
  from ordered;
$$;
grant execute on function pg_temp.rmvp07_command(
  text, uuid, bigint, text, text
) to authenticated;
grant execute on function pg_temp.rmvp07_read() to authenticated;
grant execute on function pg_temp.rmvp07_validation(
  uuid, bigint, text
) to authenticated;
grant execute on function pg_temp.rmvp07_lines(jsonb) to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101',
  true
);
insert into rmvp07_results values (
  'approval_denied',
  atlas_api.approve_confirmed_needs(pg_temp.rmvp07_command(
    'approve_confirmed_needs',
    'b6700000-0000-0000-0000-000000000001', 1,
    'rmvp07-approval-denied', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
  ))
), (
  'release_denied',
  atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000002', 1,
      'rmvp07-release-denied', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
), (
  'malformed', atlas_api.approve_confirmed_needs(
    '{"contract_version":"RMVP-07.v1"}'::jsonb
  )
), (
  'wrong_reason',
  atlas_api.approve_confirmed_needs(pg_temp.rmvp07_command(
    'approve_confirmed_needs',
    'b6700000-0000-0000-0000-000000000003', 1,
    'rmvp07-wrong-reason', 'CONFIRMED_NEED_RELEASE_REQUESTED'
  ))
);
reset role;

select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'approval_denied'),
  'ACTOR_NOT_AUTHORIZED',
  'RMVP07-32 approval requires its independent active GLOBAL capability'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'release_denied'),
  'ACTOR_NOT_AUTHORIZED',
  'RMVP07-33 release requires its independent active GLOBAL capability'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'malformed'),
  'VALIDATION_FAILED',
  'RMVP07-34 malformed closed requests fail before authorization or writes'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'wrong_reason'),
  'VALIDATION_FAILED',
  'RMVP07-35 the command-specific exact reason is enforced'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'b6000000-0000-0000-0000-000000000003', capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code in (
  'confirmed_need_validation.validate',
  'confirmed_need_approval.approve',
  'confirmed_need_release.release'
);

set local role authenticated;
insert into rmvp07_results values (
  'approval_wrong_state',
  atlas_api.approve_confirmed_needs(pg_temp.rmvp07_command(
    'approve_confirmed_needs',
    'b6700000-0000-0000-0000-000000000004', 1,
    'rmvp07-approval-wrong-state', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
  ))
), (
  'release_wrong_state',
  atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000005', 1,
      'rmvp07-release-wrong-state', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
), (
  'initial_read', atlas_api.get_confirmed_need_review(pg_temp.rmvp07_read())
);

insert into rmvp07_results
select 'preview', atlas_api.preview_confirmed_need_confirmation(
  jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject',
      'b6000000-0000-0000-0000-000000000101'::uuid,
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id',
        'b6500000-0000-0000-0000-000000000050'::uuid,
      'expected_batch_version', 1,
      'lines', pg_temp.rmvp07_lines(response -> 'workbench')
    )
  )
)
from rmvp07_results where result_name = 'initial_read';

insert into rmvp07_results
select 'confirmed', atlas_api.confirm_need_quantities(jsonb_build_object(
  'contract_version', 'RMVP-05.v1',
  'command_id', 'b6700000-0000-0000-0000-000000000006'::uuid,
  'correlation_id', gen_random_uuid(),
  'idempotency_key', 'rmvp07-confirm-prerequisite',
  'expected_version', 1,
  'requested_by_auth_subject',
    'b6000000-0000-0000-0000-000000000101'::uuid,
  'requested_at', transaction_timestamp() - interval '1 second',
  'reason_code', 'CONFIRMED_NEED_QUANTITIES_CONFIRMED',
  'reason_note', null,
  'payload', jsonb_build_object(
    'confirmed_need_batch_id',
      'b6500000-0000-0000-0000-000000000050'::uuid,
    'preview_hash', preview.response #>> '{preview,preview_hash}',
    'lines', pg_temp.rmvp07_lines(initial.response -> 'workbench')
  )
))
from rmvp07_results preview cross join rmvp07_results initial
where preview.result_name = 'preview' and initial.result_name = 'initial_read';

reset role;
\ir ../local/purchase_review_saved_allocations_fixture.sql
set local role authenticated;

insert into rmvp07_results values (
  'validated', atlas_api.validate_confirmed_needs(
    pg_temp.rmvp07_validation(
      'b6700000-0000-0000-0000-000000000007', 2, 'rmvp07-validation'
    )
  )
), (
  'approval_stale', atlas_api.approve_confirmed_needs(
    pg_temp.rmvp07_command(
      'approve_confirmed_needs',
      'b6700000-0000-0000-0000-000000000008', 2,
      'rmvp07-approval-stale', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    )
  )
);
reset role;

create temporary table rmvp07_before as
select jsonb_build_object(
  'attempt_fingerprint', (
    select validation_fingerprint
    from atlas_planning.confirmed_need_validation_attempts
    where confirmed_need_batch_id =
      'b6500000-0000-0000-0000-000000000050'
      and outcome = 'VALIDATED'
  ),
  'downstream', jsonb_build_object(
    'handoff_batches',
      (select count(*) from atlas_planning.purchase_handoff_batches),
    'handoff_revisions',
      (select count(*) from atlas_planning.purchase_handoff_revisions),
    'handoff_lines',
      (select count(*) from atlas_planning.purchase_handoff_lines),
    'handoff_line_revisions',
      (select count(*) from atlas_planning.purchase_handoff_line_revisions),
    'demand_references',
      (select count(*) from atlas_planning.purchase_demand_references),
    'procurement',
      (select count(*) from atlas_procurement.fulfilment_allocations),
    'warehouse',
      (select count(*) from atlas_evidence.supplier_receiving_evidence),
    'dispatch',
      (select count(*) from atlas_dispatch.dispatch_plans)
  )
) as state;

-- A mutable Unit eligibility change creates a blocker in the shared current
-- projection and must reject approval without lifecycle evidence.
update atlas_admin.units set unit_status = 'INACTIVE'
where unit_id = 'b6500000-0000-0000-0000-000000000005';
set local role authenticated;
insert into rmvp07_results values (
  'approval_drift', atlas_api.approve_confirmed_needs(
    pg_temp.rmvp07_command(
      'approve_confirmed_needs',
      'b6700000-0000-0000-0000-000000000009', 3,
      'rmvp07-approval-drift', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    )
  )
);
reset role;
update atlas_admin.units set unit_status = 'ACTIVE'
where unit_id = 'b6500000-0000-0000-0000-000000000005';

set local role authenticated;
insert into rmvp07_results values (
  'approved', atlas_api.approve_confirmed_needs(
    pg_temp.rmvp07_command(
      'approve_confirmed_needs',
      'b6700000-0000-0000-0000-000000000010', 3,
      'rmvp07-approved', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    )
  )
), (
  'approval_replay', atlas_api.approve_confirmed_needs(
    pg_temp.rmvp07_command(
      'approve_confirmed_needs',
      'b6700000-0000-0000-0000-000000000010', 3,
      'rmvp07-approved', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    )
  )
), (
  'approval_conflict', atlas_api.approve_confirmed_needs(
    pg_temp.rmvp07_command(
      'approve_confirmed_needs',
      'b6700000-0000-0000-0000-000000000011', 3,
      'rmvp07-approved', 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    )
  )
), (
  'release_stale', atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000012', 3,
      'rmvp07-release-stale', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
);
reset role;

-- The same lifecycle-neutral projection blocks release if approval-bound
-- current Unit eligibility changes.
update atlas_admin.units set unit_status = 'INACTIVE'
where unit_id = 'b6500000-0000-0000-0000-000000000005';
set local role authenticated;
insert into rmvp07_results values (
  'release_drift',
  atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000013', 4,
      'rmvp07-release-drift', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
);
reset role;
update atlas_admin.units set unit_status = 'ACTIVE'
where unit_id = 'b6500000-0000-0000-0000-000000000005';

set local role authenticated;
insert into rmvp07_results values (
  'released', atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000014', 4,
      'rmvp07-released', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
), (
  'release_replay',
  atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000014', 4,
      'rmvp07-released', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
), (
  'release_conflict',
  atlas_api.release_confirmed_needs_for_purchase_handoff(
    pg_temp.rmvp07_command(
      'release_confirmed_needs_for_purchase_handoff',
      'b6700000-0000-0000-0000-000000000015', 4,
      'rmvp07-released', 'CONFIRMED_NEED_RELEASE_REQUESTED'
    )
  )
);
insert into rmvp07_results values (
  'final_read', atlas_api.get_confirmed_need_review(pg_temp.rmvp07_read())
);
reset role;

-- Command rejection, approval, release, replay, atomicity, and read model.
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'approval_wrong_state'),
  'INVALID_LIFECYCLE_STATE',
  'RMVP07-36 non-VALIDATED approval is rejected'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'release_wrong_state'),
  'INVALID_LIFECYCLE_STATE',
  'RMVP07-37 non-APPROVED release is rejected'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'approval_stale'),
  'STALE_VERSION',
  'RMVP07-38 stale approval is rejected with authoritative version knowledge'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'approval_drift'),
  'CURRENT_FACTS_CHANGED',
  'RMVP07-39 changed validated Unit or issue facts reject approval'
);
select is(
  (select response ->> 'resulting_batch_status' from rmvp07_results
   where result_name = 'approved'),
  'APPROVED',
  'RMVP07-40 approval advances the complete batch to APPROVED'
);
select is(
  (select response ->> 'resulting_batch_version' from rmvp07_results
   where result_name = 'approved'),
  '4',
  'RMVP07-41 approval increments the batch version exactly once'
);
select is(
  (select response from rmvp07_results where result_name = 'approval_replay'),
  (select response from rmvp07_results where result_name = 'approved'),
  'RMVP07-42 approval exact replay returns the byte-for-byte original response'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'approval_conflict'),
  'IDEMPOTENCY_CONFLICT',
  'RMVP07-43 changed command identity under the scoped key conflicts'
);
select is(
  (select validation_fingerprint
   from atlas_planning.confirmed_need_validation_attempts
   where confirmed_need_batch_id =
     'b6500000-0000-0000-0000-000000000050' and outcome = 'VALIDATED'),
  (select state ->> 'attempt_fingerprint' from rmvp07_before),
  'RMVP07-44 approval preserves the immutable RMVP-06 fingerprint unchanged'
);
select ok(
  (select snapshot.confirmed_need_validation_attempt_id =
      (approved.response ->> 'confirmed_need_validation_attempt_id')::uuid
     and snapshot.validated_fact_fingerprint =
      approved.response ->> 'validated_fact_fingerprint'
     and snapshot.approved_version = 4
   from atlas_planning.confirmed_need_approval_snapshots snapshot
   cross join rmvp07_results approved
   where approved.result_name = 'approved'
     and snapshot.confirmed_need_approval_snapshot_id =
       (approved.response ->> 'confirmed_need_approval_snapshot_id')::uuid),
  'RMVP07-45 snapshot binds exact validation lineage version and fact fingerprint'
);
select is(
  (select count(*)::integer
   from atlas_planning.confirmed_need_snapshot_lines snapshot_line
   join rmvp07_results approved on approved.result_name = 'approved'
   where snapshot_line.confirmed_need_approval_snapshot_id =
     (approved.response ->> 'confirmed_need_approval_snapshot_id')::uuid),
  (select count(*)::integer from atlas_planning.confirmed_need_lines
   where confirmed_need_batch_id =
     'b6500000-0000-0000-0000-000000000050'),
  'RMVP07-46 approval creates every-and-only one snapshot line per stable line'
);
select ok(
  not exists (
    select 1 from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id =
      'b6500000-0000-0000-0000-000000000050'
      and revision.is_current and revision.revision_status <> 'RELEASED'
  ),
  'RMVP07-47 line metadata advances DRAFT to APPROVED to RELEASED without payload replacement'
);
select ok(
  (select current_confirmed_need_validation_attempt_id is null
     and current_confirmed_need_approval_snapshot_id is not null
     and current_confirmed_need_release_id is not null
     and batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
     and version = 5
   from atlas_planning.confirmed_need_batches
   where confirmed_need_batch_id =
     'b6500000-0000-0000-0000-000000000050'),
  'RMVP07-48 final authority pointers and resulting version are exact'
);
select ok(
  (select count(*) = 2 from atlas_audit.domain_events
   where command_id in (
     'b6700000-0000-0000-0000-000000000010',
     'b6700000-0000-0000-0000-000000000014'
   )) and
  (select count(*) = 2 from atlas_audit.audit_events
   where command_id in (
     'b6700000-0000-0000-0000-000000000010',
     'b6700000-0000-0000-0000-000000000014'
   )) and
  (select count(*) = 2 from atlas_core.command_receipts
   where command_id in (
     'b6700000-0000-0000-0000-000000000010',
     'b6700000-0000-0000-0000-000000000014'
   ) and outcome = 'COMPLETED'),
  'RMVP07-49 approval and release each atomically persist one receipt event and audit'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'release_stale'),
  'STALE_VERSION',
  'RMVP07-50 stale release is rejected'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'release_drift'),
  'APPROVAL_FACTS_CHANGED',
  'RMVP07-51 changed approval-bound projection rejects release'
);
select is(
  (select response ->> 'resulting_batch_status' from rmvp07_results
   where result_name = 'released'),
  'RELEASED_FOR_PURCHASE_HANDOFF',
  'RMVP07-52 release advances the batch without creating Purchase Handoff'
);
select is(
  (select response ->> 'resulting_released_batch_version'
   from rmvp07_results where result_name = 'released'),
  '5',
  'RMVP07-53 release increments the batch version exactly once'
);
select ok(
  (select release.confirmed_need_approval_snapshot_id =
      (released.response ->> 'confirmed_need_approval_snapshot_id')::uuid
     and release.source_approved_batch_version = 4
     and release.resulting_released_batch_version = 5
   from atlas_planning.confirmed_need_releases release
   cross join rmvp07_results released
   where released.result_name = 'released'
     and release.confirmed_need_release_id =
       (released.response ->> 'confirmed_need_release_id')::uuid),
  'RMVP07-54 release row binds the exact current approval and sequential versions'
);
select is(
  (select response from rmvp07_results where result_name = 'release_replay'),
  (select response from rmvp07_results where result_name = 'released'),
  'RMVP07-55 release exact replay returns the byte-for-byte original response'
);
select is(
  (select response ->> 'error_code' from rmvp07_results
   where result_name = 'release_conflict'),
  'IDEMPOTENCY_CONFLICT',
  'RMVP07-56 release scoped idempotency conflict creates no second release'
);
select is(
  (select count(*)::integer from atlas_planning.confirmed_need_releases
   where confirmed_need_batch_id =
     'b6500000-0000-0000-0000-000000000050'),
  1,
  'RMVP07-57 exactly one immutable release exists for the approval'
);
select is(
  (select state -> 'downstream' from rmvp07_before),
  jsonb_build_object(
    'handoff_batches',
      (select count(*) from atlas_planning.purchase_handoff_batches),
    'handoff_revisions',
      (select count(*) from atlas_planning.purchase_handoff_revisions),
    'handoff_lines',
      (select count(*) from atlas_planning.purchase_handoff_lines),
    'handoff_line_revisions',
      (select count(*) from atlas_planning.purchase_handoff_line_revisions),
    'demand_references',
      (select count(*) from atlas_planning.purchase_demand_references),
    'procurement',
      (select count(*) from atlas_procurement.fulfilment_allocations),
    'warehouse',
      (select count(*) from atlas_evidence.supplier_receiving_evidence),
    'dispatch',
      (select count(*) from atlas_dispatch.dispatch_plans)
  ),
  'RMVP07-58 release creates zero Purchase Handoff Procurement Warehouse or Dispatch fact'
);
select is(
  (select array_agg(key order by key)::text[]
   from rmvp07_results result
   cross join lateral jsonb_object_keys(result.response) key
   where result.result_name = 'approved'),
  array[
    'approved_at', 'approved_by_actor_id', 'approved_line_count',
    'approved_version', 'audit_id', 'authoritative_readback',
    'command_id', 'command_name', 'confirmed_need_approval_snapshot_id',
    'confirmed_need_batch_id', 'confirmed_need_validation_attempt_id',
    'contract_version', 'correlation_id', 'event_id', 'idempotency_status',
    'prior_batch_status', 'prior_batch_version', 'receipt_id',
    'resulting_batch_status', 'resulting_batch_version',
    'safe_operator_message', 'source_kind', 'success',
    'validated_fact_fingerprint',
    'validation_attempt_fingerprint', 'warning_count'
  ]::text[],
  'RMVP07-59 approval success has exactly the accepted fields'
);
select is(
  (select array_agg(key order by key)::text[]
   from rmvp07_results result
   cross join lateral jsonb_object_keys(result.response) key
   where result.result_name = 'released'),
  array[
    'audit_id', 'authoritative_readback', 'command_id', 'command_name',
    'confirmed_need_approval_snapshot_id', 'confirmed_need_batch_id',
    'confirmed_need_release_id', 'contract_version', 'correlation_id',
    'event_id', 'idempotency_status', 'prior_batch_status',
    'prior_batch_version', 'receipt_id', 'released_at',
    'released_by_actor_id', 'released_line_count', 'resulting_batch_status',
    'resulting_batch_version', 'resulting_released_batch_version',
    'safe_operator_message', 'source_approved_batch_version', 'source_kind',
    'success', 'validated_fact_fingerprint', 'warning_count'
  ]::text[],
  'RMVP07-60 release success has exactly the accepted fields'
);
select ok(
  (select jsonb_typeof(response #> '{workbench,allowed_actions,approve_confirmed_needs}') = 'boolean'
     and jsonb_typeof(response #> '{workbench,allowed_actions,release_confirmed_needs_for_purchase_handoff}') = 'boolean'
     and response #>> '{workbench,disabled_reason_codes,approve_confirmed_needs}' = 'APPROVAL_ALREADY_COMPLETED'
     and response #>> '{workbench,disabled_reason_codes,release_confirmed_needs_for_purchase_handoff}' = 'RELEASE_ALREADY_COMPLETED'
     and jsonb_typeof(response #> '{workbench,approval}') = 'object'
     and jsonb_typeof(response #> '{workbench,release}') = 'object'
     and jsonb_typeof(response #> '{workbench,facts_changed_since_validation}') = 'boolean'
     and jsonb_typeof(response #> '{workbench,facts_changed_since_approval}') = 'boolean'
     and jsonb_typeof(response #> '{workbench,lifecycle_history}') = 'array'
   from rmvp07_results where result_name = 'final_read'),
  'RMVP07-61 read model exposes every exact additive field with final action values'
);
select is(
  (select array_agg(item ->> 'evidence_kind' order by ordinal)::text[]
   from rmvp07_results result
   cross join lateral jsonb_array_elements(
     result.response #> '{workbench,lifecycle_history}'
   ) with ordinality history(item, ordinal)
   where result.result_name = 'final_read'),
  array['RELEASE', 'APPROVAL', 'VALIDATION']::text[],
  'RMVP07-62 lifecycle history is newest-first release approval validation'
);
select ok(
  (select bool_and(
     (select array_agg(key order by key)::text[]
      from jsonb_object_keys(item) key) = array[
       'actor', 'evidence_id', 'evidence_kind', 'occurred_at', 'outcome',
       'reason_code', 'resulting_version', 'source_version', 'warning_count'
     ]::text[]
   )
   from rmvp07_results result
   cross join lateral jsonb_array_elements(
     result.response #> '{workbench,lifecycle_history}'
   ) history(item)
   where result.result_name = 'final_read'),
  'RMVP07-63 every lifecycle item has exactly the accepted shape'
);
select ok(
  (select response #>> '{workbench,disabled_reasons,approve_confirmed_needs}' =
      'Lô nhu cầu đã được phê duyệt.'
     and response #>> '{workbench,disabled_reasons,release_confirmed_needs_for_purchase_handoff}' =
      'Lô nhu cầu đã được phát hành.'
   from rmvp07_results where result_name = 'final_read'),
  'RMVP07-64 closed disabled registry returns the exact Vietnamese completed messages'
);
select ok(
  (select response #>> '{workbench,contract_version}' is null
     and response #>> '{contract_version}' = 'RMVP-05.v1'
     and jsonb_typeof(response #> '{workbench,lines}') = 'array'
     and jsonb_typeof(response #> '{workbench,validation}') = 'object'
   from rmvp07_results where result_name = 'final_read'),
  'RMVP07-65 the RMVP-05 read envelope and existing workbench fields remain compatible'
);

select throws_ok(
  $$update atlas_planning.confirmed_need_releases
    set released_at = transaction_timestamp()$$,
  '55000',
  'Confirmed Need approval and release evidence is immutable and undeletable',
  'RMVP07-66 release evidence rejects mutation'
);
select throws_ok(
  $$delete from atlas_planning.confirmed_need_approval_snapshots
    where source_kind = 'NEED_GENERATION'$$,
  '55000',
  'Confirmed Need approval and release evidence is immutable and undeletable',
  'RMVP07-67 approval evidence rejects deletion'
);

select * from finish();
rollback;
