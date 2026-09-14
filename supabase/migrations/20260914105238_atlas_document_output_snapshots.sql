-- Immutable document-output facts required by the staff-approved PO/PXK layouts.

reset role;
grant atlas_owner,atlas_read_runtime,atlas_procurement_command_runtime,
  atlas_dispatch_command_runtime to postgres with set true;
set role atlas_owner;

alter table atlas_procurement.purchase_order_line_revisions
  add column school_breakdown_snapshot jsonb,
  add constraint purchase_order_line_revisions_school_breakdown_snapshot_check
    check (school_breakdown_snapshot is null
      or jsonb_typeof(school_breakdown_snapshot)='array');

alter table atlas_admin.schools
  add column dispatch_document_issuer_name text,
  add column dispatch_document_issuer_address text,
  add constraint schools_dispatch_document_issuer_check check (
    (dispatch_document_issuer_name is null
      and dispatch_document_issuer_address is null)
    or
    (dispatch_document_issuer_name=btrim(dispatch_document_issuer_name)
      and char_length(dispatch_document_issuer_name) between 1 and 200
      and dispatch_document_issuer_address=btrim(dispatch_document_issuer_address)
      and char_length(dispatch_document_issuer_address) between 1 and 300)
  );

alter table atlas_dispatch.school_dispatch_releases
  add column school_display_order_snapshot integer,
  add column document_issuer_name_snapshot text,
  add column document_issuer_address_snapshot text,
  add constraint school_dispatch_releases_display_order_snapshot_check
    check (school_display_order_snapshot is null
      or school_display_order_snapshot>=0),
  add constraint school_dispatch_releases_issuer_snapshot_check check (
    (document_issuer_name_snapshot is null
      and document_issuer_address_snapshot is null)
    or
    (document_issuer_name_snapshot=btrim(document_issuer_name_snapshot)
      and char_length(document_issuer_name_snapshot) between 1 and 200
      and document_issuer_address_snapshot=btrim(document_issuer_address_snapshot)
      and char_length(document_issuer_address_snapshot) between 1 and 300)
  );

create function atlas_core.school_catering_po_school_breakdown(
  p_supplier_split_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  with target as (
    select target_split.family_revision_id,target_split.supplier_split_id
    from atlas_procurement.school_catering_allocation_supplier_splits target_split
    where target_split.supplier_split_id=p_supplier_split_id
  ), contributions as materialized (
    select contribution.family_contribution_id,
      contribution.family_revision_id,contribution.contribution_quantity,
      confirmed_revision.school_id,confirmed_revision.delivery_location_id
    from atlas_procurement.school_catering_allocation_family_contributions contribution
    join target on target.family_revision_id=contribution.family_revision_id
    join atlas_planning.purchase_handoff_line_revisions handoff_line
      on handoff_line.purchase_handoff_line_revision_id=
        contribution.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions confirmed_revision
      on confirmed_revision.confirmed_need_line_revision_id=
        handoff_line.confirmed_need_line_revision_id
  ), contribution_ranges as materialized (
    select contribution.*,
      coalesce(sum(contribution_quantity) over(
        partition by family_revision_id order by family_contribution_id
        rows between unbounded preceding and 1 preceding),0)::numeric(20,6)
        contribution_start,
      sum(contribution_quantity) over(
        partition by family_revision_id order by family_contribution_id
        rows between unbounded preceding and current row)::numeric(20,6)
        contribution_end
    from contributions contribution
  ), split_ranges as materialized (
    select split.supplier_split_id,split.family_revision_id,
      coalesce(sum(split.allocated_quantity) over(
        partition by split.family_revision_id order by split.supplier_id
        rows between unbounded preceding and 1 preceding),0)::numeric(20,6)
        split_start,
      sum(split.allocated_quantity) over(
        partition by split.family_revision_id order by split.supplier_id
        rows between unbounded preceding and current row)::numeric(20,6)
        split_end
    from atlas_procurement.school_catering_allocation_supplier_splits split
    join target on target.family_revision_id=split.family_revision_id
  ), coverage as (
    select contribution.school_id,contribution.delivery_location_id,
      (least(contribution.contribution_end,split.split_end)-
        greatest(contribution.contribution_start,split.split_start))::numeric(20,6)
        ordered_quantity
    from contribution_ranges contribution
    join split_ranges split using(family_revision_id)
    join target on target.supplier_split_id=split.supplier_split_id
    where least(contribution.contribution_end,split.split_end)>
      greatest(contribution.contribution_start,split.split_start)
  ), grouped as (
    select coverage.school_id,school.school_name,school.display_order,
      coverage.delivery_location_id,location.location_name,
      sum(coverage.ordered_quantity)::numeric(20,6) ordered_quantity
    from coverage
    join atlas_admin.schools school on school.school_id=coverage.school_id
    join atlas_admin.delivery_locations location
      on location.delivery_location_id=coverage.delivery_location_id
    group by coverage.school_id,school.school_name,school.display_order,
      coverage.delivery_location_id,location.location_name
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'school_id',school_id,'school_name',school_name,
    'school_display_order',display_order,
    'delivery_location_id',delivery_location_id,
    'delivery_location_name',location_name,
    'ordered_quantity',ordered_quantity::text
  ) order by display_order,school_name,school_id,delivery_location_id),'[]'::jsonb)
  from grouped;
