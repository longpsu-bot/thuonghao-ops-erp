-- RMVP-06: connected complete-batch Confirmed Need validation.
--
-- One NEED_GENERATION working batch is evaluated as a complete immutable set.
-- A governed BLOCKED result commits evidence without changing lifecycle/version;
-- a VALIDATED result atomically advances the batch once. Approval, release,
-- Purchase Handoff, Procurement, Warehouse, and Dispatch remain unchanged.

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values (
  'confirmed_need_validation.validate',
  'Validate complete Confirmed Need batch',
  'PLANNING',
  'ACTIVE'
);

set role atlas_owner;

alter table atlas_planning.confirmed_need_lines
  add constraint confirmed_need_lines_validation_owner_key unique (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    controlled_unit_id
  );

alter table atlas_planning.confirmed_need_line_revisions
  add constraint confirmed_need_line_revisions_validation_owner_key unique (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    unit_id,
    theoretical_quantity
  );

alter table atlas_planning.confirmed_need_line_decisions
  add constraint confirmed_need_line_decisions_validation_owner_key unique (
    confirmed_need_line_decision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    confirmed_need_line_revision_id,
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id,
    confirmed_quantity_after,
    planning_tick_count
  );

create table atlas_planning.confirmed_need_validation_attempts (
  confirmed_need_validation_attempt_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  attempt_number bigint not null,
  source_kind text not null,
  evaluated_batch_version bigint not null,
  resulting_batch_version bigint not null,
  prior_batch_status text not null,
  resulting_batch_status text not null,
  outcome text not null,
  line_count integer not null,
  blocking_issue_count integer not null,
  warning_count integer not null,
  validation_fingerprint text not null,
  evaluated_by_actor_id uuid not null,
  evaluated_at timestamptz not null,
  command_id uuid not null,
  correlation_id uuid not null,
  reason_code text not null,
  reason_note text,
  constraint confirmed_need_validation_attempts_pkey primary key (
    confirmed_need_validation_attempt_id
  ),
  constraint confirmed_need_validation_attempts_batch_attempt_key unique (
    confirmed_need_batch_id,
    attempt_number
  ),
  constraint confirmed_need_validation_attempts_id_batch_key unique (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id
  ),
  constraint confirmed_need_validation_attempts_outcome_owner_key unique (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    outcome
  ),
  constraint confirmed_need_validation_attempts_exact_result_key unique (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    outcome,
    resulting_batch_version
  ),
  constraint confirmed_need_validation_attempts_command_key unique (command_id),
  constraint confirmed_need_validation_attempts_source_check check (
    source_kind = 'NEED_GENERATION'
  ),
  constraint confirmed_need_validation_attempts_outcome_check check (
    outcome in ('VALIDATED', 'BLOCKED')
  ),
  constraint confirmed_need_validation_attempts_status_check check (
    prior_batch_status in ('DRAFT_REVIEW', 'REOPENED')
    and resulting_batch_status in ('DRAFT_REVIEW', 'REOPENED', 'VALIDATED')
  ),
  constraint confirmed_need_validation_attempts_version_check check (
    evaluated_batch_version > 0
    and resulting_batch_version > 0
    and attempt_number > 0
  ),
  constraint confirmed_need_validation_attempts_count_check check (
    line_count >= 0
    and blocking_issue_count >= 0
    and warning_count >= 0
  ),
  constraint confirmed_need_validation_attempts_fingerprint_check check (
    validation_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  constraint confirmed_need_validation_attempts_reason_check check (
    reason_code = 'BATCH_VALIDATION_REQUESTED'
    and (
      reason_note is null
      or (
        reason_note = btrim(reason_note)
        and char_length(reason_note) between 1 and 500
      )
    )
  ),
  constraint confirmed_need_validation_attempts_result_check check (
    (
      outcome = 'VALIDATED'
      and resulting_batch_version = evaluated_batch_version + 1
      and blocking_issue_count = 0
      and resulting_batch_status = 'VALIDATED'
    ) or (
      outcome = 'BLOCKED'
      and resulting_batch_version = evaluated_batch_version
      and blocking_issue_count > 0
      and resulting_batch_status = prior_batch_status
    )
  ),
  constraint confirmed_need_validation_attempts_batch_fkey foreign key (
    confirmed_need_batch_id
  ) references atlas_planning.confirmed_need_batches (
    confirmed_need_batch_id
  ) on delete restrict,
  constraint confirmed_need_validation_attempts_actor_fkey foreign key (
    evaluated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_validation_attempts_command_fkey foreign key (
    command_id
  ) references atlas_core.command_receipts (command_id) on delete restrict
);

create table atlas_planning.confirmed_need_validation_lines (
  confirmed_need_validation_line_id uuid not null default gen_random_uuid(),
  confirmed_need_validation_attempt_id uuid not null,
  confirmed_need_batch_id uuid not null,
  confirmed_need_line_id uuid not null,
  validation_outcome text not null,
  controlled_unit_id uuid not null,
  observed_current_revision_count integer not null,
  observed_current_decision_count integer not null,
  observed_eligible_policy_count integer not null,
  observed_source_membership_count integer not null,
  line_sort_position integer not null,
  current_confirmed_need_line_revision_id uuid,
  current_confirmed_need_line_decision_id uuid,
  planning_quantity_policy_id uuid,
  planning_quantity_policy_revision_id uuid,
  need_generation_run_id uuid,
  need_generation_run_version bigint,
  need_generation_release_snapshot_id uuid,
  theoretical_quantity numeric(20, 6),
  confirmed_quantity numeric(20, 6),
  planning_tick_count numeric(20, 0),
  source_membership_total numeric(20, 6),
  constraint confirmed_need_validation_lines_pkey primary key (
    confirmed_need_validation_line_id
  ),
  constraint confirmed_need_validation_lines_attempt_line_key unique (
    confirmed_need_validation_attempt_id,
    confirmed_need_line_id
  ),
  constraint confirmed_need_validation_lines_attempt_sort_key unique (
    confirmed_need_validation_attempt_id,
    line_sort_position
  ),
  constraint confirmed_need_validation_lines_issue_owner_key unique (
    confirmed_need_validation_line_id,
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    confirmed_need_line_id
  ),
  constraint confirmed_need_validation_lines_outcome_check check (
    validation_outcome in ('VALIDATED', 'BLOCKED')
  ),
  constraint confirmed_need_validation_lines_count_check check (
    observed_current_revision_count >= 0
    and observed_current_decision_count >= 0
    and observed_eligible_policy_count >= 0
    and observed_source_membership_count >= 0
    and line_sort_position > 0
  ),
  constraint confirmed_need_validation_lines_quantity_check check (
    theoretical_quantity is null or theoretical_quantity >= 0
  ),
  constraint confirmed_need_validation_lines_confirmed_quantity_check check (
    confirmed_quantity is null or confirmed_quantity >= 0
  ),
  constraint confirmed_need_validation_lines_tick_check check (
    planning_tick_count is null or planning_tick_count >= 0
  ),
  constraint confirmed_need_validation_lines_validated_shape_check check (
    validation_outcome = 'BLOCKED'
    or (
      observed_current_revision_count = 1
      and observed_current_decision_count = 1
      and observed_eligible_policy_count = 1
      and observed_source_membership_count > 0
      and current_confirmed_need_line_revision_id is not null
      and current_confirmed_need_line_decision_id is not null
      and planning_quantity_policy_id is not null
      and planning_quantity_policy_revision_id is not null
      and need_generation_run_id is not null
      and need_generation_run_version is not null
      and need_generation_release_snapshot_id is not null
      and theoretical_quantity is not null
      and confirmed_quantity is not null
      and planning_tick_count is not null
      and source_membership_total is not null
    )
  ),
  constraint confirmed_need_validation_lines_attempt_fkey foreign key (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    validation_outcome
  ) references atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    outcome
  ) on delete restrict,
  constraint confirmed_need_validation_lines_line_fkey foreign key (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    controlled_unit_id
  ) references atlas_planning.confirmed_need_lines (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    controlled_unit_id
  ) on delete restrict,
  constraint confirmed_need_validation_lines_revision_fkey foreign key (
    current_confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    controlled_unit_id,
    theoretical_quantity
  ) references atlas_planning.confirmed_need_line_revisions (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    unit_id,
    theoretical_quantity
  ) on delete restrict,
  constraint confirmed_need_validation_lines_decision_fkey foreign key (
    current_confirmed_need_line_decision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    current_confirmed_need_line_revision_id,
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    controlled_unit_id,
    confirmed_quantity,
    planning_tick_count
  ) references atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_decision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    confirmed_need_line_revision_id,
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id,
    confirmed_quantity_after,
    planning_tick_count
  ) on delete restrict,
  constraint confirmed_need_validation_lines_policy_fkey foreign key (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    controlled_unit_id
  ) references atlas_planning.planning_quantity_policy_revisions (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id
  ) on delete restrict,
  constraint confirmed_need_validation_lines_release_fkey foreign key (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    need_generation_run_version
  ) references atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) on delete restrict
);

