-- PA-05E: bounded Procurement command family for supplier-direct wholesale Slice 1.
--
-- This migration adds exactly two reviewed Procurement commands. It reuses the
-- PA-04 authoritative tables and creates no Warehouse, Evidence, Dispatch,
-- reporting, Storage, seed, hosted-project, Retool, or OPS v1 fact.

do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'atlas_procurement_command_runtime') then
    create role atlas_procurement_command_runtime nologin noinherit;
  end if;
end
$$;

-- A stable allocation line is assigned to at most one supplier purchase order
-- across all purchase orders. Together with command-owned all-supplier-line
-- selection, this also race-protects one released PO per allocation/supplier.
create unique index purchase_order_lines_allocation_line_key
  on atlas_procurement.purchase_order_lines (fulfilment_allocation_line_id);

create or replace function atlas_core.pa_05e_validate_command_request(
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
  v_requested_at timestamptz;
  v_allowed_keys constant text[] := array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ];
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb), 'VALIDATION_FAILED',
      'The command request must be a JSON object.', 'PROCUREMENT', command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if not (request ?& v_allowed_keys) or request - v_allowed_keys <> '{}'::jsonb then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request',
        'message', 'Use exactly the PA-05E command-envelope fields.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'PA-05E.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05E.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'command_id', 'message', 'A valid UUID is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'correlation_id', 'message', 'A valid UUID is required.')
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'expected_version', 'message', 'A positive integer version is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.')
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
  if v_requested_at is null or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_at', 'message', 'A valid non-future timestamp is required.')
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_code', 'message', 'A reason code is required.')
    );
  end if;
  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_note', 'message', 'The reason_note field is required and may be null.')
    );
  end if;
  if request -> 'payload' is null or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The command envelope is invalid.',
      'PROCUREMENT', command_name, false, v_errors
    );
  end if;
  return null;
end;
$$;