$$;

revoke execute on function atlas_core.school_catering_po_school_breakdown(uuid)
  from public,anon,authenticated,service_role;

create function atlas_core.freeze_school_catering_po_line_output()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_revision_status text;
  v_total numeric(20,6);
begin
  select revision_status into v_revision_status
  from atlas_procurement.purchase_order_revisions
  where purchase_order_revision_id=new.purchase_order_revision_id;
  if v_revision_status='RELEASED_TO_SUPPLIER'
     and new.school_catering_allocation_supplier_split_id is not null then
    new.school_breakdown_snapshot :=
      atlas_core.school_catering_po_school_breakdown(
        new.school_catering_allocation_supplier_split_id);
    select sum((school->>'ordered_quantity')::numeric)::numeric(20,6)
      into v_total
    from jsonb_array_elements(new.school_breakdown_snapshot) school;
    if jsonb_array_length(new.school_breakdown_snapshot)=0
       or v_total is distinct from new.ordered_quantity then
      raise exception using errcode='23514',
        message='released school-catering PO line requires a complete exact School snapshot';
    end if;
  elsif new.school_breakdown_snapshot is not null then
    raise exception using errcode='23514',
      message='draft or wholesale PO line cannot carry an official School snapshot';
  end if;
  return new;
end;
$$;

revoke execute on function atlas_core.freeze_school_catering_po_line_output()
  from public,anon,authenticated,service_role;
create trigger freeze_school_catering_po_line_output
  before insert on atlas_procurement.purchase_order_line_revisions
  for each row execute function atlas_core.freeze_school_catering_po_line_output();

grant create on schema atlas_core to atlas_procurement_command_runtime,atlas_read_runtime;
reset role;
alter function atlas_core.school_catering_po_school_breakdown(uuid)
  owner to atlas_read_runtime;
alter function atlas_core.freeze_school_catering_po_line_output()
  owner to atlas_procurement_command_runtime;
grant execute on function atlas_core.school_catering_po_school_breakdown(uuid)
  to atlas_procurement_command_runtime;
set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime,atlas_read_runtime;

create function atlas_core.freeze_school_dispatch_header_output()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_school record;
begin
  select display_order,dispatch_document_issuer_name,
    dispatch_document_issuer_address into v_school
  from atlas_admin.schools where school_id=new.school_id;
  if v_school.dispatch_document_issuer_name is null
     or v_school.dispatch_document_issuer_address is null then
    raise exception using errcode='23514',
      message='School PXK issuer configuration is required before release';
  end if;
  new.school_display_order_snapshot := v_school.display_order;
  new.document_issuer_name_snapshot := v_school.dispatch_document_issuer_name;
  new.document_issuer_address_snapshot := v_school.dispatch_document_issuer_address;
  return new;
