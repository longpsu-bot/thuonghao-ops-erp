begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(65);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Public surface, persistence, and least privilege (1-13).
select is(
  (select count(*)::integer from atlas_core.capabilities
   where capability_code = 'confirmed_need_validation.validate'),
  1,
  'RMVP06-01 the accepted validation capability exists exactly once'
);
select has_function(
  'atlas_api', 'validate_confirmed_needs', array['jsonb'],
  'RMVP06-02 the validation API exists'
);
select is(
  (select pg_get_userbyid(proowner)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'),
  'atlas_confirmed_need_review_runtime',
  'RMVP06-03 the dedicated Confirmed Need runtime owns validation'
);
select ok(
  (select prosecdef and proconfig = array['search_path=""']::text[]
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'),
  'RMVP06-04 validation is a fixed-search-path security definer'
);
select ok(
  (select has_function_privilege('authenticated', p.oid, 'EXECUTE')
     and not has_function_privilege('anon', p.oid, 'EXECUTE')
     and not has_function_privilege('service_role', p.oid, 'EXECUTE')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'),
  'RMVP06-05 only authenticated receives public execute'
);
select is(
  (select jsonb_build_object(
     'login', rolcanlogin, 'inherit', rolinherit, 'superuser', rolsuper,
     'create_role', rolcreaterole, 'create_db', rolcreatedb,
     'replication', rolreplication, 'bypass_rls', rolbypassrls
   ) from pg_roles where rolname = 'atlas_confirmed_need_review_runtime'),
  jsonb_build_object(
    'login', false, 'inherit', false, 'superuser', false,
    'create_role', false, 'create_db', false,
    'replication', false, 'bypass_rls', false
  ),
  'RMVP06-06 the reused runtime remains NOLOGIN NOINHERIT and unprivileged'
);
select is(
  (select array_agg(tablename order by tablename)::text[]
   from pg_tables
   where schemaname = 'atlas_planning'
     and tablename like 'confirmed_need_validation_%'),
  array[
    'confirmed_need_validation_attempts',
    'confirmed_need_validation_issues',
    'confirmed_need_validation_lines'
  ]::text[],
  'RMVP06-07 exactly three validation evidence relations exist'
);
select ok(
  (select bool_and(relrowsecurity and relforcerowsecurity)
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'atlas_planning'
     and c.relname in (
       'confirmed_need_validation_attempts',
       'confirmed_need_validation_lines',
       'confirmed_need_validation_issues'
     )),
  'RMVP06-08 all validation evidence forces RLS'
);
select ok(
  not has_table_privilege('authenticated',
    'atlas_planning.confirmed_need_validation_attempts', 'SELECT')
  and not has_table_privilege('authenticated',
    'atlas_planning.confirmed_need_validation_lines', 'SELECT')
  and not has_table_privilege('authenticated',
    'atlas_planning.confirmed_need_validation_issues', 'SELECT'),
  'RMVP06-09 browser roles receive no direct evidence access'
);
select ok(
  (select pg_get_constraintdef(oid) like '%CURRENT_REVISION_AMBIGUOUS%'
     and pg_get_constraintdef(oid) like '%CURRENT_DECISION_AMBIGUOUS%'
     and pg_get_constraintdef(oid) like '%PLANNING_POLICY_MISSING%'
     and pg_get_constraintdef(oid) like '%PLANNING_POLICY_AMBIGUOUS%'
   from pg_constraint
   where conname = 'confirmed_need_validation_issues_code_check'),
  'RMVP06-10 persistence includes all four corrected missing/ambiguous codes'
);
select ok(
  (select pg_get_constraintdef(oid) like '%ZERO_CONFIRMED_QUANTITY%'
     and pg_get_constraintdef(oid) like '%UPSTREAM_WARNING_RETAINED%'
   from pg_constraint
   where conname = 'confirmed_need_validation_issues_severity_code_check'),
  'RMVP06-11 exactly the approved warning family is severity-bound'
);
select is(
  (select count(*)::integer
   from pg_trigger
   where tgname like 'confirmed_need_validation_%_immutable'
     and not tgisinternal),
  3,
  'RMVP06-12 all three evidence relations reject update and delete'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%source_kind <> ''NEED_GENERATION''%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'),
  'RMVP06-13 the public command rejects direct wholesale validation'
);

select is(
  (select count(*)::integer
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'),
  1,
  'RMVP06-S01 validation has no public overload'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%RMVP-06.v1%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'),
  'RMVP06-S02 the public command implements the exact RMVP-06.v1 contract'
);
select is(
  (select count(*)::integer
   from atlas_core.role_capabilities role_capability
   join atlas_core.capabilities capability using (capability_id)
   where capability.capability_code = 'confirmed_need_validation.validate'),
  0,
  'RMVP06-S03 the production capability remains unbound'
);
select is(
  (select count(*)::integer from pg_roles
   where rolname like 'atlas\_%' escape '\'),
  11,
  'RMVP06-S04 validation adds no database role'
);
select has_column(
  'atlas_planning', 'confirmed_need_batches',
  'current_confirmed_need_validation_attempt_id',
  'RMVP06-S05 the accepted successful-attempt pointer exists'
);
select ok(
  (select bool_and(pg_get_userbyid(c.relowner) = 'atlas_owner')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'atlas_planning'
     and c.relname in (
       'confirmed_need_validation_attempts',
       'confirmed_need_validation_lines',
       'confirmed_need_validation_issues'
     )),
  'RMVP06-S06 atlas_owner owns all evidence relations'
);
select is(
  (select count(*)::integer
   from pg_policy policy
   join pg_class relation on relation.oid = policy.polrelid
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'atlas_planning'
     and relation.relname like 'confirmed_need_validation_%'
     and policy.polroles = array['atlas_confirmed_need_review_runtime'::regrole::oid]),
  6,
  'RMVP06-S07 evidence has exact runtime select/insert policies only'
);
select ok(
  not exists (
    select 1
    from information_schema.role_table_grants grant_row
    where grant_row.grantee = 'atlas_confirmed_need_review_runtime'
      and grant_row.table_schema in (
        'atlas_procurement', 'atlas_evidence', 'atlas_dispatch'
      )
  ),
  'RMVP06-S08 validation receives no downstream-domain relation privilege'
);
select ok(
  (select pg_get_constraintdef(oid) like '%outcome = ''VALIDATED''%'
     and pg_get_constraintdef(oid) like '%outcome = ''BLOCKED''%'
     and pg_get_constraintdef(oid) like '%resulting_batch_version = (evaluated_batch_version + 1)%'
   from pg_constraint
   where conname = 'confirmed_need_validation_attempts_result_check'),
  'RMVP06-S09 attempt outcomes enforce exact lifecycle/version semantics'
);
select ok(
  (select pg_get_constraintdef(oid) like '%observed_current_revision_count = 1%'
     and pg_get_constraintdef(oid) like '%observed_current_decision_count = 1%'
     and pg_get_constraintdef(oid) like '%observed_eligible_policy_count = 1%'
     and pg_get_constraintdef(oid) like '%observed_source_membership_count > 0%'
   from pg_constraint
   where conname = 'confirmed_need_validation_lines_validated_shape_check'),
  'RMVP06-S10 successful observations require complete exact cardinalities'
);
select ok(
  (select condeferrable
     and pg_get_constraintdef(oid) like '%current_confirmed_need_validation_attempt_id%'
     and pg_get_constraintdef(oid) like '%confirmed_need_batch_id%'
   from pg_constraint
   where conname = 'confirmed_need_batches_current_validation_fkey'),
  'RMVP06-S11 the same-batch successful pointer is deferred and relational'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'confirmed_need_validation_attempts_batch_attempt_key'
      and contype = 'u'
  ),
  'RMVP06-S12 attempt numbering is unique within a batch'
);
select ok(
  not has_table_privilege(
    'atlas_confirmed_need_review_runtime',
    'atlas_planning.confirmed_need_validation_attempts', 'DELETE'
  ) and not has_table_privilege(
    'atlas_confirmed_need_review_runtime',
    'atlas_planning.confirmed_need_validation_lines', 'DELETE'
  ) and not has_table_privilege(
    'atlas_confirmed_need_review_runtime',
    'atlas_planning.confirmed_need_validation_issues', 'DELETE'
  ),
  'RMVP06-S13 the runtime cannot delete validation evidence'
);
select is(
  (select count(*)::integer
   from pg_class relation
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'atlas_planning'
     and relation.relkind in ('v', 'm')
     and relation.relname like '%validation%'),
  0,
  'RMVP06-S14 validation adds no view or materialized view'
);

with actual as (
  select distinct match[1] as code
  from pg_constraint constraint_row
  cross join lateral regexp_matches(
    pg_get_constraintdef(constraint_row.oid),
    '''([A-Z][A-Z_]+)''',
    'g'
  ) match
  where constraint_row.conname = 'confirmed_need_validation_issues_code_check'
), expected(code) as (
  select unnest(array[
    'NO_CURRENT_LINES',
    'CURRENT_LINE_SET_INVALID',
    'CURRENT_REVISION_MISSING',
    'CURRENT_REVISION_AMBIGUOUS',
    'CURRENT_DECISION_MISSING',
    'CURRENT_DECISION_AMBIGUOUS',
    'DECISION_REVISION_MISMATCH',
    'SOURCE_RELEASE_NOT_CURRENT',
    'CONTRIBUTION_MEMBERSHIP_INVALID',
    'THEORETICAL_TOTAL_MISMATCH',
    'CONTROLLED_UNIT_INACTIVE',
    'PLANNING_POLICY_MISSING',
    'PLANNING_POLICY_AMBIGUOUS',
    'PLANNING_POLICY_NOT_ELIGIBLE',
    'DECISION_POLICY_MISMATCH',
    'CONFIRMED_QUANTITY_INVALID',
    'ADJUSTMENT_REASON_INCOMPLETE',
    'SOURCE_BLOCKER_PRESENT',
    'CURRENT_FACTS_CHANGED',
    'ZERO_CONFIRMED_QUANTITY',
    'UPSTREAM_WARNING_RETAINED'
  ]::text[])
)
select is(
  (select array_agg(code order by code)::text[] from actual),
  (select array_agg(code order by code)::text[] from expected),
  'RMVP06-C01 persistence accepts exactly the approved 19+2 issue registry'
);
select ok(
  (select position('if v_revision_count = 1 then' in definition) > 0
     and position('elsif v_revision_count = 0 then' in definition)
       < position('''current_revision_missing''' in definition)
     and position('''current_revision_missing''' in definition)
       < position('''current_revision_ambiguous''' in definition)
   from (
     select lower(pg_get_functiondef(p.oid)) as definition
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'atlas_core'
       and p.proname = 'rmvp_06_canonical_evaluation'
   ) source),
  'RMVP06-C02 revision count zero and greater-than-one use distinct missing/ambiguous codes'
);
select ok(
  (select position('if v_decision_count = 1 then' in definition) > 0
     and position('elsif v_decision_count = 0 then' in definition)
       < position('''current_decision_missing''' in definition)
     and position('''current_decision_missing''' in definition)
       < position('''current_decision_ambiguous''' in definition)
   from (
     select lower(pg_get_functiondef(p.oid)) as definition
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'atlas_core'
       and p.proname = 'rmvp_06_canonical_evaluation'
   ) source),
  'RMVP06-C03 decision count zero and greater-than-one use distinct missing/ambiguous codes'
);
select ok(
  (select position('if v_policy_count = 1 then' in definition) > 0
     and position('elsif v_policy_count = 0 then' in definition)
       < position('''planning_policy_missing''' in definition)
     and position('''planning_policy_missing''' in definition)
       < position('''planning_policy_ambiguous''' in definition)
   from (
     select lower(pg_get_functiondef(p.oid)) as definition
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'atlas_core'
       and p.proname = 'rmvp_06_canonical_evaluation'
   ) source),
  'RMVP06-C04 policy count zero and greater-than-one use distinct missing/ambiguous codes'
);
with source as (
  select split_part(lower(pg_get_functiondef(p.oid)), 'with ranked as', 2) as definition
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'rmvp_06_canonical_evaluation'
), matches as (
  select found.captures[1] as code, found.ordinal
  from source
  cross join lateral regexp_matches(
    definition,
    '''([a-z][a-z_]+)''',
    'g'
  ) with ordinality found(captures, ordinal)
  where found.captures[1] = any(array[
    'no_current_lines', 'current_line_set_invalid',
    'current_revision_missing', 'current_revision_ambiguous',
    'current_decision_missing', 'current_decision_ambiguous',
    'decision_revision_mismatch', 'source_release_not_current',
    'contribution_membership_invalid', 'theoretical_total_mismatch',
    'controlled_unit_inactive', 'planning_policy_missing',
    'planning_policy_ambiguous', 'planning_policy_not_eligible',
    'decision_policy_mismatch', 'confirmed_quantity_invalid',
    'adjustment_reason_incomplete', 'source_blocker_present',
    'current_facts_changed', 'zero_confirmed_quantity',
    'upstream_warning_retained'
  ]::text[])
), first_registry as (
  select code, ordinal from matches order by ordinal limit 21
)
select is(
  (select array_agg(code order by ordinal)::text[] from first_registry),
  array[
    'no_current_lines', 'current_line_set_invalid',
    'current_revision_missing', 'current_revision_ambiguous',
    'current_decision_missing', 'current_decision_ambiguous',
    'decision_revision_mismatch', 'source_release_not_current',
    'contribution_membership_invalid', 'theoretical_total_mismatch',
    'controlled_unit_inactive', 'planning_policy_missing',
    'planning_policy_ambiguous', 'planning_policy_not_eligible',
    'decision_policy_mismatch', 'confirmed_quantity_invalid',
    'adjustment_reason_incomplete', 'source_blocker_present',
    'current_facts_changed', 'zero_confirmed_quantity',
    'upstream_warning_retained'
  ]::text[],
  'RMVP06-C05 canonical issue order is all 19 blockers followed by both warnings'
);

-- The focused suite reuses the deterministic accepted RMVP-05 persistence
-- fixture. CI installs the three bounded local fixture files immediately before
-- this transaction because `supabase test db <file>` mounts only the test file.

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'b6000000-0000-0000-0000-000000000003',
  capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code = 'confirmed_need_validation.validate';

create temporary table rmvp06_results (
  result_name text primary key,
  response jsonb not null
);
grant select, insert on rmvp06_results to authenticated;

create function pg_temp.rmvp06_read()
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101',
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', 'b6500000-0000-0000-0000-000000000050',
      'filters', '{}'::jsonb, 'line_offset', 0, 'line_limit', 100
    )
  );
$$;

create function pg_temp.rmvp06_validation(
  p_command_id uuid, p_expected_version bigint, p_key text
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-06.v1',
    'command_id', p_command_id,
    'correlation_id', gen_random_uuid(),
    'idempotency_key', p_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101',
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'BATCH_VALIDATION_REQUESTED',
    'reason_note', null,
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', 'b6500000-0000-0000-0000-000000000050'
    )
  );
$$;

create function pg_temp.rmvp06_lines(p_workbench jsonb)
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

grant execute on function pg_temp.rmvp06_read() to authenticated;
grant execute on function pg_temp.rmvp06_validation(uuid, bigint, text)
  to authenticated;
grant execute on function pg_temp.rmvp06_lines(jsonb) to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101',
  true
);