create table atlas_planning.confirmed_need_validation_issues (
  confirmed_need_validation_issue_id uuid not null default gen_random_uuid(),
  confirmed_need_validation_attempt_id uuid not null,
  confirmed_need_validation_line_id uuid,
  confirmed_need_batch_id uuid not null,
  confirmed_need_line_id uuid,
  severity text not null,
  issue_code text not null,
  safe_operator_message text not null,
  issue_sort_position integer not null,
  constraint confirmed_need_validation_issues_pkey primary key (
    confirmed_need_validation_issue_id
  ),
  constraint confirmed_need_validation_issues_attempt_sort_key unique (
    confirmed_need_validation_attempt_id,
    issue_sort_position
  ),
  constraint confirmed_need_validation_issues_severity_check check (
    severity in ('BLOCKING', 'WARNING')
  ),
  constraint confirmed_need_validation_issues_code_check check (
    issue_code in (
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
    )
  ),
  constraint confirmed_need_validation_issues_severity_code_check check (
    (
      issue_code in ('ZERO_CONFIRMED_QUANTITY', 'UPSTREAM_WARNING_RETAINED')
      and severity = 'WARNING'
    ) or (
      issue_code not in ('ZERO_CONFIRMED_QUANTITY', 'UPSTREAM_WARNING_RETAINED')
      and severity = 'BLOCKING'
    )
  ),
  constraint confirmed_need_validation_issues_message_check check (
    safe_operator_message = btrim(safe_operator_message)
    and char_length(safe_operator_message) between 1 and 500
  ),
  constraint confirmed_need_validation_issues_sort_check check (
    issue_sort_position > 0
  ),
  constraint confirmed_need_validation_issues_line_shape_check check (
    (confirmed_need_validation_line_id is null) = (confirmed_need_line_id is null)
  ),
  constraint confirmed_need_validation_issues_attempt_fkey foreign key (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id
  ) references atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id
  ) on delete restrict,
  constraint confirmed_need_validation_issues_line_fkey foreign key (
    confirmed_need_validation_line_id,
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    confirmed_need_line_id
  ) references atlas_planning.confirmed_need_validation_lines (
    confirmed_need_validation_line_id,
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    confirmed_need_line_id
  ) on delete restrict
);

alter table atlas_planning.confirmed_need_batches
  add column current_confirmed_need_validation_attempt_id uuid,
  add constraint confirmed_need_batches_current_validation_fkey foreign key (
    current_confirmed_need_validation_attempt_id,
    confirmed_need_batch_id
  ) references atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id
  ) on delete restrict
  deferrable initially deferred;

create index confirmed_need_validation_attempts_batch_history_idx
  on atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_batch_id,
    attempt_number desc
  );
create index confirmed_need_validation_attempts_actor_idx
  on atlas_planning.confirmed_need_validation_attempts (evaluated_by_actor_id);
create index confirmed_need_validation_lines_line_idx
  on atlas_planning.confirmed_need_validation_lines (
    confirmed_need_line_id,
    confirmed_need_validation_attempt_id
  );
create index confirmed_need_validation_lines_revision_idx
  on atlas_planning.confirmed_need_validation_lines (
    current_confirmed_need_line_revision_id
  ) where current_confirmed_need_line_revision_id is not null;
create index confirmed_need_validation_lines_decision_idx
  on atlas_planning.confirmed_need_validation_lines (
    current_confirmed_need_line_decision_id
  ) where current_confirmed_need_line_decision_id is not null;
create index confirmed_need_validation_issues_line_idx
  on atlas_planning.confirmed_need_validation_issues (
    confirmed_need_line_id,
    confirmed_need_validation_attempt_id
  ) where confirmed_need_line_id is not null;
create index confirmed_need_batches_current_validation_idx
  on atlas_planning.confirmed_need_batches (
    current_confirmed_need_validation_attempt_id
  ) where current_confirmed_need_validation_attempt_id is not null;

create function atlas_planning.rmvp_06_immutable_validation_evidence()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Confirmed Need validation evidence is immutable and undeletable';
end;
$$;

create function atlas_planning.rmvp_06_validation_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_attempt_id uuid;
  v_attempt atlas_planning.confirmed_need_validation_attempts%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
begin
  if tg_table_name = 'confirmed_need_batches' then
    if new.current_confirmed_need_validation_attempt_id is null then
      return null;
    end if;
    v_attempt_id := new.current_confirmed_need_validation_attempt_id;
  else
    v_attempt_id := new.confirmed_need_validation_attempt_id;
  end if;

  select * into strict v_attempt
  from atlas_planning.confirmed_need_validation_attempts attempt
  where attempt.confirmed_need_validation_attempt_id = v_attempt_id;

  select * into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_attempt.confirmed_need_batch_id;

  if (select count(*) from atlas_planning.confirmed_need_validation_lines line
      where line.confirmed_need_validation_attempt_id = v_attempt_id)
      <> v_attempt.line_count
  then
    raise exception using errcode = '23514', message = 'Validation line membership is incomplete';
  end if;

  if (select count(*) from atlas_planning.confirmed_need_validation_issues issue
      where issue.confirmed_need_validation_attempt_id = v_attempt_id
        and issue.severity = 'BLOCKING') <> v_attempt.blocking_issue_count
    or (select count(*) from atlas_planning.confirmed_need_validation_issues issue
      where issue.confirmed_need_validation_attempt_id = v_attempt_id
        and issue.severity = 'WARNING') <> v_attempt.warning_count
  then
    raise exception using errcode = '23514', message = 'Validation issue counts are inconsistent';
  end if;

  if v_attempt.outcome = 'VALIDATED' then
    if v_batch.current_confirmed_need_validation_attempt_id is distinct from v_attempt_id
      or v_batch.batch_status <> 'VALIDATED'
      or v_batch.version <> v_attempt.resulting_batch_version
    then
      raise exception using errcode = '23514', message = 'Successful validation pointer is not current';
    end if;

    if exists (
      select 1
      from atlas_planning.confirmed_need_validation_lines observation
      join atlas_admin.units unit
        on unit.unit_id = observation.controlled_unit_id
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_revision_id = observation.current_confirmed_need_line_revision_id
      join atlas_planning.confirmed_need_line_decisions decision
        on decision.confirmed_need_line_decision_id = observation.current_confirmed_need_line_decision_id
      join atlas_planning.planning_quantity_policy_revisions policy_revision
        on policy_revision.planning_quantity_policy_revision_id = observation.planning_quantity_policy_revision_id
      where observation.confirmed_need_validation_attempt_id = v_attempt_id
        and (
          observation.validation_outcome <> 'VALIDATED'
          or unit.unit_status <> 'ACTIVE'
          or not revision.is_current
          or decision.confirmed_need_line_revision_id <> revision.confirmed_need_line_revision_id
          or decision.planning_quantity_policy_revision_id <> policy_revision.planning_quantity_policy_revision_id
          or policy_revision.planning_step * observation.planning_tick_count
            <> observation.confirmed_quantity
          or observation.source_membership_total <> observation.theoretical_quantity
          or observation.observed_source_membership_count <> (
            select count(*)
            from atlas_planning.confirmed_need_line_revision_contributions contribution
            where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
          )
          or observation.source_membership_total <> (
            select sum(contribution.controlled_contribution_quantity)
            from atlas_planning.confirmed_need_line_revision_contributions contribution
            where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
          )
        )
    ) then
      raise exception using errcode = '23514', message = 'Successful validation binding set is incomplete or inexact';
    end if;
  elsif v_batch.current_confirmed_need_validation_attempt_id = v_attempt_id then
    raise exception using errcode = '23514', message = 'Blocked validation cannot be the current successful validation';
  end if;

  return null;
end;
$$;