end;
$$;

revoke execute on function atlas_core.freeze_school_dispatch_header_output()
  from public,anon,authenticated,service_role;
create trigger freeze_school_dispatch_header_output
  before insert on atlas_dispatch.school_dispatch_releases
  for each row execute function atlas_core.freeze_school_dispatch_header_output();

grant create on schema atlas_core to atlas_read_runtime;
reset role;
alter function atlas_core.freeze_school_dispatch_header_output()
  owner to atlas_read_runtime;
set role atlas_owner;
revoke create on schema atlas_core from atlas_read_runtime;

grant create on schema atlas_core to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

create or replace function atlas_core.school_dispatch_release_json(p_release_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'school_dispatch_release_id',release.school_dispatch_release_id,
    'service_date',release.service_date,'school_id',release.school_id,
    'delivery_location_id',release.delivery_location_id,
    'status',release.release_status,'document_number',release.document_number,
    'source_fingerprint',release.source_fingerprint,
    'predecessor_release_id',release.predecessor_release_id,
    'school_name',release.school_name_snapshot,
    'school_display_order',release.school_display_order_snapshot,
    'delivery_location_name',release.delivery_location_name_snapshot,
    'delivery_address',release.delivery_address_snapshot,
    'document_issuer_name',release.document_issuer_name_snapshot,
    'document_issuer_address',release.document_issuer_address_snapshot,
    'note',release.note,'version',release.version,
    'released_by_actor_id',release.released_by_actor_id,
    'released_at',release.released_at,
    'export_ready',release.school_display_order_snapshot is not null
      and release.document_issuer_name_snapshot is not null
      and release.document_issuer_address_snapshot is not null,
    'lines',coalesce((select jsonb_agg(jsonb_build_object(
      'school_dispatch_release_line_id',line.school_dispatch_release_line_id,
      'ingredient_id',line.ingredient_id,
      'ingredient_name',line.ingredient_name_snapshot,
      'unit_id',line.unit_id,'unit_code',line.unit_code_snapshot,
      'quantity',line.quantity::text,
      'sources',coalesce((select jsonb_agg(jsonb_build_object(
        'confirmed_need_line_revision_id',source.confirmed_need_line_revision_id,
        'confirmed_need_line_decision_id',source.confirmed_need_line_decision_id,
        'allocation_family_revision_id',source.allocation_family_revision_id,
        'allocation_family_contribution_id',source.allocation_family_contribution_id,
        'allocation_supplier_split_id',source.allocation_supplier_split_id,
        'purchase_order_id',source.purchase_order_id,
        'purchase_order_revision_id',source.purchase_order_revision_id,
        'purchase_order_line_revision_id',source.purchase_order_line_revision_id,
        'covered_quantity',source.covered_quantity::text
      ) order by source.school_dispatch_release_line_source_id)
      from atlas_dispatch.school_dispatch_release_line_sources source
      where source.school_dispatch_release_line_id=
        line.school_dispatch_release_line_id),'[]'::jsonb)
    ) order by line.ingredient_name_snapshot,line.school_dispatch_release_line_id)
    from atlas_dispatch.school_dispatch_release_lines line
    where line.school_dispatch_release_id=release.school_dispatch_release_id),
    '[]'::jsonb)
  )
  from atlas_dispatch.school_dispatch_releases release
  where release.school_dispatch_release_id=p_release_id;
$$;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_read_runtime;
grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

alter function atlas_api.get_school_catering_purchase_orders(jsonb)
  rename to get_school_catering_purchase_orders_v2_base;
revoke execute on function atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)
  from public,anon,authenticated,service_role;

