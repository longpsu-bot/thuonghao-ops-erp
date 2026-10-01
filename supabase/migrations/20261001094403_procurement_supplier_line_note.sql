-- PROCUREMENT-SUPPLIER-LINE-NOTE-01. Add one explicit supplier instruction to
-- immutable allocation splits and freeze it on each generated PO line.
-- Existing history remains null; no hosted deployment is authorized here.

reset role;
grant atlas_owner,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set true;
set role atlas_owner;

alter table atlas_procurement.school_catering_allocation_supplier_splits
  add column supplier_note text,
  add constraint school_catering_supplier_note_check check (
    supplier_note is null or (
      supplier_note = pg_catalog.btrim(supplier_note, E' \t\n\r\f')
      and pg_catalog.char_length(supplier_note) between 1 and 500));

alter table atlas_procurement.purchase_order_line_revisions
  add column supplier_note_snapshot text,
  add constraint purchase_order_line_supplier_note_snapshot_check check (
    supplier_note_snapshot is null or (
      supplier_note_snapshot = pg_catalog.btrim(supplier_note_snapshot, E' \t\n\r\f')
      and pg_catalog.char_length(supplier_note_snapshot) between 1 and 500));

comment on column atlas_procurement.school_catering_allocation_supplier_splits.supplier_note is
  'Optional supplier-facing instruction explicitly saved with this immutable supplier allocation split.';
comment on column atlas_procurement.purchase_order_line_revisions.supplier_note_snapshot is
  'Backend-frozen supplier instruction from this line''s exact immutable allocation supplier split.';

grant create on schema atlas_core to atlas_procurement_command_runtime;
grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_procurement_command_runtime;

-- Amend the two existing source-qualified writers. The v1 request envelope
-- remains callable: omitted supplier_note is null, while an optional string or
-- JSON null is accepted. Recommendation-generated splits remain null.
do $split_writers$
declare
  target regprocedure;
  definition text;
  original text;
begin
  foreach target in array array[
    'atlas_core.school_catering_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text)'::regprocedure,
    'atlas_core.purchase_review_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text,text)'::regprocedure
  ] loop
    definition := pg_catalog.pg_get_functiondef(target);
    original := definition;
    definition := pg_catalog.replace(definition,
      $old$s - array['supplier_id','allocated_quantity'] <> '{}'::jsonb$old$,
      $new$s - array['supplier_id','allocated_quantity','supplier_note'] <> '{}'::jsonb$new$);
    definition := pg_catalog.replace(definition,
      $old$      return jsonb_build_object('success',false,'error_code','NON_POSITIVE_SPLIT');
    end if;$old$,
      $new$      return jsonb_build_object('success',false,'error_code','NON_POSITIVE_SPLIT');
    end if;
    if exists(select 1 from pg_catalog.jsonb_array_elements(p_splits) s
      where (s ? 'supplier_note' and pg_catalog.jsonb_typeof(s -> 'supplier_note') not in ('string','null'))
         or pg_catalog.char_length(pg_catalog.btrim(s ->> 'supplier_note', E' \t\n\r\f')) > 500) then
      return jsonb_build_object('success',false,'error_code','SUPPLIER_NOTE_INVALID');
    end if;$new$);
    definition := pg_catalog.replace(definition,
      $old$family_revision_id,supplier_id,allocated_quantity,split_ratio,decision_origin)$old$,
      $new$family_revision_id,supplier_id,allocated_quantity,split_ratio,decision_origin,supplier_note)$new$);
    definition := pg_catalog.replace(definition,
      $old$p_decision_origin);$old$,
      $new$p_decision_origin,
      nullif(pg_catalog.btrim(v_split ->> 'supplier_note', E' \t\n\r\f'),''));$new$);
    if definition = original
       or pg_catalog.strpos(definition,$new$decision_origin,supplier_note)$new$)=0
       or pg_catalog.strpos(definition,$new$'error_code','SUPPLIER_NOTE_INVALID'$new$)=0 then
      raise exception 'Supplier note writer amendment did not match %',target;
    end if;
    execute definition;
  end loop;
end;
$split_writers$;

-- Promotion must carry the exact note from the confirmed-source split.
do $promotion$
declare
  definition text := pg_catalog.pg_get_functiondef(
    'atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid)'::regprocedure);
  old_fragment text := $old$'supplier_id',s.supplier_id,'allocated_quantity',s.allocated_quantity::text)$old$;