create or replace function atlas_api.release_supplier_purchase_order(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'release_supplier_purchase_order';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_fulfilment_allocation_revision_id uuid;
  v_fulfilment_allocation_id uuid;
  v_supplier_id uuid;
  v_document_number text;
  v_allocation_version bigint;
  v_allocation_status text;
  v_revision_status text;
  v_revision_current boolean;
  v_dispatch_requirement_id uuid;
  v_dispatch_requirement_revision_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_service_date date;
  v_supplier_name text;
  v_location_name text;
  v_allocation_line_count integer;
  v_valid_line_count integer;
  v_supplier_line_count integer;
  v_purchase_order_id uuid;
  v_purchase_order_revision_id uuid;
  v_purchase_order_line_id uuid;
  v_purchase_order_line_revision_id uuid;
  v_purchase_order_line_ids jsonb := '[]'::jsonb;
  v_purchase_order_line_revision_ids jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_row record;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05e_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PROCUREMENT', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  v_fulfilment_allocation_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'fulfilment_allocation_revision_id'
  );
  v_supplier_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'supplier_id');
  v_document_number := pg_catalog.btrim(coalesce(v_payload ->> 'document_number', ''));
  if not (v_payload ?& array[
       'fulfilment_allocation_revision_id', 'supplier_id', 'document_number'
     ])
     or v_payload - array[
       'fulfilment_allocation_revision_id', 'supplier_id', 'document_number'
     ] <> '{}'::jsonb
     or v_fulfilment_allocation_revision_id is null
     or v_supplier_id is null
     or v_document_number = '' or pg_catalog.length(v_document_number) > 200 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Provide only one allocation revision, one supplier, and one document number.',
      'PROCUREMENT', v_command_name
    );
  end if;

  select far.fulfilment_allocation_id, fa.version, fa.allocation_status,
         far.revision_status, far.is_current, fa.dispatch_requirement_id,
         drr.dispatch_requirement_revision_id, dr.customer_id,
         dr.delivery_location_id, dr.service_date
    into v_fulfilment_allocation_id, v_allocation_version, v_allocation_status,
         v_revision_status, v_revision_current, v_dispatch_requirement_id,
         v_dispatch_requirement_revision_id, v_customer_id,
         v_delivery_location_id, v_service_date
  from atlas_procurement.fulfilment_allocation_revisions far
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = fa.dispatch_requirement_id
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_id = dr.dispatch_requirement_id
   and drr.is_current
  where far.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id;
  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The current supplier-direct allocation revision could not be validated.',
      'PROCUREMENT', v_command_name
    );
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'supplier_purchase_order.release',
    'PROCUREMENT', v_command_name, v_customer_id, v_delivery_location_id, null
  );
  if v_error is not null then return v_error; end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'PROCUREMENT',
    'allocation-revision:' || v_fulfilment_allocation_revision_id::text ||
    ':supplier:' || v_supplier_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.customers c
    where c.customer_id = v_customer_id for key share;
  perform 1 from atlas_admin.delivery_locations dl
    where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.suppliers s
    where s.supplier_id = v_supplier_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select drlr.ingredient_id
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
      where falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select falr.unit_id
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      where falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
    ) order by u.unit_id for key share;
  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id = v_dispatch_requirement_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id = v_dispatch_requirement_id
    order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    order by drlr.dispatch_requirement_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    ) order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr
    where pdr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    ) order by pdr.purchase_demand_reference_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.fulfilment_allocation_id = v_fulfilment_allocation_id for update;
  perform 1 from atlas_procurement.fulfilment_allocation_revisions far
    where far.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_lines fal
    where fal.fulfilment_allocation_id = v_fulfilment_allocation_id
    order by fal.fulfilment_allocation_line_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
    where falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
    order by falr.fulfilment_allocation_line_revision_id for key share;

  -- Document-number attempts across different allocations share a deterministic
  -- transaction-scoped lock before the existing global unique-index check.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('PA-05E:PO:' || v_document_number, 0)
  );
  perform 1 from atlas_procurement.purchase_orders po
    where po.document_number = v_document_number
    order by po.purchase_order_id for key share;
  perform 1 from atlas_procurement.purchase_order_lines pol
    where pol.fulfilment_allocation_line_id in (
      select falr.fulfilment_allocation_line_id
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      where falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
        and falr.supplier_id = v_supplier_id
    ) order by pol.purchase_order_line_id for key share;

  select fa.version, fa.allocation_status, far.revision_status, far.is_current,
         dr.customer_id, dr.delivery_location_id, dr.service_date,
         s.supplier_name, dl.location_name
    into v_allocation_version, v_allocation_status, v_revision_status, v_revision_current,
         v_customer_id, v_delivery_location_id, v_service_date,
         v_supplier_name, v_location_name
  from atlas_procurement.fulfilment_allocations fa
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_id = fa.fulfilment_allocation_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = fa.dispatch_requirement_id
  join atlas_admin.suppliers s on s.supplier_id = v_supplier_id
  join atlas_admin.delivery_locations dl
    on dl.delivery_location_id = dr.delivery_location_id
  where fa.fulfilment_allocation_id = v_fulfilment_allocation_id
    and far.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id;

  if v_allocation_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The fulfilment allocation changed. Refresh before purchase-order release.',
      'PROCUREMENT', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_fulfilment_allocation_id), v_allocation_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_allocation_line_count
  from atlas_procurement.fulfilment_allocation_lines fal
  where fal.fulfilment_allocation_id = v_fulfilment_allocation_id;

  select count(*)::integer,
         count(*) filter (where falr.supplier_id = v_supplier_id)::integer
    into v_valid_line_count, v_supplier_line_count
  from atlas_procurement.fulfilment_allocation_line_revisions falr
  join atlas_procurement.fulfilment_allocation_lines fal
    on fal.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
   and fal.fulfilment_allocation_id = v_fulfilment_allocation_id
   and fal.portion_sequence = 1
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
   and far.fulfilment_allocation_id = v_fulfilment_allocation_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
   and drlr.dispatch_requirement_line_id = fal.dispatch_requirement_line_id
  join atlas_planning.dispatch_requirement_lines drl
    on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
   and drl.dispatch_requirement_id = fa.dispatch_requirement_id
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
   and drr.dispatch_requirement_id = fa.dispatch_requirement_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
  join atlas_admin.customers c on c.customer_id = dr.customer_id
  join atlas_admin.delivery_locations dl on dl.delivery_location_id = dr.delivery_location_id
  join atlas_admin.suppliers s on s.supplier_id = falr.supplier_id
  join atlas_admin.ingredients i on i.ingredient_id = drlr.ingredient_id
  join atlas_admin.units u on u.unit_id = drlr.unit_id
  join atlas_planning.purchase_handoff_line_revisions phlr
    on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
  join atlas_planning.purchase_handoff_lines phl
    on phl.purchase_handoff_line_id = drl.purchase_handoff_line_id
   and phl.purchase_handoff_line_id = phlr.purchase_handoff_line_id
  join atlas_planning.purchase_handoff_revisions phr
    on phr.purchase_handoff_revision_id = phlr.purchase_handoff_revision_id
   and phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
  join atlas_planning.purchase_handoff_batches phb
    on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
   and phb.purchase_handoff_batch_id = phl.purchase_handoff_batch_id
  join atlas_planning.confirmed_need_lines cnl
    on cnl.confirmed_need_line_id = phl.confirmed_need_line_id
  join atlas_planning.confirmed_need_line_revisions cnlr
    on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
   and cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
  join atlas_planning.confirmed_need_batches cnb
    on cnb.confirmed_need_batch_id = cnl.confirmed_need_batch_id
   and cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
  join atlas_planning.purchase_demand_references pdr
    on pdr.purchase_handoff_line_revision_id = phlr.purchase_handoff_line_revision_id
  join atlas_planning.confirmed_need_approval_snapshots cns
    on cns.confirmed_need_batch_id = cnb.confirmed_need_batch_id
   and cns.approved_version = cnb.version
  join atlas_planning.confirmed_need_snapshot_lines cnsl
    on cnsl.confirmed_need_snapshot_line_id = pdr.confirmed_need_snapshot_line_id
   and cnsl.confirmed_need_approval_snapshot_id = cns.confirmed_need_approval_snapshot_id
   and cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
  join atlas_planning.wholesale_order_line_revisions wolr
    on wolr.wholesale_order_line_revision_id = pdr.wholesale_order_line_revision_id
   and wolr.wholesale_order_line_revision_id = cnlr.wholesale_order_line_revision_id
  join atlas_planning.wholesale_order_lines wol
    on wol.wholesale_order_line_id = wolr.wholesale_order_line_id
   and wol.wholesale_order_line_id = cnl.wholesale_order_line_id
  join atlas_planning.wholesale_orders wo
    on wo.wholesale_order_id = wol.wholesale_order_id
   and wo.wholesale_order_id = cnb.wholesale_order_id
  where falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
    and fa.allocation_status = 'READY_FOR_DISPATCH'
    and far.revision_status = 'READY_FOR_DISPATCH' and far.is_current
    and falr.fulfilment_source_type = 'SUPPLIER_PO'
    and falr.line_status = 'READY_FOR_EVIDENCE'
    and dr.source_of_need = 'WHOLESALE' and dr.requirement_status = 'RELEASED'
    and drr.revision_status = 'RELEASED' and drr.is_current
    and drr.released_by_actor_id is not null and drr.released_at is not null
    and c.customer_type = 'WHOLESALE' and c.customer_status = 'ACTIVE'
    and dl.customer_id = dr.customer_id and dl.location_status = 'ACTIVE'
    and s.supplier_status = 'ACTIVE'
    and i.ingredient_status = 'ACTIVE' and u.unit_status = 'ACTIVE'
    and phb.handoff_status = 'RELEASED_TO_PROCUREMENT'
    and phr.revision_status = 'RELEASED_TO_PROCUREMENT' and phr.is_current
    and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
    and cnlr.is_current and cnlr.revision_status = 'RELEASED'
    and wolr.is_current and wolr.revision_status = 'RELEASED'
    and wo.order_status = 'RELEASED'
    and wo.customer_id = dr.customer_id
    and wo.delivery_location_id = dr.delivery_location_id
    and wo.service_date = dr.service_date
    and phlr.delivery_location_id = dr.delivery_location_id
    and phlr.service_date = dr.service_date
    and cnb.period_start = dr.service_date and cnb.period_end = dr.service_date
    and drlr.ingredient_id = phlr.ingredient_id
    and phlr.ingredient_id = cnlr.ingredient_id
    and cnlr.ingredient_id = cnsl.ingredient_id
    and cnsl.ingredient_id = wolr.ingredient_id
    and drlr.unit_id = phlr.unit_id
    and phlr.unit_id = cnlr.unit_id
    and cnlr.unit_id = cnsl.unit_id
    and cnsl.unit_id = pdr.unit_id
    and pdr.unit_id = wolr.unit_id
    and falr.unit_id = drlr.unit_id
    and drlr.required_quantity = phlr.handoff_quantity
    and phlr.handoff_quantity = pdr.approved_quantity
    and pdr.approved_quantity = cnsl.approved_quantity
    and cnsl.approved_quantity = cnlr.confirmed_quantity
    and cnlr.confirmed_quantity = cnlr.theoretical_quantity
    and cnlr.theoretical_quantity = wolr.requested_quantity
    and falr.allocated_quantity = drlr.required_quantity;

  if v_allocation_status <> 'READY_FOR_DISPATCH'
     or v_revision_status <> 'READY_FOR_DISPATCH' or not v_revision_current
     or v_allocation_line_count < 1
     or v_valid_line_count <> v_allocation_line_count
     or v_supplier_line_count < 1
     or v_supplier_name is null or pg_catalog.btrim(v_supplier_name) = ''
     or v_location_name is null or pg_catalog.btrim(v_location_name) = ''
     or exists (
       select 1 from atlas_procurement.purchase_orders po
       where po.document_number = v_document_number
     )
     or exists (
       select 1
       from atlas_procurement.purchase_order_line_revisions polr
       join atlas_procurement.purchase_order_revisions por
         on por.purchase_order_revision_id = polr.purchase_order_revision_id
        and por.is_current and por.revision_status = 'RELEASED_TO_SUPPLIER'
       join atlas_procurement.purchase_orders po
         on po.purchase_order_id = por.purchase_order_id
        and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
        and po.supplier_id = v_supplier_id
       join atlas_procurement.fulfilment_allocation_line_revisions falr
         on falr.fulfilment_allocation_line_revision_id = polr.fulfilment_allocation_line_revision_id
        and falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
     )
     or exists (
       select 1
       from atlas_procurement.purchase_order_lines pol
       join atlas_procurement.fulfilment_allocation_lines fal
         on fal.fulfilment_allocation_line_id = pol.fulfilment_allocation_line_id
       join atlas_procurement.fulfilment_allocation_line_revisions falr
         on falr.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
        and falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
        and falr.supplier_id = v_supplier_id
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Purchase-order release requires every and only the selected supplier lines from one current exact allocation.',
      'PROCUREMENT', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  begin
    insert into atlas_procurement.purchase_orders (
      supplier_id, document_number, purchase_order_status, version
    ) values (
      v_supplier_id, v_document_number, 'RELEASED_TO_SUPPLIER', 1
    ) returning purchase_order_id into v_purchase_order_id;

    insert into atlas_procurement.purchase_order_revisions (
      purchase_order_id, revision_number, revision_kind, revision_status,
      is_current, service_date, delivery_location_id, supplier_name_snapshot,
      delivery_location_snapshot, released_by_actor_id, released_at,
      reason_note, command_id
    ) values (
      v_purchase_order_id, 1, 'BASE', 'RELEASED_TO_SUPPLIER', true,
      v_service_date, v_delivery_location_id, v_supplier_name, v_location_name,
      v_actor_id, pg_catalog.transaction_timestamp(), request ->> 'reason_note',
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
    ) returning purchase_order_revision_id into v_purchase_order_revision_id;

    for v_row in
      select fal.fulfilment_allocation_line_id,
             falr.fulfilment_allocation_line_revision_id,
             drlr.ingredient_id, falr.allocated_quantity, falr.unit_id
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      join atlas_procurement.fulfilment_allocation_lines fal
        on fal.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
      where falr.fulfilment_allocation_revision_id = v_fulfilment_allocation_revision_id
        and falr.supplier_id = v_supplier_id
      order by fal.fulfilment_allocation_line_id
    loop
      insert into atlas_procurement.purchase_order_lines (
        purchase_order_id, fulfilment_allocation_line_id
      ) values (
        v_purchase_order_id, v_row.fulfilment_allocation_line_id
      ) returning purchase_order_line_id into v_purchase_order_line_id;
      v_purchase_order_line_ids := v_purchase_order_line_ids ||
        pg_catalog.jsonb_build_array(v_purchase_order_line_id);

      insert into atlas_procurement.purchase_order_line_revisions (
        purchase_order_revision_id, purchase_order_line_id,
        fulfilment_allocation_line_revision_id, ingredient_id,
        ordered_quantity, unit_id, delivery_location_id, service_date
      ) values (
        v_purchase_order_revision_id, v_purchase_order_line_id,
        v_row.fulfilment_allocation_line_revision_id, v_row.ingredient_id,
        v_row.allocated_quantity, v_row.unit_id, v_delivery_location_id,
        v_service_date
      ) returning purchase_order_line_revision_id
        into v_purchase_order_line_revision_id;
      v_purchase_order_line_revision_ids := v_purchase_order_line_revision_ids ||
        pg_catalog.jsonb_build_array(v_purchase_order_line_revision_id);
    end loop;

    insert into atlas_audit.domain_events (
      event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
      command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
      payload_summary
    ) values (
      'SupplierPurchaseOrderReleased', 'PROCUREMENT', 'PurchaseOrder',
      v_purchase_order_id, 1, v_receipt_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      pg_catalog.transaction_timestamp(),
      pg_catalog.jsonb_build_object(
        'fulfilment_allocation_revision_id', v_fulfilment_allocation_revision_id,
        'supplier_id', v_supplier_id, 'document_number', v_document_number,
        'line_count', v_supplier_line_count
      )
    ) returning domain_event_id into v_domain_event_id;

    insert into atlas_audit.audit_events (
      event_type, source_domain, aggregate_type, aggregate_id,
      aggregate_version_after, command_receipt_id, command_id, correlation_id,
      actor_id, reason_code, reason_note, after_summary, source_interface,
      occurred_at
    ) values (
      'SupplierPurchaseOrderReleased', 'PROCUREMENT', 'PurchaseOrder',
      v_purchase_order_id, 1, v_receipt_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      request ->> 'reason_code', request ->> 'reason_note',
      pg_catalog.jsonb_build_object(
        'status', 'RELEASED_TO_SUPPLIER', 'document_number', v_document_number,
        'line_count', v_supplier_line_count
      ),
      'atlas_api', pg_catalog.transaction_timestamp()
    ) returning audit_event_id into v_audit_event_id;
  exception
    when unique_violation then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'The supplier/allocation purchase order or document number already exists.',
        'PROCUREMENT', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'purchase_order_id', v_purchase_order_id,
      'purchase_order_revision_id', v_purchase_order_revision_id,
      'purchase_order_line_ids', v_purchase_order_line_ids,
      'purchase_order_line_revision_ids', v_purchase_order_line_revision_ids,
      'fulfilment_allocation_id', v_fulfilment_allocation_id,
      'fulfilment_allocation_revision_id', v_fulfilment_allocation_revision_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'purchase_order_version', 1,
      'fulfilment_allocation_version', v_allocation_version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Supplier purchase order released exactly.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'PROCUREMENT', v_command_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The supplier purchase order could not be released safely.',
      'PROCUREMENT', v_command_name
    );