create function atlas_api.get_school_catering_purchase_orders(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_response jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_order jsonb;
  v_lines jsonb;
  v_export_ready boolean;
begin
  v_response := atlas_api.get_school_catering_purchase_orders_v2_base(request);
  if not coalesce((v_response->>'success')::boolean,false) then return v_response; end if;
  for v_order in select value from jsonb_array_elements(v_response->'purchase_orders') loop
    select coalesce(jsonb_agg(line.value || jsonb_build_object(
      'school_breakdown',coalesce(revision.school_breakdown_snapshot,'[]'::jsonb)
    ) order by line.ordinality),'[]'::jsonb)
      into v_lines
    from jsonb_array_elements(v_order->'lines') with ordinality line(value,ordinality)
    left join atlas_procurement.purchase_order_line_revisions revision
      on revision.purchase_order_line_revision_id=
        (line.value->>'purchase_order_line_revision_id')::uuid;
    select v_order->>'status'='RELEASED_TO_SUPPLIER'
      and jsonb_array_length(v_lines)>0
      and not exists(select 1 from jsonb_array_elements(v_lines) line
        where jsonb_array_length(line->'school_breakdown')=0)
      into v_export_ready;
    v_order := v_order || jsonb_build_object(
      'lines',v_lines,'export_ready',v_export_ready,
      'allowed_actions',(v_order->'allowed_actions') ||
        jsonb_build_object('export',v_export_ready),
      'blockers',(v_order->'blockers') || case
        when v_order->>'status'='RELEASED_TO_SUPPLIER' and not v_export_ready
          then '["PO_EXPORT_SNAPSHOT_MISSING"]'::jsonb else '[]'::jsonb end,
      'disabled_reasons',(v_order->'disabled_reasons') || case
        when v_order->>'status'='RELEASED_TO_SUPPLIER' and not v_export_ready
          then '["PO_EXPORT_SNAPSHOT_MISSING"]'::jsonb else '[]'::jsonb end
    );
    v_orders := v_orders || jsonb_build_array(v_order);
  end loop;
  return jsonb_set(v_response,'{purchase_orders}',v_orders);
exception when others then
  return jsonb_build_object('success',false,'error_code','INTERNAL_READ_FAILURE',
    'safe_message','The school-catering purchase orders could not be read safely.',
    'retryable',true,'write_certainty','NO_BUSINESS_WRITE');
end;
$$;

revoke execute on function atlas_api.get_school_catering_purchase_orders(jsonb)
  from public,anon,service_role;
grant execute on function atlas_api.get_school_catering_purchase_orders(jsonb)
  to authenticated;

alter function atlas_api.get_school_dispatch_release_workbench(jsonb)
  rename to get_school_dispatch_release_workbench_v1_base;
revoke execute on function atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)
  from public,anon,authenticated,service_role;

create function atlas_api.get_school_dispatch_release_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_response jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_row jsonb;
  v_export_ready boolean;
begin
  v_response := atlas_api.get_school_dispatch_release_workbench_v1_base(request);
  if not coalesce((v_response->>'success')::boolean,false) then return v_response; end if;
  for v_row in select value from jsonb_array_elements(v_response->'rows') loop
    v_export_ready := coalesce(
      (v_row#>>'{current_release,export_ready}')::boolean,false);
    v_row := v_row || jsonb_build_object(
      'allowed_actions',(v_row->'allowed_actions') ||
        jsonb_build_object('export',v_export_ready),
      'blockers',(v_row->'blockers') || case
        when v_row->'current_release'<>'null'::jsonb and not v_export_ready
          then '["PXK_EXPORT_SNAPSHOT_MISSING"]'::jsonb else '[]'::jsonb end
    );
    v_rows := v_rows || jsonb_build_array(v_row);
  end loop;
  return jsonb_set(v_response,'{rows}',v_rows);
exception when others then
  return jsonb_build_object('success',false,'error_code','INTERNAL_READ_FAILURE',
    'safe_message','The School dispatch release workbench could not be read safely.',
    'retryable',true,'write_certainty','NO_BUSINESS_WRITE');
end;
$$;

revoke execute on function atlas_api.get_school_dispatch_release_workbench(jsonb)
  from public,anon,service_role;
grant execute on function atlas_api.get_school_dispatch_release_workbench(jsonb)
  to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;
reset role;
grant atlas_read_runtime,atlas_procurement_command_runtime,
  atlas_dispatch_command_runtime to postgres with set false;
reset role;
