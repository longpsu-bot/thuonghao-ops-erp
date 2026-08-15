-- UI-QUALITY-03C-B amendment: restore the two controlled Ingredient
-- classifications evidenced by OPS v1 without adding a generic taxonomy,
-- capability, role, public function name, or browser table access.

set role atlas_owner;

create table atlas_admin.ingredient_types (
  ingredient_type_id uuid not null default gen_random_uuid(),
  ingredient_type_code text not null,
  ingredient_type_name text not null,
  display_order smallint not null,
  ingredient_type_status text not null default 'ACTIVE',
  constraint ingredient_types_pkey primary key (ingredient_type_id),
  constraint ingredient_types_code_key unique (ingredient_type_code),
  constraint ingredient_types_name_key unique (ingredient_type_name),
  constraint ingredient_types_display_order_key unique (display_order),
  constraint ingredient_types_code_check check (
    ingredient_type_code = lower(btrim(ingredient_type_code))
    and ingredient_type_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'
  ),
  constraint ingredient_types_name_check check (
    ingredient_type_name = btrim(ingredient_type_name)
    and ingredient_type_name <> ''
  ),
  constraint ingredient_types_display_order_check check (display_order > 0),
  constraint ingredient_types_status_check check (
    ingredient_type_status in ('ACTIVE', 'INACTIVE')
  )
);

create index ingredient_types_status_order_idx
  on atlas_admin.ingredient_types (
    ingredient_type_status,
    display_order,
    ingredient_type_code
  );

create table atlas_admin.ingredient_order_groups (
  ingredient_order_group_id uuid not null default gen_random_uuid(),
  ingredient_order_group_code text not null,
  ingredient_order_group_name text not null,
  display_order smallint not null,
  ingredient_order_group_status text not null default 'ACTIVE',
  constraint ingredient_order_groups_pkey primary key (
    ingredient_order_group_id
  ),
  constraint ingredient_order_groups_code_key unique (
    ingredient_order_group_code
  ),
  constraint ingredient_order_groups_name_key unique (
    ingredient_order_group_name
  ),
  constraint ingredient_order_groups_display_order_key unique (display_order),
  constraint ingredient_order_groups_code_check check (
    ingredient_order_group_code = lower(btrim(ingredient_order_group_code))
    and ingredient_order_group_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'
  ),
  constraint ingredient_order_groups_name_check check (
    ingredient_order_group_name = btrim(ingredient_order_group_name)
    and ingredient_order_group_name <> ''
  ),
  constraint ingredient_order_groups_display_order_check check (
    display_order > 0
  ),
  constraint ingredient_order_groups_status_check check (
    ingredient_order_group_status in ('ACTIVE', 'INACTIVE')
  )
);

create index ingredient_order_groups_status_order_idx
  on atlas_admin.ingredient_order_groups (
    ingredient_order_group_status,
    display_order,
    ingredient_order_group_code
  );

insert into atlas_admin.ingredient_types (
  ingredient_type_id,
  ingredient_type_code,
  ingredient_type_name,
  display_order
) values
  ('c3100000-0000-4000-8000-000000000001', 'banh_keo', 'Bánh kẹo', 1),
  ('c3100000-0000-4000-8000-000000000002', 'banh_nuoc', 'Bánh nước', 2),
  ('c3100000-0000-4000-8000-000000000003', 'bo', 'Bò', 3),
  ('c3100000-0000-4000-8000-000000000004', 'bo_sua', 'Bơ sữa', 4),
  ('c3100000-0000-4000-8000-000000000005', 'bun_nui_mi_kho', 'Bún, nui, mì khô', 5),
  ('c3100000-0000-4000-8000-000000000006', 'cha', 'Chả', 6),
  ('c3100000-0000-4000-8000-000000000007', 'dau_hu', 'Đậu hủ', 7),
  ('c3100000-0000-4000-8000-000000000008', 'gia_cam', 'Gia cầm', 8),
  ('c3100000-0000-4000-8000-000000000009', 'heo', 'Heo', 9),
  ('c3100000-0000-4000-8000-000000000010', 'khac', 'Khác', 10),
  ('c3100000-0000-4000-8000-000000000011', 'lap_xuong_tom_kho', 'Lạp xưởng - tôm khô', 11),
  ('c3100000-0000-4000-8000-000000000012', 'rau_cu_qua', 'Rau củ quả', 12),
  ('c3100000-0000-4000-8000-000000000013', 'sua_tuoi', 'Sữa tươi', 13),
  ('c3100000-0000-4000-8000-000000000014', 'tan_tuoi', 'Tần tươi', 14),
  ('c3100000-0000-4000-8000-000000000015', 'thuc_pham_kho_gia_vi', 'Thực phẩm khô - gia vị', 15),
  ('c3100000-0000-4000-8000-000000000016', 'thuy_hai_san', 'Thuỷ hải sản', 16),
  ('c3100000-0000-4000-8000-000000000017', 'trung', 'Trứng', 17);

