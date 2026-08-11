begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in ('save_recipe', 'release_recipe')
  ),
  array['release_recipe', 'save_recipe']::text[],
  'UI-QUALITY-03A exposes exactly the two additive human-level commands'
);

select ok(
  (
    select bool_and(
      p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
      and r.rolname = 'atlas_master_data_command_runtime'
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in ('save_recipe', 'release_recipe')
  ),
  'v2 commands retain fixed-path definer ownership and the exact API-role boundary'
);

select ok(
  not exists (
    select 1
    from pg_auth_members membership
    join pg_roles granted_role on granted_role.oid = membership.roleid
    join pg_roles member_role on member_role.oid = membership.member
    where granted_role.rolname in (
      'atlas_master_data_command_runtime',
      'atlas_read_runtime'
    )
      and member_role.rolname = 'postgres'
      and membership.set_option
  ),
  'UI-QUALITY-03A leaves no postgres set-role membership in Recipe runtimes'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'create_recipe_draft',
        'replace_recipe_draft_composition',
        'validate_recipe_version',
        'release_recipe_version_for_planning',
        'create_recipe_successor_version'
      )
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ),
  5,
  'all five existing v1 lifecycle commands remain physically callable'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  (
    'f3000000-0000-0000-0000-000000000001',
    'HUMAN',
    'UI-QUALITY-03A authorized operator'
  ),
  (
    'f3000000-0000-0000-0000-000000000002',
    'HUMAN',
    'UI-QUALITY-03A denied operator'
  ),
  (
    'f3000000-0000-0000-0000-000000000003',
    'HUMAN',
    'UI-QUALITY-03A unscoped operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'f3000000-0000-0000-0000-000000000011',
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000101'
  ),
  (
    'f3000000-0000-0000-0000-000000000012',
    'f3000000-0000-0000-0000-000000000002',
    'f3000000-0000-0000-0000-000000000102'
  ),
  (
    'f3000000-0000-0000-0000-000000000013',
    'f3000000-0000-0000-0000-000000000003',
    'f3000000-0000-0000-0000-000000000103'
  );

insert into atlas_core.roles (
  role_id, role_code, role_name
) values
  (
    'f3000000-0000-0000-0000-000000000020',
    'uiq03a.recipe_operator',
    'UI-QUALITY-03A recipe operator'
  ),
  (
    'f3000000-0000-0000-0000-000000000021',
    'uiq03a.no_capability',
    'UI-QUALITY-03A no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'f3000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities
where capability_code in (
  'master_data.recipes.read',
  'master_data.recipes.write',
  'master_data.recipes.release'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000020'
  ),
  (
    'f3000000-0000-0000-0000-000000000002',
    'f3000000-0000-0000-0000-000000000021'
  ),
  (
    'f3000000-0000-0000-0000-000000000003',
    'f3000000-0000-0000-0000-000000000020'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('f3000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('f3000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'f3100000-0000-0000-0000-000000000001',
  'uiq03a-primary',
  'UI-QUALITY-03A Primary'
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'f3100000-0000-0000-0000-000000000010',
  'uiq03a-kg',
  'UI-QUALITY-03A kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'f3100000-0000-0000-0000-000000000020',
    'uiq03a-pumpkin',
    'UI-QUALITY-03A Pumpkin',
    'Food',
    'f3100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'f3100000-0000-0000-0000-000000000021',
    'uiq03a-pork',
    'UI-QUALITY-03A Pork',
    'Food',
    'f3100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  );

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_category, dish_status,
  display_order, requires_need_generation, version
) values (
  'f3100000-0000-0000-0000-000000000030',
  'uiq03a-soup',
  'UI-QUALITY-03A Soup',
  'Acceptance',
  'ACTIVE',
  9300,
  true,
  1
);

create or replace function pg_temp.uiq03a_request(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb,
  p_subject uuid default 'f3000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02A.v2',
    'command_id', md5('uiq03a-command:' || p_name)::uuid,
    'correlation_id', 'f3900000-0000-0000-0000-000000000001',
    'idempotency_key', 'uiq03a:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', case
      when p_name like 'release%' then 'RECIPE_PUT_INTO_USE'
      else 'RECIPE_SAVED'
    end,
    'reason_note', null,
    'payload', p_payload
  );
$$;

create temporary table uiq03a_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on uiq03a_results to authenticated;

create temporary table uiq03a_snapshot as
select
  (select count(*) from atlas_planning.need_generation_recipe_selections)
    as planning_selection_count,
  (select count(*) from atlas_planning.need_generation_recipe_line_uses)
    as planning_line_use_count,
  (select count(*) from atlas_admin.recipe_composition_adjustments)
    as adjustment_count,
  (select count(*) from atlas_procurement.purchase_orders)
    as procurement_count,
  (select count(*) from atlas_dispatch.dispatch_plans)
    as dispatch_count;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);

select lives_ok(
  $$select atlas_api.get_dish_recipe_workbench(
    jsonb_build_object(
      'contract_version', 'RMVP-02A.v1',
      'requested_by_auth_subject',
        'f3000000-0000-0000-0000-000000000101',
      'correlation_id', 'f3900000-0000-0000-0000-000000000002',
      'payload', '{}'::jsonb
    )
  )$$,
  'the existing v1 workbench read remains callable without a v2 shape'
);

select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000102',
  true
);
insert into uiq03a_results values (
  'save-denied',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-denied',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', null,
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', null
          )
        )
      ),
      'f3000000-0000-0000-0000-000000000102'
    )
  )
);