insert into rmvp06_results values (
  'initial_read', atlas_api.get_confirmed_need_review(pg_temp.rmvp06_read())
);
insert into rmvp06_results values (
  'blocked', atlas_api.validate_confirmed_needs(pg_temp.rmvp06_validation(
    'b6600000-0000-0000-0000-000000000001', 1, 'rmvp06-blocked'
  ))
);
insert into rmvp06_results values (
  'blocked_replay', atlas_api.validate_confirmed_needs(pg_temp.rmvp06_validation(
    'b6600000-0000-0000-0000-000000000001', 1, 'rmvp06-blocked'
  ))
);
insert into rmvp06_results values (
  'blocked_conflict', atlas_api.validate_confirmed_needs(pg_temp.rmvp06_validation(
    'b6600000-0000-0000-0000-000000000009', 1, 'rmvp06-blocked'
  ))
);

insert into rmvp06_results
select 'preview', atlas_api.preview_confirmed_need_confirmation(
  jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101',
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', 'b6500000-0000-0000-0000-000000000050',
      'expected_batch_version', 1,
      'lines', pg_temp.rmvp06_lines(response -> 'workbench')
    )
  )
)
from rmvp06_results where result_name = 'initial_read';

insert into rmvp06_results
select 'confirmed', atlas_api.confirm_need_quantities(jsonb_build_object(
  'contract_version', 'RMVP-05.v1',
  'command_id', 'b6600000-0000-0000-0000-000000000002',
  'correlation_id', gen_random_uuid(),
  'idempotency_key', 'rmvp06-confirm-prerequisite',
  'expected_version', 1,
  'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101',
  'requested_at', transaction_timestamp() - interval '1 second',
  'reason_code', 'CONFIRMED_NEED_QUANTITIES_CONFIRMED',
  'reason_note', null,
  'payload', jsonb_build_object(
    'confirmed_need_batch_id', 'b6500000-0000-0000-0000-000000000050',
    'preview_hash', preview.response #>> '{preview,preview_hash}',
    'lines', pg_temp.rmvp06_lines(initial.response -> 'workbench')
  )
))
from rmvp06_results preview
cross join rmvp06_results initial
where preview.result_name = 'preview'
  and initial.result_name = 'initial_read';

