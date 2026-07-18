-- PA-05C-H3: expose bounded current command context through the existing
-- dispatch Evidence readiness read without changing the public API surface.

-- READ-02 is deliberately owned by the no-login read runtime. PostgreSQL
-- requires temporary membership to replace an existing function owned by
-- that role; temporary SET authority is revoked before this migration commits.
grant atlas_read_runtime to postgres with set true;

create or replace function atlas_api.get_dispatch_evidence_readiness(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_dispatch_evidence_readiness';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_trip_id uuid;
  v_requirement_revision_id uuid;
  v_source_revision_id uuid;
  v_selector_count integer;
  v_scope_count integer;
  v_unauthorized_scope_count integer;
  v_scope_customer_id uuid;
  v_scope_location_id uuid;
  v_scope_trip_id uuid;
  v_lineage_conflict_count integer;
  v_items jsonb;
begin
  v_error := atlas_core.pa_05c_validate_envelope(request, v_name);
  if v_error is not null then return v_error; end if;

  v_trip_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'dispatch_trip_id');
  v_requirement_revision_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'dispatch_requirement_revision_id'
  );
  v_source_revision_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'wholesale_order_line_revision_id'
  );
  v_selector_count := (v_trip_id is not null)::integer
    + (v_requirement_revision_id is not null)::integer
    + (v_source_revision_id is not null)::integer;
  if v_selector_count <> 1 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'UNBOUNDED_OR_AMBIGUOUS_SELECTOR',
      'Provide exactly one supported bounded readiness selector.'
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'REPORTING', v_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  with selector_scopes as (
    select distinct dr.customer_id, dr.delivery_location_id, dt.dispatch_trip_id
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_id = dr.dispatch_requirement_id
    left join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    left join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions cnlr
      on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
    where (v_trip_id is not null and dt.dispatch_trip_id = v_trip_id)
       or (v_requirement_revision_id is not null and drr.dispatch_requirement_revision_id = v_requirement_revision_id)
       or (v_source_revision_id is not null and cnlr.wholesale_order_line_revision_id = v_source_revision_id)
  )
  select count(*)::integer,
    count(*) filter (where not atlas_core.pa_05c_actor_can_read_scope(
      v_actor_id, 'dispatch_evidence_readiness.read', customer_id, delivery_location_id, dispatch_trip_id
    ))::integer,
    (pg_catalog.array_agg(customer_id order by customer_id))[1],
    (pg_catalog.array_agg(delivery_location_id order by delivery_location_id))[1],
    (pg_catalog.array_agg(dispatch_trip_id order by dispatch_trip_id))[1]
  into v_scope_count, v_unauthorized_scope_count,
    v_scope_customer_id, v_scope_location_id, v_scope_trip_id
  from selector_scopes;

  if v_scope_count = 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'NOT_FOUND', 'No supplier-direct readiness context matches the selector.'
    );
  end if;
  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'dispatch_evidence_readiness.read', 'REPORTING', v_name,
    v_scope_customer_id, v_scope_location_id, v_scope_trip_id
  );
  if v_error is not null and v_error ->> 'error_code' = 'CAPABILITY_DENIED' then return v_error; end if;
  if v_unauthorized_scope_count > 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'SCOPE_DENIED', 'The selected readiness context includes an unauthorized Atlas scope.'
    );
  end if;

  with lines as (
    select
      dr.customer_id, dr.delivery_location_id, dr.service_date,
      dr.dispatch_requirement_id,
      drr.dispatch_requirement_revision_id, drlr.dispatch_requirement_line_revision_id,
      historical_falr.fulfilment_allocation_line_revision_id,
      historical_falr.allocated_quantity,
      historical_falr.unit_id, dt.dispatch_trip_id, dt.trip_reference, dt.trip_status,
      ds.dispatch_stop_id, ds.stop_sequence, ds.stop_status,
      coalesce(l.loaded_quantity, 0) as loaded_quantity,
      coalesce(e.valid_applied_quantity, 0) as valid_applied_quantity,
      coalesce(e.has_invalid_evidence, false) as has_invalid_evidence,
      coalesce(e.has_evidence, false) as has_evidence,
      coalesce(l.delivered, false) as delivered,
      coalesce(e.evidence_references, '[]'::jsonb) as evidence_references,
      current_allocation.context_count as current_allocation_context_count,
      current_allocation.fulfilment_allocation_context,
      coalesce(purchase_context.purchase_commitments, '[]'::jsonb) as purchase_commitments,
      coalesce(purchase_context.conflict_count, 0) as purchase_commitment_conflict_count
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_id = dr.dispatch_requirement_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions cnlr
      on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
    join atlas_procurement.fulfilment_allocation_line_revisions historical_falr
      on historical_falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
    join atlas_procurement.fulfilment_allocation_lines fal
      on fal.fulfilment_allocation_line_id = historical_falr.fulfilment_allocation_line_id
    join atlas_procurement.fulfilment_allocations fa
      on fa.fulfilment_allocation_id = fal.fulfilment_allocation_id
     and fa.dispatch_requirement_id = dr.dispatch_requirement_id
    left join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    left join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    left join lateral (
      select
        count(*)::integer as context_count,
        (pg_catalog.array_agg(
          current_falr.fulfilment_allocation_line_revision_id
          order by current_far.fulfilment_allocation_revision_id,
            current_falr.fulfilment_allocation_line_revision_id
        ))[1] as current_line_revision_id,
        (pg_catalog.array_agg(
          current_falr.supplier_id
          order by current_far.fulfilment_allocation_revision_id,
            current_falr.fulfilment_allocation_line_revision_id
        ))[1] as supplier_id,
        (pg_catalog.array_agg(
          current_drlr.ingredient_id
          order by current_far.fulfilment_allocation_revision_id,
            current_falr.fulfilment_allocation_line_revision_id
        ))[1] as ingredient_id,
        (pg_catalog.array_agg(
          current_falr.unit_id
          order by current_far.fulfilment_allocation_revision_id,
            current_falr.fulfilment_allocation_line_revision_id
        ))[1] as unit_id,
        (pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'fulfilment_allocation_id', fa.fulfilment_allocation_id,
          'fulfilment_allocation_version', fa.version,
          'fulfilment_allocation_status', fa.allocation_status,
          'fulfilment_allocation_revision_id', current_far.fulfilment_allocation_revision_id,
          'fulfilment_allocation_revision_status', current_far.revision_status,
          'fulfilment_allocation_line_id', fal.fulfilment_allocation_line_id,
          'fulfilment_allocation_line_revision_id', current_falr.fulfilment_allocation_line_revision_id,
          'supplier_id', current_falr.supplier_id,
          'ingredient_id', current_drlr.ingredient_id,
          'unit_id', current_falr.unit_id,
          'allocated_quantity', current_falr.allocated_quantity
        ) order by current_far.fulfilment_allocation_revision_id,
          current_falr.fulfilment_allocation_line_revision_id) -> 0
        ) as fulfilment_allocation_context
      from atlas_procurement.fulfilment_allocation_revisions current_far
      join atlas_procurement.fulfilment_allocation_line_revisions current_falr
        on current_falr.fulfilment_allocation_revision_id = current_far.fulfilment_allocation_revision_id
       and current_falr.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
      join atlas_planning.dispatch_requirement_line_revisions current_drlr
        on current_drlr.dispatch_requirement_line_revision_id =
          current_falr.dispatch_requirement_line_revision_id
       and current_drlr.dispatch_requirement_line_id = fal.dispatch_requirement_line_id
      join atlas_planning.dispatch_requirement_revisions current_drr
        on current_drr.dispatch_requirement_revision_id =
          current_drlr.dispatch_requirement_revision_id
       and current_drr.dispatch_requirement_id = fa.dispatch_requirement_id
      where current_far.fulfilment_allocation_id = fa.fulfilment_allocation_id
        and current_far.is_current
        and current_far.revision_kind <> 'CANCELLATION'
        and current_falr.line_status <> 'SUPERSEDED'
    ) current_allocation on true
    left join lateral (
      select
        coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'purchase_order_id', candidates.purchase_order_id,
          'purchase_order_version', candidates.purchase_order_version,
          'purchase_order_status', candidates.purchase_order_status,
          'purchase_order_revision_id', candidates.purchase_order_revision_id,
          'purchase_order_revision_status', candidates.purchase_order_revision_status,
          'purchase_order_line_id', candidates.purchase_order_line_id,
          'purchase_order_line_revision_id', candidates.purchase_order_line_revision_id,
          'supplier_id', candidates.supplier_id,
          'ingredient_id', candidates.ingredient_id,
          'ordered_quantity', candidates.ordered_quantity,
          'unit_id', candidates.unit_id,
          'service_date', candidates.service_date,
          'delivery_location_id', candidates.delivery_location_id
        ) order by candidates.purchase_order_id,
          candidates.purchase_order_revision_id,
          candidates.purchase_order_line_id,
          candidates.purchase_order_line_revision_id)
          filter (where candidates.is_consistent), '[]'::jsonb) as purchase_commitments,
        count(*) filter (where candidates.is_consistent is not true)::integer as conflict_count
      from (
        select
          po.purchase_order_id,
          po.version as purchase_order_version,
          po.purchase_order_status,
          por.purchase_order_revision_id,
          por.revision_status as purchase_order_revision_status,
          pol.purchase_order_line_id,
          polr.purchase_order_line_revision_id,
          po.supplier_id,
          polr.ingredient_id,
          polr.ordered_quantity,
          polr.unit_id,
          polr.service_date,
          polr.delivery_location_id,
          polr.fulfilment_allocation_line_revision_id = current_allocation.current_line_revision_id
            and po.supplier_id = current_allocation.supplier_id
            and polr.ingredient_id = current_allocation.ingredient_id
            and polr.unit_id = current_allocation.unit_id
            and por.service_date = dr.service_date
            and polr.service_date = dr.service_date
            and por.delivery_location_id = dr.delivery_location_id
            and polr.delivery_location_id = dr.delivery_location_id
            as is_consistent
        from atlas_procurement.purchase_order_lines pol
        join atlas_procurement.purchase_orders po
          on po.purchase_order_id = pol.purchase_order_id
        join atlas_procurement.purchase_order_revisions por
          on por.purchase_order_id = po.purchase_order_id
         and por.is_current
         and por.revision_kind <> 'CANCELLATION'
         and por.revision_status in ('RELEASED_TO_SUPPLIER', 'SUPPLIER_CONFIRMED')
        join atlas_procurement.purchase_order_line_revisions polr
          on polr.purchase_order_revision_id = por.purchase_order_revision_id
         and polr.purchase_order_line_id = pol.purchase_order_line_id
        where pol.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
          and po.purchase_order_status in ('RELEASED_TO_SUPPLIER', 'SUPPLIER_CONFIRMED')
      ) candidates
    ) purchase_context on true
    left join lateral (
      select
        coalesce(sum(dll.loaded_quantity) filter (
          where dll.line_status = 'CONFIRMED' and dl.load_status = 'CONFIRMED'
        ), 0) as loaded_quantity,
        exists (
          select 1
          from atlas_dispatch.dispatch_load_lines delivered_line
          join atlas_dispatch.delivery_confirmation_lines dcl
            on dcl.dispatch_load_line_id = delivered_line.dispatch_load_line_id
          join atlas_dispatch.delivery_confirmations dc
            on dc.delivery_confirmation_id = dcl.delivery_confirmation_id
          where delivered_line.dispatch_stop_id = ds.dispatch_stop_id
            and delivered_line.fulfilment_allocation_line_revision_id =
              historical_falr.fulfilment_allocation_line_revision_id
            and dc.confirmation_status = 'VALID'
            and dc.delivery_outcome = 'DELIVERED'
        ) as delivered
      from atlas_dispatch.dispatch_load_lines dll
      join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
      where dll.dispatch_stop_id = ds.dispatch_stop_id
        and dll.fulfilment_allocation_line_revision_id =
          historical_falr.fulfilment_allocation_line_revision_id
    ) l on true
    left join lateral (
      select
        coalesce(sum(ea.applied_quantity) filter (
          where ea.application_status = 'VALID' and sre.evidence_status = 'VALID'
        ), 0) as valid_applied_quantity,
        coalesce(bool_or(sre.evidence_status in ('VOIDED', 'SUPERSEDED')
          or ea.application_status in ('VOIDED', 'SUPERSEDED')), false) as has_invalid_evidence,
        coalesce(bool_or(ea.evidence_application_id is not null), false) as has_evidence,
        coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'supplier_receiving_evidence_id', sre.supplier_receiving_evidence_id,
          'evidence_reference', sre.evidence_reference,
          'evidence_status', sre.evidence_status,
          'evidence_application_id', ea.evidence_application_id,
          'application_status', ea.application_status
        ) order by ea.recorded_at, ea.evidence_application_id)
          filter (where sre.supplier_receiving_evidence_id is not null), '[]'::jsonb) as evidence_references
      from atlas_evidence.evidence_applications ea
      join atlas_evidence.supplier_receiving_evidence sre
        on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
      where ea.fulfilment_allocation_line_revision_id =
        historical_falr.fulfilment_allocation_line_revision_id
    ) e on true
    where (
      (v_trip_id is not null and dt.dispatch_trip_id = v_trip_id)
      or (v_requirement_revision_id is not null and drr.dispatch_requirement_revision_id = v_requirement_revision_id)
      or (v_source_revision_id is not null and cnlr.wholesale_order_line_revision_id = v_source_revision_id)
    ) and atlas_core.pa_05c_actor_can_read_scope(
        v_actor_id, 'dispatch_evidence_readiness.read',
        dr.customer_id, dr.delivery_location_id, dt.dispatch_trip_id
      )
  ), shaped as (
    select *, case
      when delivered then 'DELIVERED'
      when loaded_quantity = 0 then 'NOT_LOADED'
      when not has_evidence then 'MISSING_EVIDENCE'
      when valid_applied_quantity = 0 and has_invalid_evidence then 'VOIDED_OR_SUPERSEDED_EVIDENCE'
      when valid_applied_quantity < loaded_quantity then 'PARTIAL_EVIDENCE'
      else 'READY'
    end as readiness_status
    from lines
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'trip_reference', trip_reference,
    'dispatch_trip_id', dispatch_trip_id,
    'trip_status', trip_status,
    'dispatch_stop_id', dispatch_stop_id,
    'stop_sequence', stop_sequence,
    'stop_status', stop_status,
    'dispatch_requirement_id', dispatch_requirement_id,
    'dispatch_requirement_revision_id', dispatch_requirement_revision_id,
    'dispatch_requirement_line_revision_id', dispatch_requirement_line_revision_id,
    'fulfilment_allocation_line_revision_id', fulfilment_allocation_line_revision_id,
    'unit_id', unit_id,
    'allocated_quantity', allocated_quantity,
    'loaded_quantity', loaded_quantity,
    'applied_evidence_quantity', valid_applied_quantity,
    'evidence_references', evidence_references,
    'evidence_status', case when has_invalid_evidence then 'HAS_VOIDED_OR_SUPERSEDED' when has_evidence then 'VALID' else 'MISSING' end,
    'evidence_application_status', case when valid_applied_quantity > 0 then 'VALID' when has_evidence then 'INVALID' else 'MISSING' end,
    'readiness_status', readiness_status,
    'blockers', case readiness_status
      when 'NOT_LOADED' then pg_catalog.jsonb_build_array('No confirmed load is available.')
      when 'MISSING_EVIDENCE' then pg_catalog.jsonb_build_array('No supplier evidence is applied.')
      when 'PARTIAL_EVIDENCE' then pg_catalog.jsonb_build_array('Applied evidence is below the loaded quantity.')
      when 'VOIDED_OR_SUPERSEDED_EVIDENCE' then pg_catalog.jsonb_build_array('Only voided or superseded evidence is available.')
      else '[]'::jsonb end,
    'warnings', case when has_invalid_evidence and valid_applied_quantity > 0
      then pg_catalog.jsonb_build_array('Historical voided or superseded evidence is present.')
      else '[]'::jsonb end,
    'command_context', pg_catalog.jsonb_build_object(
      'fulfilment_allocation', fulfilment_allocation_context,
      'purchase_commitments', purchase_commitments
    )
  ) order by dispatch_trip_id, stop_sequence, fulfilment_allocation_line_revision_id), '[]'::jsonb),
    count(*) filter (
      where current_allocation_context_count <> 1
         or purchase_commitment_conflict_count > 0
    )::integer
  into v_items, v_lineage_conflict_count
  from shaped;

  if v_lineage_conflict_count > 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'CURRENT_LINEAGE_CONFLICT',
      'Current Evidence command context is internally inconsistent.'
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', 'PA-05C.v1',
    'selector', request -> 'payload',
    'authorized_scope', pg_catalog.jsonb_build_object(
      'customer_id', v_scope_customer_id, 'delivery_location_id', v_scope_location_id,
      'dispatch_trip_id', coalesce(v_trip_id, v_scope_trip_id)
    ),
    'readiness_items', v_items,
    'advisory_only', true,
    'safe_operator_message', 'Authorized dispatch evidence readiness returned.'
  );
exception when others then
  return atlas_core.pa_05c_read_error(
    request, v_name, 'INTERNAL_READ_FAILURE', 'Dispatch evidence readiness could not be returned safely.'
  );
end;
$$;

comment on function atlas_api.get_dispatch_evidence_readiness(jsonb)
is 'READ-02 advisory dispatch Evidence readiness with bounded authoritative current allocation and Purchase Order command context; PA-05C-H3.';

revoke atlas_read_runtime from postgres;
