begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  to_regprocedure(
    'atlas_api.get_recipe_adjustment_operator_workbench(jsonb)'
  ) is not null,
  'UI-QUALITY-03B adds the one bounded RMVP-02B.v2 operator read'
);

select ok(
  (
    select p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and owner.rolname = 'atlas_read_runtime'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles owner on owner.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname = 'get_recipe_adjustment_operator_workbench'
  ),
  'the v2 read retains fixed-path least-privilege runtime ownership and grants'
);

select ok(
  position(
    'current_date' in lower(
      pg_get_functiondef(
        'atlas_core.uiq03b_recipe_adjustment_operator_payload(date)'
          ::regprocedure
      )
    )
  ) = 0,
  'operator temporal resolution never uses CURRENT_DATE'
);

select ok(
  (
    select count(*) = 6
      and bool_and(
        has_function_privilege('authenticated', p.oid, 'EXECUTE')
      )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_recipe_adjustment_workbench',
        'resolve_effective_recipe_composition',
        'preview_recipe_composition_adjustment',
        'create_recipe_composition_adjustment',
        'supersede_recipe_composition_adjustment',
        'cancel_recipe_composition_adjustment'
      )
  ),
  'all six RMVP-02B.v1 reads and commands remain callable'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values (
  'f3000000-0000-0000-0000-000000000001',
  'HUMAN',
  'UI-QUALITY-03B native operator'
);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values (
  'f3000000-0000-0000-0000-000000000011',
  'f3000000-0000-0000-0000-000000000001',
  'f3000000-0000-0000-0000-000000000101'
);

