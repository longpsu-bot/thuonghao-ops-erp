-- RMVP-07: connected Confirmed Need approval and release.
--
-- This migration advances one exact NEED_GENERATION validation to an
-- immutable approval snapshot, then records a separate Planning release.
-- It preserves PA-05D WHOLESALE release-at-version-1 behavior and creates no
-- Purchase Handoff, Procurement, Warehouse, or Dispatch fact.

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values
  (
    'confirmed_need_approval.approve',
    'Approve validated Confirmed Need batch',
    'PLANNING',
    'ACTIVE'
  ),
  (
    'confirmed_need_release.release',
    'Release approved Confirmed Need for purchase handoff',
    'PLANNING',
    'ACTIVE'
  );

set role atlas_owner;

alter table atlas_planning.confirmed_need_validation_attempts
  add constraint confirmed_need_validation_attempts_rmvp07_source_key unique (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    source_kind
  ),
  add constraint confirmed_need_validation_attempts_rmvp07_owner_key unique (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    source_kind,
    outcome
  );

alter table atlas_planning.confirmed_need_approval_snapshots
  add column source_kind text not null default 'WHOLESALE',
  add column confirmed_need_validation_attempt_id uuid,
  add column validated_fact_fingerprint text,
  add constraint confirmed_need_approval_snapshots_source_check check (
    source_kind in ('WHOLESALE', 'NEED_GENERATION')
  ),
  add constraint confirmed_need_approval_snapshots_rmvp07_shape_check check (
    (
      source_kind = 'WHOLESALE'
      and confirmed_need_validation_attempt_id is null
      and validated_fact_fingerprint is null
    ) or (
      source_kind = 'NEED_GENERATION'
      and confirmed_need_validation_attempt_id is not null
      and validated_fact_fingerprint ~ '^[0-9a-f]{64}$'
    )
  ),
  add constraint confirmed_need_approval_snapshots_batch_source_fkey foreign key (
    confirmed_need_batch_id,
    source_kind
  ) references atlas_planning.confirmed_need_batches (
    confirmed_need_batch_id,
    source_kind
  ) on delete restrict,
  add constraint confirmed_need_approval_snapshots_validation_fkey foreign key (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    source_kind
  ) references atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_validation_attempt_id,
    confirmed_need_batch_id,
    source_kind
  ) on delete restrict
  deferrable initially deferred,
  add constraint confirmed_need_approval_snapshots_exact_owner_key unique (
    confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    source_kind,
    approved_version
  ),
  add constraint confirmed_need_approval_snapshots_pointer_owner_key unique (
    confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    source_kind
  );

create unique index confirmed_need_approval_snapshots_validation_key
  on atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_validation_attempt_id
  ) where source_kind = 'NEED_GENERATION';

create index confirmed_need_approval_snapshots_batch_source_idx
  on atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_batch_id,
    source_kind,
    approved_version desc
  );

create table atlas_planning.confirmed_need_releases (
  confirmed_need_release_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  source_kind text not null,
  confirmed_need_approval_snapshot_id uuid not null,
  source_approved_batch_version bigint not null,
  resulting_released_batch_version bigint not null,
  released_by_actor_id uuid not null,
  released_at timestamptz not null,
  command_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint confirmed_need_releases_pkey primary key (
    confirmed_need_release_id
  ),
  constraint confirmed_need_releases_snapshot_key unique (
    confirmed_need_approval_snapshot_id
  ),
  constraint confirmed_need_releases_command_key unique (command_id),
  constraint confirmed_need_releases_exact_owner_key unique (
    confirmed_need_release_id,
    confirmed_need_batch_id,
    source_kind,
    resulting_released_batch_version
  ),
  constraint confirmed_need_releases_pointer_owner_key unique (
    confirmed_need_release_id,
    confirmed_need_batch_id,
    source_kind
  ),
  constraint confirmed_need_releases_source_check check (
    source_kind = 'NEED_GENERATION'
  ),
  constraint confirmed_need_releases_version_check check (
    source_approved_batch_version > 0
    and resulting_released_batch_version = source_approved_batch_version + 1
  ),
  constraint confirmed_need_releases_batch_fkey foreign key (
    confirmed_need_batch_id,
    source_kind
  ) references atlas_planning.confirmed_need_batches (
    confirmed_need_batch_id,
    source_kind
  ) on delete restrict,
  constraint confirmed_need_releases_snapshot_fkey foreign key (
    confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    source_kind,
    source_approved_batch_version
  ) references atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    source_kind,
    approved_version
  ) on delete restrict,
  constraint confirmed_need_releases_actor_fkey foreign key (
    released_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_releases_command_fkey foreign key (
    command_id
  ) references atlas_core.command_receipts (command_id) on delete restrict
);

create index confirmed_need_releases_batch_history_idx
  on atlas_planning.confirmed_need_releases (
    confirmed_need_batch_id,
    resulting_released_batch_version desc
  );
create index confirmed_need_releases_actor_idx
  on atlas_planning.confirmed_need_releases (released_by_actor_id);

alter table atlas_planning.confirmed_need_batches
  add column current_confirmed_need_approval_snapshot_id uuid,
  add column current_confirmed_need_release_id uuid,
  add constraint confirmed_need_batches_current_approval_fkey foreign key (
    current_confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    source_kind
  ) references atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    source_kind
  ) on delete restrict
  deferrable initially deferred,
  add constraint confirmed_need_batches_current_rmvp07_release_fkey foreign key (
    current_confirmed_need_release_id,
    confirmed_need_batch_id,
    source_kind
  ) references atlas_planning.confirmed_need_releases (
    confirmed_need_release_id,
    confirmed_need_batch_id,
    source_kind
  ) on delete restrict
  deferrable initially deferred;

create index confirmed_need_batches_current_approval_idx
  on atlas_planning.confirmed_need_batches (
    current_confirmed_need_approval_snapshot_id
  ) where current_confirmed_need_approval_snapshot_id is not null;
create index confirmed_need_batches_current_rmvp07_release_idx
  on atlas_planning.confirmed_need_batches (
    current_confirmed_need_release_id
  ) where current_confirmed_need_release_id is not null;

create function atlas_planning.rmvp_07_immutable_approval_release_evidence()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Confirmed Need approval and release evidence is immutable and undeletable';
end;
$$;

create function atlas_core.rmvp_07_record_change(
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
    before_summary, after_summary, 'atlas_api',
    pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_id;

  return pg_catalog.jsonb_build_object(
    'domain_event_id', v_event_id,
    'audit_event_id', v_audit_id
  );
end;
$$;

create function atlas_api.approve_confirmed_needs(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'approve_confirmed_needs';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,confirmed_need_batch_id}'
  );
  v_expected_version bigint := atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  );
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_attempt atlas_planning.confirmed_need_validation_attempts%rowtype;
  v_snapshot_id uuid := gen_random_uuid();
  v_reconstructed_projection jsonb;
  v_current_projection jsonb;
  v_fact_fingerprint text;
  v_approved_line_count integer;
  v_events jsonb;
  v_response jsonb;
  v_before_summary jsonb;
  v_after_summary jsonb;
  v_resulting_version bigint;
