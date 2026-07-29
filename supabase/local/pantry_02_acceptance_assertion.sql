-- PANTRY-02 local-only physical acceptance assertions.
-- Invoked only after scripts/verify-local-pantry02.mjs has proved a loopback URL.

do $pantry_02_acceptance$
declare
  target_batch atlas_planning.pantry_need_batches%rowtype;
  downstream_count bigint;
begin
  select batch.*
    into target_batch
  from atlas_planning.pantry_need_batches batch
  order by batch.updated_at desc, batch.pantry_need_batch_id desc
  limit 1;

  if target_batch.pantry_need_batch_id is null
    or target_batch.pantry_need_batch_status <> 'APPROVED'
    or target_batch.version <> 8
    or not target_batch.no_additions_confirmed
  then
    raise exception
      'PANTRY-02 local batch did not finish as approved zero-additions version 8';
  end if;

  if (
    select count(*)
    from atlas_planning.pantry_need_approval_snapshots snapshot
    where snapshot.pantry_need_batch_id = target_batch.pantry_need_batch_id
  ) <> 2
    or not exists (
      select 1
      from atlas_planning.pantry_need_approval_snapshots snapshot
      where snapshot.pantry_need_batch_id =
        target_batch.pantry_need_batch_id
        and snapshot.approved_batch_version = 4
        and not snapshot.no_additions_confirmed
        and snapshot.line_count = 1
    )
    or not exists (
      select 1
      from atlas_planning.pantry_need_approval_snapshots snapshot
      where snapshot.pantry_need_batch_id =
        target_batch.pantry_need_batch_id
        and snapshot.approved_batch_version = 8
        and snapshot.no_additions_confirmed
        and snapshot.line_count = 0
    )
  then
    raise exception
      'PANTRY-02 local approval snapshot history is not exact';
  end if;

  if (
    select count(*)
    from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
    join atlas_planning.pantry_need_approval_snapshots snapshot
      on snapshot.pantry_need_approval_snapshot_id =
        snapshot_line.pantry_need_approval_snapshot_id
    where snapshot.pantry_need_batch_id = target_batch.pantry_need_batch_id
  ) <> 1 then
    raise exception
      'PANTRY-02 local zero successor fabricated or altered snapshot lines';
  end if;

  if (
    select count(*)
    from atlas_planning.pantry_need_lines line
    where line.pantry_need_batch_id = target_batch.pantry_need_batch_id
      and line.line_status = 'ACTIVE'
  ) <> 0
    or (
      select count(*)
      from atlas_planning.pantry_need_lines line
      where line.pantry_need_batch_id = target_batch.pantry_need_batch_id
        and line.line_status = 'INVALID'
    ) <> 1
  then
    raise exception
      'PANTRY-02 local zero successor did not invalidate the stable working line';
  end if;

  if (
    select count(*)
    from atlas_audit.domain_events event
    where event.aggregate_type = 'PantryNeedBatch'
      and event.aggregate_id = target_batch.pantry_need_batch_id
  ) <> 8
    or (
      select count(*)
      from atlas_audit.audit_events audit
      where audit.aggregate_type = 'PantryNeedBatch'
        and audit.aggregate_id = target_batch.pantry_need_batch_id
    ) <> 8
  then
    raise exception
      'PANTRY-02 local material actions lack exact event or audit evidence';
  end if;

  if not exists (
    select 1
    from atlas_audit.domain_events event
    where event.aggregate_type = 'PantryNeedBatch'
      and event.aggregate_id = target_batch.pantry_need_batch_id
      and event.event_type = 'PantryDraftReplaced'
      and event.aggregate_version = 6
      and event.payload_summary ->> 'status' = 'REOPENED'
  )
    or not exists (
      select 1
      from atlas_audit.audit_events audit
      where audit.aggregate_type = 'PantryNeedBatch'
        and audit.aggregate_id = target_batch.pantry_need_batch_id
        and audit.event_type = 'PantryDraftReplaced'
        and audit.aggregate_version_after = 6
        and audit.after_summary ->> 'status' = 'REOPENED'
    )
  then
    raise exception
      'PANTRY-02 local version 6 correction did not preserve REOPENED status';
  end if;

  select
    (select count(*) from atlas_planning.planning_input_sets)
    + (select count(*) from atlas_planning.need_generation_runs)
    + (select count(*) from atlas_planning.confirmed_need_batches)
    + (select count(*) from atlas_planning.purchase_handoff_batches)
    + (select count(*) from atlas_planning.wholesale_orders)
    + (select count(*) from atlas_procurement.fulfilment_allocations)
    + (select count(*) from atlas_procurement.purchase_orders)
    + (select count(*) from atlas_evidence.supplier_receiving_evidence)
    + (select count(*) from atlas_dispatch.dispatch_plans)
    into downstream_count;

  if downstream_count <> 0 then
    raise exception
      'PANTRY-02 local lifecycle unexpectedly mutated a downstream object';
  end if;
end
$pantry_02_acceptance$;