create trigger confirmed_need_validation_attempts_immutable
before update or delete on atlas_planning.confirmed_need_validation_attempts
for each row execute function atlas_planning.rmvp_06_immutable_validation_evidence();
create trigger confirmed_need_validation_lines_immutable
before update or delete on atlas_planning.confirmed_need_validation_lines
for each row execute function atlas_planning.rmvp_06_immutable_validation_evidence();
create trigger confirmed_need_validation_issues_immutable
before update or delete on atlas_planning.confirmed_need_validation_issues
for each row execute function atlas_planning.rmvp_06_immutable_validation_evidence();

create constraint trigger confirmed_need_validation_attempts_integrity
after insert on atlas_planning.confirmed_need_validation_attempts
deferrable initially deferred
for each row execute function atlas_planning.rmvp_06_validation_integrity();
create constraint trigger confirmed_need_validation_lines_integrity
after insert on atlas_planning.confirmed_need_validation_lines
deferrable initially deferred
for each row execute function atlas_planning.rmvp_06_validation_integrity();
create constraint trigger confirmed_need_validation_issues_integrity
after insert on atlas_planning.confirmed_need_validation_issues
deferrable initially deferred
for each row execute function atlas_planning.rmvp_06_validation_integrity();
create constraint trigger confirmed_need_batches_validation_integrity
after insert or update of current_confirmed_need_validation_attempt_id, batch_status, version
on atlas_planning.confirmed_need_batches
deferrable initially deferred
for each row execute function atlas_planning.rmvp_06_validation_integrity();

alter table atlas_planning.confirmed_need_validation_attempts enable row level security;
alter table atlas_planning.confirmed_need_validation_attempts force row level security;
alter table atlas_planning.confirmed_need_validation_lines enable row level security;
alter table atlas_planning.confirmed_need_validation_lines force row level security;
alter table atlas_planning.confirmed_need_validation_issues enable row level security;
alter table atlas_planning.confirmed_need_validation_issues force row level security;

revoke all on table atlas_planning.confirmed_need_validation_attempts
from public, anon, authenticated, service_role;
revoke all on table atlas_planning.confirmed_need_validation_lines
from public, anon, authenticated, service_role;
revoke all on table atlas_planning.confirmed_need_validation_issues
from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.rmvp_06_immutable_validation_evidence()
from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.rmvp_06_validation_integrity()
from public, anon, authenticated, service_role;

create function atlas_core.rmvp_06_error(
  request jsonb,
  error_code text,
  safe_message text,
  retryable boolean default false,
  field_errors jsonb default '[]'::jsonb,
  blocking_references jsonb default '[]'::jsonb,
  actual_version bigint default null
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-06.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'PLANNING',
    'command_name', 'validate_confirmed_needs',
    'retryable', retryable,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'blocking_references', coalesce(blocking_references, '[]'::jsonb),
    'expected_version', request ->> 'expected_version',
    'actual_version', actual_version,
    'correlation_id', request ->> 'correlation_id',
    'command_id', request ->> 'command_id',
    'write_certainty', 'NO_VALIDATION_EVIDENCE',
    'local_draft_may_be_preserved', true,
    'exact_retry_safe', retryable,
    'refresh_read', 'get_confirmed_need_review'
  ));
$$;