begin
  if pg_catalog.strpos(definition,old_fragment)=0 then
    raise exception 'Expected allocation promotion split projection was not found';
  end if;
  execute pg_catalog.replace(definition,old_fragment,
    $new$'supplier_id',s.supplier_id,'allocated_quantity',s.allocated_quantity::text,
      'supplier_note',s.supplier_note)$new$);
end;
$promotion$;

-- The insert guard is the only writer of supplier_note_snapshot. It also
-- retains the existing released School breakdown freeze and completeness gate.
create or replace function atlas_core.freeze_school_catering_po_line_output()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_revision_status text;
  v_total numeric(20,6);
begin
  if new.school_catering_allocation_supplier_split_id is not null then
    select split.supplier_note into new.supplier_note_snapshot
    from atlas_procurement.school_catering_allocation_supplier_splits split
    where split.supplier_split_id=new.school_catering_allocation_supplier_split_id;
  elsif new.supplier_note_snapshot is not null then
    raise exception using errcode='23514',
      message='non-school PO line cannot carry a supplier split note';
  end if;

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
    from pg_catalog.jsonb_array_elements(new.school_breakdown_snapshot) school;
    if pg_catalog.jsonb_array_length(new.school_breakdown_snapshot)=0
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

-- Both allocation reads expose the persisted note. Existing public RPC names
-- and numeric-string shaping stay intact.
reset role;
set role atlas_read_runtime;
do $confirmed_read$
declare
  definition text := pg_catalog.pg_get_functiondef(
    'atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  old_fragment text := $old$'allocated_quantity',s.allocated_quantity::text,'split_ratio',s.split_ratio::text)$old$;
begin
  if pg_catalog.strpos(definition,old_fragment)=0 then
    raise exception 'Expected confirmed allocation split projection was not found';
  end if;
  execute pg_catalog.replace(definition,old_fragment,
    $new$'allocated_quantity',s.allocated_quantity::text,'split_ratio',s.split_ratio::text,
      'supplier_note',s.supplier_note)$new$);
end;
$confirmed_read$;

create or replace function atlas_api.get_school_catering_procurement_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  response jsonb;
  shaped_rows jsonb;
begin
  response := atlas_core.procurement_read_exact_numbers_as_strings(
    atlas_core.get_school_catering_procurement_workbench_numeric_compat(request));
  if response->>'success' is distinct from 'true' then return response; end if;
  select coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_set(row.value,'{splits}',coalesce((
      select pg_catalog.jsonb_agg(split.value || pg_catalog.jsonb_build_object(
        'supplier_note',saved.supplier_note) order by split.ordinality)
      from pg_catalog.jsonb_array_elements(row.value->'splits')
        with ordinality split(value,ordinality)
      left join atlas_procurement.school_catering_allocation_supplier_splits saved
        on saved.supplier_split_id=(split.value->>'supplier_split_id')::uuid
    ),'[]'::jsonb)) order by row.ordinality),'[]'::jsonb)
    into shaped_rows
  from pg_catalog.jsonb_array_elements(response->'rows')
    with ordinality row(value,ordinality);
  return pg_catalog.jsonb_set(response,'{rows}',shaped_rows);
end;
$$;

-- PO reads use the frozen line column, including historical released and
-- superseded revisions; they never reconstruct a note from current allocation.
do $po_read$
declare
  definition text := pg_catalog.pg_get_functiondef(
    'atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure);
  old_fragment text := $old$'school_breakdown',coalesce(revision.school_breakdown_snapshot,'[]'::jsonb)$old$;
begin
  if pg_catalog.strpos(definition,old_fragment)=0 then
    raise exception 'Expected PO line snapshot projection was not found';
  end if;
  definition := pg_catalog.replace(definition,old_fragment,
    $new$'school_breakdown',coalesce(revision.school_breakdown_snapshot,'[]'::jsonb),
      'supplier_note',revision.supplier_note_snapshot$new$);
  -- A superseded released PO remains an immutable supplier document. Apply
  -- the existing complete-snapshot gate to both historical issued statuses.
  definition := pg_catalog.replace(definition,
    $old$v_order->>'status'='RELEASED_TO_SUPPLIER'$old$,
    $new$v_order->>'status' in ('RELEASED_TO_SUPPLIER','SUPERSEDED')$new$);
  if pg_catalog.strpos(definition,$new$v_order->>'status' in ('RELEASED_TO_SUPPLIER','SUPERSEDED')$new$)=0 then
    raise exception 'Expected released/superseded export guard was not amended';
  end if;
  execute definition;
end;
$po_read$;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime;
revoke create on schema atlas_api from atlas_read_runtime;
reset role;
grant atlas_owner,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set false;