end;
$$;

create or replace function atlas_api.allocate_supplier_direct_fulfilment(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'allocate_supplier_direct_fulfilment';
  v_payload jsonb := request -> 'payload';
  v_lines jsonb;
  v_line jsonb;
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_dispatch_requirement_revision_id uuid;
  v_dispatch_requirement_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_requirement_version bigint;
  v_requirement_status text;
  v_revision_status text;
  v_revision_current boolean;
  v_submitted_count integer;
  v_distinct_count integer;
  v_requirement_line_count integer;
  v_valid_line_count integer;
  v_supplier_count integer;
  v_fulfilment_allocation_id uuid;
  v_fulfilment_allocation_revision_id uuid;
  v_fulfilment_allocation_line_id uuid;
  v_fulfilment_allocation_line_revision_id uuid;
  v_allocation_line_ids jsonb := '[]'::jsonb;
  v_allocation_line_revision_ids jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_row record;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05e_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PROCUREMENT', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  v_dispatch_requirement_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'dispatch_requirement_revision_id'
  );
  v_lines := v_payload -> 'lines';
  if not (v_payload ?& array['dispatch_requirement_revision_id', 'lines'])
     or v_payload - array['dispatch_requirement_revision_id', 'lines'] <> '{}'::jsonb
     or v_dispatch_requirement_revision_id is null
     or v_lines is null or pg_catalog.jsonb_typeof(v_lines) <> 'array' then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Provide only one Dispatch Requirement revision and its exact allocation lines.',
      'PROCUREMENT', v_command_name
    );
  end if;

  v_submitted_count := pg_catalog.jsonb_array_length(v_lines);
  if v_submitted_count < 1 or v_submitted_count > 100 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'Allocation requires between 1 and 100 lines.',
      'PROCUREMENT', v_command_name, false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Provide between 1 and 100 exact lines.')
      )
    );
  end if;

  for v_line in select value from pg_catalog.jsonb_array_elements(v_lines)
  loop
    if pg_catalog.jsonb_typeof(v_line) <> 'object'
       or not (v_line ?& array[
         'dispatch_requirement_line_revision_id', 'supplier_id',
         'allocated_quantity', 'unit_id'
       ])
       or v_line - array[
         'dispatch_requirement_line_revision_id', 'supplier_id',
         'allocated_quantity', 'unit_id'
       ] <> '{}'::jsonb
       or atlas_core.pa_05b_safe_uuid(v_line ->> 'dispatch_requirement_line_revision_id') is null
       or atlas_core.pa_05b_safe_uuid(v_line ->> 'supplier_id') is null
       or atlas_core.pa_05b_safe_uuid(v_line ->> 'unit_id') is null
       or atlas_core.pa_05b_safe_numeric(v_line ->> 'allocated_quantity') is null
       or atlas_core.pa_05b_safe_numeric(v_line ->> 'allocated_quantity') <= 0 then
      return atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'An allocation line is incomplete or invalid.',
        'PROCUREMENT', v_command_name, false,
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload.lines',
            'message', 'Use only exact requirement-line revision, supplier, positive quantity, and unit fields.'
          )
        )
      );
    end if;
  end loop;

  select count(distinct atlas_core.pa_05b_safe_uuid(x.value ->> 'dispatch_requirement_line_revision_id'))::integer
    into v_distinct_count
  from pg_catalog.jsonb_array_elements(v_lines) x;
  if v_distinct_count <> v_submitted_count then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Each Dispatch Requirement line revision must appear exactly once.',
      'PROCUREMENT', v_command_name
    );
  end if;

  select drr.dispatch_requirement_id, dr.customer_id, dr.delivery_location_id,
         dr.version, dr.requirement_status, drr.revision_status, drr.is_current
    into v_dispatch_requirement_id, v_customer_id, v_delivery_location_id,
         v_requirement_version, v_requirement_status, v_revision_status, v_revision_current
  from atlas_planning.dispatch_requirement_revisions drr
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
  where drr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id;
  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The released Dispatch Requirement revision could not be validated.',
      'PROCUREMENT', v_command_name
    );
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'supplier_direct_fulfilment.allocate',
    'PROCUREMENT', v_command_name, v_customer_id, v_delivery_location_id, null
  );
  if v_error is not null then return v_error; end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'PROCUREMENT',
    'dispatch-requirement:' || v_dispatch_requirement_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  -- Lock and then re-read every authoritative reference in deterministic order.
  perform 1 from atlas_admin.customers c
    where c.customer_id = v_customer_id for key share;
  perform 1 from atlas_admin.delivery_locations dl
    where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.suppliers s
    where s.supplier_id in (
      select atlas_core.pa_05b_safe_uuid(x.value ->> 'supplier_id')
      from pg_catalog.jsonb_array_elements(v_lines) x
    ) order by s.supplier_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select drlr.ingredient_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select drlr.unit_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    ) order by u.unit_id for key share;
  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id = v_dispatch_requirement_id for update;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id = v_dispatch_requirement_id
    order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    order by drlr.dispatch_requirement_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    ) order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr
    where pdr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    ) order by pdr.purchase_demand_reference_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.dispatch_requirement_id = v_dispatch_requirement_id
    order by fa.fulfilment_allocation_id for update;

  select dr.version, dr.requirement_status, drr.revision_status, drr.is_current
    into v_requirement_version, v_requirement_status, v_revision_status, v_revision_current
  from atlas_planning.dispatch_requirements dr
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_id = dr.dispatch_requirement_id
  where dr.dispatch_requirement_id = v_dispatch_requirement_id
    and drr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id;

  if v_requirement_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The Dispatch Requirement changed. Refresh before allocation.',
      'PROCUREMENT', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_dispatch_requirement_id), v_requirement_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_requirement_line_count
  from atlas_planning.dispatch_requirement_lines drl
  where drl.dispatch_requirement_id = v_dispatch_requirement_id;

  with submitted as (
    select
      atlas_core.pa_05b_safe_uuid(x.value ->> 'dispatch_requirement_line_revision_id') as line_revision_id,
      atlas_core.pa_05b_safe_uuid(x.value ->> 'supplier_id') as supplier_id,
      atlas_core.pa_05b_safe_numeric(x.value ->> 'allocated_quantity') as allocated_quantity,
      atlas_core.pa_05b_safe_uuid(x.value ->> 'unit_id') as unit_id
    from pg_catalog.jsonb_array_elements(v_lines) x
  )
  select count(*)::integer, count(distinct submitted.supplier_id)::integer
    into v_valid_line_count, v_supplier_count
  from atlas_planning.dispatch_requirement_line_revisions drlr
  join submitted on submitted.line_revision_id = drlr.dispatch_requirement_line_revision_id
  join atlas_planning.dispatch_requirement_lines drl
    on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
   and drl.dispatch_requirement_id = v_dispatch_requirement_id
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
   and drr.dispatch_requirement_id = v_dispatch_requirement_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
  join atlas_admin.customers c on c.customer_id = dr.customer_id
  join atlas_admin.delivery_locations dl on dl.delivery_location_id = dr.delivery_location_id
  join atlas_admin.suppliers s on s.supplier_id = submitted.supplier_id
  join atlas_admin.ingredients i on i.ingredient_id = drlr.ingredient_id
  join atlas_admin.units u on u.unit_id = drlr.unit_id
  join atlas_planning.purchase_handoff_line_revisions phlr
    on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
  join atlas_planning.purchase_handoff_lines phl
    on phl.purchase_handoff_line_id = drl.purchase_handoff_line_id
   and phl.purchase_handoff_line_id = phlr.purchase_handoff_line_id
  join atlas_planning.purchase_handoff_revisions phr
    on phr.purchase_handoff_revision_id = phlr.purchase_handoff_revision_id
   and phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
  join atlas_planning.purchase_handoff_batches phb
    on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
   and phb.purchase_handoff_batch_id = phl.purchase_handoff_batch_id
  join atlas_planning.confirmed_need_lines cnl
    on cnl.confirmed_need_line_id = phl.confirmed_need_line_id
  join atlas_planning.confirmed_need_line_revisions cnlr
    on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
   and cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
  join atlas_planning.confirmed_need_batches cnb
    on cnb.confirmed_need_batch_id = cnl.confirmed_need_batch_id
   and cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
  join atlas_planning.purchase_demand_references pdr
    on pdr.purchase_handoff_line_revision_id = phlr.purchase_handoff_line_revision_id
  join atlas_planning.confirmed_need_approval_snapshots cns
    on cns.confirmed_need_batch_id = cnb.confirmed_need_batch_id
   and cns.approved_version = cnb.version
  join atlas_planning.confirmed_need_snapshot_lines cnsl
    on cnsl.confirmed_need_snapshot_line_id = pdr.confirmed_need_snapshot_line_id
   and cnsl.confirmed_need_approval_snapshot_id = cns.confirmed_need_approval_snapshot_id
   and cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
  join atlas_planning.wholesale_order_line_revisions wolr
    on wolr.wholesale_order_line_revision_id = pdr.wholesale_order_line_revision_id
   and wolr.wholesale_order_line_revision_id = cnlr.wholesale_order_line_revision_id
  join atlas_planning.wholesale_order_lines wol
    on wol.wholesale_order_line_id = wolr.wholesale_order_line_id
   and wol.wholesale_order_line_id = cnl.wholesale_order_line_id
  join atlas_planning.wholesale_orders wo
    on wo.wholesale_order_id = wol.wholesale_order_id
   and wo.wholesale_order_id = cnb.wholesale_order_id
  where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
    and dr.source_of_need = 'WHOLESALE'
    and dr.requirement_status = 'RELEASED'
    and drr.revision_status = 'RELEASED' and drr.is_current
    and drr.released_by_actor_id is not null and drr.released_at is not null
    and pg_catalog.btrim(drr.customer_name_snapshot) <> ''
    and pg_catalog.btrim(drr.location_name_snapshot) <> ''
    and pg_catalog.btrim(drr.address_snapshot) <> ''
    and c.customer_type = 'WHOLESALE' and c.customer_status = 'ACTIVE'
    and dl.customer_id = dr.customer_id and dl.location_status = 'ACTIVE'
    and s.supplier_status = 'ACTIVE'
    and i.ingredient_status = 'ACTIVE' and u.unit_status = 'ACTIVE'
    and phb.handoff_status = 'RELEASED_TO_PROCUREMENT'
    and phr.revision_status = 'RELEASED_TO_PROCUREMENT' and phr.is_current
    and phr.released_by_actor_id is not null and phr.released_at is not null
    and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
    and cnb.approved_by_actor_id is not null and cnb.approved_at is not null
    and cnb.released_by_actor_id is not null and cnb.released_at is not null
    and cnlr.is_current and cnlr.revision_status = 'RELEASED'
    and wolr.is_current and wolr.revision_status = 'RELEASED'
    and wo.order_status = 'RELEASED'
    and wo.customer_id = dr.customer_id
    and wo.delivery_location_id = dr.delivery_location_id
    and wo.service_date = dr.service_date
    and phlr.delivery_location_id = dr.delivery_location_id
    and phlr.service_date = dr.service_date
    and cnb.period_start = dr.service_date and cnb.period_end = dr.service_date
    and drlr.ingredient_id = phlr.ingredient_id
    and phlr.ingredient_id = cnlr.ingredient_id
    and cnlr.ingredient_id = cnsl.ingredient_id
    and cnsl.ingredient_id = wolr.ingredient_id
    and drlr.unit_id = phlr.unit_id
    and phlr.unit_id = cnlr.unit_id
    and cnlr.unit_id = cnsl.unit_id
    and cnsl.unit_id = pdr.unit_id
    and pdr.unit_id = wolr.unit_id
    and drlr.required_quantity = phlr.handoff_quantity
    and phlr.handoff_quantity = pdr.approved_quantity
    and pdr.approved_quantity = cnsl.approved_quantity
    and cnsl.approved_quantity = cnlr.confirmed_quantity
    and cnlr.confirmed_quantity = cnlr.theoretical_quantity
    and cnlr.theoretical_quantity = wolr.requested_quantity
    and submitted.allocated_quantity = drlr.required_quantity
    and submitted.unit_id = drlr.unit_id;

  if v_requirement_status <> 'RELEASED'
     or v_revision_status <> 'RELEASED' or not v_revision_current
     or v_requirement_line_count < 1
     or v_submitted_count <> v_requirement_line_count
     or v_distinct_count <> v_requirement_line_count
     or v_valid_line_count <> v_requirement_line_count
     or v_supplier_count < 1
     or exists (
       select 1 from atlas_procurement.fulfilment_allocations fa
       where fa.dispatch_requirement_id = v_dispatch_requirement_id
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Allocation requires exact full-line supplier-direct coverage of one current released requirement.',
      'PROCUREMENT', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  begin
    insert into atlas_procurement.fulfilment_allocations (
      dispatch_requirement_id, allocation_status, version
    ) values (
      v_dispatch_requirement_id, 'READY_FOR_DISPATCH', 1
    ) returning fulfilment_allocation_id into v_fulfilment_allocation_id;

    insert into atlas_procurement.fulfilment_allocation_revisions (
      fulfilment_allocation_id, revision_number, revision_kind, revision_status,
      is_current, allocated_by_actor_id, allocated_at, reason_note, command_id
    ) values (
      v_fulfilment_allocation_id, 1, 'BASE', 'READY_FOR_DISPATCH',
      true, v_actor_id, pg_catalog.transaction_timestamp(), request ->> 'reason_note',
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
    ) returning fulfilment_allocation_revision_id into v_fulfilment_allocation_revision_id;

    for v_row in
      select drlr.dispatch_requirement_line_revision_id,
             drlr.dispatch_requirement_line_id,
             atlas_core.pa_05b_safe_uuid(x.value ->> 'supplier_id') as supplier_id,
             drlr.required_quantity, drlr.unit_id
      from pg_catalog.jsonb_array_elements(v_lines) x
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_line_revision_id =
           atlas_core.pa_05b_safe_uuid(x.value ->> 'dispatch_requirement_line_revision_id')
      where drlr.dispatch_requirement_revision_id = v_dispatch_requirement_revision_id
      order by drlr.dispatch_requirement_line_revision_id
    loop
      insert into atlas_procurement.fulfilment_allocation_lines (
        fulfilment_allocation_id, dispatch_requirement_line_id, portion_sequence
      ) values (
        v_fulfilment_allocation_id, v_row.dispatch_requirement_line_id, 1
      ) returning fulfilment_allocation_line_id into v_fulfilment_allocation_line_id;
      v_allocation_line_ids := v_allocation_line_ids ||
        pg_catalog.jsonb_build_array(v_fulfilment_allocation_line_id);

      insert into atlas_procurement.fulfilment_allocation_line_revisions (
        fulfilment_allocation_revision_id, fulfilment_allocation_line_id,
        dispatch_requirement_line_revision_id, fulfilment_source_type,
        supplier_id, allocated_quantity, unit_id, line_status
      ) values (
        v_fulfilment_allocation_revision_id, v_fulfilment_allocation_line_id,
        v_row.dispatch_requirement_line_revision_id, 'SUPPLIER_PO',
        v_row.supplier_id, v_row.required_quantity, v_row.unit_id, 'READY_FOR_EVIDENCE'
      ) returning fulfilment_allocation_line_revision_id
        into v_fulfilment_allocation_line_revision_id;
      v_allocation_line_revision_ids := v_allocation_line_revision_ids ||
        pg_catalog.jsonb_build_array(v_fulfilment_allocation_line_revision_id);
    end loop;

    insert into atlas_audit.domain_events (
      event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
      command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
      payload_summary
    ) values (
      'SupplierDirectFulfilmentAllocated', 'PROCUREMENT', 'FulfilmentAllocation',
      v_fulfilment_allocation_id, 1, v_receipt_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      pg_catalog.transaction_timestamp(),
      pg_catalog.jsonb_build_object(
        'dispatch_requirement_revision_id', v_dispatch_requirement_revision_id,
        'line_count', v_requirement_line_count, 'supplier_count', v_supplier_count
      )
    ) returning domain_event_id into v_domain_event_id;

    insert into atlas_audit.audit_events (
      event_type, source_domain, aggregate_type, aggregate_id,
      aggregate_version_after, command_receipt_id, command_id, correlation_id,
      actor_id, reason_code, reason_note, after_summary, source_interface,
      occurred_at
    ) values (
      'SupplierDirectFulfilmentAllocated', 'PROCUREMENT', 'FulfilmentAllocation',
      v_fulfilment_allocation_id, 1, v_receipt_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      request ->> 'reason_code', request ->> 'reason_note',
      pg_catalog.jsonb_build_object(
        'status', 'READY_FOR_DISPATCH', 'line_count', v_requirement_line_count
      ),
      'atlas_api', pg_catalog.transaction_timestamp()
    ) returning audit_event_id into v_audit_event_id;
  exception
    when unique_violation then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'A supplier-direct allocation already exists for this requirement.',
        'PROCUREMENT', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'fulfilment_allocation_id', v_fulfilment_allocation_id,
      'fulfilment_allocation_revision_id', v_fulfilment_allocation_revision_id,
      'fulfilment_allocation_line_ids', v_allocation_line_ids,
      'fulfilment_allocation_line_revision_ids', v_allocation_line_revision_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object('fulfilment_allocation_version', 1),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Supplier-direct fulfilment allocated exactly.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'PROCUREMENT', v_command_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'Supplier-direct fulfilment could not be allocated safely.',
      'PROCUREMENT', v_command_name
    );