insert into atlas_admin.ingredient_order_groups (
  ingredient_order_group_id,
  ingredient_order_group_code,
  ingredient_order_group_name,
  display_order
) values
  ('c3200000-0000-4000-8000-000000000001', 'pantry', 'Hàng đặt riêng', 1),
  ('c3200000-0000-4000-8000-000000000002', 'daily_vegetable', 'Rau củ', 2),
  ('c3200000-0000-4000-8000-000000000003', 'daily_other', 'Còn lại', 3);

alter table atlas_admin.ingredients
  add column ingredient_type_id uuid,
  add column ingredient_order_group_id uuid,
  add constraint ingredients_ingredient_type_fkey foreign key (
    ingredient_type_id
  ) references atlas_admin.ingredient_types (ingredient_type_id)
    on delete restrict,
  add constraint ingredients_order_group_fkey foreign key (
    ingredient_order_group_id
  ) references atlas_admin.ingredient_order_groups (
    ingredient_order_group_id
  ) on delete restrict;

create index ingredients_ingredient_type_idx
  on atlas_admin.ingredients (ingredient_type_id)
  where ingredient_type_id is not null;
create index ingredients_order_group_idx
  on atlas_admin.ingredients (ingredient_order_group_id)
  where ingredient_order_group_id is not null;

-- Only exact catalog names after the existing trim/case normalization are
-- backfilled. Unknown historical text remains visibly unresolved rather than
-- being guessed or promoted into a catalog row.
update atlas_admin.ingredients ingredient
set ingredient_type_id = ingredient_type.ingredient_type_id,
    ingredient_type = ingredient_type.ingredient_type_name,
    ingredient_group = ingredient_type.ingredient_type_name
from atlas_admin.ingredient_types ingredient_type
where ingredient.ingredient_type_id is null
  and lower(btrim(ingredient.ingredient_type)) =
    lower(ingredient_type.ingredient_type_name);

update atlas_admin.ingredients ingredient
set ingredient_order_group_id = order_group.ingredient_order_group_id,
    shopping_type = order_group.ingredient_order_group_name
from atlas_admin.ingredient_order_groups order_group
where ingredient.ingredient_order_group_id is null
  and lower(btrim(ingredient.shopping_type)) =
    lower(order_group.ingredient_order_group_name);

alter table atlas_admin.ingredient_types enable row level security;
alter table atlas_admin.ingredient_types force row level security;
alter table atlas_admin.ingredient_order_groups enable row level security;
alter table atlas_admin.ingredient_order_groups force row level security;

grant select on
  atlas_admin.ingredient_types,
  atlas_admin.ingredient_order_groups
to atlas_read_runtime, atlas_master_data_command_runtime;

grant insert (
  ingredient_type_id,
  ingredient_order_group_id
) on atlas_admin.ingredients to atlas_master_data_command_runtime;
grant update (
  ingredient_type_id,
  ingredient_order_group_id
) on atlas_admin.ingredients to atlas_master_data_command_runtime;

create policy ui_quality_03c_b_read_types
  on atlas_admin.ingredient_types
  for select to atlas_read_runtime using (true);
create policy ui_quality_03c_b_read_order_groups
  on atlas_admin.ingredient_order_groups
  for select to atlas_read_runtime using (true);
create policy ui_quality_03c_b_command_types
  on atlas_admin.ingredient_types
  for select to atlas_master_data_command_runtime using (true);
create policy ui_quality_03c_b_command_order_groups
  on atlas_admin.ingredient_order_groups
  for select to atlas_master_data_command_runtime using (true);

comment on table atlas_admin.ingredient_types is
  'Private predefined Ingredient material classifications; exposed only through the authorized RMVP-01 shaped read.';
comment on table atlas_admin.ingredient_order_groups is
  'Private predefined operational purchasing/review groups with stable workflow order: Pantry special-order, daily vegetables, then other daily Ingredients.';
comment on column atlas_admin.ingredients.ingredient_type_id is
  'Authoritative Ingredient material-classification identity; legacy ingredient_type text is compatibility shaping only.';
comment on column atlas_admin.ingredients.ingredient_order_group_id is
  'Authoritative Ingredient purchasing/review-group identity; legacy shopping_type text is compatibility shaping only.';