create function atlas_core.rmvp_06_validate_command(request jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_requested_at timestamptz;
  v_reason_note text;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_06_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The validation command must be a JSON object.'
    );
  end if;

  if request - array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ] <> '{}'::jsonb or not (request ?& array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ]) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request',
        'message', 'Provide exactly the RMVP-06 command envelope.'
      )
    );
  end if;

  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
  v_reason_note := case when request -> 'reason_note' = 'null'::jsonb
    then null else request ->> 'reason_note' end;
  if request ->> 'contract_version' is distinct from 'RMVP-06.v1'
    or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
    or coalesce(atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'), 0) < 1
    or nullif(pg_catalog.btrim(request ->> 'idempotency_key'), '') is null
    or pg_catalog.char_length(request ->> 'idempotency_key') > 200
    or v_requested_at is null
    or v_requested_at > pg_catalog.transaction_timestamp()
    or request ->> 'reason_code' is distinct from 'BATCH_VALIDATION_REQUESTED'
    or (
      request -> 'reason_note' <> 'null'::jsonb
      and (
        pg_catalog.jsonb_typeof(request -> 'reason_note') <> 'string'
        or v_reason_note is distinct from pg_catalog.btrim(v_reason_note)
        or pg_catalog.char_length(v_reason_note) not between 1 and 500
      )
    )
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request',
        'message', 'The contract, command identity, version, time, idempotency, or reason is invalid.'
      )
    );
  end if;

  v_payload := request -> 'payload';
  if pg_catalog.jsonb_typeof(v_payload) is distinct from 'object'
    or v_payload - array['confirmed_need_batch_id'] <> '{}'::jsonb
    or not (v_payload ? 'confirmed_need_batch_id')
    or atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id') is null
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'Provide only one valid confirmed_need_batch_id.'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_06_error(
      request,
      'VALIDATION_FAILED',
      'The Confirmed Need validation command is invalid.',
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_06_issue(
  severity text,
  issue_code text,
  safe_operator_message text,
  confirmed_need_line_id uuid,
  issue_sort_position integer
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'severity', severity,
    'issue_code', issue_code,
    'safe_operator_message', safe_operator_message,
    'confirmed_need_line_id', confirmed_need_line_id,
    'issue_sort_position', issue_sort_position
  );
$$;

create function atlas_core.rmvp_06_canonical_evaluation(
  batch_id uuid,
  prior_fingerprint text default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_revision atlas_planning.confirmed_need_line_revisions%rowtype;
  v_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_policy atlas_planning.planning_quantity_policy_revisions%rowtype;
  v_lines jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_line_count integer := 0;
  v_line_sort integer := 0;
  v_issue_sort integer := 0;
  v_revision_count integer;
  v_decision_count integer;
  v_policy_count integer;
  v_membership_count integer;
  v_membership_total numeric(20, 6);
  v_unit_status text;
  v_source_current boolean;
  v_membership_invalid boolean;
  v_source_blocker boolean;
  v_source_warning boolean;
  v_decision_policy_eligible boolean;
  v_blocking_count integer;
  v_warning_count integer;
  v_fingerprint text;
begin
  select * into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = batch_id;

  select count(*)::integer into v_line_count
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = batch_id;

  if v_line_count = 0 then
    v_issue_sort := v_issue_sort + 1;
    v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
      'BLOCKING', 'NO_CURRENT_LINES',
      'The batch has no current Confirmed Need lines to validate.',
      null, v_issue_sort
    ));
  end if;

  if (
    select count(*) <> count(distinct row(
      line.service_date, line.customer_id, line.school_id,
      line.delivery_location_id, line.ingredient_id, line.controlled_unit_id
    ))
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = batch_id
  ) then
    v_issue_sort := v_issue_sort + 1;
    v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
      'BLOCKING', 'CURRENT_LINE_SET_INVALID',
      'The current stable-line set is duplicated or incomplete.',
      null, v_issue_sort
    ));
  end if;

  for v_line in
    select line.*
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = batch_id
    order by line.confirmed_need_line_id
  loop
    v_line_sort := v_line_sort + 1;
    v_revision := null;
    v_decision := null;
    v_policy := null;
    v_membership_count := 0;
    v_membership_total := null;

    select count(*)::integer into v_revision_count
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_line_id = v_line.confirmed_need_line_id
      and revision.is_current;
    if v_revision_count = 1 then
      select * into strict v_revision
      from atlas_planning.confirmed_need_line_revisions revision
      where revision.confirmed_need_line_id = v_line.confirmed_need_line_id
        and revision.is_current;
    elsif v_revision_count = 0 then
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'CURRENT_REVISION_MISSING',
        'The stable line has no exact current quantity revision.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    else
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'CURRENT_REVISION_AMBIGUOUS',
        'The stable line resolves more than one current quantity revision.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    end if;

    select count(*)::integer into v_decision_count
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_line_id = v_line.confirmed_need_line_id
      and decision.confirmed_need_line_decision_id
        = v_line.current_confirmed_need_line_decision_id;
    if v_decision_count = 1 then
      select * into strict v_decision
      from atlas_planning.confirmed_need_line_decisions decision
      where decision.confirmed_need_line_id = v_line.confirmed_need_line_id
        and decision.confirmed_need_line_decision_id
          = v_line.current_confirmed_need_line_decision_id;
    elsif v_decision_count = 0 then
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'CURRENT_DECISION_MISSING',
        'The current stable line has no explicit Planning quantity decision.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    else
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'CURRENT_DECISION_AMBIGUOUS',
        'The current stable line resolves more than one Planning decision.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    end if;

    select count(*)::integer into v_policy_count
    from atlas_planning.planning_quantity_policy_revisions policy
    where policy.unit_id = v_line.controlled_unit_id
      and policy.policy_revision_status in ('ACTIVE', 'RETIRED')
      and policy.effective_from <= v_line.service_date
      and (policy.effective_to is null or v_line.service_date < policy.effective_to);
    if v_policy_count = 1 then
      select * into strict v_policy
      from atlas_planning.planning_quantity_policy_revisions policy
      where policy.unit_id = v_line.controlled_unit_id
        and policy.policy_revision_status in ('ACTIVE', 'RETIRED')
        and policy.effective_from <= v_line.service_date
        and (policy.effective_to is null or v_line.service_date < policy.effective_to);
    elsif v_policy_count = 0 then
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'PLANNING_POLICY_MISSING',
        'No eligible exact-Unit Planning quantity policy exists.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    else
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'PLANNING_POLICY_AMBIGUOUS',
        'More than one eligible exact-Unit Planning quantity policy exists.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    end if;

    select unit.unit_status into strict v_unit_status
    from atlas_admin.units unit
    where unit.unit_id = v_line.controlled_unit_id;
    if v_unit_status <> 'ACTIVE' then
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'CONTROLLED_UNIT_INACTIVE',
        'The controlled Unit is not active.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    end if;

    if v_revision_count = 1 then
      select count(*)::integer, sum(contribution.controlled_contribution_quantity)
      into v_membership_count, v_membership_total
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_line_revision_id
        = v_revision.confirmed_need_line_revision_id;

      v_source_current :=
        v_revision.need_generation_run_id is not distinct from v_batch.current_need_generation_run_id
        and v_revision.need_generation_run_version is not distinct from v_batch.current_need_generation_run_version
        and v_revision.need_generation_release_snapshot_id is not distinct from v_batch.current_need_generation_release_snapshot_id
        and exists (
          select 1
          from atlas_planning.need_generation_runs run
          join atlas_planning.need_generation_release_snapshots release
            on release.need_generation_run_id = run.need_generation_run_id
           and release.released_run_version = run.version
          where run.need_generation_run_id = v_batch.current_need_generation_run_id
            and run.version = v_batch.current_need_generation_run_version
            and run.run_status = 'RELEASED_FOR_CONFIRMATION'
            and release.need_generation_release_snapshot_id
              = v_batch.current_need_generation_release_snapshot_id
        );
      if not v_source_current then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'SOURCE_RELEASE_NOT_CURRENT',
          'The current line no longer binds the exact current released Need Generation source.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;

      v_membership_invalid := v_membership_count = 0 or exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions contribution
        join atlas_planning.need_generation_release_snapshot_lines release_line
          on release_line.need_generation_release_snapshot_line_id
            = contribution.need_generation_release_snapshot_line_id
        join atlas_planning.theoretical_need_lines theoretical
          on theoretical.theoretical_need_line_id = contribution.theoretical_need_line_id
        where contribution.confirmed_need_line_revision_id
          = v_revision.confirmed_need_line_revision_id
          and (
            contribution.confirmed_need_batch_id <> batch_id
            or contribution.confirmed_need_line_id <> v_line.confirmed_need_line_id
            or contribution.need_generation_run_id <> v_revision.need_generation_run_id
            or contribution.need_generation_run_version <> v_revision.need_generation_run_version
            or contribution.need_generation_release_snapshot_id
              <> v_revision.need_generation_release_snapshot_id
            or release_line.need_generation_release_snapshot_id
              <> v_revision.need_generation_release_snapshot_id
            or theoretical.line_disposition <> 'ACTIVE'
            or theoretical.service_date <> v_line.service_date
            or theoretical.school_id <> v_line.school_id
            or theoretical.ingredient_id <> v_line.ingredient_id
            or theoretical.unit_id <> v_line.controlled_unit_id
            or contribution.source_unit_id <> v_line.controlled_unit_id
            or contribution.controlled_unit_id <> v_line.controlled_unit_id
            or contribution.controlled_contribution_quantity
              <> contribution.source_theoretical_quantity
          )
      );
      if v_membership_invalid then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'CONTRIBUTION_MEMBERSHIP_INVALID',
          'The exact revision-owned contribution membership is incomplete or invalid.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;
      if v_membership_count > 0
        and v_membership_total is distinct from v_revision.theoretical_quantity
      then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'THEORETICAL_TOTAL_MISMATCH',
          'The contribution total does not equal the immutable theoretical quantity.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;

      select exists (
        select 1
        from atlas_planning.need_generation_release_snapshot_issues member
        join atlas_planning.need_generation_issues issue
          on issue.need_generation_issue_id = member.need_generation_issue_id
        where member.need_generation_release_snapshot_id
          = v_revision.need_generation_release_snapshot_id
          and issue.severity = 'BLOCKING'
          and (
            issue.theoretical_need_line_id is null
            or exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions contribution
              where contribution.confirmed_need_line_revision_id
                = v_revision.confirmed_need_line_revision_id
                and contribution.theoretical_need_line_id
                  = issue.theoretical_need_line_id
            )
          )
      ), exists (
        select 1
        from atlas_planning.need_generation_release_snapshot_issues member
        join atlas_planning.need_generation_issues issue
          on issue.need_generation_issue_id = member.need_generation_issue_id
        where member.need_generation_release_snapshot_id
          = v_revision.need_generation_release_snapshot_id
          and issue.severity = 'WARNING'
          and (
            issue.theoretical_need_line_id is null
            or exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions contribution
              where contribution.confirmed_need_line_revision_id
                = v_revision.confirmed_need_line_revision_id
                and contribution.theoretical_need_line_id
                  = issue.theoretical_need_line_id
            )
          )
      ) into v_source_blocker, v_source_warning;
      if v_source_blocker then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'SOURCE_BLOCKER_PRESENT',
          'The exact released upstream evidence retains a governed blocker.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;
      if v_source_warning then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'WARNING', 'UPSTREAM_WARNING_RETAINED',
          'The exact released upstream evidence retains a governed warning.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;
    end if;

    if v_revision_count = 1 and v_decision_count = 1
      and v_decision.confirmed_need_line_revision_id
        is distinct from v_revision.confirmed_need_line_revision_id
    then
      v_issue_sort := v_issue_sort + 1;
      v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
        'BLOCKING', 'DECISION_REVISION_MISMATCH',
        'The current Planning decision does not bind the exact current revision.',
        v_line.confirmed_need_line_id, v_issue_sort
      ));
    end if;

    if v_decision_count = 1 then
      select exists (
        select 1
        from atlas_planning.planning_quantity_policy_revisions policy
        where policy.planning_quantity_policy_revision_id
          = v_decision.planning_quantity_policy_revision_id
          and policy.planning_quantity_policy_id
            = v_decision.planning_quantity_policy_id
          and policy.unit_id = v_line.controlled_unit_id
          and policy.policy_revision_status in ('ACTIVE', 'RETIRED')
          and policy.effective_from <= v_line.service_date
          and (policy.effective_to is null or v_line.service_date < policy.effective_to)
      ) into v_decision_policy_eligible;
      if not v_decision_policy_eligible then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'PLANNING_POLICY_NOT_ELIGIBLE',
          'The decision-bound Planning policy is not eligible for this Unit and service date.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;

      if v_policy_count = 1 and (
        v_decision.planning_quantity_policy_id
          is distinct from v_policy.planning_quantity_policy_id
        or v_decision.planning_quantity_policy_revision_id
          is distinct from v_policy.planning_quantity_policy_revision_id
        or v_decision.planning_tick_count * v_policy.planning_step
          is distinct from v_decision.confirmed_quantity_after
      ) then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'DECISION_POLICY_MISMATCH',
          'The current decision does not bind the exact eligible policy and Planning step.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;

      if v_decision.confirmed_quantity_after < 0
        or v_decision.planning_tick_count < 0
        or (v_policy_count = 1 and (
          pg_catalog.mod(v_decision.confirmed_quantity_after, v_policy.planning_step) <> 0
          or v_decision.planning_tick_count * v_policy.planning_step
            <> v_decision.confirmed_quantity_after
        ))
      then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'CONFIRMED_QUANTITY_INVALID',
          'The confirmed quantity is invalid or not exactly representable by the decision-bound Planning step.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      elsif v_decision.confirmed_quantity_after = 0 then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'WARNING', 'ZERO_CONFIRMED_QUANTITY',
          'The reviewed confirmed quantity is exactly zero.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;

      if (
        v_decision.decision_kind = 'UNCHANGED_PROPOSAL_ACCEPTED'
        and (
          v_decision.reason_code <> 'PROPOSAL_ACCEPTED'
          or (v_decision.predecessor_decision_id is null and v_decision.reason_note is not null)
        )
      ) or (
        v_decision.decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
        and (
          v_decision.reason_code not in (
            'PLANNING_STEP_ADJUSTMENT',
            'OPERATIONAL_QUANTITY_ADJUSTMENT',
            'OTHER'
          )
          or (
            v_decision.reason_code in ('OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER')
            and v_decision.reason_note is null
          )
        )
      ) or (
        v_decision.predecessor_decision_id is not null
        and v_decision.reason_note is null
      ) then
        v_issue_sort := v_issue_sort + 1;
        v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
          'BLOCKING', 'ADJUSTMENT_REASON_INCOMPLETE',
          'The current Planning decision has incomplete adjustment or correction reason evidence.',
          v_line.confirmed_need_line_id, v_issue_sort
        ));
      end if;
    end if;

    v_lines := v_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'confirmed_need_line_id', v_line.confirmed_need_line_id,
        'controlled_unit_id', v_line.controlled_unit_id,
        'observed_current_revision_count', v_revision_count,
        'observed_current_decision_count', v_decision_count,
        'observed_eligible_policy_count', v_policy_count,
        'observed_source_membership_count', v_membership_count,
        'line_sort_position', v_line_sort,
        'current_confirmed_need_line_revision_id',
          case when v_revision_count = 1 then v_revision.confirmed_need_line_revision_id else null end,
        'current_confirmed_need_line_decision_id',
          case when v_decision_count = 1 then v_decision.confirmed_need_line_decision_id else null end,
        'planning_quantity_policy_id',
          case when v_policy_count = 1 then v_policy.planning_quantity_policy_id else null end,
        'planning_quantity_policy_revision_id',
          case when v_policy_count = 1 then v_policy.planning_quantity_policy_revision_id else null end,
        'need_generation_run_id',
          case when v_revision_count = 1 then v_revision.need_generation_run_id else null end,
        'need_generation_run_version',
          case when v_revision_count = 1 then v_revision.need_generation_run_version else null end,
        'need_generation_release_snapshot_id',
          case when v_revision_count = 1 then v_revision.need_generation_release_snapshot_id else null end,
        'theoretical_quantity',
          case when v_revision_count = 1 then v_revision.theoretical_quantity::text else null end,
        'confirmed_quantity',
          case when v_decision_count = 1 then v_decision.confirmed_quantity_after::text else null end,
        'planning_tick_count',
          case when v_decision_count = 1 then v_decision.planning_tick_count::text else null end,
        'source_membership_total',
          case when v_revision_count = 1 then v_membership_total::text else null end
      )
    );
  end loop;

  with ranked as (
    select item,
      row_number() over (order by
        case when item ->> 'severity' = 'BLOCKING' then 0 else 1 end,
        pg_catalog.array_position(array[
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
        ]::text[], item ->> 'issue_code'),
        item ->> 'confirmed_need_line_id' nulls first
      )::integer as canonical_position
    from pg_catalog.jsonb_array_elements(v_issues) item
  )
  select coalesce(pg_catalog.jsonb_agg(
    (item - 'issue_sort_position') || pg_catalog.jsonb_build_object(
      'issue_sort_position', canonical_position
    ) order by canonical_position
  ), '[]'::jsonb)
  into v_issues
  from ranked;
  v_issue_sort := pg_catalog.jsonb_array_length(v_issues);

  v_fingerprint := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-06.v1',
      'confirmed_need_batch_id', batch_id,
      'evaluated_batch_version', v_batch.version,
      'prior_batch_status', v_batch.batch_status,
      'ordered_lines', v_lines,
      'ordered_issues', v_issues
    )::text,
    'UTF8'
  )), 'hex');

  if prior_fingerprint is not null and v_fingerprint is distinct from prior_fingerprint then
    v_issue_sort := v_issue_sort + 1;
    v_issues := v_issues || pg_catalog.jsonb_build_array(atlas_core.rmvp_06_issue(
      'BLOCKING', 'CURRENT_FACTS_CHANGED',
      'A critical current fact changed while the authoritative validation locks were acquired.',
      null, v_issue_sort
    ));
    with ranked as (
      select item,
        row_number() over (order by
          case when item ->> 'severity' = 'BLOCKING' then 0 else 1 end,
          pg_catalog.array_position(array[
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
          ]::text[], item ->> 'issue_code'),
          item ->> 'confirmed_need_line_id' nulls first
        )::integer as canonical_position
      from pg_catalog.jsonb_array_elements(v_issues) item
    )
    select pg_catalog.jsonb_agg(
      (item - 'issue_sort_position') || pg_catalog.jsonb_build_object(
        'issue_sort_position', canonical_position
      ) order by canonical_position
    )
    into v_issues
    from ranked;
    v_fingerprint := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'contract_version', 'RMVP-06.v1',
        'confirmed_need_batch_id', batch_id,
        'evaluated_batch_version', v_batch.version,
        'prior_batch_status', v_batch.batch_status,
        'ordered_lines', v_lines,
        'ordered_issues', v_issues
      )::text,
      'UTF8'
    )), 'hex');
  end if;

  select count(*) filter (where item ->> 'severity' = 'BLOCKING')::integer,
    count(*) filter (where item ->> 'severity' = 'WARNING')::integer
  into v_blocking_count, v_warning_count
  from pg_catalog.jsonb_array_elements(v_issues) item;

  return pg_catalog.jsonb_build_object(
    'outcome', case when v_blocking_count = 0 then 'VALIDATED' else 'BLOCKED' end,
    'line_count', v_line_count,
    'blocking_issue_count', v_blocking_count,
    'warning_count', v_warning_count,
    'validation_fingerprint', v_fingerprint,
    'ordered_lines', v_lines,
    'ordered_issues', v_issues
  );