end;
$$;

-- Procurement runtime: relation access is limited to authorization/receipt
-- infrastructure, read-and-lock access to released lineage, inserts into the
-- eight Procurement facts, and paired audit facts. Lock-only UPDATE grants do
-- not have matching UPDATE policies and therefore cannot mutate FORCE-RLS
-- protected prerequisite or Procurement rows.
grant usage on schema
  atlas_core, atlas_admin, atlas_planning, atlas_procurement, atlas_audit, atlas_api
to atlas_procurement_command_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.customers,
  atlas_admin.delivery_locations,
  atlas_admin.ingredients,
  atlas_admin.suppliers,
  atlas_admin.units,
  atlas_planning.wholesale_orders,
  atlas_planning.wholesale_order_lines,
  atlas_planning.wholesale_order_line_revisions,
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_approval_snapshots,
  atlas_planning.confirmed_need_snapshot_lines,
  atlas_planning.purchase_handoff_batches,
  atlas_planning.purchase_handoff_revisions,
  atlas_planning.purchase_handoff_lines,
  atlas_planning.purchase_handoff_line_revisions,
  atlas_planning.purchase_demand_references,
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_lines,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_lines,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions,
  atlas_procurement.purchase_order_lines,
  atlas_procurement.purchase_order_line_revisions