-- Temporary SET membership permits the owner role to replace the existing
-- runtime-owned functions without changing their owners. It is revoked below.
reset role;
grant atlas_read_runtime, atlas_master_data_command_runtime
  to atlas_owner with set true;
set role atlas_owner;
grant create on schema atlas_api
  to atlas_read_runtime, atlas_master_data_command_runtime;
reset role;

-- Preserve RMVP-01.v1 while shaping the authoritative identities and active
-- option catalogs through the existing authorized read function.
set role atlas_read_runtime;

create or replace function atlas_api.get_ingredient_supplier_master_data(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_ingredient_supplier_master_data';
  v_error jsonb;
  v_context jsonb;
  v_ingredients jsonb;
  v_suppliers jsonb;
  v_units jsonb;
  v_ingredient_types jsonb;
  v_ingredient_order_groups jsonb;
begin
  v_error := atlas_core.rmvp_01_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_id', i.ingredient_id,
        'ingredient_code', i.ingredient_code,
        'ingredient_name', i.ingredient_name,
        'ingredient_status', i.ingredient_status,
        'ingredient_type_id', i.ingredient_type_id,
        'ingredient_type_name', coalesce(it.ingredient_type_name, i.ingredient_type),
        'ingredient_order_group_id', i.ingredient_order_group_id,
        'ingredient_order_group_name', coalesce(iog.ingredient_order_group_name, i.shopping_type),
        'ingredient_type', coalesce(it.ingredient_type_name, i.ingredient_type),
        'shopping_type', coalesce(iog.ingredient_order_group_name, i.shopping_type),
        'purchase_unit_id', i.purchase_unit_id,
        'purchase_unit_code', u.unit_code,
        'purchase_unit_name', u.unit_name,
        'order_step', i.order_step,
        'version', i.version,
        'supplier_priorities',
        coalesce(
          (
            select pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'supplier_eligibility_id', se.supplier_eligibility_id,
                'supplier_id', sp.supplier_id,
                'supplier_name', sp.supplier_name,
                'priority', se.priority
              )
              order by se.priority, sp.supplier_name, sp.supplier_id
            )
            from atlas_admin.supplier_eligibilities se
            join atlas_admin.suppliers sp on sp.supplier_id = se.supplier_id
            where se.ingredient_id = i.ingredient_id
              and se.eligibility_status = 'ACTIVE'
              and se.priority is not null
          ),
          '[]'::jsonb
        )
      )
      order by i.ingredient_name, i.ingredient_id
    ),
    '[]'::jsonb
  )
  into v_ingredients
  from atlas_admin.ingredients i
  left join atlas_admin.units u on u.unit_id = i.purchase_unit_id
  left join atlas_admin.ingredient_types it
    on it.ingredient_type_id = i.ingredient_type_id
  left join atlas_admin.ingredient_order_groups iog
    on iog.ingredient_order_group_id = i.ingredient_order_group_id;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'supplier_id', s.supplier_id,
        'supplier_code', s.supplier_code,
        'supplier_name', s.supplier_name,
        'supplier_status', s.supplier_status,
        'contact_name', s.contact_name,
        'contact_phone', s.contact_phone,
        'contact_email', s.contact_email,
        'version', s.version
      )
      order by s.supplier_name, s.supplier_id
    ),
    '[]'::jsonb
  ) into v_suppliers
  from atlas_admin.suppliers s;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'unit_id', u.unit_id,
        'unit_code', u.unit_code,
        'unit_name', u.unit_name,
        'unit_status', u.unit_status
      )
      order by u.unit_name, u.unit_id
    ),
    '[]'::jsonb
  ) into v_units
  from atlas_admin.units u;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_type_id', it.ingredient_type_id,
        'ingredient_type_code', it.ingredient_type_code,
        'ingredient_type_name', it.ingredient_type_name,
        'display_order', it.display_order,
        'ingredient_type_status', it.ingredient_type_status
      ) order by it.display_order, it.ingredient_type_code
    ),
    '[]'::jsonb
  ) into v_ingredient_types
  from atlas_admin.ingredient_types it
  where it.ingredient_type_status = 'ACTIVE';

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_order_group_id', iog.ingredient_order_group_id,
        'ingredient_order_group_code', iog.ingredient_order_group_code,
        'ingredient_order_group_name', iog.ingredient_order_group_name,
        'display_order', iog.display_order,
        'ingredient_order_group_status', iog.ingredient_order_group_status
      ) order by iog.display_order, iog.ingredient_order_group_code
    ),
    '[]'::jsonb
  ) into v_ingredient_order_groups
  from atlas_admin.ingredient_order_groups iog
  where iog.ingredient_order_group_status = 'ACTIVE';

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-01.v1',
    'correlation_id', request ->> 'correlation_id',
    'ingredients', v_ingredients,
    'suppliers', v_suppliers,
    'units', v_units,
    'ingredient_types', v_ingredient_types,
    'ingredient_order_groups', v_ingredient_order_groups,
    'safe_operator_message', 'Authorized ingredient and supplier master data returned.'
  );
