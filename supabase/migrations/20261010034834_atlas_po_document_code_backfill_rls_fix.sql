-- Forward correction for PR #360 hosted adoption.
-- The original backfill executed under atlas_owner, while FORCE RLS correctly
-- prevented owner UPDATE without a matching policy. Run the deterministic
-- source-derived adoption as the migration principal and prove completeness.
reset role;

update atlas_admin.ingredients
set document_code=substr(ingredient_code,15)
where document_code is null
  and ingredient_code ~ '^v1-ingredient-[1-9][0-9]*$';

update atlas_admin.suppliers
set document_code=substr(supplier_code,13)
where document_code is null
  and supplier_code ~ '^v1-supplier-[1-9][0-9]*$';

do $verify$
begin
  if exists(
    select 1 from atlas_admin.ingredients
    where ingredient_code ~ '^v1-ingredient-[1-9][0-9]*$'
      and document_code is distinct from substr(ingredient_code,15)
  ) then
    raise exception 'V1 Ingredient document-code adoption incomplete';
  end if;
  if exists(
    select 1 from atlas_admin.suppliers
    where supplier_code ~ '^v1-supplier-[1-9][0-9]*$'
      and document_code is distinct from substr(supplier_code,13)
  ) then
    raise exception 'V1 Supplier document-code adoption incomplete';
  end if;
end;
$verify$;
