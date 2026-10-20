-- Owner #400 / 6279713889: reconcile the two existing advisory reads with K2.
-- Writers, source rejection, privileges, locks and immutable history are intact.
begin;

do $allocation_read$
declare definition text;
begin
  definition:=pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  if position('-- Once promoted, retain the real Handoff source' in definition)=0
    or position('v_exact_source' in definition)>0 then
    raise exception 'K3 unexpected pinned allocation read baseline';
  end if;
  definition:=replace(definition,'  v_blockers jsonb:',
    '  v_proof jsonb; v_canonical jsonb; v_post_release boolean; v_exact_source boolean;'||E'\n  v_blockers jsonb:');
  definition:=replace(definition,$old$    v_complete:=coalesce((p->>'complete')::boolean,false);
    if not v_complete then
      v_blockers:='["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."]';
      v_row_blockers:=v_blockers;
    end if;
    if v_complete and (p->>'family_quantity')::numeric<=0 then continue; end if;$old$,
    '    v_complete:=coalesce((p->>''complete'')::boolean,false);');
  definition:=replace(definition,$old$    -- Once promoted, retain the real Handoff source for currentness and legacy Save.
    if r.source_kind='PURCHASE_HANDOFF' and p->>'batch_status'='RELEASED_FOR_PURCHASE_HANDOFF' then
      p:=p || atlas_core.school_catering_family_projection((p->>'service_date')::date,
        (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)
        || jsonb_build_object('source_kind','PURCHASE_HANDOFF');
    end if;$old$,
$new$    -- K2 selects authority per family, not from the whole batch's new version.
    -- Keep actual CN School membership above: Handoff contributors carry source
    -- line identities, not a School's current default-location membership.
    select exists(select 1 from atlas_planning.confirmed_need_batches batch
      where batch.confirmed_need_batch_id=(p->>'source_confirmed_need_batch_id')::uuid
        and batch.batch_status='REOPENED' and batch.released_at is not null)
      into v_post_release;
    if v_post_release then
      v_proof:=atlas_core.purchase_review_confirmed_projection((p->>'service_date')::date,
        (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid);
      if v_proof->>'corrected_source_eligible' is distinct from 'true' then
        p:=p||jsonb_build_object('complete',false,'source_fingerprint',null,'family_quantity',null);
      elsif v_proof->>'corrected_family'='true' then
        -- A genuine later correction remains an editable CN proposal even when
        -- the canonical selector rejects the previously accepted contributors.
        p:=p||v_proof;
      else
        v_canonical:=atlas_core.school_catering_family_projection((p->>'service_date')::date,
          (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid);
        p:=(p-array['source_confirmed_need_batch_id','source_confirmed_need_batch_version'])
          ||v_canonical||jsonb_build_object('source_kind','PURCHASE_HANDOFF',
            'complete',v_canonical->>'source_purchase_handoff_revision_id' is not null
              and jsonb_array_length(v_canonical->'contributions')>0);
      end if;
    elsif r.source_kind='PURCHASE_HANDOFF' and p->>'batch_status'='RELEASED_FOR_PURCHASE_HANDOFF' then
      p:=p||atlas_core.school_catering_family_projection((p->>'service_date')::date,
          (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)
        ||jsonb_build_object('source_kind','PURCHASE_HANDOFF');
    end if;
    v_complete:=coalesce((p->>'complete')::boolean,false)
      and p->>'source_fingerprint' is not null and p->>'family_quantity' is not null
      and (p->>'source_kind'<>'PURCHASE_HANDOFF' or (
        p->>'source_purchase_handoff_revision_id' is not null
        and jsonb_array_length(p->'contributions')>0));
    p:=p||jsonb_build_object('complete',v_complete);
    if not v_complete then
      v_row_blockers:=jsonb_build_array('Nguồn nhu cầu chưa đầy đủ hoặc đã thay đổi. Tải lại và kiểm tra trước khi phân bổ.');
      v_blockers:=v_row_blockers;
    end if;
    if v_complete and (p->>'family_quantity')::numeric<=0 then continue; end if;
    -- Exact typed source membership; equal totals alone do not establish currentness.
    -- K2 permits an earlier CN batch version only while these same contributors
    -- remain current (a later correction can affect a different family).
    v_exact_source:=r.source_kind=p->>'source_kind' and r.unit_id=(p->>'unit_id')::uuid
      and case when p->>'source_kind'='CONFIRMED_NEED' then
        r.source_confirmed_need_batch_id::text=p->>'source_confirmed_need_batch_id'
        and r.source_confirmed_need_batch_version<=(p->>'source_confirmed_need_batch_version')::bigint
        and r.source_purchase_handoff_revision_id is null
      else r.source_purchase_handoff_revision_id::text=p->>'source_purchase_handoff_revision_id'
        and r.source_confirmed_need_batch_id is null and r.source_confirmed_need_batch_version is null end
      and not exists((select c.purchase_handoff_line_revision_id,
          c.confirmed_need_line_revision_id,c.confirmed_need_line_decision_id,c.contribution_quantity
        from atlas_procurement.school_catering_allocation_family_contributions c
        where c.family_revision_id=r.family_revision_id
        except select (c->>'purchase_handoff_line_revision_id')::uuid,
          (c->>'confirmed_need_line_revision_id')::uuid,(c->>'confirmed_need_line_decision_id')::uuid,
          (c->>'contribution_quantity')::numeric from jsonb_array_elements(p->'contributions') c)
        union all (select (c->>'purchase_handoff_line_revision_id')::uuid,
          (c->>'confirmed_need_line_revision_id')::uuid,(c->>'confirmed_need_line_decision_id')::uuid,
          (c->>'contribution_quantity')::numeric from jsonb_array_elements(p->'contributions') c
        except select c.purchase_handoff_line_revision_id,
          c.confirmed_need_line_revision_id,c.confirmed_need_line_decision_id,c.contribution_quantity
        from atlas_procurement.school_catering_allocation_family_contributions c
        where c.family_revision_id=r.family_revision_id));$new$);
  definition:=replace(definition,
    'when r.source_fingerprint=p->>''source_fingerprint'' and v_eligible',
    'when r.source_fingerprint=p->>''source_fingerprint'' and v_exact_source and v_eligible');
  definition:=replace(definition,
    'when r.source_fingerprint<>p->>''source_fingerprint'' and v_eligible',
    'when (r.source_fingerprint is distinct from p->>''source_fingerprint'' or not coalesce(v_exact_source,false)) and v_eligible');
  definition:=replace(definition,$old$  v_legacy:=atlas_api.get_school_catering_procurement_workbench(
    request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1'));$old$,
$new$  -- Only unmatched Handoff keys can contribute legacy rows. Avoid running
  -- a second complete K2 projection of families already materialized above.
  v_legacy:=jsonb_build_object('rows','[]'::jsonb);
  if exists(select 1 from atlas_planning.purchase_handoff_batches batch
    join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
    join atlas_planning.purchase_handoff_line_revisions line using(purchase_handoff_revision_id)
    join atlas_planning.purchase_demand_references demand using(purchase_handoff_line_revision_id)
    where batch.handoff_status='RELEASED_TO_PROCUREMENT' and revision.is_current
      and revision.revision_status='RELEASED_TO_PROCUREMENT' and demand.source_kind='NEED_GENERATION'
      and line.service_date between v_start and v_end
      and atlas_core.school_catering_actor_has_scope(v_actor_id,null,null,line.delivery_location_id)
      and not exists(select 1 from jsonb_array_elements(v_sources) source
        where source->>'service_date'=line.service_date::text
          and source->>'delivery_location_id'=line.delivery_location_id::text
          and source->>'ingredient_id'=line.ingredient_id::text and source->>'unit_id'=line.unit_id::text)) then
    v_legacy:=atlas_api.get_school_catering_procurement_workbench(
      request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1'));
  end if;$new$);
  definition:=replace(definition,$old$      v_rows:=v_rows||jsonb_build_array(v_row||jsonb_build_object('complete',true,
        'family',(v_row->'family')||jsonb_build_object('source_kind','PURCHASE_HANDOFF')));$old$,
$new$      -- A legacy key can outlive the current CN source. K2's unavailable
      -- projection is a blocker, never complete/editable historical authority.
      v_complete:=v_row#>>'{family,source_fingerprint}' is not null
        and coalesce((v_row->>'family_quantity')::numeric,0)>0
        and jsonb_array_length(coalesce(v_row->'contributions','[]'))>0;
      v_row:=v_row||jsonb_build_object('complete',v_complete,
        'family',(v_row->'family')||jsonb_build_object('source_kind','PURCHASE_HANDOFF'),
        'allowed_actions',jsonb_build_object(
          'save_allocation',v_complete and v_can_write
            and coalesce((v_row#>>'{allowed_actions,save_allocation}')::boolean,false),
          'confirm_recommendation',v_complete and v_can_write
            and coalesce((v_row#>>'{allowed_actions,confirm_recommendation}')::boolean,false)));
      if not v_complete then
        v_row:=v_row||jsonb_build_object('state','BLOCKED','recommendation',null,
          'rebalance_proposal',null,'disabled_reasons',jsonb_build_array(
            'Nguồn nhu cầu không còn hiện hành. Tải lại và kiểm tra trước khi phân bổ.'),
          'blockers',jsonb_build_array('Nguồn nhu cầu không còn hiện hành. Tải lại và kiểm tra trước khi phân bổ.'));
      end if;
      v_rows:=v_rows||jsonb_build_array(v_row);$new$);
  if position('K2 selects authority per family' in definition)=0 then
    raise exception 'K3 allocation read source anchor changed';
  end if;
  execute definition;
end $allocation_read$;

do $preparation_read$
declare definition text;
begin
  definition:=pg_get_functiondef('atlas_core.purchase_review_preparation_status(date,uuid)'::regprocedure);
  if position('v_post_release' in definition)>0 then
    raise exception 'K3 unexpected pinned Preparation read baseline';
  end if;
  definition:=replace(definition,'  v_ready boolean:=false;',
    '  v_post_release boolean:=false; v_proof jsonb; v_cancellation_required boolean:=false;'||E'\n  v_ready boolean:=false;');
  definition:=replace(definition,$old$  v_ready:=atlas_core.purchase_review_preparation_allocation_ready(v_batch)
    or coalesce((atlas_core.school_catering_po_date_readiness(p_date)->>'ready')::boolean,false);$old$,
$new$  if p->>'batch_status'='REOPENED' then
    -- K2 validates the entire single batch's current facts and original history.
    -- Reuse that proof once; date readiness still selects every family below.
    v_proof:=atlas_core.purchase_review_confirmed_projection((p->>'service_date')::date,
      (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid);
    v_post_release:=coalesce((v_proof->>'post_release_correction')::boolean,false);
  end if;
  if v_post_release then
    -- Same whole-date canonical gate as Preparation, independent of UI filters.
    -- Raw CN/default readiness cannot override a retained Handoff SOURCE_CHANGED.
    v_ready:=coalesce((v_proof->>'corrected_source_eligible')::boolean,false)
      and coalesce((atlas_core.school_catering_po_date_readiness(p_date)->>'ready')::boolean,false);
    if v_ready then
      -- Reuse the frontier's existing cancellation discriminator. Do not require
      -- pre-Draft coverage: Preparation itself creates that complete coverage.
      select exists(select 1 from atlas_procurement.purchase_orders po
        join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
        where po.purchase_order_kind='SCHOOL_CATERING' and po.school_catering_service_date=p_date
          and po.purchase_order_status='RELEASED_TO_SUPPLIER' and revision.is_current
          and atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,revision.purchase_order_revision_id)='CANCELLATION_REQUIRED')
        into v_cancellation_required;
      v_ready:=not v_cancellation_required;
    end if;
  else
    v_ready:=atlas_core.purchase_review_preparation_allocation_ready(v_batch)
      or coalesce((atlas_core.school_catering_po_date_readiness(p_date)->>'ready')::boolean,false);
  end if;$new$);
  definition:=replace(definition,
    '''blockers'',case when v_ready then ''[]''::jsonb else',
    '''blockers'',case when v_ready then ''[]''::jsonb when v_cancellation_required then '||
      'jsonb_build_array(''Có đơn mua đã phát hành cần quy trình hủy trước khi tiếp tục.'') else');
  if position('Same whole-date canonical gate' in definition)=0 then
    raise exception 'K3 Preparation read readiness anchor changed';
  end if;
  execute definition;
end $preparation_read$;

commit;