exception when others then
  return atlas_core.rmvp_01_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'Ingredient and supplier master data could not be returned safely.'
  );
end;
$$;

reset role;

-- Existing RMVP-01 command names now accept authoritative IDs. Legacy text
-- remains accepted only when it resolves to one exact canonical display name
-- after trim/case normalization. IDs and text may not disagree.
set role atlas_master_data_command_runtime;

create or replace function atlas_api.create_ingredient(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_ingredient';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_code', '')));
  v_ingredient_name text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_name', ''));
  v_type_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_type_id');
  v_type_text text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_type', ''));
  v_group_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_order_group_id');
  v_group_text text := pg_catalog.btrim(coalesce(v_payload ->> 'shopping_type', ''));
  v_type atlas_admin.ingredient_types%rowtype;
  v_group atlas_admin.ingredient_order_groups%rowtype;
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'purchase_unit_id');
  v_order_step numeric := atlas_core.pa_05b_safe_numeric(v_payload ->> 'order_step');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient_id uuid;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or v_code = '' or v_ingredient_name = '' or v_unit_id is null
     or v_order_step is null or v_order_step <= 0
     or (not (v_payload ? 'ingredient_type_id') and v_type_text = '')
     or (not (v_payload ? 'ingredient_order_group_id') and v_group_text = '')
     or ((v_payload ? 'ingredient_type_id') and v_type_id is null)
     or ((v_payload ? 'ingredient_order_group_id') and v_group_id is null) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'Ingredient values are incomplete or invalid.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'code, name, purchase unit, authoritative ingredient type, authoritative order group, and a positive order step are required; create uses expected_version 1.'
      ))
    );
  end if;

  if v_type_id is not null then
    select * into v_type from atlas_admin.ingredient_types
    where ingredient_type_id = v_type_id and ingredient_type_status = 'ACTIVE';
  else
    select * into v_type from atlas_admin.ingredient_types
    where lower(ingredient_type_name) = lower(v_type_text)
      and ingredient_type_status = 'ACTIVE';
  end if;
  if not found or (v_type_text <> '' and lower(v_type_text) <> lower(v_type.ingredient_type_name)) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The ingredient type is not an active Atlas catalog value.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload.ingredient_type_id',
        'message', 'Use one active Ingredient type ID, or its exact canonical display name.'
      ))
    );
  end if;

  if v_group_id is not null then
    select * into v_group from atlas_admin.ingredient_order_groups
    where ingredient_order_group_id = v_group_id
      and ingredient_order_group_status = 'ACTIVE';
  else
    select * into v_group from atlas_admin.ingredient_order_groups
    where lower(ingredient_order_group_name) = lower(v_group_text)
      and ingredient_order_group_status = 'ACTIVE';
  end if;
  if not found or (v_group_text <> '' and lower(v_group_text) <> lower(v_group.ingredient_order_group_name)) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The order group is not an active Atlas catalog value.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload.ingredient_order_group_id',
        'message', 'Use one active Ingredient order-group ID, or its exact canonical display name.'
      ))
    );
  end if;

  v_prepare := atlas_core.rmvp_01_prepare_command(
    request, v_name, 'master_data.ingredients.write', 'ingredient-code:' || v_code
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if not exists (
    select 1 from atlas_admin.units
    where unit_id = v_unit_id and unit_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The purchase unit is not active.', 'ADMIN', v_name
      ), false
    );
  end if;
  insert into atlas_admin.ingredients (
    ingredient_code, ingredient_name, ingredient_group, purchase_unit_id,
    ingredient_type_id, ingredient_order_group_id,
    ingredient_type, shopping_type, order_step
  ) values (
    v_code, v_ingredient_name, v_type.ingredient_type_name, v_unit_id,
    v_type.ingredient_type_id, v_group.ingredient_order_group_id,
    v_type.ingredient_type_name, v_group.ingredient_order_group_name, v_order_step
  ) returning ingredient_id into v_ingredient_id;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientCreated',
    'Ingredient', v_ingredient_id, null, 1, null,
    pg_catalog.jsonb_build_object(
      'ingredient_code', v_code,
      'ingredient_name', v_ingredient_name,
      'ingredient_status', 'ACTIVE',
      'purchase_unit_id', v_unit_id,
      'ingredient_type_id', v_type.ingredient_type_id,
      'ingredient_type', v_type.ingredient_type_name,
      'ingredient_order_group_id', v_group.ingredient_order_group_id,
      'shopping_type', v_group.ingredient_order_group_name,
      'order_step', v_order_step
    ),
    'Ingredient created.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request, 'CONFLICT', 'The ingredient code is already in use.', 'ADMIN', v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The ingredient could not be created safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.update_ingredient(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_ingredient';
  v_payload jsonb := request -> 'payload';
  v_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_id');
  v_ingredient_name text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_name', ''));
  v_type_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_type_id');
  v_type_text text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_type', ''));
  v_group_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_order_group_id');
  v_group_text text := pg_catalog.btrim(coalesce(v_payload ->> 'shopping_type', ''));
  v_type atlas_admin.ingredient_types%rowtype;
  v_group atlas_admin.ingredient_order_groups%rowtype;
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'purchase_unit_id');
  v_order_step numeric := atlas_core.pa_05b_safe_numeric(v_payload ->> 'order_step');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient atlas_admin.ingredients%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if v_ingredient_id is null or v_ingredient_name = '' or v_unit_id is null
     or v_order_step is null or v_order_step <= 0
     or (not (v_payload ? 'ingredient_type_id') and v_type_text = '')
     or (not (v_payload ? 'ingredient_order_group_id') and v_group_text = '')
     or ((v_payload ? 'ingredient_type_id') and v_type_id is null)
     or ((v_payload ? 'ingredient_order_group_id') and v_group_id is null) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'Ingredient values are incomplete or invalid.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'ingredient_id, name, purchase unit, authoritative ingredient type, authoritative order group, and a positive order step are required.'
      ))
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request, v_name, 'master_data.ingredients.write', 'ingredient:' || v_ingredient_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_ingredient from atlas_admin.ingredients
  where ingredient_id = v_ingredient_id for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The ingredient was not found.', 'ADMIN', v_name
      ), false
    );
  end if;
  if v_ingredient.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The ingredient changed after it was read. Refresh before saving.',
        'ADMIN', v_name, false, '[]'::jsonb, '[]'::jsonb, v_ingredient.version
      ), false
    );
  end if;
  if v_ingredient.ingredient_status = 'ARCHIVED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION', 'Archived ingredients cannot be edited.', 'ADMIN', v_name
      ), false
    );
  end if;

  if v_type_id is not null then
    select * into v_type from atlas_admin.ingredient_types
    where ingredient_type_id = v_type_id
      and (ingredient_type_status = 'ACTIVE' or ingredient_type_id = v_ingredient.ingredient_type_id);
  else
    select * into v_type from atlas_admin.ingredient_types
    where lower(ingredient_type_name) = lower(v_type_text)
      and (ingredient_type_status = 'ACTIVE' or ingredient_type_id = v_ingredient.ingredient_type_id);
  end if;
  if not found or (v_type_text <> '' and lower(v_type_text) <> lower(v_type.ingredient_type_name)) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The ingredient type is not an assignable Atlas catalog value.',
        'ADMIN', v_name, false,
        pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'field', 'payload.ingredient_type_id',
          'message', 'Use an active Ingredient type, or preserve the Ingredient current inactive type.'
        ))
      ), false
    );
  end if;
  if v_group_id is not null then
    select * into v_group from atlas_admin.ingredient_order_groups
    where ingredient_order_group_id = v_group_id
      and (ingredient_order_group_status = 'ACTIVE' or ingredient_order_group_id = v_ingredient.ingredient_order_group_id);
  else
    select * into v_group from atlas_admin.ingredient_order_groups
    where lower(ingredient_order_group_name) = lower(v_group_text)
      and (ingredient_order_group_status = 'ACTIVE' or ingredient_order_group_id = v_ingredient.ingredient_order_group_id);
  end if;
  if not found or (v_group_text <> '' and lower(v_group_text) <> lower(v_group.ingredient_order_group_name)) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The order group is not an assignable Atlas catalog value.',
        'ADMIN', v_name, false,
        pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'field', 'payload.ingredient_order_group_id',
          'message', 'Use an active order group, or preserve the Ingredient current inactive order group.'
        ))
      ), false
    );
  end if;
  if not exists (
    select 1 from atlas_admin.units
    where unit_id = v_unit_id
      and (unit_status = 'ACTIVE' or unit_id = v_ingredient.purchase_unit_id)
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The purchase unit is not assignable.', 'ADMIN', v_name
      ), false
    );
  end if;

  v_before := pg_catalog.jsonb_build_object(
    'ingredient_name', v_ingredient.ingredient_name,
    'purchase_unit_id', v_ingredient.purchase_unit_id,
    'ingredient_type_id', v_ingredient.ingredient_type_id,
    'ingredient_type', v_ingredient.ingredient_type,
    'ingredient_order_group_id', v_ingredient.ingredient_order_group_id,
    'shopping_type', v_ingredient.shopping_type,
    'order_step', v_ingredient.order_step,
    'ingredient_status', v_ingredient.ingredient_status
  );
  update atlas_admin.ingredients
  set ingredient_name = v_ingredient_name,
      ingredient_group = v_type.ingredient_type_name,
      purchase_unit_id = v_unit_id,
      ingredient_type_id = v_type.ingredient_type_id,
      ingredient_order_group_id = v_group.ingredient_order_group_id,
      ingredient_type = v_type.ingredient_type_name,
      shopping_type = v_group.ingredient_order_group_name,
      order_step = v_order_step,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ingredient_id = v_ingredient_id;
  v_after := pg_catalog.jsonb_build_object(
    'ingredient_name', v_ingredient_name,
    'purchase_unit_id', v_unit_id,
    'ingredient_type_id', v_type.ingredient_type_id,
    'ingredient_type', v_type.ingredient_type_name,
    'ingredient_order_group_id', v_group.ingredient_order_group_id,
    'shopping_type', v_group.ingredient_order_group_name,
    'order_step', v_order_step,
    'ingredient_status', v_ingredient.ingredient_status
  );
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientUpdated',
    'Ingredient', v_ingredient_id, v_ingredient.version, v_ingredient.version + 1,
    v_before, v_after, 'Ingredient saved.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The ingredient could not be locked safely. Retry the exact request.',
      'ADMIN', v_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The ingredient could not be saved safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.set_ingredient_lifecycle(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'set_ingredient_lifecycle';
  v_payload jsonb := request -> 'payload';
  v_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_id');
  v_status text := pg_catalog.upper(pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_status', '')));
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient atlas_admin.ingredients%rowtype;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if v_ingredient_id is null or v_status not in ('ACTIVE', 'INACTIVE', 'ARCHIVED') then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The ingredient lifecycle request is invalid.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload.ingredient_status', 'message', 'Use ACTIVE, INACTIVE, or ARCHIVED.'
      ))
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request, v_name, 'master_data.ingredients.write', 'ingredient:' || v_ingredient_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_ingredient from atlas_admin.ingredients
  where ingredient_id = v_ingredient_id for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The ingredient was not found.', 'ADMIN', v_name
      ), false
    );
  end if;
  if v_ingredient.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The ingredient changed after it was read. Refresh before saving.',
        'ADMIN', v_name, false, '[]'::jsonb, '[]'::jsonb, v_ingredient.version
      ), false
    );
  end if;
  if v_ingredient.ingredient_status = 'ARCHIVED' and v_status <> 'ARCHIVED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'Archived ingredients are retained for traceability and cannot be reactivated.',
        'ADMIN', v_name
      ), false
    );
  end if;
  if v_status = 'ACTIVE' and (
    v_ingredient.purchase_unit_id is null
    or v_ingredient.ingredient_type_id is null
    or v_ingredient.ingredient_order_group_id is null
    or v_ingredient.order_step is null
    or not exists (
      select 1 from atlas_admin.ingredient_types
      where ingredient_type_id = v_ingredient.ingredient_type_id
        and ingredient_type_status = 'ACTIVE'
    )
    or not exists (
      select 1 from atlas_admin.ingredient_order_groups
      where ingredient_order_group_id = v_ingredient.ingredient_order_group_id
        and ingredient_order_group_status = 'ACTIVE'
    )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'The ingredient must have complete active purchasing fields before activation.',
        'ADMIN', v_name
      ), false
    );
  end if;
  update atlas_admin.ingredients
  set ingredient_status = v_status,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ingredient_id = v_ingredient_id;
  if v_status <> 'ACTIVE' then
    update atlas_admin.supplier_eligibilities
    set eligibility_status = 'INACTIVE',
        effective_to = greatest(current_date, effective_from + 1),
        version = version + 1,
        updated_at = pg_catalog.transaction_timestamp()
    where ingredient_id = v_ingredient_id
      and eligibility_status = 'ACTIVE';
  end if;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientLifecycleChanged',
    'Ingredient', v_ingredient_id, v_ingredient.version, v_ingredient.version + 1,
    pg_catalog.jsonb_build_object('ingredient_status', v_ingredient.ingredient_status),
    pg_catalog.jsonb_build_object('ingredient_status', v_status),
    'Ingredient lifecycle saved without deleting referenced history.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The ingredient could not be locked safely. Retry the exact request.',
      'ADMIN', v_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The ingredient lifecycle could not be saved safely.', 'ADMIN', v_name
    );