begin
  v_error := atlas_core.rmvp_07_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_07_authorize(
    request,
    v_name,
    'confirmed_need_approval.approve'
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_name,
    'PLANNING',
    'ConfirmedNeedBatch:' || v_batch_id::text
  );
  if v_begin ->> 'status' = 'REPLAY' then
    return v_begin -> 'response';
  elsif v_begin ->> 'status' <> 'NEW' then
    return atlas_core.rmvp_07_error(
      request,
      v_name,
      v_begin #>> '{response,error_code}',
      v_begin #>> '{response,safe_message}',
      coalesce((v_begin #>> '{response,retryable}')::boolean, false)
    );
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select batch.*
  into v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id
  for update;
  if not found then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'The requested Confirmed Need batch was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.source_kind <> 'NEED_GENERATION' then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'UNSUPPORTED_SOURCE_KIND',
      'RMVP-07 approval supports NEED_GENERATION batches only.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.batch_status <> 'VALIDATED' then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'INVALID_LIFECYCLE_STATE',
      'The Confirmed Need batch must be VALIDATED before approval.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.version <> v_expected_version then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'STALE_VERSION',
      'The Confirmed Need batch version changed. Refresh before approving.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.current_confirmed_need_validation_attempt_id is null then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CURRENT_VALIDATION_MISSING',
      'The current successful validation evidence is missing.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select attempt.*
  into v_attempt
  from atlas_planning.confirmed_need_validation_attempts attempt
  where attempt.confirmed_need_validation_attempt_id
    = v_batch.current_confirmed_need_validation_attempt_id
  for share;
  if not found or v_attempt.outcome <> 'VALIDATED'
    or v_attempt.blocking_issue_count <> 0
  then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CURRENT_VALIDATION_NOT_SUCCESSFUL',
      'The current validation evidence is not a successful validation.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_attempt.confirmed_need_batch_id <> v_batch_id
    or v_attempt.source_kind <> 'NEED_GENERATION'
    or v_attempt.resulting_batch_version <> v_batch.version
  then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CURRENT_VALIDATION_NOT_CURRENT',
      'The successful validation evidence is no longer current.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  perform observation.confirmed_need_validation_line_id
  from atlas_planning.confirmed_need_validation_lines observation
  where observation.confirmed_need_validation_attempt_id
    = v_attempt.confirmed_need_validation_attempt_id
  order by observation.line_sort_position
  for share;
  perform issue.confirmed_need_validation_issue_id
  from atlas_planning.confirmed_need_validation_issues issue
  where issue.confirmed_need_validation_attempt_id
    = v_attempt.confirmed_need_validation_attempt_id
  order by issue.issue_sort_position
  for share;
  perform line.confirmed_need_line_id
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = v_batch_id
  order by line.confirmed_need_line_id
  for share;
  perform revision.confirmed_need_line_revision_id
  from atlas_planning.confirmed_need_line_revisions revision
  where revision.confirmed_need_batch_id = v_batch_id
    and revision.is_current
  order by revision.confirmed_need_line_revision_id
  for update;
  perform decision.confirmed_need_line_decision_id
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_batch_id = v_batch_id
    and decision.confirmed_need_line_decision_id in (
      select line.current_confirmed_need_line_decision_id
      from atlas_planning.confirmed_need_lines line
      where line.confirmed_need_batch_id = v_batch_id
    )
  order by decision.confirmed_need_line_decision_id
  for share;
  perform unit.unit_id
  from atlas_admin.units unit
  where unit.unit_id in (
    select line.controlled_unit_id
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
  )
  order by unit.unit_id
  for share;
  perform policy.planning_quantity_policy_id
  from atlas_planning.planning_quantity_policies policy
  where policy.planning_quantity_policy_id in (
    select decision.planning_quantity_policy_id
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id
  )
  order by policy.planning_quantity_policy_id
  for share;
  perform policy_revision.planning_quantity_policy_revision_id
  from atlas_planning.planning_quantity_policy_revisions policy_revision
  where policy_revision.planning_quantity_policy_revision_id in (
    select decision.planning_quantity_policy_revision_id
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id
  )
  order by policy_revision.planning_quantity_policy_revision_id
  for share;
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
  perform contribution.confirmed_need_line_revision_contribution_id
  from atlas_planning.confirmed_need_line_revision_contributions contribution
  where contribution.confirmed_need_line_revision_id in (
    select revision.confirmed_need_line_revision_id
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and revision.is_current
  )
  order by contribution.confirmed_need_line_revision_contribution_id
  for share;

  if not atlas_core.rmvp_07_validation_evidence_complete(
    v_batch_id,
    v_attempt.confirmed_need_validation_attempt_id,
    v_batch.version
  ) then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'VALIDATION_EVIDENCE_INCOMPLETE',
      'The successful validation evidence is incomplete or inexact.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_reconstructed_projection :=
    atlas_core.rmvp_07_validated_facts_projection(
      v_batch_id,
      v_attempt.confirmed_need_validation_attempt_id
    );
  v_current_projection := atlas_core.rmvp_07_validated_facts_projection(
    v_batch_id,
    null
  );
  if v_reconstructed_projection is distinct from v_current_projection then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CURRENT_FACTS_CHANGED',
      'The validated facts changed. Refresh and validate again before approval.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  v_fact_fingerprint :=
    atlas_core.rmvp_07_validated_facts_fingerprint(v_current_projection);

  if exists (
    select 1
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    where snapshot.confirmed_need_batch_id = v_batch_id
      and snapshot.source_kind = 'NEED_GENERATION'
      and snapshot.approved_version = v_batch.version + 1
  ) then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'APPROVAL_ALREADY_EXISTS',
      'An approval already exists for this validated batch version.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (
    select 1
    from atlas_planning.purchase_handoff_batches handoff
    where handoff.confirmed_need_batch_id = v_batch_id
  ) then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'PURCHASE_HANDOFF_CONFLICT',
      'An incompatible Purchase Handoff already exists.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_resulting_version := v_batch.version + 1;
  insert into atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_approval_snapshot_id,
    confirmed_need_batch_id,
    approved_version,
    approved_by_actor_id,
    approved_at,
    command_id,
    source_kind,
    confirmed_need_validation_attempt_id,
    validated_fact_fingerprint
  ) values (
    v_snapshot_id,
    v_batch_id,
    v_resulting_version,
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    'NEED_GENERATION',
    v_attempt.confirmed_need_validation_attempt_id,
    v_fact_fingerprint
  );

  insert into atlas_planning.confirmed_need_snapshot_lines (
    confirmed_need_approval_snapshot_id,
    confirmed_need_line_revision_id,
    ingredient_id,
    approved_quantity,
    unit_id,
    ingredient_name_snapshot
  )
  select
    v_snapshot_id,
    revision.confirmed_need_line_revision_id,
    revision.ingredient_id,
    revision.confirmed_quantity,
    revision.unit_id,
    ingredient.ingredient_name
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id = line.confirmed_need_line_id
   and revision.is_current
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id = revision.ingredient_id
  where line.confirmed_need_batch_id = v_batch_id
  order by line.confirmed_need_line_id;
  get diagnostics v_approved_line_count = row_count;

  update atlas_planning.confirmed_need_line_revisions revision
  set revision_status = 'APPROVED'
  where revision.confirmed_need_batch_id = v_batch_id
    and revision.is_current
    and revision.revision_status = 'DRAFT';
  if found is false then
    raise exception using
      errcode = '23514',
      message = 'Approval did not advance exact current line metadata';
  end if;

  update atlas_planning.confirmed_need_batches
  set batch_status = 'APPROVED',
      version = v_resulting_version,
      approved_by_actor_id = v_actor_id,
      approved_at = pg_catalog.transaction_timestamp(),
      current_confirmed_need_validation_attempt_id = null,
      current_confirmed_need_approval_snapshot_id = v_snapshot_id,
      current_confirmed_need_release_id = null,
      updated_at = pg_catalog.transaction_timestamp()
  where confirmed_need_batch_id = v_batch_id;

  v_before_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', v_batch.source_kind,
    'batch_status', v_batch.batch_status,
    'batch_version', v_batch.version,
    'validation_attempt_id', v_attempt.confirmed_need_validation_attempt_id
  );
  v_after_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', 'NEED_GENERATION',
    'prior_status', v_batch.batch_status,
    'resulting_status', 'APPROVED',
    'prior_version', v_batch.version,
    'resulting_version', v_resulting_version,
    'validation_attempt_id', v_attempt.confirmed_need_validation_attempt_id,
    'approval_snapshot_id', v_snapshot_id,
    'validated_fact_fingerprint', v_fact_fingerprint,
    'approved_line_count', v_approved_line_count,
    'warning_count', v_attempt.warning_count,
    'actor_id', v_actor_id,
    'command_id', request -> 'command_id',
    'correlation_id', request -> 'correlation_id',
    'reason_code', request ->> 'reason_code',
    'approved_at', pg_catalog.transaction_timestamp()
  );
  v_events := atlas_core.rmvp_07_record_change(
    request, v_actor_id, v_receipt_id, v_batch_id,
    v_batch.version, v_resulting_version,
    'ConfirmedNeedsApproved', v_before_summary, v_after_summary
  );

  set constraints all immediate;
  set constraints all deferred;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-07.v1',
    'command_name', v_name,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', 'NEED_GENERATION',
    'prior_batch_status', v_batch.batch_status,
    'resulting_batch_status', 'APPROVED',
    'prior_batch_version', v_batch.version,
    'resulting_batch_version', v_resulting_version,
    'confirmed_need_validation_attempt_id',
      v_attempt.confirmed_need_validation_attempt_id,
    'validation_attempt_fingerprint', v_attempt.validation_fingerprint,
    'validated_fact_fingerprint', v_fact_fingerprint,
    'confirmed_need_approval_snapshot_id', v_snapshot_id,
    'approved_version', v_resulting_version,
    'approved_line_count', v_approved_line_count,
    'warning_count', v_attempt.warning_count,
    'approved_by_actor_id', v_actor_id,
    'approved_at', pg_catalog.transaction_timestamp(),
    'receipt_id', v_receipt_id,
    'event_id', v_events -> 'domain_event_id',
    'audit_id', v_events -> 'audit_event_id',
    'safe_operator_message',
      'The complete Confirmed Need batch was approved and is awaiting release.',
    'authoritative_readback', atlas_core.rmvp_07_extend_workbench(
      atlas_core.rmvp_06_extend_workbench(
        atlas_core.rmvp_05_workbench_payload(
          v_batch_id, '{}'::jsonb, 0, 100
        )
      ),
      v_actor_id
    )
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception when others then
  return atlas_core.rmvp_07_error(
    request, v_name, 'INTERNAL_COMMAND_FAILURE',
    'The approval was not committed. Refresh before trying again.'
  );
end;
$$;

create function atlas_api.release_confirmed_needs_for_purchase_handoff(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text :=
    'release_confirmed_needs_for_purchase_handoff';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,confirmed_need_batch_id}'
  );
  v_expected_version bigint := atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  );
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_snapshot atlas_planning.confirmed_need_approval_snapshots%rowtype;
  v_attempt atlas_planning.confirmed_need_validation_attempts%rowtype;
  v_release_id uuid := gen_random_uuid();
  v_current_projection jsonb;
  v_current_fingerprint text;
  v_released_line_count integer;
  v_resulting_version bigint;
  v_events jsonb;
  v_response jsonb;
  v_before_summary jsonb;
  v_after_summary jsonb;
