-- ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01: approved forward-only null-code amendment.
-- Existing owners, privileges, locks, receipts and all historical data remain.
begin;
create temporary table b2_role_lease on commit drop as
select r.rolname,a.set_option from pg_roles r join pg_auth_members a on a.roleid=r.oid
where a.member=(select oid from pg_roles where rolname=current_user)
  and a.grantor=(select oid from pg_roles where rolname=current_user)
  and r.rolname in ('atlas_owner','atlas_procurement_command_runtime','atlas_read_runtime');
do $$ begin
  if (select count(*) from b2_role_lease)<>3 then
    raise exception 'B2 requires the existing three authoring memberships';
  end if;
end $$;
create temporary table b2_function_security on commit drop as
select oid,proowner,proacl,proconfig,prosecdef,provolatile from pg_proc
where oid in ('atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure,
  'atlas_core.freeze_school_catering_po_line_output()'::regprocedure,
  'atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure);
create temporary table b2_schema_lease on commit drop as
select schema_name,role_name,has_schema_privilege(role_name,schema_name,'CREATE') as had_create
from (values ('atlas_api','atlas_procurement_command_runtime'),
  ('atlas_core','atlas_procurement_command_runtime'),('atlas_api','atlas_read_runtime'))
  leases(schema_name,role_name);
grant select on b2_schema_lease to atlas_owner;
grant atlas_owner,atlas_procurement_command_runtime,atlas_read_runtime to postgres with set true;
set role atlas_owner;
do $$ declare lease record; begin
  for lease in select * from b2_schema_lease where not had_create loop
    execute format('grant create on schema %I to %I',lease.schema_name,lease.role_name);
  end loop;
end $$;
reset role;
set role atlas_procurement_command_runtime;
do $patch$
declare
  definition text := replace(pg_get_functiondef('atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure),E'\r','');
  change record;
begin
  if strpos(definition,'ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01')>0 then return; end if;
  for change in select * from (values
      (1,$old$  if not exists(select 1 from atlas_admin.suppliers where supplier_id=v_root.supplier_id
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
$old$,$new$  -- ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01: Supplier identity required; Ingredient code optional.
  if not exists(select 1 from atlas_admin.suppliers where supplier_id=v_root.supplier_id
      and document_code=btrim(document_code) and char_length(document_code) between 1 and 200
      and document_code !~ '[[:cntrl:]]'
      and document_code !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
      and document_code !~* '^v1-(ingredient|supplier)-'
      and document_code !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') then
    v_error:=atlas_core.pa_05b_command_error(request,'PO_DOCUMENT_CODE_REQUIRED',
      'Bổ sung mã NCC trên chứng từ trước khi phát hành PO.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if exists(select 1 from atlas_procurement.purchase_order_line_revisions line
      join atlas_admin.ingredients ingredient using(ingredient_id)
      where line.purchase_order_revision_id=v_expected_revision_id
        and ingredient.document_code is not null
        and (nullif(btrim(ingredient.document_code),'') is null
          or ingredient.document_code<>btrim(ingredient.document_code)
          or char_length(ingredient.document_code)>200
          or ingredient.document_code ~ '[[:cntrl:]]'
      or ingredient.document_code ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
          or ingredient.document_code ~* '^v1-(ingredient|supplier)-'
          or ingredient.document_code ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')) then
    v_error:=atlas_core.pa_05b_command_error(request,'PO_INGREDIENT_DOCUMENT_CODE_INVALID',
      'Mã nội bộ nguyên liệu không hợp lệ; kiểm tra Dữ liệu gốc hoặc để trống.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
$new$)
  ) changes(expected_count,old_text,new_text) loop
    if (length(definition)-length(replace(definition,change.old_text,'')))
       /length(change.old_text)<>change.expected_count then
      raise exception 'B2 expected predecessor anchor absent in atlas_api.release_school_catering_purchase_order(jsonb)';
    end if;
    definition:=replace(definition,change.old_text,change.new_text);
  end loop;
  execute definition;
end;
$patch$;
do $patch$
declare
  definition text := replace(pg_get_functiondef('atlas_core.freeze_school_catering_po_line_output()'::regprocedure),E'\r','');
  change record;
begin
  if strpos(definition,'ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01')>0 then return; end if;
  for change in select * from (values
      (1,$old$    if nullif(btrim(new.ingredient_document_code_snapshot),'') is null
      or nullif(btrim(new.ingredient_name_snapshot),'') is null$old$,$new$    -- ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01: freeze null internal codes without inventing one.
    if nullif(btrim(new.ingredient_name_snapshot),'') is null$new$)
  ) changes(expected_count,old_text,new_text) loop
    if (length(definition)-length(replace(definition,change.old_text,'')))
       /length(change.old_text)<>change.expected_count then
      raise exception 'B2 expected predecessor anchor absent in atlas_core.freeze_school_catering_po_line_output()';
    end if;
    definition:=replace(definition,change.old_text,change.new_text);
  end loop;
  execute definition;
end;
$patch$;
reset role;
set role atlas_read_runtime;
do $patch$
declare
  definition text := replace(pg_get_functiondef('atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure),E'\r','');
  change record;
begin
  if strpos(definition,'ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01')>0 then return; end if;
  for change in select * from (values
      (1,$old$v_codes_ready boolean;$old$,$new$v_codes_ready boolean; v_supplier_code_ready boolean;$new$),
      (1,$old$  v_response:=atlas_api.get_school_catering_purchase_orders_v2_base(request);$old$,$new$  -- ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01: nullable Ingredient metadata is not an outward requirement.
  v_response:=atlas_api.get_school_catering_purchase_orders_v2_base(request);$new$),
      (1,$old$          nullif(btrim(line->>'ingredient_document_code_snapshot'),'') is null
          or line->>'ingredient_document_code_snapshot'<>btrim(line->>'ingredient_document_code_snapshot')
          or char_length(line->>'ingredient_document_code_snapshot')>200
          or line->>'ingredient_document_code_snapshot' ~ '[[:cntrl:]]'
      or line->>'ingredient_document_code_snapshot' ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
          or line->>'ingredient_document_code_snapshot' ~* '^v1-(ingredient|supplier)-'
          or line->>'ingredient_document_code_snapshot' ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
$old$,$new$          (line->>'ingredient_document_code_snapshot' is not null and (
          nullif(btrim(line->>'ingredient_document_code_snapshot'),'') is null
          or line->>'ingredient_document_code_snapshot'<>btrim(line->>'ingredient_document_code_snapshot')
          or char_length(line->>'ingredient_document_code_snapshot')>200
          or line->>'ingredient_document_code_snapshot' ~ '[[:cntrl:]]'
      or line->>'ingredient_document_code_snapshot' ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
          or line->>'ingredient_document_code_snapshot' ~* '^v1-(ingredient|supplier)-'
          or line->>'ingredient_document_code_snapshot' ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'))
$new$),
      (1,$old$    v_codes_ready:=nullif(btrim(v_supplier_code),'') is not null
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
$old$,$new$    v_supplier_code_ready:=nullif(btrim(v_supplier_code),'') is not null
      and v_supplier_code=btrim(v_supplier_code) and char_length(v_supplier_code)<=200
      and v_supplier_code !~ '[[:cntrl:]]'
      and v_supplier_code !~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
      and v_supplier_code !~* '^v1-(ingredient|supplier)-'
      and v_supplier_code !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
    v_codes_ready:=v_supplier_code_ready and not exists(
      select 1 from jsonb_array_elements(v_lines) line where
        (line#>>'{ingredient,document_code}' is not null and (
        nullif(btrim(line#>>'{ingredient,document_code}'),'') is null
        or line#>>'{ingredient,document_code}'<>btrim(line#>>'{ingredient,document_code}')
        or char_length(line#>>'{ingredient,document_code}')>200
        or line#>>'{ingredient,document_code}' ~ '[[:cntrl:]]'
      or line#>>'{ingredient,document_code}' ~ U&'^[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]|[\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]$'
        or line#>>'{ingredient,document_code}' ~* '^v1-(ingredient|supplier)-'
        or line#>>'{ingredient,document_code}' ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')));
$new$),
      (2,$old$when not v_official and not v_codes_ready then '["PO_DOCUMENT_CODE_REQUIRED"]'::jsonb else '[]'::jsonb end,$old$,$new$when not v_official and not v_supplier_code_ready then '["PO_DOCUMENT_CODE_REQUIRED"]'::jsonb
        when not v_official and not v_codes_ready then '["PO_INGREDIENT_DOCUMENT_CODE_INVALID"]'::jsonb else '[]'::jsonb end,$new$)
  ) changes(expected_count,old_text,new_text) loop
    if (length(definition)-length(replace(definition,change.old_text,'')))
       /length(change.old_text)<>change.expected_count then
      raise exception 'B2 expected predecessor anchor absent in atlas_api.get_school_catering_purchase_orders(jsonb)';
    end if;
    definition:=replace(definition,change.old_text,change.new_text);
  end loop;
  execute definition;
end;
$patch$;
reset role;
set role atlas_owner;
do $$ declare lease record; begin
  for lease in select * from b2_schema_lease where not had_create loop
    execute format('revoke create on schema %I from %I',lease.schema_name,lease.role_name);
  end loop;
end $$;
reset role;
do $$ declare lease record; begin
  if exists(select 1 from b2_function_security before join pg_proc after using(oid)
    where before.proowner is distinct from after.proowner
       or before.proacl is distinct from after.proacl
       or before.proconfig is distinct from after.proconfig
       or before.prosecdef is distinct from after.prosecdef
       or before.provolatile is distinct from after.provolatile) then
    raise exception 'B2 changed function security attributes';
  end if;
  for lease in select * from b2_role_lease loop
    execute format('grant %I to postgres with set %s',lease.rolname,
      case when lease.set_option then 'true' else 'false' end);
  end loop;
end $$;
commit;