to atlas_procurement_command_runtime;

grant insert, update on atlas_core.command_receipts
  to atlas_procurement_command_runtime;

grant update on
  atlas_admin.customers,
  atlas_admin.delivery_locations,
  atlas_admin.ingredients,
  atlas_admin.suppliers,
  atlas_admin.units,
  atlas_planning.wholesale_orders,
  atlas_planning.wholesale_order_lines,
  atlas_planning.wholesale_order_line_revisions,
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_approval_snapshots,
  atlas_planning.confirmed_need_snapshot_lines,
  atlas_planning.purchase_handoff_batches,
  atlas_planning.purchase_handoff_revisions,
  atlas_planning.purchase_handoff_lines,
  atlas_planning.purchase_handoff_line_revisions,
  atlas_planning.purchase_demand_references,
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_lines,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_lines,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions,
  atlas_procurement.purchase_order_lines,
  atlas_procurement.purchase_order_line_revisions
to atlas_procurement_command_runtime;

grant insert on
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_lines,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions,
  atlas_procurement.purchase_order_lines,
  atlas_procurement.purchase_order_line_revisions,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_procurement_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events
  to atlas_procurement_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
  to atlas_procurement_command_runtime;

create policy pa_05e_procurement_select on atlas_core.actors
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_core.actor_auth_subjects
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_core.roles
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_core.capabilities
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_core.role_capabilities
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_core.actor_role_memberships
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_core.actor_scopes
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_receipt_select on atlas_core.command_receipts
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_receipt_insert on atlas_core.command_receipts
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_receipt_update on atlas_core.command_receipts
  for update to atlas_procurement_command_runtime using (true) with check (true);