begin
  v_error := atlas_core.rmvp_07_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_07_authorize(
    request,
    v_name,
    'confirmed_need_release.release'
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_name,
    'PLANNING',
    'ConfirmedNeedBatch:' || v_batch_id::text
  );
  if v_begin ->> 'status' = 'REPLAY' then
    return v_begin -> 'response';
  elsif v_begin ->> 'status' <> 'NEW' then
    return atlas_core.rmvp_07_error(
      request,
      v_name,
      v_begin #>> '{response,error_code}',
      v_begin #>> '{response,safe_message}',
      coalesce((v_begin #>> '{response,retryable}')::boolean, false)
    );
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select batch.*
  into v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id
  for update;
  if not found then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'The requested Confirmed Need batch was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.source_kind <> 'NEED_GENERATION' then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'UNSUPPORTED_SOURCE_KIND',
      'RMVP-07 release supports NEED_GENERATION batches only.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.batch_status <> 'APPROVED' then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'INVALID_LIFECYCLE_STATE',
      'The Confirmed Need batch must be APPROVED before release.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.version <> v_expected_version then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'STALE_VERSION',
      'The Confirmed Need batch version changed. Refresh before releasing.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.current_confirmed_need_approval_snapshot_id is null then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CURRENT_APPROVAL_MISSING',
      'The current approval evidence is missing.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select snapshot.*
  into v_snapshot
  from atlas_planning.confirmed_need_approval_snapshots snapshot
  where snapshot.confirmed_need_approval_snapshot_id
    = v_batch.current_confirmed_need_approval_snapshot_id
  for share;
  if not found
    or v_snapshot.confirmed_need_batch_id <> v_batch_id
    or v_snapshot.source_kind <> 'NEED_GENERATION'
    or v_snapshot.approved_version <> v_batch.version
  then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'CURRENT_APPROVAL_NOT_CURRENT',
      'The approval evidence is no longer current.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select attempt.*
  into v_attempt
  from atlas_planning.confirmed_need_validation_attempts attempt
  where attempt.confirmed_need_validation_attempt_id
    = v_snapshot.confirmed_need_validation_attempt_id
    and attempt.confirmed_need_batch_id = v_batch_id
  for share;

  perform snapshot_line.confirmed_need_snapshot_line_id
  from atlas_planning.confirmed_need_snapshot_lines snapshot_line
  where snapshot_line.confirmed_need_approval_snapshot_id
    = v_snapshot.confirmed_need_approval_snapshot_id
  order by snapshot_line.confirmed_need_snapshot_line_id
  for share;
  perform line.confirmed_need_line_id
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = v_batch_id
  order by line.confirmed_need_line_id
  for share;
  perform revision.confirmed_need_line_revision_id
  from atlas_planning.confirmed_need_line_revisions revision
  where revision.confirmed_need_batch_id = v_batch_id
    and revision.is_current
  order by revision.confirmed_need_line_revision_id
  for update;
  perform decision.confirmed_need_line_decision_id
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_batch_id = v_batch_id
    and decision.confirmed_need_line_decision_id in (
      select line.current_confirmed_need_line_decision_id
      from atlas_planning.confirmed_need_lines line
      where line.confirmed_need_batch_id = v_batch_id
    )
  order by decision.confirmed_need_line_decision_id
  for share;
  perform unit.unit_id
  from atlas_admin.units unit
  where unit.unit_id in (
    select line.controlled_unit_id
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
  )
  order by unit.unit_id
  for share;
  perform policy.planning_quantity_policy_id
  from atlas_planning.planning_quantity_policies policy
  where policy.planning_quantity_policy_id in (
    select decision.planning_quantity_policy_id
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id
  )
  order by policy.planning_quantity_policy_id
  for share;
  perform policy_revision.planning_quantity_policy_revision_id
  from atlas_planning.planning_quantity_policy_revisions policy_revision
  where policy_revision.planning_quantity_policy_revision_id in (
    select decision.planning_quantity_policy_revision_id
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id
  )
  order by policy_revision.planning_quantity_policy_revision_id
  for share;
  perform run.need_generation_run_id
  from atlas_planning.need_generation_runs run
  where run.need_generation_run_id = v_batch.current_need_generation_run_id
  for share;
  perform source_release.need_generation_release_snapshot_id
  from atlas_planning.need_generation_release_snapshots source_release
  where source_release.need_generation_release_snapshot_id
    = v_batch.current_need_generation_release_snapshot_id
  for share;
  perform member.need_generation_release_snapshot_line_id
  from atlas_planning.need_generation_release_snapshot_lines member
  where member.need_generation_release_snapshot_id
    = v_batch.current_need_generation_release_snapshot_id
  order by member.need_generation_release_snapshot_line_id
  for share;
  perform contribution.confirmed_need_line_revision_contribution_id
  from atlas_planning.confirmed_need_line_revision_contributions contribution
  where contribution.confirmed_need_line_revision_id in (
    select snapshot_line.confirmed_need_line_revision_id
    from atlas_planning.confirmed_need_snapshot_lines snapshot_line
    where snapshot_line.confirmed_need_approval_snapshot_id
      = v_snapshot.confirmed_need_approval_snapshot_id
  )
  order by contribution.confirmed_need_line_revision_contribution_id
  for share;

  if not atlas_core.rmvp_07_snapshot_current_complete(
    v_batch_id,
    v_snapshot.confirmed_need_approval_snapshot_id,
    'APPROVED'
  ) or v_attempt.confirmed_need_validation_attempt_id is null
    or v_attempt.outcome <> 'VALIDATED'
    or v_attempt.blocking_issue_count <> 0
  then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'APPROVAL_EVIDENCE_INCOMPLETE',
      'The approval evidence is incomplete or inexact.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_current_projection := atlas_core.rmvp_07_validated_facts_projection(
    v_batch_id,
    null
  );
  v_current_fingerprint :=
    atlas_core.rmvp_07_validated_facts_fingerprint(v_current_projection);
  if v_current_fingerprint is distinct from
    v_snapshot.validated_fact_fingerprint
  then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'APPROVAL_FACTS_CHANGED',
      'The approved facts changed. Refresh and review the batch again.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (
    select 1
    from atlas_planning.confirmed_need_releases release
    where release.confirmed_need_approval_snapshot_id
      = v_snapshot.confirmed_need_approval_snapshot_id
  ) then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'RELEASE_ALREADY_EXISTS',
      'A release already exists for this approval snapshot.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (
    select 1
    from atlas_planning.purchase_handoff_batches handoff
    where handoff.confirmed_need_batch_id = v_batch_id
  ) then
    v_error := atlas_core.rmvp_07_error(
      request, v_name, 'PURCHASE_HANDOFF_CONFLICT',
      'An incompatible Purchase Handoff already exists.',
      false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer
  into v_released_line_count
  from atlas_planning.confirmed_need_snapshot_lines snapshot_line
  where snapshot_line.confirmed_need_approval_snapshot_id
    = v_snapshot.confirmed_need_approval_snapshot_id;
  v_resulting_version := v_batch.version + 1;

  insert into atlas_planning.confirmed_need_releases (
    confirmed_need_release_id,
    confirmed_need_batch_id,
    source_kind,
    confirmed_need_approval_snapshot_id,
    source_approved_batch_version,
    resulting_released_batch_version,
    released_by_actor_id,
    released_at,
    command_id
  ) values (
    v_release_id,
    v_batch_id,
    'NEED_GENERATION',
    v_snapshot.confirmed_need_approval_snapshot_id,
    v_batch.version,
    v_resulting_version,
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  );

  update atlas_planning.confirmed_need_line_revisions revision
  set revision_status = 'RELEASED'
  where revision.confirmed_need_line_revision_id in (
    select snapshot_line.confirmed_need_line_revision_id
    from atlas_planning.confirmed_need_snapshot_lines snapshot_line
    where snapshot_line.confirmed_need_approval_snapshot_id
      = v_snapshot.confirmed_need_approval_snapshot_id
  )
    and revision.is_current
    and revision.revision_status = 'APPROVED';
  if found is false then
    raise exception using
      errcode = '23514',
      message = 'Release did not advance exact current line metadata';
  end if;

  update atlas_planning.confirmed_need_batches
  set batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF',
      version = v_resulting_version,
      released_by_actor_id = v_actor_id,
      released_at = pg_catalog.transaction_timestamp(),
      current_confirmed_need_release_id = v_release_id,
      updated_at = pg_catalog.transaction_timestamp()
  where confirmed_need_batch_id = v_batch_id;

  v_before_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', v_batch.source_kind,
    'batch_status', v_batch.batch_status,
    'batch_version', v_batch.version,
    'approval_snapshot_id', v_snapshot.confirmed_need_approval_snapshot_id
  );
  v_after_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', 'NEED_GENERATION',
    'prior_status', v_batch.batch_status,
    'resulting_status', 'RELEASED_FOR_PURCHASE_HANDOFF',
    'prior_version', v_batch.version,
    'resulting_version', v_resulting_version,
    'approval_snapshot_id', v_snapshot.confirmed_need_approval_snapshot_id,
    'release_id', v_release_id,
    'validated_fact_fingerprint', v_snapshot.validated_fact_fingerprint,
    'released_line_count', v_released_line_count,
    'warning_count', v_attempt.warning_count,
    'actor_id', v_actor_id,
    'command_id', request -> 'command_id',
    'correlation_id', request -> 'correlation_id',
    'reason_code', request ->> 'reason_code',
    'released_at', pg_catalog.transaction_timestamp()
  );
  v_events := atlas_core.rmvp_07_record_change(
    request, v_actor_id, v_receipt_id, v_batch_id,
    v_batch.version, v_resulting_version,
    'ConfirmedNeedsReleasedForPurchaseHandoff',
    v_before_summary, v_after_summary
  );

  set constraints all immediate;
  set constraints all deferred;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-07.v1',
    'command_name', v_name,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'confirmed_need_batch_id', v_batch_id,
    'source_kind', 'NEED_GENERATION',
    'prior_batch_status', v_batch.batch_status,
    'resulting_batch_status', 'RELEASED_FOR_PURCHASE_HANDOFF',
    'prior_batch_version', v_batch.version,
    'resulting_batch_version', v_resulting_version,
    'confirmed_need_approval_snapshot_id',
      v_snapshot.confirmed_need_approval_snapshot_id,
    'validated_fact_fingerprint', v_snapshot.validated_fact_fingerprint,
    'confirmed_need_release_id', v_release_id,
    'source_approved_batch_version', v_batch.version,
    'resulting_released_batch_version', v_resulting_version,
    'released_line_count', v_released_line_count,
    'warning_count', v_attempt.warning_count,
    'released_by_actor_id', v_actor_id,
    'released_at', pg_catalog.transaction_timestamp(),
    'receipt_id', v_receipt_id,
    'event_id', v_events -> 'domain_event_id',
    'audit_id', v_events -> 'audit_event_id',
    'safe_operator_message',
      'The approved Confirmed Need batch was released for later Purchase Handoff creation.',
    'authoritative_readback', atlas_core.rmvp_07_extend_workbench(
      atlas_core.rmvp_06_extend_workbench(
        atlas_core.rmvp_05_workbench_payload(
          v_batch_id, '{}'::jsonb, 0, 100
        )
      ),
      v_actor_id
    )
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception when others then
  return atlas_core.rmvp_07_error(
    request, v_name, 'INTERNAL_COMMAND_FAILURE',
    'The release was not committed. Refresh before trying again.'
  );
end;
$$;

create function atlas_planning.rmvp_07_approval_release_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_snapshot atlas_planning.confirmed_need_approval_snapshots%rowtype;
  v_release atlas_planning.confirmed_need_releases%rowtype;