end;
$$;

reset role;

-- Keep the legacy importer entry point stable. The original implementation is
-- retained as a private core; this wrapper rejects unknown catalog display
-- names before any target data is written and canonicalizes valid imports.
alter function atlas_legacy.import_master_data_snapshot(jsonb)
  rename to import_master_data_snapshot_core;

create function atlas_legacy.import_master_data_snapshot(snapshot jsonb)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_source_system text := pg_catalog.btrim(coalesce(snapshot ->> 'source_system', ''));
  v_snapshot_id text := pg_catalog.btrim(coalesce(snapshot ->> 'snapshot_id', ''));
  v_checksum text := pg_catalog.lower(pg_catalog.btrim(coalesce(snapshot ->> 'snapshot_checksum', '')));
  v_exported_at timestamptz := atlas_core.pa_05b_safe_timestamptz(snapshot ->> 'exported_at');
  v_records jsonb := snapshot -> 'records';
  v_batch_id uuid := gen_random_uuid();
  v_existing atlas_legacy.import_batches%rowtype;
  v_source_counts jsonb;
  v_total_source_count bigint := 0;
  v_errors jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if current_user <> 'postgres' then
    raise exception using
      errcode = '42501',
      message = 'RMVP-01 import is restricted to the privileged local database operator.';
  end if;

  if v_source_system = '' or v_snapshot_id = ''
     or v_checksum !~ '^[0-9a-f]{64}$'
     or v_exported_at is null or v_records is null
     or pg_catalog.jsonb_typeof(v_records) <> 'object' then
    return atlas_legacy.import_master_data_snapshot_core(snapshot);
  end if;
  select * into v_existing from atlas_legacy.import_batches
  where source_system = v_source_system and snapshot_id = v_snapshot_id;
  if found then
    return atlas_legacy.import_master_data_snapshot_core(snapshot);
  end if;

  v_source_counts := pg_catalog.jsonb_build_object(
    'customers', pg_catalog.jsonb_array_length(coalesce(v_records -> 'customers', '[]'::jsonb)),
    'delivery_locations', pg_catalog.jsonb_array_length(coalesce(v_records -> 'delivery_locations', '[]'::jsonb)),
    'school_types', pg_catalog.jsonb_array_length(coalesce(v_records -> 'school_types', '[]'::jsonb)),
    'schools', pg_catalog.jsonb_array_length(coalesce(v_records -> 'schools', '[]'::jsonb)),
    'units', pg_catalog.jsonb_array_length(coalesce(v_records -> 'units', '[]'::jsonb)),
    'ingredients', pg_catalog.jsonb_array_length(coalesce(v_records -> 'ingredients', '[]'::jsonb)),
    'suppliers', pg_catalog.jsonb_array_length(coalesce(v_records -> 'suppliers', '[]'::jsonb)),
    'supplier_priorities', pg_catalog.jsonb_array_length(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb))
  );
  select coalesce(pg_catalog.sum(value::bigint), 0) into v_total_source_count
  from pg_catalog.jsonb_each_text(v_source_counts);

  select coalesce(pg_catalog.jsonb_agg(error_item order by error_item ->> 'legacy_id', error_item ->> 'field'), '[]'::jsonb)
  into v_errors
  from (
    select pg_catalog.jsonb_build_object(
      'legacy_id', item ->> 'legacy_id',
      'field', 'records.ingredients.ingredient_type',
      'message', 'Ingredient type must resolve to one active canonical Atlas catalog display name.'
    ) error_item
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'ingredients', '[]'::jsonb)) item
    where not exists (
      select 1 from atlas_admin.ingredient_types it
      where lower(it.ingredient_type_name) = lower(pg_catalog.btrim(coalesce(item ->> 'ingredient_type', '')))
        and it.ingredient_type_status = 'ACTIVE'
    )
    union all
    select pg_catalog.jsonb_build_object(
      'legacy_id', item ->> 'legacy_id',
      'field', 'records.ingredients.shopping_type',
      'message', 'Order group must resolve to one active canonical Atlas catalog display name.'
    )
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'ingredients', '[]'::jsonb)) item
    where not exists (
      select 1 from atlas_admin.ingredient_order_groups iog
      where lower(iog.ingredient_order_group_name) = lower(pg_catalog.btrim(coalesce(item ->> 'shopping_type', '')))
        and iog.ingredient_order_group_status = 'ACTIVE'
    )
  ) errors;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    v_result := pg_catalog.jsonb_build_object(
      'success', false,
      'error_code', 'SNAPSHOT_REJECTED',
      'safe_message', 'The snapshot contains an unknown Ingredient catalog value; no target writes were committed.',
      'import_batch_id', v_batch_id,
      'source_counts', v_source_counts,
      'duplicate_references', '[]'::jsonb,
      'missing_references', '[]'::jsonb,
      'validation_errors', v_errors,
      'operation_counts', pg_catalog.jsonb_build_object(
        'inserted', 0, 'updated', 0, 'skipped', 0, 'rejected', v_total_source_count
      ),
      'reconciliation', pg_catalog.jsonb_build_object('passed', false),
      'rerun', false
    );
    insert into atlas_legacy.import_batches (
      import_batch_id, source_system, snapshot_id, snapshot_checksum,
      exported_at, import_status, source_counts, operation_counts,
      duplicate_references, missing_references, validation_errors,
      reconciliation, result_payload, completed_at
    ) values (
      v_batch_id, v_source_system, v_snapshot_id, v_checksum,
      v_exported_at, 'REJECTED', v_source_counts,
      v_result -> 'operation_counts', '[]'::jsonb, '[]'::jsonb, v_errors,
      v_result -> 'reconciliation', v_result, pg_catalog.transaction_timestamp()
    );
    return v_result;
  end if;

  v_result := atlas_legacy.import_master_data_snapshot_core(snapshot);
  if coalesce((v_result ->> 'success')::boolean, false) then
    update atlas_admin.ingredients ingredient
    set ingredient_type_id = it.ingredient_type_id,
        ingredient_order_group_id = iog.ingredient_order_group_id,
        ingredient_group = it.ingredient_type_name,
        ingredient_type = it.ingredient_type_name,
        shopping_type = iog.ingredient_order_group_name
    from atlas_legacy.master_data_mappings mapping,
      pg_catalog.jsonb_array_elements(coalesce(v_records -> 'ingredients', '[]'::jsonb)) item,
      atlas_admin.ingredient_types it,
      atlas_admin.ingredient_order_groups iog
    where mapping.import_batch_id = atlas_core.pa_05b_safe_uuid(v_result ->> 'import_batch_id')
      and mapping.object_type = 'INGREDIENT'
      and mapping.ingredient_id = ingredient.ingredient_id
      and mapping.legacy_id = item ->> 'legacy_id'
      and lower(it.ingredient_type_name) = lower(pg_catalog.btrim(item ->> 'ingredient_type'))
      and lower(iog.ingredient_order_group_name) = lower(pg_catalog.btrim(item ->> 'shopping_type'));
  end if;
  return v_result;