end;
$$;

create function atlas_core.rmvp_06_extend_workbench(workbench jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    workbench ->> 'confirmed_need_batch_id'
  );
  v_batch_status text := workbench ->> 'batch_status';
  v_attempt atlas_planning.confirmed_need_validation_attempts%rowtype;
  v_actor_name text;
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_lines jsonb;
  v_validation_allowed boolean;
  v_disabled_reason text;
begin
  select attempt.*
  into v_attempt
  from atlas_planning.confirmed_need_validation_attempts attempt
  where attempt.confirmed_need_batch_id = v_batch_id
  order by attempt.attempt_number desc
  limit 1;

  if found then
    select actor.display_name
    into v_actor_name
    from atlas_core.actors actor
    where actor.actor_id = v_attempt.evaluated_by_actor_id;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'issue_id', issue.confirmed_need_validation_issue_id,
      'validation_line_id', issue.confirmed_need_validation_line_id,
      'confirmed_need_line_id', issue.confirmed_need_line_id,
      'severity', issue.severity,
      'code', issue.issue_code,
      'message', issue.safe_operator_message,
      'sort_position', issue.issue_sort_position
    ) order by issue.issue_sort_position), '[]'::jsonb)
    into v_blockers
    from atlas_planning.confirmed_need_validation_issues issue
    where issue.confirmed_need_validation_attempt_id
      = v_attempt.confirmed_need_validation_attempt_id
      and issue.severity = 'BLOCKING';

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'issue_id', issue.confirmed_need_validation_issue_id,
      'validation_line_id', issue.confirmed_need_validation_line_id,
      'confirmed_need_line_id', issue.confirmed_need_line_id,
      'severity', issue.severity,
      'code', issue.issue_code,
      'message', issue.safe_operator_message,
      'sort_position', issue.issue_sort_position
    ) order by issue.issue_sort_position), '[]'::jsonb)
    into v_warnings
    from atlas_planning.confirmed_need_validation_issues issue
    where issue.confirmed_need_validation_attempt_id
      = v_attempt.confirmed_need_validation_attempt_id
      and issue.severity = 'WARNING';
  end if;

  select coalesce(pg_catalog.jsonb_agg(
    page.line || pg_catalog.jsonb_build_object(
      'validation_issues', pg_catalog.jsonb_build_object(
        'blocking', case when v_attempt.confirmed_need_validation_attempt_id is null
          then '[]'::jsonb else coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
              'issue_id', issue.confirmed_need_validation_issue_id,
              'severity', issue.severity,
              'code', issue.issue_code,
              'message', issue.safe_operator_message,
              'sort_position', issue.issue_sort_position
            ) order by issue.issue_sort_position)
            from atlas_planning.confirmed_need_validation_issues issue
            where issue.confirmed_need_validation_attempt_id
              = v_attempt.confirmed_need_validation_attempt_id
              and issue.confirmed_need_line_id::text
                = page.line ->> 'confirmed_need_line_id'
              and issue.severity = 'BLOCKING'
          ), '[]'::jsonb) end,
        'warnings', case when v_attempt.confirmed_need_validation_attempt_id is null
          then '[]'::jsonb else coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
              'issue_id', issue.confirmed_need_validation_issue_id,
              'severity', issue.severity,
              'code', issue.issue_code,
              'message', issue.safe_operator_message,
              'sort_position', issue.issue_sort_position
            ) order by issue.issue_sort_position)
            from atlas_planning.confirmed_need_validation_issues issue
            where issue.confirmed_need_validation_attempt_id
              = v_attempt.confirmed_need_validation_attempt_id
              and issue.confirmed_need_line_id::text
                = page.line ->> 'confirmed_need_line_id'
              and issue.severity = 'WARNING'
          ), '[]'::jsonb) end
      )
    ) order by page.ordinality), '[]'::jsonb)
  into v_lines
  from pg_catalog.jsonb_array_elements(workbench -> 'lines')
    with ordinality as page(line, ordinality);

  v_validation_allowed := v_batch_status in ('DRAFT_REVIEW', 'REOPENED');
  v_disabled_reason := case
    when v_validation_allowed then null
    when v_batch_status = 'VALIDATED' then 'Lô đã được kiểm tra; chờ phê duyệt.'
    else 'Lô không ở trạng thái có thể kiểm tra.'
  end;

  return workbench
    || pg_catalog.jsonb_build_object(
      'lines', v_lines,
      'authoritative_batch_status', v_batch_status,
      'editing_allowed', v_batch_status in ('DRAFT_REVIEW', 'REOPENED'),
      'validation_allowed', v_validation_allowed,
      'validation_disabled_reason', v_disabled_reason,
      'validation', case
        when v_attempt.confirmed_need_validation_attempt_id is null then
          pg_catalog.jsonb_build_object(
            'latest_attempt_id', null,
            'latest_attempt_number', null,
            'latest_outcome', null,
            'evaluated_version', null,
            'resulting_version', null,
            'evaluated_actor', null,
            'evaluated_at', null,
            'validated_actor', null,
            'validated_at', null,
            'validation_fingerprint', null,
            'blocking_count', 0,
            'warning_count', 0,
            'grouped_issues', pg_catalog.jsonb_build_object(
              'blocking', '[]'::jsonb,
              'warnings', '[]'::jsonb
            )
          )
        else pg_catalog.jsonb_build_object(
          'latest_attempt_id', v_attempt.confirmed_need_validation_attempt_id,
          'latest_attempt_number', v_attempt.attempt_number,
          'latest_outcome', v_attempt.outcome,
          'evaluated_version', v_attempt.evaluated_batch_version,
          'resulting_version', v_attempt.resulting_batch_version,
          'evaluated_actor', pg_catalog.jsonb_build_object(
            'id', v_attempt.evaluated_by_actor_id,
            'name', v_actor_name
          ),
          'evaluated_at', v_attempt.evaluated_at,
          'validated_actor', case when v_attempt.outcome = 'VALIDATED'
            then pg_catalog.jsonb_build_object(
              'id', v_attempt.evaluated_by_actor_id,
              'name', v_actor_name
            ) else null end,
          'validated_at', case when v_attempt.outcome = 'VALIDATED'
            then v_attempt.evaluated_at else null end,
          'validation_fingerprint', v_attempt.validation_fingerprint,
          'blocking_count', v_attempt.blocking_issue_count,
          'warning_count', v_attempt.warning_count,
          'grouped_issues', pg_catalog.jsonb_build_object(
            'blocking', v_blockers,
            'warnings', v_warnings
          )
        ) end
    );
