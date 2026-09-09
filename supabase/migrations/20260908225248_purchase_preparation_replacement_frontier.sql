-- Allow atomic purchase preparation to commit at the D-044 replacement
-- frontier without weakening exact current-PO coverage or mutating a released PO.

reset role;
grant atlas_owner,atlas_procurement_command_runtime,
  atlas_confirmed_need_review_runtime to postgres with set true;

set role atlas_owner;
grant create on schema atlas_core to atlas_procurement_command_runtime;
reset role;

set role atlas_procurement_command_runtime;
create function atlas_core.purchase_review_preparation_po_frontier(p_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_readiness jsonb;
  v_has_requirement boolean := false;
  v_has_replacement boolean := false;
  v_has_missing boolean := false;
begin
  if atlas_core.purchase_review_po_coverage(p_date) then
    return jsonb_build_object(
      'acceptable',true,
      'frontier','EXACT_COVERAGE',
      'blockers','[]'::jsonb
    );
  end if;

  v_readiness := atlas_core.school_catering_po_date_readiness(p_date);
  if not coalesce((v_readiness ->> 'ready')::boolean,false) then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','OTHER_INVALID_STATE',
      'blockers',jsonb_build_array(
        'Phân bổ nhà cung ứng chưa khớp với nhu cầu bàn giao hiện hành.'
      )
    );
  end if;

  if exists(
    select 1
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_date
      and po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and atlas_core.school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id
      )='CANCELLATION_REQUIRED'
  ) then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','CANCELLATION_REQUIRED',
      'blockers',jsonb_build_array(
        'Có đơn mua đã phát hành cần quy trình hủy trước khi tiếp tục.'
      )
    );
  end if;

  if exists(
    select 1
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_date
      and po.purchase_order_status='DRAFT'
      and (
        por.revision_status<>'DRAFT'
        or atlas_core.school_catering_po_commitment_state(
          po.purchase_order_id,por.purchase_order_revision_id
        )<>'DRAFT_CURRENT'
        or not exists(
          select 1
          from atlas_procurement.purchase_orders predecessor
          join atlas_procurement.purchase_order_revisions predecessor_revision
            on predecessor_revision.purchase_order_id=predecessor.purchase_order_id
           and predecessor_revision.is_current
          where predecessor.purchase_order_id=po.replaces_purchase_order_id
            and predecessor.purchase_order_kind='SCHOOL_CATERING'
            and predecessor.supplier_id=po.supplier_id
            and predecessor.school_catering_service_date=p_date
            and predecessor.purchase_order_status='RELEASED_TO_SUPPLIER'
            and atlas_core.school_catering_po_commitment_state(
              predecessor.purchase_order_id,
              predecessor_revision.purchase_order_revision_id
            )='REPLACEMENT_REQUIRED'
        )
      )
  ) then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','OTHER_INVALID_STATE',
      'blockers',jsonb_build_array(
        'Đơn mua nháp hiện có không còn khớp với phân bổ nhà cung ứng hiện hành. Hãy làm mới hoặc xử lý đơn nháp trước khi tiếp tục.'
      )
    );
  end if;

  with expected as materialized (
    select f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      s.supplier_split_id,s.supplier_id,s.allocated_quantity
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date=p_date
      and r.source_kind='PURCHASE_HANDOFF'
      and r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=atlas_core.pa_05b_safe_numeric(
        projection.value ->> 'family_quantity'
      )
  ), active_actual as materialized (
    select po.supplier_id,po.purchase_order_status,por.revision_status,polr.*
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.purchase_order_revision_id=por.purchase_order_revision_id
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_date
      and po.purchase_order_status in ('DRAFT','RELEASED_TO_SUPPLIER')
  ), supplier_frontiers as (
    select supplier.supplier_id,
      (
        (select count(*) from expected e
          where e.supplier_id=supplier.supplier_id)=
        (select count(*) from active_actual a
          where a.supplier_id=supplier.supplier_id)
        and not exists(
          select 1
          from expected e
          where e.supplier_id=supplier.supplier_id
            and not exists(
              select 1
              from active_actual a
              where a.supplier_id=e.supplier_id
                and a.purchase_order_status=a.revision_status
                and a.revision_status in ('DRAFT','RELEASED_TO_SUPPLIER')
                and a.school_catering_allocation_supplier_split_id=e.supplier_split_id
                and a.ordered_quantity=e.allocated_quantity
                and a.delivery_location_id=e.delivery_location_id
                and a.ingredient_id=e.ingredient_id
                and a.unit_id=e.unit_id
                and a.service_date=e.service_date
            )
        )
      ) exact_coverage,
      exists(
        select 1
        from atlas_procurement.purchase_orders po
        join atlas_procurement.purchase_order_revisions por
          on por.purchase_order_id=po.purchase_order_id and por.is_current
        where po.purchase_order_kind='SCHOOL_CATERING'
          and po.school_catering_service_date=p_date
          and po.supplier_id=supplier.supplier_id
          and po.purchase_order_status='RELEASED_TO_SUPPLIER'
          and atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id
          )='REPLACEMENT_REQUIRED'
      ) replacement_frontier
    from (select distinct e.supplier_id from expected e) supplier
  )
  select exists(select 1 from supplier_frontiers),
    coalesce(bool_or(replacement_frontier),false),
    coalesce(bool_or(not exact_coverage and not replacement_frontier),true)
  into v_has_requirement,v_has_replacement,v_has_missing
  from supplier_frontiers;

  if not v_has_requirement or v_has_missing then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','MISSING_COVERAGE',
      'blockers',jsonb_build_array(
        'Thiếu bao phủ đơn mua hiện hành cho một hoặc nhiều nhà cung ứng.'
      )
    );
  end if;

  if not v_has_replacement then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','OTHER_INVALID_STATE',
      'blockers',jsonb_build_array(
        'Trạng thái đơn mua hiện hành chưa phù hợp để tiếp tục.'
      )
    );
  end if;

  return jsonb_build_object(
    'acceptable',true,
    'frontier','REPLACEMENT_FRONTIER',
    'blockers','[]'::jsonb
  );