end;
$$;

revoke execute on function atlas_legacy.import_master_data_snapshot_core(jsonb)
  from public, anon, authenticated, service_role,
    atlas_read_runtime, atlas_master_data_command_runtime;
grant execute on function atlas_legacy.import_master_data_snapshot_core(jsonb)
  to postgres;
revoke execute on function atlas_legacy.import_master_data_snapshot(jsonb)
  from public, anon, authenticated, service_role,
    atlas_read_runtime, atlas_master_data_command_runtime;
grant execute on function atlas_legacy.import_master_data_snapshot(jsonb)
  to postgres;

comment on function atlas_legacy.import_master_data_snapshot_core(jsonb) is
  'Private original RMVP-01 snapshot importer retained behind the authoritative Ingredient-catalog validation wrapper.';
comment on function atlas_legacy.import_master_data_snapshot(jsonb) is
  'RMVP-01 local-operator-only importer; rejects unknown Ingredient catalog names and resolves exact normalized display names to authoritative IDs.';

set role atlas_read_runtime;
comment on function atlas_api.get_ingredient_supplier_master_data(jsonb) is
  'RMVP-01.v1 authorized shaped read including active Ingredient catalogs and per-Ingredient authoritative catalog identities.';
reset role;

set role atlas_master_data_command_runtime;
comment on function atlas_api.create_ingredient(jsonb) is
  'RMVP-01.v1 Ingredient creation using authoritative catalog IDs with exact canonical legacy-name compatibility.';
comment on function atlas_api.update_ingredient(jsonb) is
  'RMVP-01.v1 Ingredient update using authoritative catalog IDs with exact canonical legacy-name compatibility.';
reset role;

set role atlas_owner;
revoke create on schema atlas_api
  from atlas_read_runtime, atlas_master_data_command_runtime;
reset role;
revoke atlas_read_runtime, atlas_master_data_command_runtime from atlas_owner;