reset role;

create temporary table rmvp06_before_validation as
select jsonb_build_object(
  'revision_count', (
    select count(*) from atlas_planning.confirmed_need_line_revisions
    where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
  ),
  'revision_hash', (
    select md5(string_agg(row(revision.*)::text, E'\n'
      order by revision.confirmed_need_line_revision_id))
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
  ),
  'decision_count', (
    select count(*) from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
  ),
  'decision_hash', (
    select md5(string_agg(row(decision.*)::text, E'\n'
      order by decision.confirmed_need_line_decision_id))
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
  ),
  'contribution_hash', (
    select md5(string_agg(row(contribution.*)::text, E'\n'
      order by contribution.confirmed_need_line_revision_contribution_id))
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    where contribution.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
  ),
  'policy_hash', (
    select md5(string_agg(row(policy.*)::text, E'\n'
      order by policy.planning_quantity_policy_revision_id))
    from atlas_planning.planning_quantity_policy_revisions policy
    where policy.unit_id = 'b6500000-0000-0000-0000-000000000005'
  ),
  'source_hash', (
    select md5(row(run.*, release.*)::text)
    from atlas_planning.need_generation_runs run
    join atlas_planning.need_generation_release_snapshots release
      on release.need_generation_run_id = run.need_generation_run_id
    where run.need_generation_run_id = 'b6550000-0000-0000-0000-000000000001'
  )
) as state;

