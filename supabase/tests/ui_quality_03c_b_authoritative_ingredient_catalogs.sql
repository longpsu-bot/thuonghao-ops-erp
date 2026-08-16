begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is(
  (
    select jsonb_agg(
      jsonb_build_array(ingredient_type_code, ingredient_type_name, display_order)
      order by display_order
    )
    from atlas_admin.ingredient_types
  ),
  jsonb_build_array(
    jsonb_build_array('banh_keo', 'Bánh kẹo', 1),
    jsonb_build_array('banh_nuoc', 'Bánh nước', 2),
    jsonb_build_array('bo', 'Bò', 3),
    jsonb_build_array('bo_sua', 'Bơ sữa', 4),
    jsonb_build_array('bun_nui_mi_kho', 'Bún, nui, mì khô', 5),
    jsonb_build_array('cha', 'Chả', 6),
    jsonb_build_array('dau_hu', 'Đậu hủ', 7),
    jsonb_build_array('gia_cam', 'Gia cầm', 8),
    jsonb_build_array('heo', 'Heo', 9),
    jsonb_build_array('khac', 'Khác', 10),
    jsonb_build_array('lap_xuong_tom_kho', 'Lạp xưởng - tôm khô', 11),
    jsonb_build_array('rau_cu_qua', 'Rau củ quả', 12),
    jsonb_build_array('sua_tuoi', 'Sữa tươi', 13),
    jsonb_build_array('tan_tuoi', 'Tần tươi', 14),
    jsonb_build_array('thuc_pham_kho_gia_vi', 'Thực phẩm khô - gia vị', 15),
    jsonb_build_array('thuy_hai_san', 'Thuỷ hải sản', 16),
    jsonb_build_array('trung', 'Trứng', 17)
  ),
  'the exact approved 17-value Ingredient type catalog is seeded in display order'
);

select is(
  (
    select jsonb_agg(
      jsonb_build_array(
        ingredient_order_group_code,
        ingredient_order_group_name,
        display_order
      ) order by display_order
    )
    from atlas_admin.ingredient_order_groups
  ),
  jsonb_build_array(
    jsonb_build_array('pantry', 'Hàng đặt riêng', 1),
    jsonb_build_array('daily_vegetable', 'Rau củ', 2),
    jsonb_build_array('daily_other', 'Còn lại', 3)
  ),
  'the exact approved order groups retain their v1 operational sort ranks'
);

select ok(
  (
    select bool_and(c.relrowsecurity and c.relforcerowsecurity)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_admin'
      and c.relname in ('ingredient_types', 'ingredient_order_groups')
  ),
  'both private catalogs enforce RLS'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) role_name
    cross join unnest(array['ingredient_types', 'ingredient_order_groups']) table_name
    where has_table_privilege(
      role_name,
      format('atlas_admin.%I', table_name),
      'SELECT,INSERT,UPDATE,DELETE'
    )
  ),
  'browser-facing API roles have no direct catalog-table privileges'
);

select ok(
  has_table_privilege('atlas_read_runtime', 'atlas_admin.ingredient_types', 'SELECT')
  and has_table_privilege('atlas_read_runtime', 'atlas_admin.ingredient_order_groups', 'SELECT')
  and has_table_privilege('atlas_master_data_command_runtime', 'atlas_admin.ingredient_types', 'SELECT')
  and has_table_privilege('atlas_master_data_command_runtime', 'atlas_admin.ingredient_order_groups', 'SELECT'),
  'only the existing read and Ingredient-command runtimes receive catalog reads'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values (
  'c3300000-0000-4000-8000-000000000001',
  'HUMAN',
  'UI-QUALITY-03C-B catalog tester'
);
insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values (
  'c3300000-0000-4000-8000-000000000002',
  'c3300000-0000-4000-8000-000000000001',
  'c3300000-0000-4000-8000-000000000003'
);
insert into atlas_core.roles (
  role_id, role_code, role_name
) values (
  'c3300000-0000-4000-8000-000000000004',
  'ui_quality_03c_b.catalog_tester',
  'UI-QUALITY-03C-B catalog tester'
);
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'c3300000-0000-4000-8000-000000000004', capability_id
from atlas_core.capabilities
where capability_code in ('master_data.read', 'master_data.ingredients.write');
insert into atlas_core.actor_role_memberships (actor_id, role_id) values (
  'c3300000-0000-4000-8000-000000000001',
  'c3300000-0000-4000-8000-000000000004'
);
insert into atlas_core.actor_scopes (actor_id, scope_kind) values (
  'c3300000-0000-4000-8000-000000000001',
  'GLOBAL'
);
insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'c3300000-0000-4000-8000-000000000010',
  'uiq03cb-kg',
  'UIQ03CB kilogram',
  'MASS',
  3
);