insert into atlas_core.roles (
  role_id, role_code, role_name
) values (
  'f3000000-0000-0000-0000-000000000020',
  'uiq03b.adjustment_reader',
  'UI-QUALITY-03B adjustment reader'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'f3000000-0000-0000-0000-000000000020',
  capability_id
from atlas_core.capabilities
where capability_code = 'master_data.recipe_adjustments.read';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values (
  'f3000000-0000-0000-0000-000000000001',
  'f3000000-0000-0000-0000-000000000020'
);

insert into atlas_core.actor_scopes (actor_id, scope_kind) values (
  'f3000000-0000-0000-0000-000000000001',
  'GLOBAL'
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'f3100000-0000-0000-0000-000000000010',
  'uiq03b-kg',
  'UIQ03B kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'f3100000-0000-0000-0000-000000000020',
    'uiq03b-old',
    'UIQ03B old Ingredient',
    'Food',
    'f3100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'f3100000-0000-0000-0000-000000000021',
    'uiq03b-new',
    'UIQ03B new Ingredient',
    'Food',
    'f3100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  );

set constraints all deferred;

insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind,
  target_ingredient_id, lifecycle_status, version,
  legacy_source, legacy_record_id,
  created_by_actor_id, updated_by_actor_id
) values
  (
    'f3200000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'ACTIVE', 1, null, null,
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3200000-0000-0000-0000-000000000002',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'ACTIVE', 1, null, null,
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3200000-0000-0000-0000-000000000003',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'ACTIVE', 2, null, null,
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3200000-0000-0000-0000-000000000004',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'CANCELLED', 2, null, null,
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3200000-0000-0000-0000-000000000005',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'ACTIVE', 2, null, null,
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3200000-0000-0000-0000-000000000006',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'ACTIVE', 1, null, null,
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3200000-0000-0000-0000-000000000007',
    'SYSTEM_INGREDIENT', 'REPLACE',
    'f3100000-0000-0000-0000-000000000020',
    'ACTIVE', 1,
    'OPS_V1_INGREDIENT_CHANGE_ORDER', 'legacy-uiq03b-1',
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000001'
  );

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, predecessor_revision_id, revision_status,
  effective_from, effective_to, substitute_ingredient_id,
  reason_code, reason_note, source_evidence, created_by_actor_id
) values
  (
    'f3210000-0000-0000-0000-000000000001',
    'f3200000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-01-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'NATIVE_ACTIVE', 'Active current adjustment.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000002',
    'f3200000-0000-0000-0000-000000000002',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-09-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'FUTURE_FIRST', 'Future first adjustment.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000003',
    'f3200000-0000-0000-0000-000000000003',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-01-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'ACTIVE_PREDECESSOR', 'Active predecessor.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000004',
    'f3200000-0000-0000-0000-000000000003',
    'SYSTEM_INGREDIENT', 'REPLACE', 2,
    'f3210000-0000-0000-0000-000000000003', 'ACTIVE',
    date '2026-09-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'FUTURE_SUCCESSOR', 'Future successor.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000005',
    'f3200000-0000-0000-0000-000000000004',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-01-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'CANCEL_PREDECESSOR', 'Predecessor before cancellation.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000006',
    'f3200000-0000-0000-0000-000000000004',
    'SYSTEM_INGREDIENT', 'REPLACE', 2,
    'f3210000-0000-0000-0000-000000000005', 'CANCELLED',
    date '2026-09-01', null, null,
    'RULE_CANCELLATION', 'Future cancellation.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000007',
    'f3200000-0000-0000-0000-000000000005',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-01-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'RESUMABLE_PREDECESSOR', 'Resumable predecessor.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000008',
    'f3200000-0000-0000-0000-000000000005',
    'SYSTEM_INGREDIENT', 'REPLACE', 2,
    'f3210000-0000-0000-0000-000000000007', 'ACTIVE',
    date '2026-07-01', date '2026-09-01',
    'f3100000-0000-0000-0000-000000000021',
    'FINITE_SUCCESSOR', 'Finite successor.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000009',
    'f3200000-0000-0000-0000-000000000006',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-07-01', date '2026-09-01',
    'f3100000-0000-0000-0000-000000000021',
    'FINITE_FIRST', 'Finite first revision.', '{}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  ),
  (
    'f3210000-0000-0000-0000-000000000010',
    'f3200000-0000-0000-0000-000000000007',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, null, 'ACTIVE',
    date '2026-01-01', null,
    'f3100000-0000-0000-0000-000000000021',
    'LEGACY_IMPORT', 'Imported without original attribution.',
    '{"historical_actor_approval_claimed":false}'::jsonb,
    'f3000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments root
set current_revision_id = current_revision.revision_id,
    current_revision_number = current_revision.revision_number
from (
  select distinct on (revision.recipe_composition_adjustment_id)
    revision.recipe_composition_adjustment_id,
    revision.recipe_composition_adjustment_revision_id as revision_id,
    revision.revision_number
  from atlas_admin.recipe_composition_adjustment_revisions revision
  where revision.recipe_composition_adjustment_id::text like
    'f3200000-0000-0000-0000-%'
  order by revision.recipe_composition_adjustment_id,
    revision.revision_number desc
) current_revision
where current_revision.recipe_composition_adjustment_id =
  root.recipe_composition_adjustment_id;

create function pg_temp.uiq03b_request(target_date date)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v2',
    'requested_by_auth_subject',
      'f3000000-0000-0000-0000-000000000101',
    'correlation_id', gen_random_uuid(),
    'payload', pg_catalog.jsonb_build_object(
      'as_of_date', target_date
    )
  );
$$;

create function pg_temp.uiq03b_row(target_id uuid, target_date date)
returns jsonb
language sql
as $$
  select row
  from pg_catalog.jsonb_array_elements(
    atlas_api.get_recipe_adjustment_operator_workbench(
      pg_temp.uiq03b_request(target_date)
    ) -> 'workbench' -> 'operator_rows'
  ) row
  where row ->> 'adjustment_id' = target_id::text;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000001',
    date '2026-08-14'
  ) ->> 'temporal_state',
  'ACTIVE',
  'active current adjustment is backend-shaped as ACTIVE'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000002',
    date '2026-08-14'
  ) ->> 'temporal_state',
  'SCHEDULED',
  'future first adjustment is backend-shaped as SCHEDULED'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000003',
    date '2026-08-14'
  ) ->> 'temporal_state',
  'ACTIVE_CHANGE_SCHEDULED',
  'active predecessor plus future successor is shaped as a scheduled change'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000004',
    date '2026-08-14'
  ) ->> 'temporal_state',
  'ACTIVE_CANCELLATION_SCHEDULED',
  'future cancellation keeps the predecessor applicable before its date'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000004',
    date '2026-09-01'
  ) ->> 'temporal_state',
  'CANCELLED',
  'cancellation effective at the reference date is shaped as CANCELLED'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000005',
    date '2026-08-14'
  ) ->> 'temporal_state',
  'ACTIVE',
  'finite successor is active during its effective period'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000005',
    date '2026-09-01'
  ) ->> 'temporal_state',
  'ACTIVE_RESUMED',
  'expired finite successor resumes its applicable predecessor'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000006',
    date '2026-09-01'
  ) ->> 'temporal_state',
  'EXPIRED',
  'finite first revision with no predecessor is shaped as EXPIRED'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000001',
    date '2026-08-14'
  ) -> 'display_revision' ->> 'issued_by_actor_name',
  'UI-QUALITY-03B native operator',
  'native issuance uses the immutable revision Actor name'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000007',
    date '2026-08-14'
  ) -> 'display_revision' ->> 'issuance_kind',
  'LEGACY_UNATTRIBUTED',
  'imported OPS v1 issuance is explicitly distinguished from native Atlas issuance'
);

select is(
  pg_temp.uiq03b_row(
    'f3200000-0000-0000-0000-000000000007',
    date '2026-08-14'
  ) -> 'display_revision' -> 'issued_by_actor_name',
  'null'::jsonb,
  'the Atlas importer Actor is not presented as the original OPS v1 issuer'
);

select * from finish();
rollback;