begin
  if tg_table_name = 'confirmed_need_batches' then
    v_batch_id := new.confirmed_need_batch_id;
  elsif tg_table_name = 'confirmed_need_approval_snapshots' then
    v_batch_id := new.confirmed_need_batch_id;
  elsif tg_table_name = 'confirmed_need_snapshot_lines' then
    select snapshot.confirmed_need_batch_id
    into strict v_batch_id
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    where snapshot.confirmed_need_approval_snapshot_id
      = new.confirmed_need_approval_snapshot_id;
  else
    v_batch_id := new.confirmed_need_batch_id;
  end if;

  select batch.*
  into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  if exists (
    select 1
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    left join atlas_planning.confirmed_need_validation_attempts attempt
      on attempt.confirmed_need_validation_attempt_id
        = snapshot.confirmed_need_validation_attempt_id
     and attempt.confirmed_need_batch_id = snapshot.confirmed_need_batch_id
     and attempt.source_kind = snapshot.source_kind
    where snapshot.confirmed_need_batch_id = v_batch_id
      and snapshot.source_kind = 'NEED_GENERATION'
      and (
        attempt.confirmed_need_validation_attempt_id is null
        or attempt.outcome <> 'VALIDATED'
        or attempt.blocking_issue_count <> 0
        or attempt.resulting_batch_version + 1 <> snapshot.approved_version
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Need Generation approval must bind one exact successful validation';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_snapshot_lines snapshot_line
    join atlas_planning.confirmed_need_approval_snapshots snapshot
      on snapshot.confirmed_need_approval_snapshot_id
        = snapshot_line.confirmed_need_approval_snapshot_id
    left join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id
        = snapshot_line.confirmed_need_line_revision_id
    left join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id = revision.confirmed_need_line_id
    where snapshot.confirmed_need_batch_id = v_batch_id
      and (
        revision.confirmed_need_line_revision_id is null
        or line.confirmed_need_line_id is null
        or revision.confirmed_need_batch_id <> snapshot.confirmed_need_batch_id
        or revision.source_kind <> snapshot.source_kind
        or line.confirmed_need_batch_id <> snapshot.confirmed_need_batch_id
        or line.source_kind <> snapshot.source_kind
        or snapshot_line.ingredient_id <> revision.ingredient_id
        or snapshot_line.unit_id <> revision.unit_id
        or snapshot_line.approved_quantity <> revision.confirmed_quantity
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Approval snapshot lines must bind exact batch-owned revision facts';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    join atlas_planning.confirmed_need_validation_attempts attempt
      on attempt.confirmed_need_validation_attempt_id
        = snapshot.confirmed_need_validation_attempt_id
    where snapshot.confirmed_need_batch_id = v_batch_id
      and snapshot.source_kind = 'NEED_GENERATION'
      and (
        (select count(*)
         from atlas_planning.confirmed_need_snapshot_lines snapshot_line
         where snapshot_line.confirmed_need_approval_snapshot_id
           = snapshot.confirmed_need_approval_snapshot_id) <> attempt.line_count
        or exists (
          select 1
          from atlas_planning.confirmed_need_validation_lines observation
          where observation.confirmed_need_validation_attempt_id
            = attempt.confirmed_need_validation_attempt_id
            and not exists (
              select 1
              from atlas_planning.confirmed_need_snapshot_lines snapshot_line
              join atlas_planning.confirmed_need_line_revisions revision
                on revision.confirmed_need_line_revision_id
                  = snapshot_line.confirmed_need_line_revision_id
              where snapshot_line.confirmed_need_approval_snapshot_id
                = snapshot.confirmed_need_approval_snapshot_id
                and revision.confirmed_need_line_id
                  = observation.confirmed_need_line_id
                and snapshot_line.confirmed_need_line_revision_id
                  = observation.current_confirmed_need_line_revision_id
                and snapshot_line.unit_id = observation.controlled_unit_id
                and snapshot_line.approved_quantity
                  = observation.confirmed_quantity
            )
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Need Generation approval snapshot membership is incomplete or inexact';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    where snapshot.confirmed_need_batch_id = v_batch_id
      and snapshot.source_kind = 'WHOLESALE'
      and (
        (select count(*)
         from atlas_planning.confirmed_need_snapshot_lines snapshot_line
         where snapshot_line.confirmed_need_approval_snapshot_id
           = snapshot.confirmed_need_approval_snapshot_id)
        <> (select count(*)
            from atlas_planning.confirmed_need_lines line
            where line.confirmed_need_batch_id = v_batch_id)
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Wholesale approval snapshot membership remains every-and-only';
  end if;

  if v_batch.source_kind = 'WHOLESALE' then
    if v_batch.current_confirmed_need_validation_attempt_id is not null
      or v_batch.current_confirmed_need_approval_snapshot_id is not null
      or v_batch.current_confirmed_need_release_id is not null
      or exists (
        select 1
        from atlas_planning.confirmed_need_releases release
        where release.confirmed_need_batch_id = v_batch_id
      )
    then
      raise exception using
        errcode = '23514',
        message = 'Wholesale batches cannot use RMVP-07 pointers or release evidence';
    end if;
    return null;
  end if;

  if v_batch.batch_status in ('DRAFT_REVIEW', 'REOPENED') then
    if v_batch.current_confirmed_need_validation_attempt_id is not null
      or v_batch.current_confirmed_need_approval_snapshot_id is not null
      or v_batch.current_confirmed_need_release_id is not null
    then
      raise exception using
        errcode = '23514',
        message = 'Working Need Generation batches cannot retain lifecycle authority pointers';
    end if;
  elsif v_batch.batch_status = 'VALIDATED' then
    if v_batch.current_confirmed_need_validation_attempt_id is null
      or v_batch.current_confirmed_need_approval_snapshot_id is not null
      or v_batch.current_confirmed_need_release_id is not null
    then
      raise exception using
        errcode = '23514',
        message = 'Validated Need Generation batches require only current validation evidence';
    end if;
  elsif v_batch.batch_status = 'APPROVED' then
    if v_batch.current_confirmed_need_validation_attempt_id is not null
      or v_batch.current_confirmed_need_approval_snapshot_id is null
      or v_batch.current_confirmed_need_release_id is not null
    then
      raise exception using
        errcode = '23514',
        message = 'Approved Need Generation batches require only current approval evidence';
    end if;
  elsif v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF' then
    if v_batch.current_confirmed_need_validation_attempt_id is not null
      or v_batch.current_confirmed_need_approval_snapshot_id is null
      or v_batch.current_confirmed_need_release_id is null
    then
      raise exception using
        errcode = '23514',
        message = 'Released Need Generation batches require current approval and release evidence';
    end if;
  end if;

  if v_batch.current_confirmed_need_approval_snapshot_id is not null then
    select snapshot.*
    into strict v_snapshot
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    where snapshot.confirmed_need_approval_snapshot_id
      = v_batch.current_confirmed_need_approval_snapshot_id;

    if v_snapshot.confirmed_need_batch_id <> v_batch_id
      or v_snapshot.source_kind <> 'NEED_GENERATION'
      or (
        v_batch.batch_status = 'APPROVED'
        and v_snapshot.approved_version <> v_batch.version
      )
      or (
        v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
        and v_snapshot.approved_version + 1 <> v_batch.version
      )
      or (select count(*)
          from atlas_planning.confirmed_need_snapshot_lines snapshot_line
          where snapshot_line.confirmed_need_approval_snapshot_id
            = v_snapshot.confirmed_need_approval_snapshot_id)
        <> (select count(*)
            from atlas_planning.confirmed_need_lines line
            where line.confirmed_need_batch_id = v_batch_id)
      or exists (
        select 1
        from atlas_planning.confirmed_need_lines line
        left join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_id = line.confirmed_need_line_id
         and revision.is_current
        left join atlas_planning.confirmed_need_snapshot_lines snapshot_line
          on snapshot_line.confirmed_need_approval_snapshot_id
            = v_snapshot.confirmed_need_approval_snapshot_id
         and snapshot_line.confirmed_need_line_revision_id
            = revision.confirmed_need_line_revision_id
        where line.confirmed_need_batch_id = v_batch_id
          and (
            revision.confirmed_need_line_revision_id is null
            or snapshot_line.confirmed_need_snapshot_line_id is null
            or revision.revision_status <> case
              when v_batch.batch_status = 'APPROVED' then 'APPROVED'
              else 'RELEASED'
            end
          )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'The current approval pointer is not exact for the batch lifecycle';
    end if;
  end if;

  if v_batch.current_confirmed_need_release_id is not null then
    select release.*
    into strict v_release
    from atlas_planning.confirmed_need_releases release
    where release.confirmed_need_release_id
      = v_batch.current_confirmed_need_release_id;

    if v_release.confirmed_need_batch_id <> v_batch_id
      or v_release.source_kind <> 'NEED_GENERATION'
      or v_release.confirmed_need_approval_snapshot_id
        <> v_batch.current_confirmed_need_approval_snapshot_id
      or v_release.resulting_released_batch_version <> v_batch.version
      or v_release.source_approved_batch_version + 1 <> v_batch.version
    then
      raise exception using
        errcode = '23514',
        message = 'The current release pointer is not exact for the released batch';
    end if;
  end if;

  return null;
end;
$$;

create trigger confirmed_need_approval_snapshots_rmvp07_immutable
before update or delete on atlas_planning.confirmed_need_approval_snapshots
for each row execute function
  atlas_planning.rmvp_07_immutable_approval_release_evidence();
create trigger confirmed_need_snapshot_lines_rmvp07_immutable
before update or delete on atlas_planning.confirmed_need_snapshot_lines
for each row execute function
  atlas_planning.rmvp_07_immutable_approval_release_evidence();
create trigger confirmed_need_releases_rmvp07_immutable
before update or delete on atlas_planning.confirmed_need_releases
for each row execute function
  atlas_planning.rmvp_07_immutable_approval_release_evidence();

create constraint trigger confirmed_need_batches_rmvp07_integrity
after insert or update of
  batch_status,
  version,
  current_confirmed_need_validation_attempt_id,
  current_confirmed_need_approval_snapshot_id,
  current_confirmed_need_release_id
on atlas_planning.confirmed_need_batches
deferrable initially deferred
for each row execute function
  atlas_planning.rmvp_07_approval_release_integrity();
create constraint trigger confirmed_need_approval_snapshots_rmvp07_integrity
after insert on atlas_planning.confirmed_need_approval_snapshots
deferrable initially deferred
for each row execute function
  atlas_planning.rmvp_07_approval_release_integrity();
create constraint trigger confirmed_need_snapshot_lines_rmvp07_integrity
after insert on atlas_planning.confirmed_need_snapshot_lines
deferrable initially deferred
for each row execute function
  atlas_planning.rmvp_07_approval_release_integrity();
create constraint trigger confirmed_need_releases_rmvp07_integrity
after insert on atlas_planning.confirmed_need_releases
deferrable initially deferred
for each row execute function
  atlas_planning.rmvp_07_approval_release_integrity();

alter table atlas_planning.confirmed_need_releases enable row level security;
alter table atlas_planning.confirmed_need_releases force row level security;

revoke all on table atlas_planning.confirmed_need_releases
from public, anon, authenticated, service_role;
revoke execute on function
  atlas_planning.rmvp_07_immutable_approval_release_evidence(),
  atlas_planning.rmvp_07_approval_release_integrity()
from public, anon, authenticated, service_role;

create function atlas_core.rmvp_07_canonical_decimal(value numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.trim_scale(value)::text;
$$;

create function atlas_core.rmvp_07_validated_facts_projection(
  batch_id uuid,
  validation_attempt_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_items jsonb;
  v_issue_items jsonb;
  v_item jsonb;
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_revision atlas_planning.confirmed_need_line_revisions%rowtype;
  v_members jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_evaluation jsonb;
begin
  if validation_attempt_id is null then
    v_evaluation := atlas_core.rmvp_06_canonical_evaluation(batch_id);
    v_items := v_evaluation -> 'ordered_lines';
    v_issue_items := v_evaluation -> 'ordered_issues';
  else
    if not exists (
      select 1
      from atlas_planning.confirmed_need_validation_attempts attempt
      where attempt.confirmed_need_validation_attempt_id = validation_attempt_id
        and attempt.confirmed_need_batch_id = batch_id
    ) then
      raise exception using
        errcode = '22023',
        message = 'The RMVP-07 validation projection source is unavailable';
    end if;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'confirmed_need_line_id', observation.confirmed_need_line_id,
      'controlled_unit_id', observation.controlled_unit_id,
      'observed_current_revision_count',
        observation.observed_current_revision_count,
      'observed_current_decision_count',
        observation.observed_current_decision_count,
      'observed_eligible_policy_count',
        observation.observed_eligible_policy_count,
      'observed_source_membership_count',
        observation.observed_source_membership_count,
      'line_sort_position', observation.line_sort_position,
      'current_confirmed_need_line_revision_id',
        observation.current_confirmed_need_line_revision_id,
      'current_confirmed_need_line_decision_id',
        observation.current_confirmed_need_line_decision_id,
      'planning_quantity_policy_id', observation.planning_quantity_policy_id,
      'planning_quantity_policy_revision_id',
        observation.planning_quantity_policy_revision_id,
      'need_generation_run_id', observation.need_generation_run_id,
      'need_generation_run_version', observation.need_generation_run_version,
      'need_generation_release_snapshot_id',
        observation.need_generation_release_snapshot_id,
      'theoretical_quantity', observation.theoretical_quantity,
      'confirmed_quantity', observation.confirmed_quantity,
      'planning_tick_count', observation.planning_tick_count,
      'source_membership_total', observation.source_membership_total
    ) order by observation.line_sort_position), '[]'::jsonb)
    into v_items
    from atlas_planning.confirmed_need_validation_lines observation
    where observation.confirmed_need_validation_attempt_id
      = validation_attempt_id;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'issue_sort_position', issue.issue_sort_position,
      'confirmed_need_line_id', issue.confirmed_need_line_id,
      'severity', issue.severity,
      'issue_code', issue.issue_code
    ) order by issue.issue_sort_position), '[]'::jsonb)
    into v_issue_items
    from atlas_planning.confirmed_need_validation_issues issue
    where issue.confirmed_need_validation_attempt_id = validation_attempt_id;
  end if;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(coalesce(v_items, '[]'::jsonb))
    order by (value ->> 'line_sort_position')::integer
  loop
    v_line := null;
    v_revision := null;

    select line.*
    into strict v_line
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_line_id
      = atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id')
      and line.confirmed_need_batch_id = batch_id;

    select revision.*
    into v_revision
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_line_revision_id
      = atlas_core.pa_05b_safe_uuid(
        v_item ->> 'current_confirmed_need_line_revision_id'
      )
      and revision.confirmed_need_line_id = v_line.confirmed_need_line_id;

    perform 1
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_line_decision_id
      = atlas_core.pa_05b_safe_uuid(
        v_item ->> 'current_confirmed_need_line_decision_id'
      )
      and decision.confirmed_need_line_id = v_line.confirmed_need_line_id;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'confirmed_need_line_revision_contribution_id',
        contribution.confirmed_need_line_revision_contribution_id,
      'need_generation_release_snapshot_line_id',
        contribution.need_generation_release_snapshot_line_id,
      'theoretical_need_line_id', contribution.theoretical_need_line_id,
      'source_theoretical_quantity',
        atlas_core.rmvp_07_canonical_decimal(
          contribution.source_theoretical_quantity
        ),
      'controlled_contribution_quantity',
        atlas_core.rmvp_07_canonical_decimal(
          contribution.controlled_contribution_quantity
        )
    ) order by contribution.confirmed_need_line_revision_contribution_id),
    '[]'::jsonb)
    into v_members
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    where contribution.confirmed_need_line_revision_id
      = v_revision.confirmed_need_line_revision_id;

    v_lines := v_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'line_sort_position', (v_item ->> 'line_sort_position')::integer,
        'confirmed_need_line_id', v_line.confirmed_need_line_id,
        'service_date', v_line.service_date,
        'customer_id', v_line.customer_id,
        'school_id', v_line.school_id,
        'delivery_location_id', v_line.delivery_location_id,
        'ingredient_id', v_line.ingredient_id,
        'current_confirmed_need_line_revision_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'current_confirmed_need_line_revision_id'
          ),
        'current_confirmed_need_line_decision_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'current_confirmed_need_line_decision_id'
          ),
        'controlled_unit_id',
          atlas_core.pa_05b_safe_uuid(v_item ->> 'controlled_unit_id'),
        'planning_quantity_policy_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'planning_quantity_policy_id'
          ),
        'planning_quantity_policy_revision_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'planning_quantity_policy_revision_id'
          ),
        'need_generation_run_id',
          atlas_core.pa_05b_safe_uuid(v_item ->> 'need_generation_run_id'),
        'need_generation_run_version',
          nullif(v_item ->> 'need_generation_run_version', '')::bigint,
        'need_generation_release_snapshot_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'need_generation_release_snapshot_id'
          ),
        'theoretical_quantity', case
          when v_item ->> 'theoretical_quantity' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'theoretical_quantity')::numeric
          ) end,
        'confirmed_quantity', case
          when v_item ->> 'confirmed_quantity' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'confirmed_quantity')::numeric
          ) end,
        'planning_tick_count', case
          when v_item ->> 'planning_tick_count' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'planning_tick_count')::numeric
          ) end,
        'source_membership_count',
          (v_item ->> 'observed_source_membership_count')::integer,
        'source_membership_total', case
          when v_item ->> 'source_membership_total' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'source_membership_total')::numeric
          ) end,
        'ordered_source_members', v_members
      )
    );
  end loop;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'issue_sort_position', (item ->> 'issue_sort_position')::integer,
    'confirmed_need_line_id',
      atlas_core.pa_05b_safe_uuid(item ->> 'confirmed_need_line_id'),
    'severity', item ->> 'severity',
    'issue_code', item ->> 'issue_code'
  ) order by (item ->> 'issue_sort_position')::integer), '[]'::jsonb)
  into v_issues
  from pg_catalog.jsonb_array_elements(
    coalesce(v_issue_items, '[]'::jsonb)
  ) item;

  return pg_catalog.jsonb_build_object(
    'projection_version', 'RMVP-07-VALIDATED-FACTS.v1',
    'confirmed_need_batch_id', batch_id,
    'ordered_lines', v_lines,
    'ordered_issues', v_issues
  );