create policy pa_05e_procurement_select on atlas_admin.customers
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_admin.delivery_locations
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_admin.ingredients
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_admin.suppliers
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_admin.units
  for select to atlas_procurement_command_runtime using (true);

create policy pa_05e_procurement_select on atlas_planning.wholesale_orders
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.wholesale_order_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.wholesale_order_line_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.confirmed_need_batches
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.confirmed_need_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.confirmed_need_line_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.confirmed_need_approval_snapshots
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.confirmed_need_snapshot_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.purchase_handoff_batches
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.purchase_handoff_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.purchase_handoff_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.purchase_handoff_line_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.purchase_demand_references
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.dispatch_requirements
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.dispatch_requirement_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.dispatch_requirement_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_select on atlas_planning.dispatch_requirement_line_revisions
  for select to atlas_procurement_command_runtime using (true);

create policy pa_05e_procurement_select on atlas_procurement.fulfilment_allocations
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.fulfilment_allocations
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.fulfilment_allocation_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.fulfilment_allocation_revisions
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.fulfilment_allocation_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.fulfilment_allocation_lines
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.fulfilment_allocation_line_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.fulfilment_allocation_line_revisions
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.purchase_orders
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.purchase_orders
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.purchase_order_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.purchase_order_revisions
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.purchase_order_lines
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.purchase_order_lines
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_select on atlas_procurement.purchase_order_line_revisions
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_insert on atlas_procurement.purchase_order_line_revisions
  for insert to atlas_procurement_command_runtime with check (true);