end;
$$;

create function atlas_core.rmvp_06_record_change(
  request jsonb,
  actor_id uuid,
  receipt_id uuid,
  batch_id uuid,
  version_before bigint,
  version_after bigint,
  event_type text,
  before_summary jsonb,
  after_summary jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_audit_id uuid;
begin
  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version, command_receipt_id, command_id, correlation_id,
    actor_id, occurred_at, payload_summary
  ) values (
    event_type, 'PLANNING', 'ConfirmedNeedBatch', batch_id,
    version_after, receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id, pg_catalog.transaction_timestamp(), after_summary
  ) returning domain_event_id into v_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_before, aggregate_version_after,
    command_receipt_id, command_id, correlation_id, actor_id,
    reason_code, reason_note, before_summary, after_summary,
    source_interface, occurred_at
  ) values (
    event_type, 'PLANNING', 'ConfirmedNeedBatch', batch_id,
    version_before, version_after, receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id, request ->> 'reason_code',
    case when request -> 'reason_note' = 'null'::jsonb
      then null else request ->> 'reason_note' end,
    before_summary, after_summary, 'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_id;

  return pg_catalog.jsonb_build_object(
    'domain_event_id', v_event_id,
    'audit_event_id', v_audit_id
  );
end;
$$;

create function atlas_api.validate_confirmed_needs(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'validate_confirmed_needs';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_payload jsonb := request -> 'payload';
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'confirmed_need_batch_id'
  );
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_prelock_evaluation jsonb;
  v_evaluation jsonb;
  v_attempt_id uuid := gen_random_uuid();
  v_attempt_number bigint;
  v_outcome text;
  v_resulting_version bigint;
  v_resulting_status text;
  v_item jsonb;
  v_validation_line_id uuid;
  v_events jsonb;
  v_before_summary jsonb;
  v_after_summary jsonb;
  v_response jsonb;
  v_event_type text;
  v_unit_id uuid;
  v_policy_id uuid;
  v_policy_revision_id uuid;
begin
  v_error := atlas_core.rmvp_06_validate_command(request);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_05_authorize_global(
    request,
    'confirmed_need_validation.validate',
    v_name,
    false
  );
  if v_context ? 'error' then
    return (v_context -> 'error') || pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-06.v1',
      'command_name', v_name,
      'write_certainty', 'NO_VALIDATION_EVIDENCE'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_name,
    'PLANNING',
    'ConfirmedNeedBatch:' || v_batch_id::text
  );
  if v_begin ->> 'status' <> 'NEW' then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select * into v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id
  for update;
  if not found then
    v_error := atlas_core.rmvp_06_error(
      request,
      'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'The requested Confirmed Need batch was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.source_kind <> 'NEED_GENERATION' then
    v_error := atlas_core.rmvp_06_error(
      request,
      'UNSUPPORTED_CONFIRMED_NEED_SOURCE',
      'Complete-batch validation currently supports NEED_GENERATION batches only.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then
    v_error := atlas_core.rmvp_06_error(
      request,
      'CONFIRMED_NEED_BATCH_NOT_VALIDATABLE',
      'The batch is not in a working lifecycle state that can be validated.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.rmvp_06_error(
      request,
      'STALE_CONFIRMED_NEED_BATCH',
      'The Confirmed Need batch version changed. Refresh before validating.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  perform line.confirmed_need_line_id
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = v_batch_id
  order by line.confirmed_need_line_id
  for update;

  v_prelock_evaluation := atlas_core.rmvp_06_canonical_evaluation(v_batch_id);

  for v_unit_id in
    select distinct line.controlled_unit_id
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
    order by line.controlled_unit_id
  loop
    perform unit.unit_id
    from atlas_admin.units unit
    where unit.unit_id = v_unit_id
    for share;
  end loop;

  for v_policy_id in
    select distinct policy.planning_quantity_policy_id
    from atlas_planning.planning_quantity_policies policy
    join atlas_planning.confirmed_need_lines line on line.controlled_unit_id = policy.unit_id
    where line.confirmed_need_batch_id = v_batch_id
    order by policy.planning_quantity_policy_id
  loop
    perform policy.planning_quantity_policy_id
    from atlas_planning.planning_quantity_policies policy
    where policy.planning_quantity_policy_id = v_policy_id
    for share;
  end loop;

  for v_policy_revision_id in
    select distinct policy_revision.planning_quantity_policy_revision_id
    from atlas_planning.planning_quantity_policy_revisions policy_revision
    join atlas_planning.confirmed_need_lines line
      on line.controlled_unit_id = policy_revision.unit_id
    where line.confirmed_need_batch_id = v_batch_id
    order by policy_revision.planning_quantity_policy_revision_id
  loop
    perform policy_revision.planning_quantity_policy_revision_id
    from atlas_planning.planning_quantity_policy_revisions policy_revision
    where policy_revision.planning_quantity_policy_revision_id = v_policy_revision_id
    for share;
  end loop;

  perform run.need_generation_run_id
  from atlas_planning.need_generation_runs run
  where run.need_generation_run_id = v_batch.current_need_generation_run_id
  for share;

  perform release.need_generation_release_snapshot_id
  from atlas_planning.need_generation_release_snapshots release
  where release.need_generation_release_snapshot_id
    = v_batch.current_need_generation_release_snapshot_id
  for share;

  perform member.need_generation_release_snapshot_line_id
  from atlas_planning.need_generation_release_snapshot_lines member
  where member.need_generation_release_snapshot_id
    = v_batch.current_need_generation_release_snapshot_id
  order by member.need_generation_release_snapshot_line_id
  for share;

  v_evaluation := atlas_core.rmvp_06_canonical_evaluation(
    v_batch_id,
    v_prelock_evaluation ->> 'validation_fingerprint'
  );
  v_outcome := v_evaluation ->> 'outcome';
  v_resulting_version := case when v_outcome = 'VALIDATED'
    then v_batch.version + 1 else v_batch.version end;
  v_resulting_status := case when v_outcome = 'VALIDATED'
    then 'VALIDATED' else v_batch.batch_status end;

  select coalesce(max(attempt.attempt_number), 0) + 1
  into v_attempt_number
  from atlas_planning.confirmed_need_validation_attempts attempt
  where attempt.confirmed_need_batch_id = v_batch_id;

  insert into atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    attempt_number,
    source_kind,
    evaluated_batch_version,
    resulting_batch_version,
    prior_batch_status,
    resulting_batch_status,
    outcome,
    line_count,
    blocking_issue_count,
    warning_count,
    validation_fingerprint,
    evaluated_by_actor_id,
    evaluated_at,
    command_id,
    correlation_id,
    reason_code,
    reason_note
  ) values (
    v_attempt_id,
    v_batch_id,
    v_attempt_number,
    v_batch.source_kind,
    v_batch.version,
    v_resulting_version,
    v_batch.batch_status,
    v_resulting_status,
    v_outcome,
    (v_evaluation ->> 'line_count')::integer,
    (v_evaluation ->> 'blocking_issue_count')::integer,
    (v_evaluation ->> 'warning_count')::integer,
    v_evaluation ->> 'validation_fingerprint',
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    request ->> 'reason_code',
    case when request -> 'reason_note' = 'null'::jsonb
      then null else request ->> 'reason_note' end
  );

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(v_evaluation -> 'ordered_lines')
    order by (value ->> 'line_sort_position')::integer
  loop
    insert into atlas_planning.confirmed_need_validation_lines (
      confirmed_need_validation_attempt_id,
      confirmed_need_batch_id,
      confirmed_need_line_id,
      validation_outcome,
      controlled_unit_id,
      observed_current_revision_count,
      observed_current_decision_count,
      observed_eligible_policy_count,
      observed_source_membership_count,
      line_sort_position,
      current_confirmed_need_line_revision_id,
      current_confirmed_need_line_decision_id,
      planning_quantity_policy_id,
      planning_quantity_policy_revision_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      theoretical_quantity,
      confirmed_quantity,
      planning_tick_count,
      source_membership_total
    ) values (
      v_attempt_id,
      v_batch_id,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id'),
      v_outcome,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'controlled_unit_id'),
      (v_item ->> 'observed_current_revision_count')::integer,
      (v_item ->> 'observed_current_decision_count')::integer,
      (v_item ->> 'observed_eligible_policy_count')::integer,
      (v_item ->> 'observed_source_membership_count')::integer,
      (v_item ->> 'line_sort_position')::integer,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'current_confirmed_need_line_revision_id'),
      atlas_core.pa_05b_safe_uuid(v_item ->> 'current_confirmed_need_line_decision_id'),
      atlas_core.pa_05b_safe_uuid(v_item ->> 'planning_quantity_policy_id'),
      atlas_core.pa_05b_safe_uuid(v_item ->> 'planning_quantity_policy_revision_id'),
      atlas_core.pa_05b_safe_uuid(v_item ->> 'need_generation_run_id'),
      nullif(v_item ->> 'need_generation_run_version', '')::bigint,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'need_generation_release_snapshot_id'),
      nullif(v_item ->> 'theoretical_quantity', '')::numeric(20, 6),
      nullif(v_item ->> 'confirmed_quantity', '')::numeric(20, 6),
      nullif(v_item ->> 'planning_tick_count', '')::numeric(20, 0),
      nullif(v_item ->> 'source_membership_total', '')::numeric(20, 6)
    );
  end loop;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(v_evaluation -> 'ordered_issues')
    order by (value ->> 'issue_sort_position')::integer
  loop
    v_validation_line_id := null;
    if v_item ->> 'confirmed_need_line_id' is not null then
      select line.confirmed_need_validation_line_id into strict v_validation_line_id
      from atlas_planning.confirmed_need_validation_lines line
      where line.confirmed_need_validation_attempt_id = v_attempt_id
        and line.confirmed_need_line_id
          = atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id');
    end if;
    insert into atlas_planning.confirmed_need_validation_issues (
      confirmed_need_validation_attempt_id,
      confirmed_need_validation_line_id,
      confirmed_need_batch_id,
      confirmed_need_line_id,
      severity,
      issue_code,
      safe_operator_message,
      issue_sort_position
    ) values (
      v_attempt_id,
      v_validation_line_id,
      v_batch_id,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id'),
      v_item ->> 'severity',
      v_item ->> 'issue_code',
      v_item ->> 'safe_operator_message',
      (v_item ->> 'issue_sort_position')::integer
    );
  end loop;

  if v_outcome = 'VALIDATED' then
    update atlas_planning.confirmed_need_batches
    set batch_status = 'VALIDATED',
        version = v_resulting_version,
        current_confirmed_need_validation_attempt_id = v_attempt_id,
        updated_at = pg_catalog.transaction_timestamp()
    where confirmed_need_batch_id = v_batch_id;
    v_event_type := 'ConfirmedNeedsValidated';
  else
    v_event_type := 'ConfirmedNeedValidationFailed';
  end if;

  v_before_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', v_batch.source_kind,
    'batch_status', v_batch.batch_status,
    'batch_version', v_batch.version
  );
  v_after_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', v_batch.source_kind,
    'prior_status', v_batch.batch_status,
    'resulting_status', v_resulting_status,
    'prior_version', v_batch.version,
    'resulting_version', v_resulting_version,
    'validation_attempt_id', v_attempt_id,
    'validation_fingerprint', v_evaluation ->> 'validation_fingerprint',
    'line_count', (v_evaluation ->> 'line_count')::integer,
    'blocking_issue_count', (v_evaluation ->> 'blocking_issue_count')::integer,
    'warning_count', (v_evaluation ->> 'warning_count')::integer,
    'stable_line_ids', (
      select coalesce(pg_catalog.jsonb_agg(item -> 'confirmed_need_line_id'
        order by (item ->> 'line_sort_position')::integer), '[]'::jsonb)
      from (
        select value as item
        from pg_catalog.jsonb_array_elements(v_evaluation -> 'ordered_lines')
        order by (value ->> 'line_sort_position')::integer
        limit 100
      ) bounded
    ),
    'ordered_issue_codes', case when v_outcome = 'BLOCKED' then (
      select coalesce(pg_catalog.jsonb_agg(item -> 'issue_code'
        order by (item ->> 'issue_sort_position')::integer), '[]'::jsonb)
      from (
        select value as item
        from pg_catalog.jsonb_array_elements(v_evaluation -> 'ordered_issues')
        order by (value ->> 'issue_sort_position')::integer
        limit 100
      ) bounded
    ) else '[]'::jsonb end,
    'actor_id', v_actor_id,
    'command_id', request -> 'command_id',
    'correlation_id', request -> 'correlation_id',
    'reason_code', request ->> 'reason_code',
    'evaluated_at', pg_catalog.transaction_timestamp()
  );

  v_events := atlas_core.rmvp_06_record_change(
    request,
    v_actor_id,
    v_receipt_id,
    v_batch_id,
    v_batch.version,
    v_resulting_version,
    v_event_type,
    v_before_summary,
    v_after_summary
  );

  set constraints all immediate;
  set constraints all deferred;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-06.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'validation_status', v_outcome,
    'confirmed_need_batch_id', v_batch_id,
    'validation_attempt_id', v_attempt_id,
    'validation_attempt_number', v_attempt_number,
    'evaluated_batch_version', v_batch.version,
    'resulting_batch_version', v_resulting_version,
    'prior_batch_status', v_batch.batch_status,
    'resulting_batch_status', v_resulting_status,
    'validation_fingerprint', v_evaluation ->> 'validation_fingerprint',
    'line_count', (v_evaluation ->> 'line_count')::integer,
    'blocking_issue_count', (v_evaluation ->> 'blocking_issue_count')::integer,
    'warning_count', (v_evaluation ->> 'warning_count')::integer,
    'receipt_id', v_receipt_id,
    'event_id', v_events -> 'domain_event_id',
    'audit_id', v_events -> 'audit_event_id',
    'safe_operator_message', case when v_outcome = 'VALIDATED'
      then 'The complete Confirmed Need batch was validated and is awaiting approval.'
      else 'The complete validation finished with business issues that require attention.'
    end,
    'authoritative_readback', atlas_core.rmvp_06_extend_workbench(
      atlas_core.rmvp_05_workbench_payload(v_batch_id, '{}'::jsonb, 0, 100)
    )
  );

  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception when others then
  return atlas_core.rmvp_06_error(
    request,
    'INTERNAL_COMMAND_FAILURE',
    'The validation was not committed. Refresh before trying again.',
    false
  );