select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000103',
  true
);
insert into uiq03a_results values (
  'save-unscoped',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-unscoped',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', null,
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', null
          )
        )
      ),
      'f3000000-0000-0000-0000-000000000103'
    )
  )
);

select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);
insert into uiq03a_results values (
  'save-new',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-new',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', null,
        'basis_portions', 80,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'Initial saved line'
          )
        )
      )
    )
  )
);

insert into uiq03a_results values (
  'save-new-replay',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-new',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', null,
        'basis_portions', 80,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'Initial saved line'
          )
        )
      )
    )
  )
);

reset role;

select is(
  (select response_payload ->> 'error_code' from uiq03a_results where result_name = 'save-denied'),
  'CAPABILITY_DENIED',
  'Save requires the narrow write capability'
);

select is(
  (select response_payload ->> 'error_code' from uiq03a_results where result_name = 'save-unscoped'),
  'SCOPE_DENIED',
  'Save requires an active global scope'
);

select is(
  (select response_payload ->> 'success' from uiq03a_results where result_name = 'save-new'),
  'true',
  'Save creates a new Recipe and editable draft atomically'
);

select is(
  (
    select jsonb_build_object(
      'basis', version.basis_portions,
      'status', version.recipe_version_status,
      'version_count', (
        select count(*) from atlas_admin.recipe_versions sibling
        where sibling.recipe_id = version.recipe_id
      ),
      'released_count', (
        select count(*) from atlas_admin.recipe_versions sibling
        where sibling.recipe_id = version.recipe_id
          and sibling.recipe_version_status = 'RELEASED_FOR_PLANNING'
      )
    )
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  jsonb_build_object(
    'basis', 80,
    'status', 'DRAFT',
    'version_count', 1,
    'released_count', 0
  ),
  'Save preserves the exact basis and does not release downstream'
);

select is(
  (select response_payload from uiq03a_results where result_name = 'save-new-replay'),
  (select response_payload from uiq03a_results where result_name = 'save-new'),
  'identical Save replay returns the stored authoritative response'
);

select is(
  (
    select count(*)::integer
    from atlas_core.command_receipts
    where idempotency_key = 'uiq03a:save-new'
  ),
  1,
  'idempotent Save replay creates no duplicate command receipt'
);

insert into uiq03a_results
select
  scenario.name,
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      scenario.name,
      version.version,
      jsonb_build_object(
        'dish_id', recipe.dish_id,
        'school_type_id', recipe.school_type_id,
        'recipe_version_id', version.recipe_version_id,
        'basis_portions', 80,
        'lines', scenario.lines
      )
    )
  )