set local role authenticated;

insert into rmvp06_results values (
  'stale', atlas_api.validate_confirmed_needs(pg_temp.rmvp06_validation(
    'b6600000-0000-0000-0000-000000000003', 1, 'rmvp06-stale'
  ))
);
insert into rmvp06_results values (
  'validated', atlas_api.validate_confirmed_needs(pg_temp.rmvp06_validation(
    'b6600000-0000-0000-0000-000000000004', 2, 'rmvp06-validated'
  ))
);
insert into rmvp06_results values (
  'replay', atlas_api.validate_confirmed_needs(pg_temp.rmvp06_validation(
    'b6600000-0000-0000-0000-000000000004', 2, 'rmvp06-validated'
  ))
);
insert into rmvp06_results values (
  'final_read', atlas_api.get_confirmed_need_review(pg_temp.rmvp06_read())
);

reset role;

-- Governed BLOCKED evaluation (14-22).
select is(
  (select response ->> 'success' from rmvp06_results where result_name = 'blocked'),
  'true', 'RMVP06-14 business blockers are a successful governed evaluation'
);
select is(
  (select response ->> 'validation_status' from rmvp06_results where result_name = 'blocked'),
  'BLOCKED', 'RMVP06-15 missing decisions produce BLOCKED'
);
select is(
  (select response ->> 'resulting_batch_version' from rmvp06_results where result_name = 'blocked'),
  '1', 'RMVP06-16 BLOCKED does not advance batch version'
);
select is(
  (select response ->> 'resulting_batch_status' from rmvp06_results where result_name = 'blocked'),
  'DRAFT_REVIEW', 'RMVP06-17 BLOCKED preserves working lifecycle'
);
select is(
  (select response ->> 'blocking_issue_count' from rmvp06_results where result_name = 'blocked'),
  '2', 'RMVP06-18 both missing current decisions are persisted blockers'
);
select is(
  (select response from rmvp06_results where result_name = 'blocked_replay'),
  (select response from rmvp06_results where result_name = 'blocked'),
  'RMVP06-R01 blocked exact replay returns the immutable original response'
);
select is(
  (select response ->> 'error_code' from rmvp06_results
   where result_name = 'blocked_conflict'),
  'IDEMPOTENCY_CONFLICT',
  'RMVP06-R02 same idempotency key with a different request conflicts'
);
select is(
  (select count(*)::integer from atlas_planning.confirmed_need_validation_attempts
   where outcome = 'BLOCKED'),
  1, 'RMVP06-19 one immutable blocked attempt exists'
);
select is(
  (select count(*)::integer from atlas_planning.confirmed_need_validation_lines line
   join atlas_planning.confirmed_need_validation_attempts attempt
     using (confirmed_need_validation_attempt_id)
   where attempt.outcome = 'BLOCKED'),
  2, 'RMVP06-20 blocked evidence preserves complete stable-line membership'
);
select ok(
  not exists (
    select 1
    from atlas_planning.confirmed_need_validation_lines line
    group by line.confirmed_need_validation_attempt_id
    having array_agg(line.confirmed_need_line_id order by line.line_sort_position)
      is distinct from array_agg(line.confirmed_need_line_id order by line.confirmed_need_line_id)
  ),
  'RMVP06-C06 every attempt persists stable lines in deterministic identity order'
);
select is(
  (select array_agg(issue_code order by issue_sort_position)::text[]
   from atlas_planning.confirmed_need_validation_issues issue
   join atlas_planning.confirmed_need_validation_attempts attempt
     using (confirmed_need_validation_attempt_id)
   where attempt.outcome = 'BLOCKED'),
  array['CURRENT_DECISION_MISSING', 'CURRENT_DECISION_MISSING']::text[],
  'RMVP06-21 missing cardinality is not merged with ambiguous cardinality'
);
select is(
  (select batch_status || ':' || version::text
   from atlas_planning.confirmed_need_batches
   where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'),
  'VALIDATED:3',
  'RMVP06-22 the later success is the only lifecycle/version advance'
);

-- Stale rejection and successful immutable evaluation (23-35).
select is(
  (select response ->> 'new_batch_version' from rmvp06_results where result_name = 'confirmed'),
  '2', 'RMVP06-23 prerequisite confirmation advances once'
);
select is(
  (select response ->> 'error_code' from rmvp06_results where result_name = 'stale'),
  'STALE_CONFIRMED_NEED_BATCH', 'RMVP06-24 stale validation fails closed'
);
select is(
  (select count(*)::integer from atlas_planning.confirmed_need_validation_attempts),
  2, 'RMVP06-25 stale rejection creates no evidence attempt'
);
select is(
  (select response ->> 'validation_status' from rmvp06_results where result_name = 'validated'),
  'VALIDATED', 'RMVP06-26 the complete eligible batch validates'
);
select is(
  (select (response ->> 'evaluated_batch_version') || ':' ||
          (response ->> 'resulting_batch_version')
   from rmvp06_results where result_name = 'validated'),
  '2:3', 'RMVP06-27 VALIDATED advances exactly one version'
);
select ok(
  (select response ->> 'line_count' = '2'
     and response ->> 'blocking_issue_count' = '0'
     and response ->> 'validation_fingerprint' ~ '^[0-9a-f]{64}$'
   from rmvp06_results where result_name = 'validated'),
  'RMVP06-28 response exposes exact counts and canonical fingerprint'
);
select ok(
  (select batch.current_confirmed_need_validation_attempt_id::text
      = result.response ->> 'validation_attempt_id'
     and batch.batch_status = 'VALIDATED' and batch.version = 3
   from atlas_planning.confirmed_need_batches batch
   join rmvp06_results result on result.result_name = 'validated'
   where batch.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'),
  'RMVP06-29 batch points to the exact successful attempt'
);
select is(
  (select count(*)::integer from atlas_planning.confirmed_need_validation_lines line
   join atlas_planning.confirmed_need_validation_attempts attempt
     using (confirmed_need_validation_attempt_id)
   where attempt.outcome = 'VALIDATED'),
  2, 'RMVP06-30 successful evidence preserves two exact line observations'
);
select ok(
  (select bool_and(
     line.observed_current_revision_count = 1
     and line.observed_current_decision_count = 1
     and line.observed_eligible_policy_count = 1
     and line.observed_source_membership_count > 0
     and line.current_confirmed_need_line_revision_id is not null
     and line.current_confirmed_need_line_decision_id is not null
     and line.planning_quantity_policy_id is not null
     and line.planning_quantity_policy_revision_id is not null
     and line.need_generation_run_id is not null
     and line.need_generation_run_version is not null
     and line.need_generation_release_snapshot_id is not null
     and line.theoretical_quantity is not null
     and line.confirmed_quantity is not null
     and line.planning_tick_count is not null
     and line.source_membership_total is not null
   )
   from atlas_planning.confirmed_need_validation_lines line
   join atlas_planning.confirmed_need_validation_attempts attempt
     using (confirmed_need_validation_attempt_id)
   where attempt.outcome = 'VALIDATED'),
  'RMVP06-R03 successful observations persist complete non-null bindings'
);
select is(
  (select count(*)::integer from atlas_planning.confirmed_need_validation_issues issue
   join atlas_planning.confirmed_need_validation_attempts attempt
     using (confirmed_need_validation_attempt_id)
   where attempt.outcome = 'VALIDATED'),
  1, 'RMVP06-31 warning-only success persists one approved warning'
);
select is(
  (select response from rmvp06_results where result_name = 'replay'),
  (select response from rmvp06_results where result_name = 'validated'),
  'RMVP06-32 exact retry returns the immutable original response'
);
select ok(
  (select response #>> '{workbench,validation,latest_outcome}' = 'VALIDATED'
     and response #>> '{workbench,editing_allowed}' = 'false'
     and response #>> '{workbench,validation_allowed}' = 'false'
     and response #>> '{workbench,validation,blocking_count}' = '0'
     and response #>> '{workbench,validation,warning_count}' = '1'
     and response #> '{workbench,validation,grouped_issues,warnings}'
       @> '[{"code":"ZERO_CONFIRMED_QUANTITY"}]'::jsonb
   from rmvp06_results where result_name = 'final_read'),
  'RMVP06-33 additive readback is current, read-only, and count-exact'
);
select is(
  (select array_agg(event_type order by occurred_at)::text[]
   from atlas_audit.domain_events
   where aggregate_id = 'b6500000-0000-0000-0000-000000000050'
     and event_type in ('ConfirmedNeedValidationFailed', 'ConfirmedNeedsValidated')),
  array['ConfirmedNeedValidationFailed', 'ConfirmedNeedsValidated']::text[],
  'RMVP06-34 blocked and successful outcomes emit the exact event names'
);
select is(
  (select count(*)::integer from atlas_audit.audit_events
   where aggregate_id = 'b6500000-0000-0000-0000-000000000050'
     and event_type in ('ConfirmedNeedValidationFailed', 'ConfirmedNeedsValidated')),
  2, 'RMVP06-35 both committed outcomes have bounded audit evidence'
);
select ok(
  (select bool_and(
     exists (
       select 1 from atlas_core.command_receipts receipt
       where receipt.command_id = attempt.command_id
         and receipt.outcome = 'COMPLETED'
     )
     and exists (
       select 1 from atlas_audit.domain_events event
       where event.command_id = attempt.command_id
     )
     and exists (
       select 1 from atlas_audit.audit_events audit
       where audit.command_id = attempt.command_id
     )
   )
   from atlas_planning.confirmed_need_validation_attempts attempt),
  'RMVP06-C07 blocked and validated evidence, receipt, event, and audit commit atomically'
);
select is(
  (select state from rmvp06_before_validation),
  (select jsonb_build_object(
    'revision_count', (
      select count(*) from atlas_planning.confirmed_need_line_revisions
      where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    ),
    'revision_hash', (
      select md5(string_agg(row(revision.*)::text, E'\n'
        order by revision.confirmed_need_line_revision_id))
      from atlas_planning.confirmed_need_line_revisions revision
      where revision.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    ),
    'decision_count', (
      select count(*) from atlas_planning.confirmed_need_line_decisions
      where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    ),
    'decision_hash', (
      select md5(string_agg(row(decision.*)::text, E'\n'
        order by decision.confirmed_need_line_decision_id))
      from atlas_planning.confirmed_need_line_decisions decision
      where decision.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    ),
    'contribution_hash', (
      select md5(string_agg(row(contribution.*)::text, E'\n'
        order by contribution.confirmed_need_line_revision_contribution_id))
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'
    ),
    'policy_hash', (
      select md5(string_agg(row(policy.*)::text, E'\n'
        order by policy.planning_quantity_policy_revision_id))
      from atlas_planning.planning_quantity_policy_revisions policy
      where policy.unit_id = 'b6500000-0000-0000-0000-000000000005'
    ),
    'source_hash', (
      select md5(row(run.*, release.*)::text)
      from atlas_planning.need_generation_runs run
      join atlas_planning.need_generation_release_snapshots release
        on release.need_generation_run_id = run.need_generation_run_id
      where run.need_generation_run_id = 'b6550000-0000-0000-0000-000000000001'
    )
  )),
  'RMVP06-R04 validation mutates no revision, decision, contribution, policy, or source fact'
);
select ok(
  (select position('for update' in definition) > 0
     and position('for v_unit_id in' in definition) > position('for update' in definition)
     and position('for v_policy_id in' in definition) > position('for v_unit_id in' in definition)
     and position('for v_policy_revision_id in' in definition) > position('for v_policy_id in' in definition)
     and position('v_prelock_evaluation ->> ''validation_fingerprint''' in definition)
       > position('for v_policy_revision_id in' in definition)
   from (
     select lower(pg_get_functiondef(p.oid)) as definition
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'atlas_api' and p.proname = 'validate_confirmed_needs'
   ) source),
  'RMVP06-R05 lock order and authoritative fingerprint reread are explicit'
);
select ok(
  (select position('prior_fingerprint is not null' in definition) > 0
     and position('v_fingerprint is distinct from prior_fingerprint' in definition) > 0
     and position(
       '''current_facts_changed''' in substring(
         definition from position(
           'v_fingerprint is distinct from prior_fingerprint' in definition
         )
       )
     ) > 0
   from (
     select lower(pg_get_functiondef(p.oid)) as definition
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'atlas_core'
       and p.proname = 'rmvp_06_canonical_evaluation'
   ) source),
  'RMVP06-C08 a changed pre-lock fingerprint fails closed with CURRENT_FACTS_CHANGED'
);

-- Immutability and complete approved registry (36-38).
select throws_ok(
  $$update atlas_planning.confirmed_need_validation_attempts
    set warning_count = warning_count + 1
    where confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050'$$,
  '55000',
  'Confirmed Need validation evidence is immutable and undeletable',
  'RMVP06-36 persisted validation evidence cannot be rewritten'
);
select is(
  (select count(distinct match[1])::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   cross join lateral regexp_matches(
     pg_get_functiondef(p.oid),
     '''(NO_CURRENT_LINES|CURRENT_LINE_SET_INVALID|CURRENT_REVISION_MISSING|CURRENT_REVISION_AMBIGUOUS|CURRENT_DECISION_MISSING|CURRENT_DECISION_AMBIGUOUS|DECISION_REVISION_MISMATCH|SOURCE_RELEASE_NOT_CURRENT|CONTRIBUTION_MEMBERSHIP_INVALID|THEORETICAL_TOTAL_MISMATCH|CONTROLLED_UNIT_INACTIVE|PLANNING_POLICY_MISSING|PLANNING_POLICY_AMBIGUOUS|PLANNING_POLICY_NOT_ELIGIBLE|DECISION_POLICY_MISMATCH|CONFIRMED_QUANTITY_INVALID|ADJUSTMENT_REASON_INCOMPLETE|SOURCE_BLOCKER_PRESENT|CURRENT_FACTS_CHANGED)''',
     'g'
   ) match
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_06_canonical_evaluation'),
  19,
  'RMVP06-37 evaluator implements the complete 19-code blocking registry'
);
select is(
  (select count(distinct match[1])::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   cross join lateral regexp_matches(
     pg_get_functiondef(p.oid),
     '''(ZERO_CONFIRMED_QUANTITY|UPSTREAM_WARNING_RETAINED)''',
     'g'
   ) match
   where n.nspname = 'atlas_core'
     and p.proname = 'rmvp_06_canonical_evaluation'),
  2,
  'RMVP06-38 evaluator implements exactly both approved warnings'
);

select * from finish();
rollback;