create policy pa_05e_procurement_audit_insert on atlas_audit.domain_events
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_audit_select on atlas_audit.domain_events
  for select to atlas_procurement_command_runtime using (true);
create policy pa_05e_procurement_audit_insert on atlas_audit.audit_events
  for insert to atlas_procurement_command_runtime with check (true);
create policy pa_05e_procurement_audit_select on atlas_audit.audit_events
  for select to atlas_procurement_command_runtime using (true);

alter function atlas_core.pa_05e_validate_command_request(jsonb, text)
  owner to atlas_owner;
revoke execute on function atlas_core.pa_05e_validate_command_request(jsonb, text)
  from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.pa_05e_validate_command_request(jsonb, text),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean)
to atlas_procurement_command_runtime;

grant atlas_procurement_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_procurement_command_runtime;
alter function atlas_api.allocate_supplier_direct_fulfilment(jsonb)
  owner to atlas_procurement_command_runtime;
alter function atlas_api.release_supplier_purchase_order(jsonb)
  owner to atlas_procurement_command_runtime;
revoke create on schema atlas_api from atlas_procurement_command_runtime;

set role atlas_procurement_command_runtime;
revoke execute on function
  atlas_api.allocate_supplier_direct_fulfilment(jsonb),
  atlas_api.release_supplier_purchase_order(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_api.allocate_supplier_direct_fulfilment(jsonb),
  atlas_api.release_supplier_purchase_order(jsonb)
to authenticated;

comment on function atlas_api.allocate_supplier_direct_fulfilment(jsonb)
  is 'PA-05E Procurement command that allocates every released requirement line exactly once to one supplier.';
comment on function atlas_api.release_supplier_purchase_order(jsonb)
  is 'PA-05E Procurement command that releases all and only one supplier allocation subset as one purchase order.';
reset role;

revoke atlas_procurement_command_runtime from postgres;
comment on role atlas_procurement_command_runtime
  is 'PA-05E no-login, no-inherit SECURITY DEFINER owner for exactly two Procurement commands.';
set role atlas_owner;
comment on schema atlas_api
  is 'Function-only Atlas Data API boundary with exactly 15 reviewed PA-05B, PA-05C, PA-05D, and PA-05E functions.';
reset role;