end;
$$;

reset role;

grant select on
  atlas_planning.confirmed_need_validation_attempts,
  atlas_planning.confirmed_need_validation_lines,
  atlas_planning.confirmed_need_validation_issues,
  atlas_planning.need_generation_issues,
  atlas_planning.need_generation_release_snapshot_issues
to atlas_confirmed_need_review_runtime;

grant insert on
  atlas_planning.confirmed_need_validation_attempts,
  atlas_planning.confirmed_need_validation_lines,
  atlas_planning.confirmed_need_validation_issues
to atlas_confirmed_need_review_runtime;

grant update (
  batch_status,
  version,
  current_confirmed_need_validation_attempt_id,
  updated_at
) on atlas_planning.confirmed_need_batches
to atlas_confirmed_need_review_runtime;

grant update (planning_quantity_policy_revision_id)
on atlas_planning.planning_quantity_policy_revisions
to atlas_confirmed_need_review_runtime;
grant update (need_generation_run_id)
on atlas_planning.need_generation_runs
to atlas_confirmed_need_review_runtime;
grant update (need_generation_release_snapshot_id)
on atlas_planning.need_generation_release_snapshots
to atlas_confirmed_need_review_runtime;
grant update (need_generation_release_snapshot_line_id)
on atlas_planning.need_generation_release_snapshot_lines
to atlas_confirmed_need_review_runtime;