create or replace function pg_temp.catalog_request(
  p_command_id uuid,
  p_key text,
  p_payload jsonb
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-01.v1',
    'command_id', p_command_id,
    'correlation_id', 'c3300000-0000-4000-8000-000000000020',
    'idempotency_key', p_key,
    'expected_version', 1,
    'requested_by_auth_subject', 'c3300000-0000-4000-8000-000000000003',
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'UI_QUALITY_03C_B_TEST',
    'reason_note', 'Rolled-back focused catalog test',
    'payload', p_payload
  );
$$;

create temporary table catalog_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on catalog_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c3300000-0000-4000-8000-000000000003',
  true
);
insert into catalog_results values (
  'legacy_create',
  atlas_api.create_ingredient(
    pg_temp.catalog_request(
      'c3300000-0000-4000-8000-000000000101',
      'uiq03cb-legacy-create',
      jsonb_build_object(
        'ingredient_code', '  UIQ03CB-RICE  ',
        'ingredient_name', ' Gạo Jasmine ',
        'purchase_unit_id', 'c3300000-0000-4000-8000-000000000010',
        'ingredient_type', '  thực PHẨM khô - gia vị ',
        'shopping_type', ' hàng ĐẶT riêng ',
        'order_step', 0.1
      )
    )
  )
);
insert into catalog_results values (
  'conflicting_create',
  atlas_api.create_ingredient(
    pg_temp.catalog_request(
      'c3300000-0000-4000-8000-000000000102',
      'uiq03cb-conflicting-create',
      jsonb_build_object(
        'ingredient_code', 'uiq03cb-conflict',
        'ingredient_name', 'Conflict',
        'purchase_unit_id', 'c3300000-0000-4000-8000-000000000010',
        'ingredient_type_id', 'c3100000-0000-4000-8000-000000000015',
        'ingredient_type', 'Rau củ quả',
        'ingredient_order_group_id', 'c3200000-0000-4000-8000-000000000001',
        'order_step', 1
      )
    )
  )
);
insert into catalog_results values (
  'unknown_create',
  atlas_api.create_ingredient(
    pg_temp.catalog_request(
      'c3300000-0000-4000-8000-000000000103',
      'uiq03cb-unknown-create',
      jsonb_build_object(
        'ingredient_code', 'uiq03cb-unknown',
        'ingredient_name', 'Unknown',
        'purchase_unit_id', 'c3300000-0000-4000-8000-000000000010',
        'ingredient_type', 'Không có trong danh mục',
        'shopping_type', 'Hàng đặt riêng',
        'order_step', 1
      )
    )
  )
);
insert into catalog_results values (
  'shaped_read',
  atlas_api.get_ingredient_supplier_master_data(
    jsonb_build_object(
      'contract_version', 'RMVP-01.v1',
      'requested_by_auth_subject', 'c3300000-0000-4000-8000-000000000003',
      'correlation_id', 'c3300000-0000-4000-8000-000000000020',
      'payload', '{}'::jsonb
    )
  )
);
reset role;

