-- Correct master-rehearsal semantics for optional School output configuration.
-- Missing issuer facts remain explicit and dispatch release stays fail-closed;
-- missing active attendance defaults remain blockers.
set role atlas_owner;

CREATE OR REPLACE FUNCTION atlas_legacy.master_import_validate_values(kind text, legacy text, source_row jsonb, v jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare result jsonb:='[]'; f text; status text;
begin
  if v is null then return result; end if;
  if kind='DISH_TYPE' and (legacy not in ('1','2','3','4','5','6') or source_row->>'dish_type_code' is distinct from ('{"1":"soup","2":"savory","3":"stir_fry","4":"dessert","5":"afternoon_snack","6":"beverage"}'::jsonb->>legacy)) then
    result:=result||jsonb_build_array(jsonb_build_object('code','DISH_TYPE_MAPPING_MISMATCH','field','dish_type_code'));
  end if;
  for f in select key from jsonb_each(v) e where e.key not in ('delivery_instructions','effective_to','dispatch_document_issuer_name','dispatch_document_issuer_address') and (e.value='null'::jsonb or (jsonb_typeof(e.value)='string' and nullif(btrim(e.value #>> '{}'),'') is null)) loop
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_REQUIRED_VALUE','field',f));
  end loop;
  status:=coalesce(v->>'school_type_status',v->>'customer_status',v->>'location_status',v->>'school_status',v->>'unit_status',v->>'ingredient_status',v->>'supplier_status',v->>'eligibility_status');
  if status is not null and status not in ('ACTIVE','INACTIVE','ARCHIVED','SUSPENDED') then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_LIFECYCLE','field','status'));
  end if;
  if kind='SCHOOL_TYPE' and (legacy not in ('1','2') or v->>'school_type_code'<>'v1-school-type-'||legacy or v->>'school_type_name'<>case legacy when '1' then 'TIỂU HỌC' when '2' then 'TRUNG HỌC' end) then
    result:=result||jsonb_build_array(jsonb_build_object('code','UNKNOWN_SCHOOL_TYPE','field','school_type_code'));
  end if;
  if kind='SCHOOL' and (
    (v->>'display_order')::integer<0
    or (v->>'default_student_portions')::integer<0
    or (v->>'default_teacher_portions')::integer<0
    or v->>'school_code'<>'v1-school-'||legacy
    or ((
      (v->>'dispatch_document_issuer_name' is null and v->>'dispatch_document_issuer_address' is null)
      or (
        v->>'dispatch_document_issuer_name' in ('CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO','CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO')
        and v->>'dispatch_document_issuer_address'='ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam'
      )
    ) is not true)
  ) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_SCHOOL_VALUE','field','school'));
  end if;
  if kind='UNIT' then
    if legacy not in ('kg','Bịch','Bó','Cái','Cây','Chai','Cốc','Gói','Hộp','Hũ','Lon','Miếng','Ổ','Quả','Trái') or
      v->>'unit_name'<>(case when legacy='kg' then 'Kilogram' else legacy end) or
      v->>'unit_code'<>(case when legacy='kg' then 'kg' else 'v1-unit-'||substr(encode(extensions.digest(convert_to(legacy,'UTF8'),'sha256'),'hex'),1,12) end) or
      v->>'dimension_code'<>(case when legacy='kg' then 'MASS' else 'COUNT' end) or
      (v->>'decimal_scale')::integer<>(case when legacy='kg' then 6 else 0 end) then
      result:=result||jsonb_build_array(jsonb_build_object('code','UNSUPPORTED_UNIT','field','unit'));
    end if;
  end if;
  if kind='INGREDIENT' and (coalesce(source_row->>'order_step','') !~ '^\d{1,14}(\.\d{1,6})?$' or (v->>'order_step')::numeric<=0 or v->>'ingredient_code'<>'v1-ingredient-'||legacy) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_INGREDIENT_VALUE','field','order_step'));
  end if;
  if kind='SUPPLIER_ELIGIBILITY' and ((v->>'priority')::integer not between 1 and 6) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_PRIORITY','field','priority'));
  end if;
  return result;
end $function$

;

reset role;