end;
$$;

create function atlas_core.rmvp_07_validated_facts_fingerprint(
  projection jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    projection::text,
    'UTF8'
  )), 'hex');
$$;

create function atlas_core.rmvp_07_error(
  request jsonb,
  command_name text,
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
  select pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-07.v1',
    'command_name', command_name,
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'PLANNING',
    'retryable', retryable,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'blocking_references', coalesce(blocking_references, '[]'::jsonb),
    'expected_version', request -> 'expected_version',
    'correlation_id', request -> 'correlation_id',
    'command_id', request -> 'command_id',
    'write_certainty', case command_name
      when 'approve_confirmed_needs' then 'NO_APPROVAL_EVIDENCE'
      else 'NO_RELEASE_EVIDENCE'
    end,
    'local_draft_may_be_preserved', false,
    'exact_retry_safe', retryable,
    'refresh_read', 'get_confirmed_need_review'
  ) || case when actual_version is null then '{}'::jsonb
    else pg_catalog.jsonb_build_object('actual_version', actual_version) end;
$$;

create function atlas_core.rmvp_07_validate_command(
  request jsonb,
  command_name text
)
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
  v_expected_reason text := case command_name
    when 'approve_confirmed_needs'
      then 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    else 'CONFIRMED_NEED_RELEASE_REQUESTED'
  end;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_07_error(
      coalesce(request, '{}'::jsonb),
      command_name,
      'VALIDATION_FAILED',
      'The RMVP-07 command must be a JSON object.'
    );
  end if;

  if request ->> 'contract_version' is distinct from 'RMVP-07.v1' then
    return atlas_core.rmvp_07_error(
      request,
      command_name,
      'UNSUPPORTED_CONTRACT_VERSION',
      'Use the RMVP-07.v1 contract.'
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
        'message', 'Provide exactly the closed RMVP-07 command envelope.'
      )
    );
  end if;

  v_requested_at := atlas_core.pa_05b_safe_timestamptz(
    request ->> 'requested_at'
  );
  v_reason_note := case when request -> 'reason_note' = 'null'::jsonb
    then null else request ->> 'reason_note' end;

  if pg_catalog.jsonb_typeof(request -> 'command_id') <> 'string'
    or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
    or pg_catalog.jsonb_typeof(request -> 'correlation_id') <> 'string'
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or pg_catalog.jsonb_typeof(request -> 'requested_by_auth_subject')
      <> 'string'
    or atlas_core.pa_05b_safe_uuid(
      request ->> 'requested_by_auth_subject'
    ) is null
    or pg_catalog.jsonb_typeof(request -> 'expected_version') <> 'number'
    or coalesce(request ->> 'expected_version', '') !~ '^[1-9][0-9]*$'
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
    or pg_catalog.jsonb_typeof(request -> 'idempotency_key') <> 'string'
    or nullif(pg_catalog.btrim(request ->> 'idempotency_key'), '') is null
    or request ->> 'idempotency_key'
      is distinct from pg_catalog.btrim(request ->> 'idempotency_key')
    or pg_catalog.char_length(request ->> 'idempotency_key') > 200
    or pg_catalog.jsonb_typeof(request -> 'requested_at') <> 'string'
    or v_requested_at is null
    or v_requested_at > pg_catalog.transaction_timestamp()
    or pg_catalog.jsonb_typeof(request -> 'reason_code') <> 'string'
    or request ->> 'reason_code' is distinct from v_expected_reason
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
        'message', 'The command identity, version, time, idempotency, or reason is invalid.'
      )
    );
  end if;

  v_payload := request -> 'payload';
  if pg_catalog.jsonb_typeof(v_payload) is distinct from 'object'
    or v_payload - array['confirmed_need_batch_id'] <> '{}'::jsonb
    or not (v_payload ? 'confirmed_need_batch_id')
    or pg_catalog.jsonb_typeof(v_payload -> 'confirmed_need_batch_id')
      <> 'string'
    or atlas_core.pa_05b_safe_uuid(
      v_payload ->> 'confirmed_need_batch_id'
    ) is null
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'Provide only one valid confirmed_need_batch_id.'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_07_error(
      request,
      command_name,
      'VALIDATION_FAILED',
      'The Confirmed Need lifecycle command is invalid.',
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_07_authorize(
  request jsonb,
  command_name text,
  capability_code text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_context jsonb;
  v_error jsonb;
  v_actor_id uuid;
begin
  v_context := atlas_core.pa_05b_resolve_actor(
    request,
    'PLANNING',
    command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.rmvp_07_error(
        request,
        command_name,
        case when v_context #>> '{error,error_code}' = 'AUTH_SUBJECT_MISMATCH'
          then 'AUTH_SUBJECT_MISMATCH' else 'ACTOR_NOT_AUTHORIZED' end,
        case when v_context #>> '{error,error_code}' = 'AUTH_SUBJECT_MISMATCH'
          then 'The asserted authentication subject does not match the current session.'
          else 'An active authorized human Planning Actor is required.' end
      )
    );
  end if;

  if v_context ->> 'actor_type' is distinct from 'HUMAN' then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.rmvp_07_error(
        request,
        command_name,
        'ACTOR_NOT_AUTHORIZED',
        'An active authorized human Planning Actor is required.'
      )
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    capability_code,
    'PLANNING',
    command_name,
    null,
    null,
    null
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.rmvp_07_error(
        request,
        command_name,
        'ACTOR_NOT_AUTHORIZED',
        'The Actor lacks the required active GLOBAL lifecycle capability.'
      )
    );
  end if;

  return pg_catalog.jsonb_build_object('actor_id', v_actor_id);
end;
$$;

create function atlas_core.rmvp_07_validation_evidence_complete(
  batch_id uuid,
  validation_attempt_id uuid,
  expected_resulting_version bigint
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.confirmed_need_validation_attempts attempt
    where attempt.confirmed_need_validation_attempt_id = validation_attempt_id
      and attempt.confirmed_need_batch_id = batch_id
      and attempt.source_kind = 'NEED_GENERATION'
      and attempt.outcome = 'VALIDATED'
      and attempt.resulting_batch_version = expected_resulting_version
      and attempt.blocking_issue_count = 0
      and attempt.line_count = (
        select count(*)
        from atlas_planning.confirmed_need_lines line
        where line.confirmed_need_batch_id = batch_id
      )
      and attempt.line_count = (
        select count(*)
        from atlas_planning.confirmed_need_validation_lines observation
        where observation.confirmed_need_validation_attempt_id
          = validation_attempt_id
      )
      and attempt.blocking_issue_count = (
        select count(*)
        from atlas_planning.confirmed_need_validation_issues issue
        where issue.confirmed_need_validation_attempt_id
          = validation_attempt_id
          and issue.severity = 'BLOCKING'
      )
      and attempt.warning_count = (
        select count(*)
        from atlas_planning.confirmed_need_validation_issues issue
        where issue.confirmed_need_validation_attempt_id
          = validation_attempt_id
          and issue.severity = 'WARNING'
      )
      and not exists (
        select 1
        from atlas_planning.confirmed_need_validation_lines observation
        left join atlas_planning.confirmed_need_lines line
          on line.confirmed_need_line_id = observation.confirmed_need_line_id
         and line.confirmed_need_batch_id = observation.confirmed_need_batch_id
        left join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_revision_id
            = observation.current_confirmed_need_line_revision_id
         and revision.confirmed_need_line_id
            = observation.confirmed_need_line_id
        left join atlas_planning.confirmed_need_line_decisions decision
          on decision.confirmed_need_line_decision_id
            = observation.current_confirmed_need_line_decision_id
         and decision.confirmed_need_line_id
            = observation.confirmed_need_line_id
        left join atlas_planning.planning_quantity_policy_revisions policy_revision
          on policy_revision.planning_quantity_policy_revision_id
            = observation.planning_quantity_policy_revision_id
         and policy_revision.planning_quantity_policy_id
            = observation.planning_quantity_policy_id
        where observation.confirmed_need_validation_attempt_id
          = validation_attempt_id
          and (
            observation.validation_outcome <> 'VALIDATED'
            or observation.observed_current_revision_count <> 1
            or observation.observed_current_decision_count <> 1
            or observation.observed_eligible_policy_count <> 1
            or observation.observed_source_membership_count < 1
            or line.confirmed_need_line_id is null
            or revision.confirmed_need_line_revision_id is null
            or not revision.is_current
            or revision.revision_status <> 'DRAFT'
            or decision.confirmed_need_line_decision_id is null
            or line.current_confirmed_need_line_decision_id
              <> decision.confirmed_need_line_decision_id
            or decision.confirmed_need_line_revision_id
              <> revision.confirmed_need_line_revision_id
            or policy_revision.planning_quantity_policy_revision_id is null
            or observation.controlled_unit_id <> line.controlled_unit_id
            or observation.controlled_unit_id <> revision.unit_id
            or observation.controlled_unit_id <> decision.unit_id
            or observation.need_generation_run_id
              <> revision.need_generation_run_id
            or observation.need_generation_run_version
              <> revision.need_generation_run_version
            or observation.need_generation_release_snapshot_id
              <> revision.need_generation_release_snapshot_id
            or observation.theoretical_quantity
              <> revision.theoretical_quantity
            or observation.confirmed_quantity
              <> decision.confirmed_quantity_after
            or observation.planning_tick_count
              <> decision.planning_tick_count
            or observation.source_membership_total
              <> revision.theoretical_quantity
            or observation.observed_source_membership_count <> (
              select count(*)
              from atlas_planning.confirmed_need_line_revision_contributions c
              where c.confirmed_need_line_revision_id
                = revision.confirmed_need_line_revision_id
            )
            or observation.source_membership_total <> (
              select sum(c.controlled_contribution_quantity)
              from atlas_planning.confirmed_need_line_revision_contributions c
              where c.confirmed_need_line_revision_id
                = revision.confirmed_need_line_revision_id
            )
          )
      )
  );
$$;

create function atlas_core.rmvp_07_snapshot_current_complete(
  batch_id uuid,
  approval_snapshot_id uuid,
  expected_revision_status text
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    join atlas_planning.confirmed_need_validation_attempts attempt
      on attempt.confirmed_need_validation_attempt_id
        = snapshot.confirmed_need_validation_attempt_id
     and attempt.confirmed_need_batch_id = snapshot.confirmed_need_batch_id
    where snapshot.confirmed_need_approval_snapshot_id = approval_snapshot_id
      and snapshot.confirmed_need_batch_id = batch_id
      and snapshot.source_kind = 'NEED_GENERATION'
      and snapshot.validated_fact_fingerprint ~ '^[0-9a-f]{64}$'
      and attempt.outcome = 'VALIDATED'
      and attempt.blocking_issue_count = 0
      and (select count(*)
           from atlas_planning.confirmed_need_snapshot_lines snapshot_line
           where snapshot_line.confirmed_need_approval_snapshot_id
             = approval_snapshot_id)
        = (select count(*)
           from atlas_planning.confirmed_need_lines line
           where line.confirmed_need_batch_id = batch_id)
      and not exists (
        select 1
        from atlas_planning.confirmed_need_lines line
        left join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_id = line.confirmed_need_line_id
         and revision.is_current
        left join atlas_planning.confirmed_need_snapshot_lines snapshot_line
          on snapshot_line.confirmed_need_approval_snapshot_id
            = approval_snapshot_id
         and snapshot_line.confirmed_need_line_revision_id
            = revision.confirmed_need_line_revision_id
        where line.confirmed_need_batch_id = batch_id
          and (
            revision.confirmed_need_line_revision_id is null
            or revision.revision_status <> expected_revision_status
            or snapshot_line.confirmed_need_snapshot_line_id is null
            or snapshot_line.ingredient_id <> revision.ingredient_id
            or snapshot_line.unit_id <> revision.unit_id
            or snapshot_line.approved_quantity <> revision.confirmed_quantity
          )
      )
  );
$$;

create function atlas_core.rmvp_07_extend_workbench(
  p_workbench jsonb,
  p_actor_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    p_workbench ->> 'confirmed_need_batch_id'
  );
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_attempt_id uuid;
  v_attempt atlas_planning.confirmed_need_validation_attempts%rowtype;
  v_snapshot atlas_planning.confirmed_need_approval_snapshots%rowtype;
  v_release atlas_planning.confirmed_need_releases%rowtype;
  v_approved_actor_name text;
  v_released_actor_name text;
  v_current_projection jsonb;
  v_validation_projection jsonb;
  v_current_fingerprint text;
  v_facts_changed_validation boolean;
  v_facts_changed_approval boolean;
  v_can_approve boolean := false;
  v_can_release boolean := false;
  v_validation_current boolean := false;
  v_validation_complete boolean := false;
  v_approval_current boolean := false;
  v_approval_complete boolean := false;
  v_handoff_conflict boolean := false;
  v_has_approval_capability boolean := false;
  v_has_release_capability boolean := false;
  v_approval_code text;
  v_release_code text;
  v_approval_message text;
  v_release_message text;
  v_history jsonb := '[]'::jsonb;
begin
  select batch.*
  into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  select exists (
    select 1
    from atlas_core.actor_role_memberships membership
    join atlas_core.roles role_record
      on role_record.role_id = membership.role_id
    join atlas_core.role_capabilities role_capability
      on role_capability.role_id = role_record.role_id
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where membership.actor_id = p_actor_id
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= pg_catalog.transaction_timestamp()
      and (membership.effective_to is null
        or membership.effective_to > pg_catalog.transaction_timestamp())
      and role_record.role_status = 'ACTIVE'
      and capability.capability_status = 'ACTIVE'
      and capability.capability_code = 'confirmed_need_approval.approve'
  ) and exists (
    select 1
    from atlas_core.actor_scopes scope
    where scope.actor_id = p_actor_id
      and scope.scope_status = 'ACTIVE'
      and scope.scope_kind = 'GLOBAL'
      and scope.effective_from <= pg_catalog.transaction_timestamp()
      and (scope.effective_to is null
        or scope.effective_to > pg_catalog.transaction_timestamp())
  ) into v_has_approval_capability;

  select exists (
    select 1
    from atlas_core.actor_role_memberships membership
    join atlas_core.roles role_record
      on role_record.role_id = membership.role_id
    join atlas_core.role_capabilities role_capability
      on role_capability.role_id = role_record.role_id
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where membership.actor_id = p_actor_id
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= pg_catalog.transaction_timestamp()
      and (membership.effective_to is null
        or membership.effective_to > pg_catalog.transaction_timestamp())
      and role_record.role_status = 'ACTIVE'
      and capability.capability_status = 'ACTIVE'
      and capability.capability_code = 'confirmed_need_release.release'
  ) and exists (
    select 1
    from atlas_core.actor_scopes scope
    where scope.actor_id = p_actor_id
      and scope.scope_status = 'ACTIVE'
      and scope.scope_kind = 'GLOBAL'
      and scope.effective_from <= pg_catalog.transaction_timestamp()
      and (scope.effective_to is null
        or scope.effective_to > pg_catalog.transaction_timestamp())
  ) into v_has_release_capability;

  if v_batch.current_confirmed_need_approval_snapshot_id is not null then
    select snapshot.*
    into v_snapshot
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    where snapshot.confirmed_need_approval_snapshot_id
      = v_batch.current_confirmed_need_approval_snapshot_id;
    if found then
      select actor.display_name
      into v_approved_actor_name
      from atlas_core.actors actor
      where actor.actor_id = v_snapshot.approved_by_actor_id;
    end if;
  end if;

  if v_batch.current_confirmed_need_release_id is not null then
    select release.*
    into v_release
    from atlas_planning.confirmed_need_releases release
    where release.confirmed_need_release_id
      = v_batch.current_confirmed_need_release_id;
    if found then
      select actor.display_name
      into v_released_actor_name
      from atlas_core.actors actor
      where actor.actor_id = v_release.released_by_actor_id;
    end if;
  end if;

  v_attempt_id := coalesce(
    v_batch.current_confirmed_need_validation_attempt_id,
    v_snapshot.confirmed_need_validation_attempt_id
  );
  if v_attempt_id is not null then
    select attempt.*
    into v_attempt
    from atlas_planning.confirmed_need_validation_attempts attempt
    where attempt.confirmed_need_validation_attempt_id = v_attempt_id
      and attempt.confirmed_need_batch_id = v_batch_id;
  end if;

  begin
    v_current_projection := atlas_core.rmvp_07_validated_facts_projection(
      v_batch_id,
      null
    );
    v_current_fingerprint :=
      atlas_core.rmvp_07_validated_facts_fingerprint(v_current_projection);
  exception when others then
    v_current_projection := null;
    v_current_fingerprint := null;
  end;

  if v_attempt.confirmed_need_validation_attempt_id is null then
    v_facts_changed_validation := null;
  else
    begin
      v_validation_projection :=
        atlas_core.rmvp_07_validated_facts_projection(
          v_batch_id,
          v_attempt.confirmed_need_validation_attempt_id
        );
      v_facts_changed_validation := v_current_projection is null
        or v_validation_projection is distinct from v_current_projection;
    exception when others then
      v_facts_changed_validation := true;
    end;
  end if;

  v_facts_changed_approval := case
    when v_snapshot.confirmed_need_approval_snapshot_id is null then null
    else v_current_fingerprint is null
      or v_current_fingerprint is distinct from
        v_snapshot.validated_fact_fingerprint
  end;

  v_validation_current :=
    v_attempt.confirmed_need_validation_attempt_id is not null
    and v_attempt.confirmed_need_batch_id = v_batch_id
    and v_attempt.source_kind = 'NEED_GENERATION'
    and v_attempt.outcome = 'VALIDATED'
    and v_attempt.resulting_batch_version = v_batch.version;
  v_validation_complete := case
    when v_batch.current_confirmed_need_validation_attempt_id is null
      then false
    else atlas_core.rmvp_07_validation_evidence_complete(
      v_batch_id,
      v_batch.current_confirmed_need_validation_attempt_id,
      v_batch.version
    )
  end;
  v_approval_current :=
    v_snapshot.confirmed_need_approval_snapshot_id is not null
    and v_snapshot.confirmed_need_batch_id = v_batch_id
    and v_snapshot.source_kind = 'NEED_GENERATION'
    and v_snapshot.approved_version = v_batch.version;
  v_approval_complete := case
    when v_snapshot.confirmed_need_approval_snapshot_id is null then false
    else atlas_core.rmvp_07_snapshot_current_complete(
      v_batch_id,
      v_snapshot.confirmed_need_approval_snapshot_id,
      'APPROVED'
    )
  end;
  select exists (
    select 1
    from atlas_planning.purchase_handoff_batches handoff
    where handoff.confirmed_need_batch_id = v_batch_id
  ) into v_handoff_conflict;

  v_approval_code := case
    when v_batch.source_kind <> 'NEED_GENERATION'
      then 'APPROVAL_UNSUPPORTED_SOURCE_KIND'
    when v_batch.batch_status in ('APPROVED', 'RELEASED_FOR_PURCHASE_HANDOFF')
      then 'APPROVAL_ALREADY_COMPLETED'
    when v_batch.batch_status <> 'VALIDATED'
      then 'APPROVAL_BATCH_NOT_VALIDATED'
    when not v_has_approval_capability
      then 'APPROVAL_CAPABILITY_REQUIRED'
    when v_batch.current_confirmed_need_validation_attempt_id is null
      then 'APPROVAL_VALIDATION_MISSING'
    when not v_validation_current
      then 'APPROVAL_VALIDATION_NOT_CURRENT'
    when not v_validation_complete
      then 'APPROVAL_VALIDATION_EVIDENCE_INCOMPLETE'
    when coalesce(v_facts_changed_validation, true)
      then 'APPROVAL_VALIDATED_FACTS_CHANGED'
    when v_handoff_conflict
      then 'APPROVAL_PURCHASE_HANDOFF_CONFLICT'
    else null
  end;
  v_approval_message := case v_approval_code
    when 'APPROVAL_UNSUPPORTED_SOURCE_KIND'
      then 'Luồng nguồn này không dùng bước phê duyệt RMVP-07.'
    when 'APPROVAL_ALREADY_COMPLETED'
      then 'Lô nhu cầu đã được phê duyệt.'
    when 'APPROVAL_BATCH_NOT_VALIDATED'
      then 'Lô nhu cầu chưa ở trạng thái đã kiểm tra.'
    when 'APPROVAL_CAPABILITY_REQUIRED'
      then 'Bạn không có quyền phê duyệt lô nhu cầu.'
    when 'APPROVAL_VALIDATION_MISSING'
      then 'Không tìm thấy bằng chứng kiểm tra hiện hành.'
    when 'APPROVAL_VALIDATION_NOT_CURRENT'
      then 'Bằng chứng kiểm tra không còn là bằng chứng hiện hành.'
    when 'APPROVAL_VALIDATION_EVIDENCE_INCOMPLETE'
      then 'Bằng chứng kiểm tra chưa đầy đủ.'
    when 'APPROVAL_VALIDATED_FACTS_CHANGED'
      then 'Dữ liệu đã thay đổi; không thể phê duyệt.'
    when 'APPROVAL_PURCHASE_HANDOFF_CONFLICT'
      then 'Đã có bàn giao mua hàng không tương thích.'
    else null
  end;

  v_release_code := case
    when v_batch.source_kind <> 'NEED_GENERATION'
      then 'RELEASE_UNSUPPORTED_SOURCE_KIND'
    when v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
      then 'RELEASE_ALREADY_COMPLETED'
    when v_batch.batch_status <> 'APPROVED'
      then 'RELEASE_BATCH_NOT_APPROVED'
    when not v_has_release_capability
      then 'RELEASE_CAPABILITY_REQUIRED'
    when v_batch.current_confirmed_need_approval_snapshot_id is null
      then 'RELEASE_APPROVAL_MISSING'
    when not v_approval_current
      then 'RELEASE_APPROVAL_NOT_CURRENT'
    when not v_approval_complete
      then 'RELEASE_APPROVAL_EVIDENCE_INCOMPLETE'
    when coalesce(v_facts_changed_approval, true)
      then 'RELEASE_APPROVED_FACTS_CHANGED'
    when v_handoff_conflict
      then 'RELEASE_PURCHASE_HANDOFF_CONFLICT'
    else null
  end;
  v_release_message := case v_release_code
    when 'RELEASE_UNSUPPORTED_SOURCE_KIND'
      then 'Luồng nguồn này không dùng bước phát hành RMVP-07.'
    when 'RELEASE_ALREADY_COMPLETED'
      then 'Lô nhu cầu đã được phát hành.'
    when 'RELEASE_BATCH_NOT_APPROVED'
      then 'Lô nhu cầu chưa được phê duyệt.'
    when 'RELEASE_CAPABILITY_REQUIRED'
      then 'Bạn không có quyền phát hành lô nhu cầu.'
    when 'RELEASE_APPROVAL_MISSING'
      then 'Không tìm thấy bản phê duyệt hiện hành.'
    when 'RELEASE_APPROVAL_NOT_CURRENT'
      then 'Bản phê duyệt không còn là bản hiện hành.'
    when 'RELEASE_APPROVAL_EVIDENCE_INCOMPLETE'
      then 'Bằng chứng phê duyệt chưa đầy đủ.'
    when 'RELEASE_APPROVED_FACTS_CHANGED'
      then 'Bản phê duyệt không còn phù hợp; cần rà soát lại.'
    when 'RELEASE_PURCHASE_HANDOFF_CONFLICT'
      then 'Đã có bàn giao mua hàng không tương thích.'
    else null
  end;

  v_can_approve := v_approval_code is null;
  v_can_release := v_release_code is null;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'evidence_kind', history.evidence_kind,
    'evidence_id', history.evidence_id,
    'outcome', history.outcome,
    'source_version', history.source_version,
    'resulting_version', history.resulting_version,
    'actor', history.actor,
    'occurred_at', history.occurred_at,
    'reason_code', history.reason_code,
    'warning_count', history.warning_count
  ) order by history.occurred_at desc, history.resulting_version desc,
    history.evidence_id desc), '[]'::jsonb)
  into v_history
  from (
    select
      'VALIDATION'::text as evidence_kind,
      attempt.confirmed_need_validation_attempt_id as evidence_id,
      attempt.outcome,
      attempt.evaluated_batch_version as source_version,
      attempt.resulting_batch_version as resulting_version,
      pg_catalog.jsonb_build_object(
        'id', attempt.evaluated_by_actor_id,
        'name', actor.display_name
      ) as actor,
      attempt.evaluated_at as occurred_at,
      attempt.reason_code,
      attempt.warning_count
    from atlas_planning.confirmed_need_validation_attempts attempt
    join atlas_core.actors actor
      on actor.actor_id = attempt.evaluated_by_actor_id
    where attempt.confirmed_need_batch_id = v_batch_id
    union all
    select
      'APPROVAL',
      snapshot.confirmed_need_approval_snapshot_id,
      'APPROVED',
      attempt.resulting_batch_version,
      snapshot.approved_version,
      pg_catalog.jsonb_build_object(
        'id', snapshot.approved_by_actor_id,
        'name', actor.display_name
      ),
      snapshot.approved_at,
      'CONFIRMED_NEED_APPROVAL_REQUESTED',
      attempt.warning_count
    from atlas_planning.confirmed_need_approval_snapshots snapshot
    join atlas_planning.confirmed_need_validation_attempts attempt
      on attempt.confirmed_need_validation_attempt_id
        = snapshot.confirmed_need_validation_attempt_id
    join atlas_core.actors actor
      on actor.actor_id = snapshot.approved_by_actor_id
    where snapshot.confirmed_need_batch_id = v_batch_id
      and snapshot.source_kind = 'NEED_GENERATION'
    union all
    select
      'RELEASE',
      release.confirmed_need_release_id,
      'RELEASED_FOR_PURCHASE_HANDOFF',
      release.source_approved_batch_version,
      release.resulting_released_batch_version,
      pg_catalog.jsonb_build_object(
        'id', release.released_by_actor_id,
        'name', actor.display_name
      ),
      release.released_at,
      'CONFIRMED_NEED_RELEASE_REQUESTED',
      attempt.warning_count
    from atlas_planning.confirmed_need_releases release
    join atlas_planning.confirmed_need_approval_snapshots snapshot
      on snapshot.confirmed_need_approval_snapshot_id
        = release.confirmed_need_approval_snapshot_id
    join atlas_planning.confirmed_need_validation_attempts attempt
      on attempt.confirmed_need_validation_attempt_id
        = snapshot.confirmed_need_validation_attempt_id
    join atlas_core.actors actor
      on actor.actor_id = release.released_by_actor_id
    where release.confirmed_need_batch_id = v_batch_id
  ) history;

  return p_workbench
    || pg_catalog.jsonb_build_object(
      'allowed_actions', (p_workbench -> 'allowed_actions')
        || pg_catalog.jsonb_build_object(
          'approve_confirmed_needs', v_can_approve,
          'release_confirmed_needs_for_purchase_handoff', v_can_release
        ),
      'disabled_reason_codes', pg_catalog.jsonb_build_object(
        'approve_confirmed_needs', v_approval_code,
        'release_confirmed_needs_for_purchase_handoff', v_release_code
      ),
      'disabled_reasons', (p_workbench -> 'disabled_reasons')
        || pg_catalog.jsonb_build_object(
          'approve_confirmed_needs', v_approval_message,
          'release_confirmed_needs_for_purchase_handoff', v_release_message
        ),
      'approval', case
        when v_snapshot.confirmed_need_approval_snapshot_id is null then
          pg_catalog.jsonb_build_object(
            'current_snapshot_id', null,
            'approved_version', null,
            'source_validated_version', null,
            'validation_attempt_id', null,
            'validation_attempt_fingerprint', null,
            'validated_fact_fingerprint', null,
            'approved_actor', null,
            'approved_at', null,
            'line_count', 0,
            'warning_count', 0
          )
        else pg_catalog.jsonb_build_object(
          'current_snapshot_id',
            v_snapshot.confirmed_need_approval_snapshot_id,
          'approved_version', v_snapshot.approved_version,
          'source_validated_version', v_attempt.resulting_batch_version,
          'validation_attempt_id',
            v_snapshot.confirmed_need_validation_attempt_id,
          'validation_attempt_fingerprint', v_attempt.validation_fingerprint,
          'validated_fact_fingerprint',
            v_snapshot.validated_fact_fingerprint,
          'approved_actor', pg_catalog.jsonb_build_object(
            'id', v_snapshot.approved_by_actor_id,
            'name', v_approved_actor_name
          ),
          'approved_at', v_snapshot.approved_at,
          'line_count', (
            select count(*)
            from atlas_planning.confirmed_need_snapshot_lines snapshot_line
            where snapshot_line.confirmed_need_approval_snapshot_id
              = v_snapshot.confirmed_need_approval_snapshot_id
          ),
          'warning_count', v_attempt.warning_count
        ) end,
      'release', case
        when v_release.confirmed_need_release_id is null then
          pg_catalog.jsonb_build_object(
            'current_release_id', null,
            'approval_snapshot_id', null,
            'source_approved_version', null,
            'resulting_released_version', null,
            'released_actor', null,
            'released_at', null
          )
        else pg_catalog.jsonb_build_object(
          'current_release_id', v_release.confirmed_need_release_id,
          'approval_snapshot_id',
            v_release.confirmed_need_approval_snapshot_id,
          'source_approved_version',
            v_release.source_approved_batch_version,
          'resulting_released_version',
            v_release.resulting_released_batch_version,
          'released_actor', pg_catalog.jsonb_build_object(
            'id', v_release.released_by_actor_id,
            'name', v_released_actor_name
          ),
          'released_at', v_release.released_at
        ) end,
      'facts_changed_since_validation', v_facts_changed_validation,
      'facts_changed_since_approval', v_facts_changed_approval,
      'lifecycle_history', v_history
    );
