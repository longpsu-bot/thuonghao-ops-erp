-- CONFIRMED-NEED-DOWNSTREAM-CORRECTION-01
-- A supplier commitment freezes its own snapshot, not upstream School facts.

reset role;
grant atlas_owner, atlas_planning_command_runtime,
  atlas_confirmed_need_review_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_planning_command_runtime,
  atlas_confirmed_need_review_runtime;
reset role;

set role atlas_planning_command_runtime;
create or replace function atlas_core.issue_222_chain_payload(run_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  with chain as (
    select run.need_generation_run_id,run.period_start,run.period_end,run.run_status,
      run.version need_generation_run_version,batch.confirmed_need_batch_id,
      batch.batch_status confirmed_need_status,batch.version confirmed_need_batch_version,
      batch.current_confirmed_need_release_id is not null or batch.released_at is not null
        planning_release_occurred
    from atlas_planning.need_generation_runs run
    left join atlas_planning.confirmed_need_batches batch
      on batch.source_kind='NEED_GENERATION'
     and batch.current_need_generation_run_id=run.need_generation_run_id
    where run.need_generation_run_id=issue_222_chain_payload.run_id
  ), handoff as (
    select
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_purchase_handoff_source_kind(
          h.purchase_handoff_batch_id)='WHOLESALE') active_handoff_exists,
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_purchase_handoff_source_kind(
          h.purchase_handoff_batch_id)='SCHOOL_CATERING')
        active_school_catering_handoff_exists,
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_handoff_has_released_po(
          h.purchase_handoff_batch_id)) released_school_catering_po_exists,
      coalesce(jsonb_agg(jsonb_build_object(
        'purchase_handoff_batch_id',h.purchase_handoff_batch_id,
        'handoff_status',h.handoff_status,'version',h.version,'source_kind',
        atlas_core.school_catering_purchase_handoff_source_kind(
          h.purchase_handoff_batch_id),
        'released_school_catering_po_exists',
        atlas_core.school_catering_handoff_has_released_po(
          h.purchase_handoff_batch_id))
        order by h.created_at,h.purchase_handoff_batch_id)
        filter(where h.purchase_handoff_batch_id is not null),'[]'::jsonb) handoffs
    from chain left join atlas_planning.purchase_handoff_batches h
      on h.confirmed_need_batch_id=chain.confirmed_need_batch_id
  ), downstream as (
    select exists(
      select 1 from chain
      join atlas_planning.purchase_handoff_batches h
        on h.confirmed_need_batch_id=chain.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions hr
        on hr.purchase_handoff_batch_id=h.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.purchase_handoff_revision_id=hr.purchase_handoff_revision_id
      join atlas_procurement.fulfilment_allocations allocation
        on allocation.dispatch_requirement_id=drr.dispatch_requirement_id
    ) wholesale_commitment_exists
  )
  select to_jsonb(chain) || jsonb_build_object(
    'is_legacy_range',chain.period_start<>chain.period_end,
    'active_purchase_handoff_exists',coalesce(handoff.active_handoff_exists,false),
    'active_school_catering_handoff_exists',
      coalesce(handoff.active_school_catering_handoff_exists,false),
    'released_school_catering_po_exists',
      coalesce(handoff.released_school_catering_po_exists,false),
    'purchase_handoffs',handoff.handoffs,
    -- Supplier-direct Wholesale execution remains blocked. A released School-
    -- catering PO is reported separately and never blocks an upstream successor.
    'later_downstream_commitment_exists',downstream.wholesale_commitment_exists)
  from chain cross join handoff cross join downstream;
$$;

reset role;
set role atlas_confirmed_need_review_runtime;
create or replace function atlas_core.issue_222_reopen_confirmed_need(
  confirmed_need_batch_id uuid,expected_version bigint
) returns atlas_planning.confirmed_need_batches
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_handoff_id uuid;
begin
  select h.purchase_handoff_batch_id into v_handoff_id
  from atlas_planning.purchase_handoff_batches h
  where h.confirmed_need_batch_id=issue_222_reopen_confirmed_need.confirmed_need_batch_id
    and h.handoff_status not in ('INVALIDATED','REOPENED') for update;
  if v_handoff_id is not null then
    if atlas_core.school_catering_purchase_handoff_source_kind(v_handoff_id)
        <> 'SCHOOL_CATERING' then
      raise exception using errcode='P0001',
        message='Wholesale Purchase Handoff correction remains blocked';
    end if;
    update atlas_planning.purchase_handoff_revisions
      set revision_status='INVALIDATED',is_current=false
      where purchase_handoff_batch_id=v_handoff_id and is_current;
    update atlas_planning.purchase_handoff_batches
      set handoff_status='INVALIDATED',version=version+1,
        updated_at=transaction_timestamp()
      where purchase_handoff_batch_id=v_handoff_id;
  end if;
  update atlas_planning.confirmed_need_batches batch
    set batch_status='REOPENED',version=batch.version+1,
      current_confirmed_need_validation_attempt_id=null,
      current_confirmed_need_approval_snapshot_id=null,
      current_confirmed_need_release_id=null,updated_at=transaction_timestamp()
    where batch.confirmed_need_batch_id=
      issue_222_reopen_confirmed_need.confirmed_need_batch_id
      and batch.version=issue_222_reopen_confirmed_need.expected_version
      and batch.source_kind='NEED_GENERATION'
      and batch.batch_status not in ('DRAFT_REVIEW','REOPENED')
    returning batch.* into v_batch;
  if v_batch.confirmed_need_batch_id is null then
    raise exception using errcode='P0001',
      message='Confirmed Need reopen precondition failed';
  end if;
  return v_batch;
end;
$$;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_planning_command_runtime,
  atlas_confirmed_need_review_runtime;
reset role;