select is(
  (select response_payload ->> 'success' from catalog_results where result_name = 'legacy_create'),
  'true',
  'legacy text input resolves after trim/case normalization'
);
select is(
  (
    select jsonb_build_array(
      ingredient_code,
      ingredient_name,
      ingredient_type_id,
      ingredient_type,
      ingredient_order_group_id,
      shopping_type,
      order_step
    )
    from atlas_admin.ingredients
    where ingredient_code = 'uiq03cb-rice'
  ),
  jsonb_build_array(
    'uiq03cb-rice',
    'Gạo Jasmine',
    'c3100000-0000-4000-8000-000000000015',
    'Thực phẩm khô - gia vị',
    'c3200000-0000-4000-8000-000000000001',
    'Hàng đặt riêng',
    0.1
  ),
  'legacy input stores canonical IDs and display names without magic numeric IDs'
);
select is(
  (select response_payload ->> 'error_code' from catalog_results where result_name = 'conflicting_create'),
  'VALIDATION_FAILED',
  'conflicting ID and legacy display text are rejected'
);
select is(
  (select response_payload ->> 'error_code' from catalog_results where result_name = 'unknown_create'),
  'VALIDATION_FAILED',
  'unknown legacy catalog text is rejected'
);
select is(
  (
    select count(*)::integer
    from atlas_admin.ingredients
    where ingredient_code in ('uiq03cb-conflict', 'uiq03cb-unknown')
  ),
  0,
  'rejected submissions create neither Ingredients nor implicit catalog rows'
);
select is(
  (
    select jsonb_array_length(response_payload -> 'ingredient_types')
    from catalog_results where result_name = 'shaped_read'
  ),
  17,
  'the shaped read exposes all active Ingredient types'
);
select is(
  (
    select response_payload -> 'ingredient_order_groups'
      -> 0 ->> 'ingredient_order_group_code'
    from catalog_results where result_name = 'shaped_read'
  ),
  'pantry',
  'the shaped read preserves operational order-group ordering'
);
select is(
  (
    select jsonb_build_array(
      item ->> 'ingredient_type_id',
      item ->> 'ingredient_type_name',
      item ->> 'ingredient_order_group_id',
      item ->> 'ingredient_order_group_name'
    )
    from catalog_results,
      jsonb_array_elements(response_payload -> 'ingredients') item
    where result_name = 'shaped_read'
      and item ->> 'ingredient_code' = 'uiq03cb-rice'
  ),
  jsonb_build_array(
    'c3100000-0000-4000-8000-000000000015',
    'Thực phẩm khô - gia vị',
    'c3200000-0000-4000-8000-000000000001',
    'Hàng đặt riêng'
  ),
  'the shaped Ingredient read exposes authoritative IDs and display names'
);