end;
$$;

create policy rmvp_07_approval_snapshot_select
on atlas_planning.confirmed_need_approval_snapshots
for select to atlas_confirmed_need_review_runtime using (true);
create policy rmvp_07_approval_snapshot_insert
on atlas_planning.confirmed_need_approval_snapshots
for insert to atlas_confirmed_need_review_runtime
with check (source_kind = 'NEED_GENERATION');
create policy rmvp_07_approval_snapshot_lock
on atlas_planning.confirmed_need_approval_snapshots
for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (false);

create policy rmvp_07_snapshot_line_select
on atlas_planning.confirmed_need_snapshot_lines
for select to atlas_confirmed_need_review_runtime using (true);
create policy rmvp_07_snapshot_line_insert
on atlas_planning.confirmed_need_snapshot_lines
for insert to atlas_confirmed_need_review_runtime with check (true);
create policy rmvp_07_snapshot_line_lock
on atlas_planning.confirmed_need_snapshot_lines
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);

create policy rmvp_07_release_select
on atlas_planning.confirmed_need_releases
for select to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION');
create policy rmvp_07_release_insert
on atlas_planning.confirmed_need_releases
for insert to atlas_confirmed_need_review_runtime
with check (source_kind = 'NEED_GENERATION');
create policy rmvp_07_release_lock
on atlas_planning.confirmed_need_releases
for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (false);