from atlas_admin.recipes recipe
join atlas_admin.recipe_versions version on version.recipe_id = recipe.recipe_id
cross join lateral (
  values
    (
      'save-invalid-ingredient',
      jsonb_build_array(
        jsonb_build_object(
          'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
          'ingredient_id', 'f3100000-0000-0000-0000-000000009999',
          'quantity_per_basis', 10,
          'unit_id', 'f3100000-0000-0000-0000-000000000010',
          'operational_note', null
        )
      )
    ),
    (
      'save-invalid-unit',
      jsonb_build_array(
        jsonb_build_object(
          'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
          'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
          'quantity_per_basis', 10,
          'unit_id', 'f3100000-0000-0000-0000-000000009999',
          'operational_note', null
        )
      )
    ),
    (
      'save-duplicate-ingredient',
      jsonb_build_array(
        jsonb_build_object(
          'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
          'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
          'quantity_per_basis', 10,
          'unit_id', 'f3100000-0000-0000-0000-000000000010',
          'operational_note', null
        ),
        jsonb_build_object(
          'recipe_line_id', 'f3200000-0000-0000-0000-000000000002',
          'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
          'quantity_per_basis', 2,
          'unit_id', 'f3100000-0000-0000-0000-000000000010',
          'operational_note', null
        )
      )
    ),
    (
      'save-invalid-quantity',
      jsonb_build_array(
        jsonb_build_object(
          'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
          'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
          'quantity_per_basis', 0,
          'unit_id', 'f3100000-0000-0000-0000-000000000010',
          'operational_note', null
        )
      )
    )
) scenario(name, lines)
where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030';

select is(
  (
    select array_agg(response_payload ->> 'error_code' order by result_name)::text[]
    from uiq03a_results
    where result_name like 'save-invalid-%'
       or result_name = 'save-duplicate-ingredient'
  ),
  array[
    'VALIDATION_FAILED',
    'VALIDATION_FAILED',
    'VALIDATION_FAILED',
    'VALIDATION_FAILED'
  ]::text[],
  'Save rejects duplicate Ingredients and invalid Ingredient, Unit, or quantity'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);

insert into uiq03a_results
select
  'save-existing',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-existing',
      (saved.response_payload #>> '{authoritative_readback,selected_recipe,expected_version}')::bigint,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id',
          saved.response_payload #>> '{authoritative_readback,selected_recipe,recipe_version_id}',
        'basis_portions', 90,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 14,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'Updated saved line'
          )
        )
      )
    )
  )
from uiq03a_results saved
where saved.result_name = 'save-new';

insert into uiq03a_results
select
  'save-stale',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-stale',
      (saved.response_payload #>> '{authoritative_readback,selected_recipe,expected_version}')::bigint - 1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id',
          saved.response_payload #>> '{authoritative_readback,selected_recipe,recipe_version_id}',
        'basis_portions', 90,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 15,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', null
          )
        )
      )
    )
  )
from uiq03a_results saved
where saved.result_name = 'save-existing';

insert into uiq03a_results
select
  'release-initial',
  atlas_api.release_recipe(
    pg_temp.uiq03a_request(
      'release-initial',
      (saved.response_payload #>> '{authoritative_readback,selected_recipe,expected_version}')::bigint,
      jsonb_build_object(
        'recipe_version_id',
          saved.response_payload #>> '{authoritative_readback,selected_recipe,recipe_version_id}'
      )
    )
  )
from uiq03a_results saved
where saved.result_name = 'save-existing';

reset role;

select is(
  (select response_payload ->> 'success' from uiq03a_results where result_name = 'save-existing'),
  'true',
  'Save replaces the existing editable draft composition atomically'
);

select is(
  (select response_payload ->> 'error_code' from uiq03a_results where result_name = 'save-stale'),
  'STALE_VERSION',
  'Save rejects a stale current version'
);

select is(
  (
    select jsonb_build_object(
      'status', version.recipe_version_status,
      'validated', version.validated_at is not null,
      'released', version.released_at is not null,
      'revision_count', (
        select count(*) from atlas_admin.recipe_line_revisions revision
        where revision.recipe_version_id = version.recipe_version_id
      )
    )
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  jsonb_build_object(
    'status', 'RELEASED_FOR_PLANNING',
    'validated', true,
    'released', true,
    'revision_count', 1
  ),
  'put-into-use validates, materializes immutable line evidence, and releases atomically'
);

create temporary table uiq03a_prior_release as
select
  version.recipe_version_id,
  version.recipe_id,
  version.version,
  atlas_core.rmvp_02a_recipe_version_composition(version.recipe_version_id)
    as composition
from atlas_admin.recipe_versions version
join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030';
grant select on uiq03a_prior_release to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);

insert into uiq03a_results
select
  'save-successor',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-successor',
      prior.version,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', prior.recipe_version_id,
        'basis_portions', 90,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 16,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'Successor saved line'
          ),
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000002',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000021',
            'quantity_per_basis', 4,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', null
          )
        )
      )
    )
  )
from uiq03a_prior_release prior;

reset role;