end;
$$;

revoke all on function
  atlas_core.purchase_review_preparation_po_frontier(date)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.purchase_review_preparation_po_frontier(date)
to atlas_confirmed_need_review_runtime;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime;
grant create on schema atlas_api to atlas_confirmed_need_review_runtime;
reset role;

set role atlas_confirmed_need_review_runtime;
do $replace_preparation_frontier$
declare
  definition text := pg_get_functiondef(
    'atlas_api.prepare_school_catering_purchase_orders(jsonb)'::regprocedure
  );
  original_definition text := definition;
begin
  definition := replace(
    definition,
    '  v_child jsonb;v_release jsonb;v_handoff jsonb;v_drafts jsonb;v_response jsonb;v_cap text;',
    '  v_child jsonb;v_release jsonb;v_handoff jsonb;v_drafts jsonb;v_frontier jsonb;v_response jsonb;v_cap text;'
  );
  definition := replace(
    definition,
    '    if not coalesce(v_drafts->''ready_dates'' @> jsonb_build_array(v_date),false)',
    E'    v_frontier:=atlas_core.purchase_review_preparation_po_frontier(v_date);\n    if not coalesce(v_drafts->''ready_dates'' @> jsonb_build_array(v_date),false)'
  );
  definition := replace(
    definition,
    '      or not atlas_core.purchase_review_po_coverage(v_date) then',
    '      or not coalesce((v_frontier->>''acceptable'')::boolean,false) then'
  );
  definition := replace(
    definition,
    '        ||jsonb_build_object(''blockers'',v_drafts->''blockers'');',
    E'        ||jsonb_build_object(''blockers'',coalesce(v_drafts->''blockers'',''[]''::jsonb)\n          ||coalesce(v_frontier->''blockers'',''[]''::jsonb));'
  );

  if definition=original_definition
     or position('v_frontier jsonb' in definition)=0
     or position('purchase_review_preparation_po_frontier(v_date)' in definition)=0
     or position('v_frontier->>''acceptable''' in definition)=0 then
    raise exception 'Expected purchase preparation definition changed';
  end if;

  execute definition;
end;
$replace_preparation_frontier$;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_confirmed_need_review_runtime;
reset role;

grant atlas_owner,atlas_procurement_command_runtime,
  atlas_confirmed_need_review_runtime to postgres with set false;
