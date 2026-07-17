-- PA-05C-H2: extend the existing private command/audit scope resolver across
-- the exact current Atlas aggregate vocabulary. The public PA-05C.v1 read
-- contract, response shape, and 100-event bound remain unchanged.

create or replace function atlas_core.pa_05c_aggregate_scope(
  aggregate_type text,
  aggregate_id uuid
)
returns table (
  customer_id uuid,
  delivery_location_id uuid,
  dispatch_trip_id uuid,
  public_reference text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with current_requirements as (
    select
      dr.dispatch_requirement_id,
      drr.dispatch_requirement_revision_id,
      drr.purchase_handoff_revision_id,
      dr.customer_id,
      dr.delivery_location_id,
      fa.fulfilment_allocation_id,
      far.fulfilment_allocation_revision_id
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_id = dr.dispatch_requirement_id
     and drr.is_current
     and drr.revision_status = 'RELEASED'
    left join atlas_procurement.fulfilment_allocations fa
      on fa.dispatch_requirement_id = dr.dispatch_requirement_id
    left join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_id = fa.fulfilment_allocation_id
     and far.is_current
    where dr.requirement_status = 'RELEASED'
  ), admitted_trips as (
    select distinct
      dpr.dispatch_requirement_revision_id,
      dpr.fulfilment_allocation_revision_id,
      dt.dispatch_trip_id,
      dt.trip_reference
    from atlas_dispatch.dispatch_plan_requirements dpr
    join atlas_dispatch.dispatch_plans dp
      on dp.dispatch_plan_id = dpr.dispatch_plan_id
     and dp.plan_status <> 'CANCELLED'
    join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    join atlas_dispatch.dispatch_trips dt
      on dt.dispatch_trip_id = ds.dispatch_trip_id
     and dt.dispatch_plan_id = dp.dispatch_plan_id
     and dt.trip_status not in ('CANCELLED', 'VOIDED')
  ), current_requirement_scopes as (
    select
      crl.*,
      at.dispatch_trip_id,
      at.trip_reference
    from current_requirements crl
    left join admitted_trips at
      on at.dispatch_requirement_revision_id = crl.dispatch_requirement_revision_id
     and at.fulfilment_allocation_revision_id = crl.fulfilment_allocation_revision_id
  ), current_source_scopes as (
    select
      crs.*,
      phb.purchase_handoff_batch_id,
      wo.wholesale_order_id,
      wo.customer_order_reference
    from current_requirement_scopes crs
    join atlas_planning.purchase_handoff_revisions phr
      on phr.purchase_handoff_revision_id = crs.purchase_handoff_revision_id
     and phr.is_current
     and phr.revision_status = 'RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_handoff_batches phb
      on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
     and phb.handoff_status = 'RELEASED_TO_PROCUREMENT'
    join atlas_planning.confirmed_need_batches cnb
      on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
     and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
    join atlas_planning.wholesale_orders wo
      on wo.wholesale_order_id = cnb.wholesale_order_id
     and wo.order_status = 'RELEASED'
  ), current_allocation_line_scopes as (
    select
      falr.fulfilment_allocation_line_revision_id,
      fa.fulfilment_allocation_id,
      far.fulfilment_allocation_revision_id,
      drr.dispatch_requirement_revision_id,
      dr.customer_id,
      dr.delivery_location_id,
      at.dispatch_trip_id,
      at.trip_reference
    from atlas_procurement.fulfilment_allocation_line_revisions falr
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
     and far.is_current
    join atlas_procurement.fulfilment_allocations fa
      on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
     and drr.is_current
     and drr.revision_status = 'RELEASED'
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
     and dr.dispatch_requirement_id = fa.dispatch_requirement_id
    left join admitted_trips at
     on at.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
     and at.fulfilment_allocation_revision_id = far.fulfilment_allocation_revision_id
    where dr.requirement_status = 'RELEASED'
  ), current_purchase_order_line_scopes as (
    select
      po.purchase_order_id,
      po.document_number,
      polr.purchase_order_line_revision_id,
      cals.customer_id,
      cals.delivery_location_id,
      cals.dispatch_trip_id,
      cals.trip_reference
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id = po.purchase_order_id
     and por.is_current
     and por.revision_status = 'RELEASED_TO_SUPPLIER'
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.purchase_order_revision_id = por.purchase_order_revision_id
    join current_allocation_line_scopes cals
      on cals.fulfilment_allocation_line_revision_id = polr.fulfilment_allocation_line_revision_id
    where po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
  ), resolved_scopes as (
    select
      crs.customer_id,
      crs.delivery_location_id,
      crs.dispatch_trip_id,
      coalesce(crs.customer_order_reference, crs.wholesale_order_id::text) as public_reference
    from current_source_scopes crs
    where pa_05c_aggregate_scope.aggregate_type = 'WholesaleOrder'
      and crs.wholesale_order_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      crs.customer_id,
      crs.delivery_location_id,
      crs.dispatch_trip_id,
      crs.purchase_handoff_batch_id::text
    from current_source_scopes crs
    where pa_05c_aggregate_scope.aggregate_type = 'PurchaseHandoff'
      and crs.purchase_handoff_batch_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      crs.customer_id,
      crs.delivery_location_id,
      crs.dispatch_trip_id,
      crs.dispatch_requirement_id::text
    from current_requirement_scopes crs
    where pa_05c_aggregate_scope.aggregate_type in ('DispatchRequirement', 'DISPATCH_REQUIREMENT')
      and crs.dispatch_requirement_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      crs.customer_id,
      crs.delivery_location_id,
      crs.dispatch_trip_id,
      crs.fulfilment_allocation_id::text
    from current_requirement_scopes crs
    where pa_05c_aggregate_scope.aggregate_type = 'FulfilmentAllocation'
      and crs.fulfilment_allocation_id = pa_05c_aggregate_scope.aggregate_id
      and crs.fulfilment_allocation_revision_id is not null

    union all

    select
      cpols.customer_id,
      cpols.delivery_location_id,
      cpols.dispatch_trip_id,
      coalesce(cpols.document_number, cpols.purchase_order_id::text)
    from current_purchase_order_line_scopes cpols
    where pa_05c_aggregate_scope.aggregate_type = 'PurchaseOrder'
      and cpols.purchase_order_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      cpols.customer_id,
      cpols.delivery_location_id,
      cpols.dispatch_trip_id,
      sre.evidence_reference
    from atlas_evidence.supplier_receiving_evidence sre
    join current_purchase_order_line_scopes cpols
      on cpols.purchase_order_line_revision_id = sre.purchase_order_line_revision_id
    where pa_05c_aggregate_scope.aggregate_type in (
        'SupplierReceivingEvidence', 'SUPPLIER_RECEIVING_EVIDENCE'
      )
      and sre.supplier_receiving_evidence_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      cals.customer_id,
      cals.delivery_location_id,
      cals.dispatch_trip_id,
      ea.evidence_application_id::text
    from atlas_evidence.evidence_applications ea
    join current_allocation_line_scopes cals
      on cals.fulfilment_allocation_line_revision_id = ea.fulfilment_allocation_line_revision_id
    where pa_05c_aggregate_scope.aggregate_type in ('EvidenceApplication', 'EVIDENCE_APPLICATION')
      and ea.evidence_application_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      dr.customer_id,
      dr.delivery_location_id,
      at.dispatch_trip_id,
      dp.plan_reference
    from atlas_dispatch.dispatch_plans dp
    join atlas_dispatch.dispatch_plan_requirements dpr
      on dpr.dispatch_plan_id = dp.dispatch_plan_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    left join admitted_trips at
      on at.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
     and at.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    where pa_05c_aggregate_scope.aggregate_type = 'DispatchPlan'
      and dp.dispatch_plan_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      dr.customer_id,
      dr.delivery_location_id,
      dt.dispatch_trip_id,
      dt.trip_reference
    from atlas_dispatch.dispatch_trips dt
    join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_trip_id = dt.dispatch_trip_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    where pa_05c_aggregate_scope.aggregate_type in ('DispatchTrip', 'DISPATCH_TRIP')
      and dt.dispatch_trip_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      dr.customer_id,
      dr.delivery_location_id,
      dt.dispatch_trip_id,
      dt.trip_reference
    from atlas_dispatch.dispatch_stops ds
    join atlas_dispatch.dispatch_trips dt
      on dt.dispatch_trip_id = ds.dispatch_trip_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    where pa_05c_aggregate_scope.aggregate_type = 'DISPATCH_STOP'
      and ds.dispatch_stop_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      dr.customer_id,
      dr.delivery_location_id,
      dl.dispatch_trip_id,
      dt.trip_reference
    from atlas_dispatch.dispatch_loads dl
    join atlas_dispatch.dispatch_trips dt
      on dt.dispatch_trip_id = dl.dispatch_trip_id
    join atlas_dispatch.dispatch_plan_requirements dpr
      on dpr.dispatch_plan_id = dt.dispatch_plan_id
     and dpr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
     and dpr.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    where pa_05c_aggregate_scope.aggregate_type in ('DispatchLoad', 'DISPATCH_LOAD')
      and dl.dispatch_load_id = pa_05c_aggregate_scope.aggregate_id

    union all

    select
      dr.customer_id,
      dr.delivery_location_id,
      dt.dispatch_trip_id,
      dt.trip_reference
    from atlas_dispatch.delivery_confirmations dc
    join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_stop_id = dc.dispatch_stop_id
    join atlas_dispatch.dispatch_trips dt
      on dt.dispatch_trip_id = ds.dispatch_trip_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    where pa_05c_aggregate_scope.aggregate_type in (
        'DeliveryConfirmation', 'DELIVERY_CONFIRMATION'
      )
      and dc.delivery_confirmation_id = pa_05c_aggregate_scope.aggregate_id
  )
  select distinct
    rs.customer_id,
    rs.delivery_location_id,
    rs.dispatch_trip_id,
    rs.public_reference
  from resolved_scopes rs;
$$;

-- These are the only current helper joins that atlas_read_runtime could not
-- already perform. Each relation has forced RLS, so the SELECT grant is paired
-- with a role-specific SELECT-only policy.
grant select on
  atlas_planning.confirmed_need_batches,
  atlas_planning.purchase_handoff_batches,
  atlas_planning.purchase_handoff_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_dispatch.dispatch_plan_requirements
to atlas_read_runtime;

create policy pa_05c_h2_read_select on atlas_planning.confirmed_need_batches
  for select to atlas_read_runtime using (true);
create policy pa_05c_h2_read_select on atlas_planning.purchase_handoff_batches
  for select to atlas_read_runtime using (true);
create policy pa_05c_h2_read_select on atlas_planning.purchase_handoff_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05c_h2_read_select on atlas_procurement.fulfilment_allocations
  for select to atlas_read_runtime using (true);
create policy pa_05c_h2_read_select on atlas_dispatch.dispatch_plan_requirements
  for select to atlas_read_runtime using (true);

alter function atlas_core.pa_05c_aggregate_scope(text, uuid) owner to atlas_owner;

revoke all on function atlas_core.pa_05c_aggregate_scope(text, uuid)
from public, anon, authenticated, service_role, atlas_command_runtime,
  atlas_evidence_command_runtime, atlas_dispatch_command_runtime,
  atlas_planning_command_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;
grant execute on function atlas_core.pa_05c_aggregate_scope(text, uuid)
to atlas_read_runtime;

comment on function atlas_core.pa_05c_aggregate_scope(text, uuid)
  is 'PA-05C-H2 current relational scope resolver for the exact reviewed Atlas command aggregate vocabulary.';