select is(
  (
    select count(*)::integer
    from pg_constraint
    where conrelid = 'atlas_admin.ingredients'::regclass
      and conname in (
        'ingredients_ingredient_type_fkey',
        'ingredients_order_group_fkey'
      )
      and contype = 'f'
  ),
  2,
  'both authoritative Ingredient references are foreign-key constrained'
);
select is(
  (select count(*)::integer from atlas_core.capabilities),
  27,
  'the correction creates no capability'
);
select is(
  (
    select count(*)::integer from pg_roles
    where rolname like 'atlas\_%' escape '\'
  ),
  11,
  'the correction creates no Atlas database role'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c3300000-0000-4000-8000-000000000003',
  true
);
insert into catalog_results values (
  'identity_update',
  atlas_api.update_ingredient(
    pg_temp.catalog_request(
      'c3300000-0000-4000-8000-000000000104',
      'uiq03cb-identity-update',
      jsonb_build_object(
        'ingredient_id', (
          select response_payload #>> '{affected_aggregate_ids,ingredient_id}'
          from catalog_results where result_name = 'legacy_create'
        ),
        'ingredient_name', 'Gạo Jasmine',
        'purchase_unit_id', 'c3300000-0000-4000-8000-000000000010',
        'ingredient_type_id', 'c3100000-0000-4000-8000-000000000015',
        'ingredient_order_group_id', 'c3200000-0000-4000-8000-000000000001',
        'order_step', 0.1
      )
    )
  )
);
insert into catalog_results values (
  'unknown_group_create',
  atlas_api.create_ingredient(
    pg_temp.catalog_request(
      'c3300000-0000-4000-8000-000000000105',
      'uiq03cb-unknown-group-create',
      jsonb_build_object(
        'ingredient_code', 'uiq03cb-unknown-group',
        'ingredient_name', 'Unknown group',
        'purchase_unit_id', 'c3300000-0000-4000-8000-000000000010',
        'ingredient_type_id', 'c3100000-0000-4000-8000-000000000015',
        'ingredient_order_group_id', 'c3200000-0000-4000-8000-999999999999',
        'order_step', 1
      )
    )
  )
);
reset role;
select is(
  (select response_payload ->> 'success' from catalog_results where result_name = 'identity_update'),
  'true',
  'Ingredient update succeeds with valid authoritative catalog identities'
);
select is(
  (select response_payload ->> 'error_code' from catalog_results where result_name = 'unknown_group_create'),
  'VALIDATION_FAILED',
  'a nonexistent authoritative order-group identity is rejected'
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type_id, ingredient_order_group_id,
  ingredient_type, shopping_type, order_step
) values (
  'c3300000-0000-4000-8000-000000000030',
  'uiq03cb-historical',
  'Historical Ingredient',
  'Khác',
  'c3300000-0000-4000-8000-000000000010',
  'c3100000-0000-4000-8000-000000000010',
  'c3200000-0000-4000-8000-000000000003',
  'Khác',
  'Còn lại',
  1
);
update atlas_admin.ingredient_types
set ingredient_type_status = 'INACTIVE'
where ingredient_type_id = 'c3100000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c3300000-0000-4000-8000-000000000003',
  true
);
insert into catalog_results values (
  'inactive_type_create',
  atlas_api.create_ingredient(
    pg_temp.catalog_request(
      'c3300000-0000-4000-8000-000000000106',
      'uiq03cb-inactive-type-create',
      jsonb_build_object(
        'ingredient_code', 'uiq03cb-inactive-type',
        'ingredient_name', 'Inactive type assignment',
        'purchase_unit_id', 'c3300000-0000-4000-8000-000000000010',
        'ingredient_type_id', 'c3100000-0000-4000-8000-000000000010',
        'ingredient_order_group_id', 'c3200000-0000-4000-8000-000000000003',
        'order_step', 1
      )
    )
  )
);
insert into catalog_results values (
  'inactive_shaped_read',
  atlas_api.get_ingredient_supplier_master_data(
    jsonb_build_object(
      'contract_version', 'RMVP-01.v1',
      'requested_by_auth_subject', 'c3300000-0000-4000-8000-000000000003',
      'correlation_id', 'c3300000-0000-4000-8000-000000000020',
      'payload', '{}'::jsonb
    )
  )
);
reset role;
select is(
  (select response_payload ->> 'error_code' from catalog_results where result_name = 'inactive_type_create'),
  'VALIDATION_FAILED',
  'an inactive catalog row cannot be newly assigned'
);
select ok(
  not exists (
    select 1
    from catalog_results,
      jsonb_array_elements(response_payload -> 'ingredient_types') item
    where result_name = 'inactive_shaped_read'
      and item ->> 'ingredient_type_id' = 'c3100000-0000-4000-8000-000000000010'
  )
  and exists (
    select 1
    from catalog_results,
      jsonb_array_elements(response_payload -> 'ingredients') item
    where result_name = 'inactive_shaped_read'
      and item ->> 'ingredient_code' = 'uiq03cb-historical'
      and item ->> 'ingredient_type_id' = 'c3100000-0000-4000-8000-000000000010'
      and item ->> 'ingredient_type_name' = 'Khác'
  ),
  'inactive rows are omitted from options while a historical selected reference remains explainable'
);

insert into catalog_results values (
  'unknown_import',
  atlas_legacy.import_master_data_snapshot(
    jsonb_build_object(
      'source_system', 'UIQ03CB_TEST',
      'snapshot_id', 'unknown-catalog',
      'snapshot_checksum', repeat('c', 64),
      'exported_at', '2026-08-16T00:00:00Z',
      'records', jsonb_build_object(
        'ingredients', jsonb_build_array(jsonb_build_object(
          'legacy_id', 'unknown-ingredient',
          'ingredient_code', 'uiq03cb-import-unknown',
          'ingredient_name', 'Unknown import',
          'ingredient_type', 'Unknown type',
          'shopping_type', 'Hàng đặt riêng',
          'purchase_unit_legacy_id', 'missing-is-not-reached',
          'order_step', 1,
          'ingredient_status', 'ACTIVE'
        ))
      )
    )
  )
);
select is(
  (select response_payload ->> 'error_code' from catalog_results where result_name = 'unknown_import'),
  'SNAPSHOT_REJECTED',
  'the importer reports an explicit blocker for unknown catalog text'
);
select ok(
  not exists (
    select 1 from atlas_admin.ingredients
    where ingredient_code = 'uiq03cb-import-unknown'
  )
  and exists (
    select 1 from atlas_legacy.import_batches
    where source_system = 'UIQ03CB_TEST'
      and snapshot_id = 'unknown-catalog'
      and import_status = 'REJECTED'
  ),
  'unknown import values write rejection evidence but no target Ingredient'
);

select * from finish();
rollback;