select is(
  (
    select jsonb_build_object(
      'version_count', count(*),
      'draft_count', count(*) filter (where recipe_version_status = 'DRAFT'),
      'released_count', count(*) filter (
        where recipe_version_status = 'RELEASED_FOR_PLANNING'
      ),
      'successor_predecessor', bool_and(
        recipe_version_status <> 'DRAFT'
        or predecessor_recipe_version_id = prior.recipe_version_id
      )
    )
    from atlas_admin.recipe_versions version
    cross join uiq03a_prior_release prior
    where version.recipe_id = prior.recipe_id
  ),
  jsonb_build_object(
    'version_count', 2,
    'draft_count', 1,
    'released_count', 1,
    'successor_predecessor', true
  ),
  'Save after release creates the correct editable successor internally'
);

select is(
  (
    select atlas_core.rmvp_02a_recipe_version_composition(
      prior.recipe_version_id
    )
    from uiq03a_prior_release prior
  ),
  (select composition from uiq03a_prior_release),
  'Save after release leaves prior released composition immutable'
);

select ok(
  exists (
    select 1
    from atlas_admin.recipe_versions successor
    join uiq03a_prior_release prior on prior.recipe_id = successor.recipe_id
    join atlas_admin.recipe_line_revisions prior_line
      on prior_line.recipe_version_id = prior.recipe_version_id
    cross join lateral jsonb_array_elements(successor.draft_composition) item
    where successor.recipe_version_status = 'DRAFT'
      and successor.predecessor_recipe_version_id = prior.recipe_version_id
      and item ->> 'recipe_line_id' = prior_line.recipe_line_id::text
      and item ->> 'predecessor_recipe_line_revision_id' =
        prior_line.recipe_line_revision_id::text
  ),
  'successor Save preserves exact version, stable line, and revision predecessor lineage'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);

insert into uiq03a_results
select
  'release-successor',
  atlas_api.release_recipe(
    pg_temp.uiq03a_request(
      'release-successor',
      (saved.response_payload #>> '{authoritative_readback,selected_recipe,expected_version}')::bigint,
      jsonb_build_object(
        'recipe_version_id',
          saved.response_payload #>> '{authoritative_readback,selected_recipe,recipe_version_id}'
      )
    )
  )
from uiq03a_results saved
where saved.result_name = 'save-successor';

reset role;

select is(
  (
    select jsonb_build_object(
      'prior_status', prior_version.recipe_version_status,
      'successor_status', successor.recipe_version_status,
      'current_release_count', count(*) filter (
        where version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      ) over ()
    )
    from uiq03a_prior_release prior
    join atlas_admin.recipe_versions prior_version
      on prior_version.recipe_version_id = prior.recipe_version_id
    join atlas_admin.recipe_versions successor
      on successor.predecessor_recipe_version_id = prior.recipe_version_id
    join atlas_admin.recipe_versions version on version.recipe_id = prior.recipe_id
    limit 1
  ),
  jsonb_build_object(
    'prior_status', 'LOCKED',
    'successor_status', 'RELEASED_FOR_PLANNING',
    'current_release_count', 1
  ),
  'put-into-use locks the prior effective Recipe and makes only the successor current'
);

select is(
  (
    select atlas_core.rmvp_02a_recipe_version_composition(
      prior.recipe_version_id
    )
    from uiq03a_prior_release prior
  ),
  (select composition from uiq03a_prior_release),
  'successor release preserves the prior immutable release evidence'
);

select is(
  (
    select jsonb_build_object(
      'planning_selection_count',
        (select count(*) from atlas_planning.need_generation_recipe_selections),
      'planning_line_use_count',
        (select count(*) from atlas_planning.need_generation_recipe_line_uses)
  )),
  (
    select jsonb_build_object(
      'planning_selection_count', planning_selection_count,
      'planning_line_use_count', planning_line_use_count
    )
    from uiq03a_snapshot
  ),
  'put-into-use changes only future Recipe selection and never rewrites historical Planning facts'
);

select is(
  (
    select jsonb_build_object(
      'adjustment_count',
        (select count(*) from atlas_admin.recipe_composition_adjustments),
      'procurement_count',
        (select count(*) from atlas_procurement.purchase_orders),
      'dispatch_count',
        (select count(*) from atlas_dispatch.dispatch_plans)
    )
  ),
  (
    select jsonb_build_object(
      'adjustment_count', adjustment_count,
      'procurement_count', procurement_count,
      'dispatch_count', dispatch_count
    )
    from uiq03a_snapshot
  ),
  'v2 Save and put-into-use create no Recipe Adjustment, Procurement, or Dispatch delta'
);

select * from finish();

rollback;