create policy rmvp_07_validation_attempt_lock
on atlas_planning.confirmed_need_validation_attempts
for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (false);
create policy rmvp_07_validation_line_lock
on atlas_planning.confirmed_need_validation_lines
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);
create policy rmvp_07_validation_issue_lock
on atlas_planning.confirmed_need_validation_issues
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);
create policy rmvp_07_decision_lock
on atlas_planning.confirmed_need_line_decisions
for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (false);
create policy rmvp_07_contribution_lock
on atlas_planning.confirmed_need_line_revision_contributions
for update to atlas_confirmed_need_review_runtime
using (true) with check (false);
create policy rmvp_07_purchase_handoff_select
on atlas_planning.purchase_handoff_batches
for select to atlas_confirmed_need_review_runtime using (true);

reset role;

grant select on
  atlas_planning.confirmed_need_approval_snapshots,
  atlas_planning.confirmed_need_snapshot_lines,
  atlas_planning.confirmed_need_releases,
  atlas_planning.purchase_handoff_batches
to atlas_confirmed_need_review_runtime;
grant insert on
  atlas_planning.confirmed_need_approval_snapshots,
  atlas_planning.confirmed_need_snapshot_lines,
  atlas_planning.confirmed_need_releases
to atlas_confirmed_need_review_runtime;