create policy rmvp_06_validation_attempt_select
on atlas_planning.confirmed_need_validation_attempts
for select to atlas_confirmed_need_review_runtime using (true);
create policy rmvp_06_validation_attempt_insert
on atlas_planning.confirmed_need_validation_attempts
for insert to atlas_confirmed_need_review_runtime
with check (source_kind = 'NEED_GENERATION');
create policy rmvp_06_validation_line_select
on atlas_planning.confirmed_need_validation_lines
for select to atlas_confirmed_need_review_runtime using (true);
create policy rmvp_06_validation_line_insert
on atlas_planning.confirmed_need_validation_lines
for insert to atlas_confirmed_need_review_runtime
with check (true);
create policy rmvp_06_validation_issue_select
on atlas_planning.confirmed_need_validation_issues
for select to atlas_confirmed_need_review_runtime using (true);
create policy rmvp_06_validation_issue_insert
on atlas_planning.confirmed_need_validation_issues
for insert to atlas_confirmed_need_review_runtime
with check (true);

create policy rmvp_06_need_generation_issue_select
on atlas_planning.need_generation_issues
for select to atlas_confirmed_need_review_runtime using (true);
create policy rmvp_06_need_generation_release_issue_select
on atlas_planning.need_generation_release_snapshot_issues
for select to atlas_confirmed_need_review_runtime using (true);

create policy rmvp_06_policy_revision_lock
on atlas_planning.planning_quantity_policy_revisions
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);
create policy rmvp_06_need_generation_run_lock
on atlas_planning.need_generation_runs
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);
create policy rmvp_06_need_generation_release_lock
on atlas_planning.need_generation_release_snapshots
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);
create policy rmvp_06_need_generation_release_line_lock
on atlas_planning.need_generation_release_snapshot_lines
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);

revoke execute on function
  atlas_core.rmvp_06_error(jsonb, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.rmvp_06_validate_command(jsonb),
  atlas_core.rmvp_06_issue(text, text, text, uuid, integer),
  atlas_core.rmvp_06_canonical_evaluation(uuid, text),
  atlas_core.rmvp_06_extend_workbench(jsonb),
  atlas_core.rmvp_06_record_change(jsonb, uuid, uuid, uuid, bigint, bigint, text, jsonb, jsonb)
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.rmvp_06_error(jsonb, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.rmvp_06_validate_command(jsonb),
  atlas_core.rmvp_06_issue(text, text, text, uuid, integer),
  atlas_core.rmvp_06_canonical_evaluation(uuid, text),
  atlas_core.rmvp_06_extend_workbench(jsonb),
  atlas_core.rmvp_06_record_change(jsonb, uuid, uuid, uuid, bigint, bigint, text, jsonb, jsonb),
  atlas_planning.rmvp_06_immutable_validation_evidence(),
  atlas_planning.rmvp_06_validation_integrity()
to atlas_confirmed_need_review_runtime;

grant atlas_confirmed_need_review_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_confirmed_need_review_runtime;

alter function atlas_core.rmvp_06_error(jsonb, text, text, boolean, jsonb, jsonb, bigint)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_06_validate_command(jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_06_issue(text, text, text, uuid, integer)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_06_canonical_evaluation(uuid, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_06_extend_workbench(jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_06_record_change(jsonb, uuid, uuid, uuid, bigint, bigint, text, jsonb, jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_api.validate_confirmed_needs(jsonb)
  owner to atlas_confirmed_need_review_runtime;

set role atlas_confirmed_need_review_runtime;

create or replace function atlas_api.get_confirmed_need_review(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_confirmed_need_review';
  v_error jsonb;
  v_context jsonb;
  v_payload jsonb := request -> 'payload';
  v_workbench jsonb;
begin
  v_error := atlas_core.rmvp_05_validate_read(request, v_name);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_05_authorize_global(
    request, 'confirmed_need_review.read', v_name, true
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  v_workbench := atlas_core.rmvp_05_workbench_payload(
    atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id'),
    coalesce(v_payload -> 'filters', '{}'::jsonb),
    coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'line_offset')::integer, 0),
    coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'line_limit')::integer, 100)
  );
  if v_workbench is null then
    return atlas_core.rmvp_05_error(
      request, v_name, 'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'The requested Confirmed Need batch was not found.', true
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-05.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench', atlas_core.rmvp_06_extend_workbench(v_workbench)
  );
exception when others then
  return atlas_core.rmvp_05_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'The Confirmed Need review could not be returned safely.', true
  );
end;
$$;

reset role;

revoke create on schema atlas_core, atlas_api
from atlas_confirmed_need_review_runtime;

revoke execute on function atlas_api.validate_confirmed_needs(jsonb)
from public, anon, authenticated, service_role;
grant usage on schema atlas_api to authenticated;
grant execute on function atlas_api.validate_confirmed_needs(jsonb)
to authenticated;

comment on function atlas_api.validate_confirmed_needs(jsonb) is
  'RMVP-06.v1 idempotent complete-batch NEED_GENERATION Confirmed Need validation with immutable VALIDATED or BLOCKED evidence.';

revoke atlas_confirmed_need_review_runtime from postgres;
