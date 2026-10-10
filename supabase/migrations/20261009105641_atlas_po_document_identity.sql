-- PR #360 authority closeout. Explicit master document codes and future-only
-- immutable school-catering PO display evidence; no historical PO backfill.
reset role;
grant atlas_owner,atlas_master_data_command_runtime,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set true;
set role atlas_owner;

alter table atlas_admin.ingredients add column document_code text,
  add constraint ingredients_document_code_check check(document_code is null or (
    document_code=btrim(document_code) and char_length(document_code) between 1 and 200
    and document_code !~ '[[:cntrl:]]'
      and document_code !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
    and document_code !~* '^v1-(ingredient|supplier)-'
    and document_code !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'));
alter table atlas_admin.suppliers add column document_code text,
  add constraint suppliers_document_code_check check(document_code is null or (
    document_code=btrim(document_code) and char_length(document_code) between 1 and 200
    and document_code !~ '[[:cntrl:]]'
      and document_code !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
    and document_code !~* '^v1-(ingredient|supplier)-'
    and document_code !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'));
grant insert(document_code),update(document_code) on atlas_admin.ingredients,atlas_admin.suppliers
  to atlas_master_data_command_runtime;

-- The approved import contracts encode the retained positive legacy ID exactly.
-- Text extraction preserves even suffixes beyond machine numeric ranges.
update atlas_admin.ingredients set document_code=substr(ingredient_code,15)
where document_code is null and ingredient_code ~ '^v1-ingredient-[1-9][0-9]*$';
update atlas_admin.suppliers set document_code=substr(supplier_code,13)
where document_code is null and supplier_code ~ '^v1-supplier-[1-9][0-9]*$';

create function atlas_core.derive_v1_master_document_code() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if new.document_code is null then
    if tg_table_name='ingredients' then
      if new.ingredient_code ~ '^v1-ingredient-[1-9][0-9]*$' then
        new.document_code:=substr(new.ingredient_code,15);
      end if;
    elsif tg_table_name='suppliers' then
      if new.supplier_code ~ '^v1-supplier-[1-9][0-9]*$' then
        new.document_code:=substr(new.supplier_code,13);
      end if;
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function atlas_core.derive_v1_master_document_code()
  from public,anon,authenticated,service_role;
create trigger derive_v1_ingredient_document_code before insert on atlas_admin.ingredients
  for each row execute function atlas_core.derive_v1_master_document_code();
create trigger derive_v1_supplier_document_code before insert on atlas_admin.suppliers
  for each row execute function atlas_core.derive_v1_master_document_code();

alter table atlas_procurement.purchase_order_revisions
  add column supplier_document_code_snapshot text;
alter table atlas_procurement.purchase_order_line_revisions
  add column ingredient_document_code_snapshot text,
  add column ingredient_name_snapshot text,
  add column unit_code_snapshot text;

-- A bounded owner helper acquires only row locks. The command runtime receives
-- no Admin UPDATE privilege, and browser roles cannot invoke this helper.
create function atlas_core.lock_school_catering_po_document_facts(
  p_supplier_id uuid,p_revision_id uuid) returns void
language plpgsql volatile security definer set search_path='' as $$
begin
  perform 1 from atlas_admin.suppliers where supplier_id=p_supplier_id for share;
  perform 1 from atlas_admin.ingredients i where exists(
    select 1 from atlas_procurement.purchase_order_line_revisions line
    where line.purchase_order_revision_id=p_revision_id and line.ingredient_id=i.ingredient_id
  ) order by i.ingredient_id for share;
  perform 1 from atlas_admin.units u where exists(
    select 1 from atlas_procurement.purchase_order_line_revisions line
    where line.purchase_order_revision_id=p_revision_id and line.unit_id=u.unit_id
  ) order by u.unit_id for share;
end;
$$;
revoke execute on function atlas_core.lock_school_catering_po_document_facts(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.lock_school_catering_po_document_facts(uuid,uuid)
  to atlas_procurement_command_runtime;

create function atlas_core.freeze_school_catering_po_header_document_code() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_kind text; v_supplier_id uuid;
begin
  select purchase_order_kind,supplier_id into v_kind,v_supplier_id
  from atlas_procurement.purchase_orders where purchase_order_id=new.purchase_order_id;
  if v_kind='SCHOOL_CATERING' and new.revision_status='RELEASED_TO_SUPPLIER' then
    select document_code into new.supplier_document_code_snapshot
    from atlas_admin.suppliers where supplier_id=v_supplier_id;
    if nullif(btrim(new.supplier_document_code_snapshot),'') is null then
      raise exception using errcode='23514',message='released PO requires supplier document code';
    end if;
  elsif new.supplier_document_code_snapshot is not null then
    raise exception using errcode='23514',message='only released school-catering PO carries document code snapshot';
  end if;
  return new;
end;
$$;
revoke execute on function atlas_core.freeze_school_catering_po_header_document_code()
  from public,anon,authenticated,service_role;
create trigger freeze_school_catering_po_header_document_code
  before insert on atlas_procurement.purchase_order_revisions
  for each row execute function atlas_core.freeze_school_catering_po_header_document_code();

-- Label/code evidence is append-only, including null historical evidence. Root
-- supersession and the existing is_current transitions still use their old rules.
create function atlas_core.guard_po_document_identity_snapshot() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_table_name='purchase_order_revisions' then
    if new.supplier_document_code_snapshot is distinct from old.supplier_document_code_snapshot then
      raise exception using errcode='23514',message='PO supplier document snapshot is immutable';
    end if;
  elsif new.ingredient_document_code_snapshot is distinct from old.ingredient_document_code_snapshot
    or new.ingredient_name_snapshot is distinct from old.ingredient_name_snapshot
    or new.unit_code_snapshot is distinct from old.unit_code_snapshot then
    raise exception using errcode='23514',message='PO item document snapshots are immutable';
  end if;
  return new;
end;
$$;
revoke execute on function atlas_core.guard_po_document_identity_snapshot()
  from public,anon,authenticated,service_role;
create trigger guard_po_header_document_identity before update of supplier_document_code_snapshot
  on atlas_procurement.purchase_order_revisions
  for each row execute function atlas_core.guard_po_document_identity_snapshot();
create trigger guard_po_line_document_identity before update of ingredient_document_code_snapshot,ingredient_name_snapshot,unit_code_snapshot
  on atlas_procurement.purchase_order_line_revisions
  for each row execute function atlas_core.guard_po_document_identity_snapshot();

grant create on schema atlas_core to atlas_master_data_command_runtime,atlas_procurement_command_runtime;
reset role;
alter function atlas_core.derive_v1_master_document_code() owner to atlas_master_data_command_runtime;
alter function atlas_core.freeze_school_catering_po_header_document_code() owner to atlas_procurement_command_runtime;
set role atlas_owner;
revoke create on schema atlas_core from atlas_master_data_command_runtime,atlas_procurement_command_runtime;
reset role;

-- Amend the existing bodies in place. Guarded source anchors preserve owners,
-- capabilities, versions, receipts, audit, catalog validation and all prior logic.
do $$
declare v_sql text; v_old text; v_name text; v_kind text; v_validation text;
begin
  v_sql:=replace(pg_get_functiondef('atlas_api.get_ingredient_supplier_master_data(jsonb)'::regprocedure),E'\r','');
  v_old:=v_sql;
  v_sql:=replace(v_sql,'''ingredient_code'', i.ingredient_code,',
    '''ingredient_code'', i.ingredient_code, ''document_code'', i.document_code,');
  v_sql:=replace(v_sql,'''supplier_code'', s.supplier_code,',
    '''supplier_code'', s.supplier_code, ''document_code'', s.document_code,');
  if v_sql=v_old then raise exception 'Master read document-code anchor absent'; end if;
  execute v_sql;

  foreach v_name in array array['create_ingredient','update_ingredient','create_supplier','update_supplier'] loop
    v_kind:=case when v_name like '%ingredient' then 'ingredient' else 'supplier' end;
    v_sql:=replace(pg_get_functiondef(('atlas_api.'||v_name||'(jsonb)')::regprocedure),E'\r','');
    v_old:=v_sql;
    v_sql:=replace(v_sql,'v_payload jsonb := request -> ''payload'';',
      'v_payload jsonb := request -> ''payload''; v_document_code text := v_payload->>''document_code'';');
    v_validation:=$validation$
  if v_payload ? 'document_code' and (
    jsonb_typeof(v_payload->'document_code') not in ('string','null')
    or (v_document_code is not null and (
      v_document_code<>btrim(v_document_code) or char_length(v_document_code) not between 1 and 200
      or v_document_code ~ '[[:cntrl:]]'
      or v_document_code ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
      or v_document_code ~* '^v1-(ingredient|supplier)-'
      or v_document_code ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'))
  ) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Use a valid outward document code or leave it blank.','ADMIN',v_name);
  end if;
$validation$;
    v_sql:=replace(v_sql,'  if atlas_core.pa_05b_safe_bigint(request ->> ''expected_version'') <> 1',
      v_validation||'  if atlas_core.pa_05b_safe_bigint(request ->> ''expected_version'') <> 1');
    if v_name like 'update_%' then
      v_sql:=replace(v_sql,'  if v_'||v_kind||'_id is null',v_validation||'  if v_'||v_kind||'_id is null');
      v_sql:=replace(v_sql,'  v_before := pg_catalog.jsonb_build_object(',
        '  if not (v_payload ? ''document_code'') then v_document_code:=v_'||v_kind||'.document_code; end if;'||E'\n'||
        '  v_before := pg_catalog.jsonb_build_object('||E'\n'||'    ''document_code'',v_'||v_kind||'.document_code,');
      v_sql:=replace(v_sql,'  set '||v_kind||'_name = v_'||v_kind||'_name,',
        '  set document_code=v_document_code, '||v_kind||'_name = v_'||v_kind||'_name,');
      v_sql:=replace(v_sql,'  v_after := pg_catalog.jsonb_build_object(',
        '  v_after := pg_catalog.jsonb_build_object('||E'\n'||'    ''document_code'',v_document_code,');
    elsif v_kind='ingredient' then
      v_sql:=replace(v_sql,'    ingredient_code, ingredient_name, ingredient_group, purchase_unit_id,',
        '    document_code, ingredient_code, ingredient_name, ingredient_group, purchase_unit_id,');
      v_sql:=replace(v_sql,'    v_code, v_ingredient_name, v_type.ingredient_type_name, v_unit_id,',
        '    v_document_code, v_code, v_ingredient_name, v_type.ingredient_type_name, v_unit_id,');
      v_sql:=replace(v_sql,'returning ingredient_id into v_ingredient_id;',
        'returning ingredient_id,document_code into v_ingredient_id,v_document_code;');
      v_sql:=replace(v_sql,'''ingredient_code'', v_code,','''document_code'',v_document_code, ''ingredient_code'', v_code,');
    else
      v_sql:=replace(v_sql,'    supplier_code,'||E'\n','    document_code, supplier_code,'||E'\n');
      v_sql:=replace(v_sql,'    v_code,'||E'\n','    v_document_code, v_code,'||E'\n');
      v_sql:=replace(v_sql,'returning supplier_id into v_supplier_id;',
        'returning supplier_id,document_code into v_supplier_id,v_document_code;');
      v_sql:=replace(v_sql,'''supplier_code'', v_code,','''document_code'',v_document_code, ''supplier_code'', v_code,');
    end if;
    if v_sql=v_old or position(v_validation in v_sql)=0 then raise exception 'Document-code command anchor absent: %',v_name; end if;
    execute v_sql;
  end loop;

  v_sql:=replace(pg_get_functiondef('atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure),E'\r','');
  v_old:=v_sql;
  v_sql:=replace(v_sql,'  select supplier_id,supplier_name,supplier_status into v_supplier',
    '  perform atlas_core.lock_school_catering_po_document_facts(v_root.supplier_id,v_expected_revision_id);'||E'\n'||
    '  select supplier_id,supplier_name,supplier_status into v_supplier');
  v_sql:=replace(v_sql,'  v_document_number := format(''PO-%s-%s'',',$release$
  if not exists(select 1 from atlas_admin.suppliers where supplier_id=v_root.supplier_id
      and document_code=btrim(document_code) and char_length(document_code) between 1 and 200
      and document_code !~ '[[:cntrl:]]'
      and document_code !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
      and document_code !~* '^v1-(ingredient|supplier)-'
      and document_code !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    or exists(select 1 from atlas_procurement.purchase_order_line_revisions line
      join atlas_admin.ingredients ingredient using(ingredient_id)
      where line.purchase_order_revision_id=v_expected_revision_id
        and (nullif(btrim(ingredient.document_code),'') is null
          or ingredient.document_code<>btrim(ingredient.document_code)
          or char_length(ingredient.document_code)>200
          or ingredient.document_code ~ '[[:cntrl:]]'
      or ingredient.document_code ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
          or ingredient.document_code ~* '^v1-(ingredient|supplier)-'
          or ingredient.document_code ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')) then
    v_error:=atlas_core.pa_05b_command_error(request,'PO_DOCUMENT_CODE_REQUIRED',
      'Bổ sung mã hàng và mã NCC trên chứng từ trước khi phát hành PO.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  v_document_number := format('PO-%s-%s',$release$);
  if v_sql=v_old then raise exception 'PO release document-validation anchor absent'; end if;
  execute v_sql;

  v_sql:=replace(pg_get_functiondef('atlas_core.freeze_school_catering_po_line_output()'::regprocedure),E'\r','');
  v_old:=v_sql;
  v_sql:=replace(v_sql,'    new.school_breakdown_snapshot :=',$capture$
    select ingredient.document_code,ingredient.ingredient_name,unit.unit_code
      into new.ingredient_document_code_snapshot,new.ingredient_name_snapshot,new.unit_code_snapshot
    from atlas_admin.ingredients ingredient join atlas_admin.units unit on unit.unit_id=new.unit_id
    where ingredient.ingredient_id=new.ingredient_id;
    if nullif(btrim(new.ingredient_document_code_snapshot),'') is null
      or nullif(btrim(new.ingredient_name_snapshot),'') is null
      or nullif(btrim(new.unit_code_snapshot),'') is null then
      raise exception using errcode='23514',message='released PO requires complete immutable item display facts';
    end if;
    new.school_breakdown_snapshot :=$capture$);
  v_sql:=replace(v_sql,'  elsif new.school_breakdown_snapshot is not null then',
    '  elsif new.school_breakdown_snapshot is not null or new.ingredient_document_code_snapshot is not null'||
    ' or new.ingredient_name_snapshot is not null or new.unit_code_snapshot is not null then');
  if v_sql=v_old then raise exception 'PO line freeze document anchor absent'; end if;
  execute v_sql;
end;
$$;

-- Existing shaped API; no extra public/base function or browser callable surface.
create or replace function atlas_api.get_school_catering_purchase_orders(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_response jsonb; v_orders jsonb:='[]'::jsonb; v_order jsonb; v_lines jsonb;
  v_official boolean; v_complete boolean; v_export_ready boolean; v_codes_ready boolean;
  v_header atlas_procurement.purchase_order_revisions%rowtype; v_supplier_code text;
begin
  v_response:=atlas_api.get_school_catering_purchase_orders_v2_base(request);
  if not coalesce((v_response->>'success')::boolean,false) then return v_response; end if;
  for v_order in select value from jsonb_array_elements(v_response->'purchase_orders') loop
    v_official:=v_order->>'status' in ('RELEASED_TO_SUPPLIER','SUPERSEDED');
    select * into strict v_header from atlas_procurement.purchase_order_revisions
      where purchase_order_revision_id=(v_order#>>'{current_revision,purchase_order_revision_id}')::uuid;
    select document_code into v_supplier_code from atlas_admin.suppliers
      where supplier_id=(v_order#>>'{supplier,supplier_id}')::uuid;
    select coalesce(jsonb_agg(line.value || jsonb_build_object(
      'ingredient_document_code_snapshot',revision.ingredient_document_code_snapshot,
      'ingredient_name_snapshot',revision.ingredient_name_snapshot,
      'unit_code_snapshot',revision.unit_code_snapshot,
      'ingredient',(line.value->'ingredient')||jsonb_build_object(
        'document_code',case when v_official then revision.ingredient_document_code_snapshot else ingredient.document_code end,
        'ingredient_name',case when v_official then coalesce(revision.ingredient_name_snapshot,'Thiếu tên hàng lịch sử') else ingredient.ingredient_name end),
      'unit',(line.value->'unit')||jsonb_build_object('unit_code',case when v_official then coalesce(revision.unit_code_snapshot,'Thiếu ĐVT lịch sử') else unit.unit_code end),
      'school_breakdown',coalesce(revision.school_breakdown_snapshot,'[]'::jsonb),
      'supplier_note',revision.supplier_note_snapshot
    ) order by line.ordinality),'[]'::jsonb) into v_lines
    from jsonb_array_elements(v_order->'lines') with ordinality line(value,ordinality)
    join atlas_procurement.purchase_order_line_revisions revision
      on revision.purchase_order_line_revision_id=(line.value->>'purchase_order_line_revision_id')::uuid
    join atlas_admin.ingredients ingredient using(ingredient_id)
    join atlas_admin.units unit on unit.unit_id=revision.unit_id;
    v_complete:=v_official and nullif(btrim(v_header.supplier_name_snapshot,U&'\0009\000A\000B\000C\000D\0020\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'),'') is not null
      and nullif(btrim(v_header.supplier_document_code_snapshot),'') is not null
      and v_header.supplier_document_code_snapshot=btrim(v_header.supplier_document_code_snapshot)
      and char_length(v_header.supplier_document_code_snapshot)<=200
      and v_header.supplier_document_code_snapshot !~ '[[:cntrl:]]'
      and v_header.supplier_document_code_snapshot !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
      and v_header.supplier_document_code_snapshot !~* '^v1-(ingredient|supplier)-'
      and v_header.supplier_document_code_snapshot !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      and jsonb_array_length(v_lines)>0 and not exists(
        select 1 from jsonb_array_elements(v_lines) line where
          nullif(btrim(line->>'ingredient_document_code_snapshot'),'') is null
          or line->>'ingredient_document_code_snapshot'<>btrim(line->>'ingredient_document_code_snapshot')
          or char_length(line->>'ingredient_document_code_snapshot')>200
          or line->>'ingredient_document_code_snapshot' ~ '[[:cntrl:]]'
      or line->>'ingredient_document_code_snapshot' ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
          or line->>'ingredient_document_code_snapshot' ~* '^v1-(ingredient|supplier)-'
          or line->>'ingredient_document_code_snapshot' ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
          or nullif(btrim(line->>'ingredient_name_snapshot',U&'\0009\000A\000B\000C\000D\0020\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'),'') is null
          or nullif(btrim(line->>'unit_code_snapshot',U&'\0009\000A\000B\000C\000D\0020\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'),'') is null
          or jsonb_array_length(line->'school_breakdown')=0);
    v_export_ready:=v_complete;
    v_codes_ready:=nullif(btrim(v_supplier_code),'') is not null
      and v_supplier_code=btrim(v_supplier_code) and char_length(v_supplier_code)<=200
      and v_supplier_code !~ '[[:cntrl:]]'
      and v_supplier_code !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
      and v_supplier_code !~* '^v1-(ingredient|supplier)-'
      and v_supplier_code !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' and not exists(
      select 1 from jsonb_array_elements(v_lines) line where
        nullif(btrim(line#>>'{ingredient,document_code}'),'') is null
        or line#>>'{ingredient,document_code}'<>btrim(line#>>'{ingredient,document_code}')
        or char_length(line#>>'{ingredient,document_code}')>200
        or line#>>'{ingredient,document_code}' ~ '[[:cntrl:]]'
      or line#>>'{ingredient,document_code}' ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
        or line#>>'{ingredient,document_code}' ~* '^v1-(ingredient|supplier)-'
        or line#>>'{ingredient,document_code}' ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}');
    v_order:=v_order||jsonb_build_object(
      'supplier',(v_order->'supplier')||jsonb_build_object(
        'document_code',case when v_official then v_header.supplier_document_code_snapshot else v_supplier_code end,
        'supplier_name',case when v_official then v_header.supplier_name_snapshot else v_order#>>'{supplier,supplier_name}' end),
      'current_revision',(v_order->'current_revision')||jsonb_build_object('supplier_document_code_snapshot',v_header.supplier_document_code_snapshot),
      'lines',v_lines,'document_snapshot_complete',v_complete,'export_ready',v_export_ready,
      'release_eligible',coalesce((v_order->>'release_eligible')::boolean,false) and v_codes_ready,
      'allowed_actions',(v_order->'allowed_actions')||jsonb_build_object(
        'export',v_export_ready,'release',coalesce((v_order#>>'{allowed_actions,release}')::boolean,false) and v_codes_ready),
      'blockers',(v_order->'blockers')||case
        when v_official and not v_complete then '["PO_DOCUMENT_SNAPSHOT_INCOMPLETE"]'::jsonb
        when not v_official and not v_codes_ready then '["PO_DOCUMENT_CODE_REQUIRED"]'::jsonb else '[]'::jsonb end,
      'disabled_reasons',(v_order->'disabled_reasons')||case
        when v_official and not v_complete then '["PO_DOCUMENT_SNAPSHOT_INCOMPLETE"]'::jsonb
        when not v_official and not v_codes_ready then '["PO_DOCUMENT_CODE_REQUIRED"]'::jsonb else '[]'::jsonb end,
      'document_export_blocker',case when v_official and not v_complete then
        'Không đủ dữ liệu chứng từ lịch sử để tái xuất chính thức.' else null end);
    v_orders:=v_orders||jsonb_build_array(v_order);
  end loop;
  return jsonb_set(v_response,'{purchase_orders}',v_orders);
exception when others then
  return jsonb_build_object('success',false,'error_code','INTERNAL_READ_FAILURE',
    'safe_message','The school-catering purchase orders could not be read safely.',
    'retryable',true,'write_certainty','NO_BUSINESS_WRITE');
end;
$$;

-- CREATE OR REPLACE preserves existing API owners and ACLs. Ownership remains
-- read runtime for reads and master/procurement runtime for business commands.
-- Rollback is forward-only: disable new maintenance/export while retaining
-- authored codes and every released snapshot column. Never rebuild old history.
reset role;
grant atlas_master_data_command_runtime,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set false;