grant update (
  batch_status,
  version,
  approved_by_actor_id,
  approved_at,
  released_by_actor_id,
  released_at,
  current_confirmed_need_validation_attempt_id,
  current_confirmed_need_approval_snapshot_id,
  current_confirmed_need_release_id,
  updated_at
) on atlas_planning.confirmed_need_batches
to atlas_confirmed_need_review_runtime;

grant update (confirmed_need_validation_attempt_id)
on atlas_planning.confirmed_need_validation_attempts
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_validation_line_id)
on atlas_planning.confirmed_need_validation_lines
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_validation_issue_id)
on atlas_planning.confirmed_need_validation_issues
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_line_decision_id)
on atlas_planning.confirmed_need_line_decisions
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_line_revision_contribution_id)
on atlas_planning.confirmed_need_line_revision_contributions
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_approval_snapshot_id)
on atlas_planning.confirmed_need_approval_snapshots
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_snapshot_line_id)
on atlas_planning.confirmed_need_snapshot_lines
to atlas_confirmed_need_review_runtime;
grant update (confirmed_need_release_id)
on atlas_planning.confirmed_need_releases
to atlas_confirmed_need_review_runtime;

revoke execute on function
  atlas_core.rmvp_07_canonical_decimal(numeric),
  atlas_core.rmvp_07_validated_facts_projection(uuid, uuid),
  atlas_core.rmvp_07_validated_facts_fingerprint(jsonb),
  atlas_core.rmvp_07_error(
    jsonb, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.rmvp_07_validate_command(jsonb, text),
  atlas_core.rmvp_07_authorize(jsonb, text, text),
  atlas_core.rmvp_07_validation_evidence_complete(uuid, uuid, bigint),
  atlas_core.rmvp_07_snapshot_current_complete(uuid, uuid, text),
  atlas_core.rmvp_07_extend_workbench(jsonb, uuid),
  atlas_core.rmvp_07_record_change(
    jsonb, uuid, uuid, uuid, bigint, bigint, text, jsonb, jsonb
  ),
  atlas_planning.rmvp_07_immutable_approval_release_evidence(),
  atlas_planning.rmvp_07_approval_release_integrity()
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.rmvp_07_canonical_decimal(numeric),
  atlas_core.rmvp_07_validated_facts_projection(uuid, uuid),
  atlas_core.rmvp_07_validated_facts_fingerprint(jsonb),
  atlas_core.rmvp_07_error(
    jsonb, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.rmvp_07_validate_command(jsonb, text),
  atlas_core.rmvp_07_authorize(jsonb, text, text),
  atlas_core.rmvp_07_validation_evidence_complete(uuid, uuid, bigint),
  atlas_core.rmvp_07_snapshot_current_complete(uuid, uuid, text),
  atlas_core.rmvp_07_extend_workbench(jsonb, uuid),
  atlas_core.rmvp_07_record_change(
    jsonb, uuid, uuid, uuid, bigint, bigint, text, jsonb, jsonb
  ),
  atlas_planning.rmvp_07_immutable_approval_release_evidence(),
  atlas_planning.rmvp_07_approval_release_integrity()
to atlas_confirmed_need_review_runtime;

grant atlas_confirmed_need_review_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api, atlas_planning
to atlas_confirmed_need_review_runtime;

alter function atlas_core.rmvp_07_canonical_decimal(numeric)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_validated_facts_projection(uuid, uuid)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_validated_facts_fingerprint(jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_error(
  jsonb, text, text, text, boolean, jsonb, jsonb, bigint
) owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_validate_command(jsonb, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_authorize(jsonb, text, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_validation_evidence_complete(
  uuid, uuid, bigint
) owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_snapshot_current_complete(uuid, uuid, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_extend_workbench(jsonb, uuid)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_07_record_change(
  jsonb, uuid, uuid, uuid, bigint, bigint, text, jsonb, jsonb
) owner to atlas_confirmed_need_review_runtime;
alter function atlas_planning.rmvp_07_approval_release_integrity()
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_api.approve_confirmed_needs(jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)
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
  v_actor_id uuid;
  v_payload jsonb := request -> 'payload';
  v_workbench jsonb;
begin
  v_error := atlas_core.rmvp_05_validate_read(request, v_name);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_05_authorize_global(
    request, 'confirmed_need_review.read', v_name, true
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_workbench := atlas_core.rmvp_05_workbench_payload(
    atlas_core.pa_05b_safe_uuid(
      v_payload ->> 'confirmed_need_batch_id'
    ),
    coalesce(v_payload -> 'filters', '{}'::jsonb),
    coalesce(
      atlas_core.pa_05b_safe_bigint(
        v_payload ->> 'line_offset'
      )::integer,
      0
    ),
    coalesce(
      atlas_core.pa_05b_safe_bigint(
        v_payload ->> 'line_limit'
      )::integer,
      100
    )
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
    'workbench', atlas_core.rmvp_07_extend_workbench(
      atlas_core.rmvp_06_extend_workbench(v_workbench),
      v_actor_id
    )
  );
exception when others then
  return atlas_core.rmvp_05_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'The Confirmed Need review could not be returned safely.', true
  );
end;
$$;

reset role;

revoke create on schema atlas_core, atlas_api, atlas_planning
from atlas_confirmed_need_review_runtime;

revoke execute on function
  atlas_api.approve_confirmed_needs(jsonb),
  atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)
from public, anon, authenticated, service_role;
grant usage on schema atlas_api to authenticated;
grant execute on function
  atlas_api.approve_confirmed_needs(jsonb),
  atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)
to authenticated;

comment on function atlas_api.approve_confirmed_needs(jsonb) is
  'RMVP-07.v1 idempotent complete-batch NEED_GENERATION Confirmed Need approval bound to exact successful validation evidence.';
comment on function
  atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb) is
  'RMVP-07.v1 idempotent Planning release of one exact immutable NEED_GENERATION approval for later Purchase Handoff.';

revoke atlas_confirmed_need_review_runtime from postgres;
