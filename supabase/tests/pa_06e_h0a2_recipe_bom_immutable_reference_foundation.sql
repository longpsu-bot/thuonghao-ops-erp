begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(88);

select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_admin'
      and c.relkind = 'r'
      and c.relname in (
        'dishes',
        'recipes',
        'recipe_versions',
        'recipe_lines',
        'recipe_line_revisions'
      )
  ),
  array[
    'dishes',
    'recipe_line_revisions',
    'recipe_lines',
    'recipe_versions',
    'recipes'
  ]::text[],
  'H0A2 creates exactly the five approved private relations'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.dishes'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'dish_id',
    'dish_code',
    'dish_name',
    'dish_category',
    'operational_notes',
    'dish_status',
    'display_order',
    'requires_need_generation',
    'version',
    'created_at',
    'updated_at'
  ]::text[],
  'dishes has only the approved bounded fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.recipes'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'recipe_id',
    'dish_id',
    'school_type_id',
    'recipe_status',
    'version',
    'created_at',
    'updated_at'
  ]::text[],
  'recipes has only the approved bounded fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.recipe_versions'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'recipe_version_id',
    'recipe_id',
    'version_number',
    'predecessor_recipe_version_id',
    'basis_portions',
    'recipe_version_status',
    'created_by_actor_id',
    'created_at',
    'validated_by_actor_id',
    'validated_at',
    'released_by_actor_id',
    'released_at',
    'locked_by_actor_id',
    'locked_at'
  ]::text[],
  'recipe_versions has only the approved lifecycle and basis fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.recipe_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array['recipe_line_id', 'recipe_id', 'line_code', 'created_at']::text[],
  'recipe_lines is a bounded stable identity independent of ingredient'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.recipe_line_revisions'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'recipe_line_revision_id',
    'recipe_id',
    'recipe_version_id',
    'recipe_line_id',
    'line_revision_number',
    'predecessor_recipe_line_revision_id',
    'ingredient_id',
    'quantity_per_basis',
    'unit_id',
    'line_disposition',
    'calculation_kind',
    'operational_note',
    'created_by_actor_id',
    'created_at'
  ]::text[],
  'recipe_line_revisions has only the exact immutable BOM fact fields'
);

select is(
  (
    select count(*)::integer
    from pg_attrdef ad
    join pg_attribute a
      on a.attrelid = ad.adrelid
     and a.attnum = ad.adnum
    where ad.adrelid in (
      'atlas_admin.dishes'::regclass,
      'atlas_admin.recipes'::regclass,
      'atlas_admin.recipe_versions'::regclass,
      'atlas_admin.recipe_lines'::regclass,
      'atlas_admin.recipe_line_revisions'::regclass
    )
      and a.attname in (
        'dish_id',
        'recipe_id',
        'recipe_version_id',
        'recipe_line_id',
        'recipe_line_revision_id'
      )
      and pg_get_expr(ad.adbin, ad.adrelid) = 'gen_random_uuid()'
  ),
  5,
  'all five business identities are database-generated UUIDs'
);

select is(
  (
    select format_type(a.atttypid, a.atttypmod)
    from pg_attribute a
    where a.attrelid = 'atlas_admin.recipe_line_revisions'::regclass
      and a.attname = 'quantity_per_basis'
      and not a.attisdropped
  ),
  'numeric(20,6)',
  'quantity_per_basis uses exact numeric(20,6) storage'
);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values
  (
    '8a000000-0000-0000-0000-000000000001',
    'HUMAN',
    'PA-06E-H0A2 recipe administrator'
  ),
  (
    '8a000000-0000-0000-0000-000000000002',
    'HUMAN',
    'PA-06E-H0A2 alternate recipe administrator'
  );

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values
  (
    '8a000000-0000-0000-0000-000000000010',
    'primary',
    'Primary School'
  ),
  (
    '8a000000-0000-0000-0000-000000000011',
    'secondary',
    'Secondary School'
  );

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code
) values
  (
    '8a000000-0000-0000-0000-000000000020',
    'kg-h0a2',
    'kilogram H0A2',
    'mass'
  ),
  (
    '8a000000-0000-0000-0000-000000000021',
    'g-h0a2',
    'gram H0A2',
    'mass'
  );

insert into atlas_admin.ingredients (
  ingredient_id,
  ingredient_code,
  ingredient_name
) values
  (
    '8a000000-0000-0000-0000-000000000030',
    'h0a2-rice',
    'H0A2 Rice'
  ),
  (
    '8a000000-0000-0000-0000-000000000031',
    'h0a2-onion',
    'H0A2 Onion'
  ),
  (
    '8a000000-0000-0000-0000-000000000032',
    'h0a2-fish',
    'H0A2 Fish'
  ),
  (
    '8a000000-0000-0000-0000-000000000033',
    'h0a2-spice',
    'H0A2 Spice'
  ),
  (
    '8a000000-0000-0000-0000-000000000034',
    'h0a2-salt',
    'H0A2 Salt'
  );

select lives_ok(
  $$
    insert into atlas_admin.dishes (
      dish_id,
      dish_code,
      dish_name,
      dish_category,
      dish_status,
      display_order,
      requires_need_generation
    ) values (
      '8a000000-0000-0000-0000-000000000100',
      'h0a2-soup',
      'H0A2 Soup',
      'Soup',
      'ACTIVE',
      10,
      true
    )
  $$,
  'a valid active need-generation Dish can be recorded'
);

select lives_ok(
  $$
    insert into atlas_admin.dishes (
      dish_id,
      dish_code,
      dish_name,
      dish_status,
      display_order,
      requires_need_generation
    ) values (
      '8a000000-0000-0000-0000-000000000101',
      'h0a2-water',
      'H0A2 Water',
      'ACTIVE',
      20,
      false
    )
  $$,
  'a Dish may explicitly require no Need Generation composition'
);

select throws_ok(
  $$
    insert into atlas_admin.dishes (
      dish_id,
      dish_code,
      dish_name
    ) values (
      '8a000000-0000-0000-0000-000000000102',
      'UPPERCASE',
      'Invalid code'
    )
  $$,
  '23514',
  'new row for relation "dishes" violates check constraint "dishes_dish_code_check"',
  'Dish codes must be lowercase stable codes'
);

select throws_ok(
  $$
    insert into atlas_admin.dishes (
      dish_id,
      dish_code,
      dish_name,
      dish_status
    ) values (
      '8a000000-0000-0000-0000-000000000103',
      'h0a2-duplicate-soup',
      '  h0a2 SOUP ',
      'ACTIVE'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "dishes_active_normalized_name_key"',
  'active normalized Dish names cannot be duplicated'
);

select lives_ok(
  $$
    insert into atlas_admin.dishes (
      dish_id,
      dish_code,
      dish_name,
      dish_status
    ) values (
      '8a000000-0000-0000-0000-000000000104',
      'h0a2-historical-soup',
      ' H0A2 SOUP ',
      'INACTIVE'
    )
  $$,
  'inactive historical Dishes may retain a duplicate normalized name'
);

select is(
  (
    select row(display_order, requires_need_generation, version)::text
    from atlas_admin.dishes
    where dish_id = '8a000000-0000-0000-0000-000000000100'
  ),
  '(10,t,1)',
  'Dish display order, Need Generation flag, and positive version are retained'
);

select lives_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id
    ) values (
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000100'
    )
  $$,
  'a general Recipe uses a null SchoolType scope'
);

select throws_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id
    ) values (
      '8a000000-0000-0000-0000-000000000201',
      '8a000000-0000-0000-0000-000000000100'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "recipes_active_general_dish_key"',
  'one Dish has at most one active general Recipe'
);

select lives_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id,
      recipe_status
    ) values (
      '8a000000-0000-0000-0000-000000000202',
      '8a000000-0000-0000-0000-000000000100',
      'INACTIVE'
    )
  $$,
  'inactive historical general Recipe roots remain retainable'
);

select lives_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id,
      school_type_id
    ) values (
      '8a000000-0000-0000-0000-000000000203',
      '8a000000-0000-0000-0000-000000000100',
      '8a000000-0000-0000-0000-000000000010'
    )
  $$,
  'a typed Recipe uses one exact SchoolType scope'
);

select throws_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id,
      school_type_id
    ) values (
      '8a000000-0000-0000-0000-000000000204',
      '8a000000-0000-0000-0000-000000000100',
      '8a000000-0000-0000-0000-000000000010'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "recipes_active_typed_dish_school_type_key"',
  'one Dish and SchoolType has at most one active typed Recipe'
);

select lives_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id,
      school_type_id
    ) values (
      '8a000000-0000-0000-0000-000000000205',
      '8a000000-0000-0000-0000-000000000100',
      '8a000000-0000-0000-0000-000000000011'
    )
  $$,
  'different exact SchoolType Recipe roots remain independent'
);

select throws_ok(
  $$
    insert into atlas_admin.recipes (
      recipe_id,
      dish_id,
      school_type_id
    ) values (
      '8a000000-0000-0000-0000-000000000206',
      '8a000000-0000-0000-0000-000000000100',
      '8a000000-0000-0000-0000-000000000099'
    )
  $$,
  '23503',
  'insert or update on table "recipes" violates foreign key constraint "recipes_school_type_fkey"',
  'typed Recipe scope requires an exact SchoolType foreign key'
);

insert into atlas_admin.recipes (
  recipe_id,
  dish_id
) values (
  '8a000000-0000-0000-0000-000000000207',
  '8a000000-0000-0000-0000-000000000101'
);

select throws_ok(
  $$
    update atlas_admin.recipes
    set dish_id = '8a000000-0000-0000-0000-000000000101'
    where recipe_id = '8a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'recipe dish and school type scope are immutable',
  'a stable Recipe root cannot be reassigned to another Dish'
);

select throws_ok(
  $$
    update atlas_admin.recipes
    set school_type_id = '8a000000-0000-0000-0000-000000000011'
    where recipe_id = '8a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'recipe dish and school type scope are immutable',
  'a general Recipe cannot be reassigned to a typed SchoolType scope'
);

select throws_ok(
  $$
    update atlas_admin.recipes
    set school_type_id = null
    where recipe_id = '8a000000-0000-0000-0000-000000000203'
  $$,
  '23514',
  'recipe dish and school type scope are immutable',
  'a typed Recipe cannot be reassigned to the general scope'
);

select lives_ok(
  $$
    update atlas_admin.recipes
    set version = version + 1,
        updated_at = timestamptz '2026-07-19 00:30:00+00'
    where recipe_id = '8a000000-0000-0000-0000-000000000205'
  $$,
  'approved Recipe version and timestamp maintenance remains available'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_versions (
      recipe_version_id,
      recipe_id,
      version_number,
      basis_portions,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000300',
      '8a000000-0000-0000-0000-000000000200',
      0,
      100,
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "recipe_versions" violates check constraint "recipe_versions_number_check"',
  'Recipe version numbers must be positive'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_versions (
      recipe_version_id,
      recipe_id,
      version_number,
      basis_portions,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000301',
      '8a000000-0000-0000-0000-000000000200',
      1,
      0,
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "recipe_versions" violates check constraint "recipe_versions_basis_portions_check"',
  'Recipe basis portions must be positive'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_versions (
      recipe_version_id,
      recipe_id,
      version_number,
      basis_portions,
      recipe_version_status,
      created_by_actor_id,
      validated_by_actor_id,
      validated_at
    ) values (
      '8a000000-0000-0000-0000-000000000302',
      '8a000000-0000-0000-0000-000000000200',
      20,
      100,
      'VALIDATED',
      '8a000000-0000-0000-0000-000000000001',
      '8a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 00:40:00+00'
    )
  $$,
  '23514',
  'new recipe versions must enter as DRAFT',
  'a RecipeVersion cannot be inserted directly as VALIDATED'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_versions (
      recipe_version_id,
      recipe_id,
      version_number,
      basis_portions,
      recipe_version_status,
      created_by_actor_id,
      validated_by_actor_id,
      validated_at,
      released_by_actor_id,
      released_at
    ) values (
      '8a000000-0000-0000-0000-000000000303',
      '8a000000-0000-0000-0000-000000000200',
      21,
      100,
      'RELEASED_FOR_PLANNING',
      '8a000000-0000-0000-0000-000000000001',
      '8a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 00:41:00+00',
      '8a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 00:42:00+00'
    )
  $$,
  '23514',
  'new recipe versions must enter as DRAFT',
  'a RecipeVersion cannot be inserted directly as RELEASED_FOR_PLANNING'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_versions (
      recipe_version_id,
      recipe_id,
      version_number,
      basis_portions,
      recipe_version_status,
      created_by_actor_id,
      validated_by_actor_id,
      validated_at,
      released_by_actor_id,
      released_at,
      locked_by_actor_id,
      locked_at
    ) values (
      '8a000000-0000-0000-0000-000000000304',
      '8a000000-0000-0000-0000-000000000200',
      22,
      100,
      'LOCKED',
      '8a000000-0000-0000-0000-000000000001',
      '8a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 00:43:00+00',
      '8a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 00:44:00+00',
      '8a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 00:45:00+00'
    )
  $$,
  '23514',
  'new recipe versions must enter as DRAFT',
  'a RecipeVersion cannot be inserted directly as LOCKED'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id,
  recipe_id,
  version_number,
  basis_portions,
  created_by_actor_id
) values (
  '8a000000-0000-0000-0000-000000000310',
  '8a000000-0000-0000-0000-000000000200',
  1,
  100,
  '8a000000-0000-0000-0000-000000000001'
);

select lives_ok(
  $$
    insert into atlas_admin.recipe_lines (
      recipe_line_id,
      recipe_id,
      line_code
    ) values
      (
        '8a000000-0000-0000-0000-000000000400',
        '8a000000-0000-0000-0000-000000000200',
        'rice'
      ),
      (
        '8a000000-0000-0000-0000-000000000401',
        '8a000000-0000-0000-0000-000000000200',
        'onion'
      ),
      (
        '8a000000-0000-0000-0000-000000000402',
        '8a000000-0000-0000-0000-000000000200',
        'spice'
      )
  $$,
  'stable RecipeLine identities can be created independently of ingredients'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_lines (
      recipe_line_id,
      recipe_id,
      line_code
    ) values (
      '8a000000-0000-0000-0000-000000000403',
      '8a000000-0000-0000-0000-000000000200',
      'UPPERCASE'
    )
  $$,
  '23514',
  'new row for relation "recipe_lines" violates check constraint "recipe_lines_line_code_check"',
  'optional RecipeLine codes must be lowercase stable codes'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_lines (
      recipe_line_id,
      recipe_id,
      line_code
    ) values (
      '8a000000-0000-0000-0000-000000000404',
      '8a000000-0000-0000-0000-000000000200',
      'rice'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "recipe_lines_recipe_line_code_key"',
  'RecipeLine codes are unique within one Recipe'
);

select throws_ok(
  $$
    update atlas_admin.recipe_lines
    set recipe_id = '8a000000-0000-0000-0000-000000000203'
    where recipe_line_id = '8a000000-0000-0000-0000-000000000402'
  $$,
  '23514',
  'stable recipe line ownership is immutable',
  'an unused stable RecipeLine cannot be reassigned to another Recipe'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000500',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000310',
      '8a000000-0000-0000-0000-000000000400',
      0,
      '8a000000-0000-0000-0000-000000000030',
      10,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'a new recipe line starts at revision number one',
  'RecipeLine revision numbering starts positively at one'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      line_disposition,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000501',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000310',
      '8a000000-0000-0000-0000-000000000400',
      1,
      '8a000000-0000-0000-0000-000000000030',
      0,
      '8a000000-0000-0000-0000-000000000020',
      'PRESENT',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "recipe_line_revisions" violates check constraint "recipe_line_revisions_quantity_disposition_check"',
  'PRESENT RecipeLine revisions require a positive quantity'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      line_disposition,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000502',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000310',
      '8a000000-0000-0000-0000-000000000400',
      1,
      '8a000000-0000-0000-0000-000000000030',
      0,
      '8a000000-0000-0000-0000-000000000020',
      'REMOVED',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "recipe_line_revisions" violates check constraint "recipe_line_revisions_quantity_disposition_check"',
  'REMOVED RecipeLine revisions require an exact predecessor'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      calculation_kind,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000503',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000310',
      '8a000000-0000-0000-0000-000000000400',
      1,
      '8a000000-0000-0000-0000-000000000030',
      10,
      '8a000000-0000-0000-0000-000000000020',
      'SPECIAL_CASE',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "recipe_line_revisions" violates check constraint "recipe_line_revisions_calculation_kind_check"',
  'H0A2 calculation kind is fixed to proportional per basis'
);

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id,
  recipe_id,
  recipe_version_id,
  recipe_line_id,
  line_revision_number,
  ingredient_id,
  quantity_per_basis,
  unit_id,
  operational_note,
  created_by_actor_id
) values
  (
    '8a000000-0000-0000-0000-000000000510',
    '8a000000-0000-0000-0000-000000000200',
    '8a000000-0000-0000-0000-000000000310',
    '8a000000-0000-0000-0000-000000000400',
    1,
    '8a000000-0000-0000-0000-000000000030',
    10.000000,
    '8a000000-0000-0000-0000-000000000020',
    'Initial rice contribution',
    '8a000000-0000-0000-0000-000000000001'
  ),
  (
    '8a000000-0000-0000-0000-000000000511',
    '8a000000-0000-0000-0000-000000000200',
    '8a000000-0000-0000-0000-000000000310',
    '8a000000-0000-0000-0000-000000000401',
    1,
    '8a000000-0000-0000-0000-000000000031',
    1.250000,
    '8a000000-0000-0000-0000-000000000020',
    'Initial onion contribution',
    '8a000000-0000-0000-0000-000000000001'
  ),
  (
    '8a000000-0000-0000-0000-000000000512',
    '8a000000-0000-0000-0000-000000000200',
    '8a000000-0000-0000-0000-000000000310',
    '8a000000-0000-0000-0000-000000000402',
    1,
    '8a000000-0000-0000-0000-000000000033',
    0.500000,
    '8a000000-0000-0000-0000-000000000020',
    'Initial spice contribution',
    '8a000000-0000-0000-0000-000000000001'
  );

set constraints all immediate;

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'RELEASED_FOR_PLANNING',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        validated_at = timestamptz '2026-07-19 01:00:00+00',
        released_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        released_at = timestamptz '2026-07-19 01:01:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  $$,
  '23514',
  'recipe version lifecycle transition is invalid',
  'RecipeVersion lifecycle cannot skip validation'
);

select lives_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        validated_at = timestamptz '2026-07-19 01:00:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  $$,
  'a complete Draft RecipeVersion can become VALIDATED'
);

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'RELEASED_FOR_PLANNING',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000002',
        validated_at = timestamptz '2026-07-19 01:00:30+00',
        released_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        released_at = timestamptz '2026-07-19 01:05:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  $$,
  '23514',
  'established recipe validation evidence is immutable',
  'VALIDATED to RELEASED preserves its original validation actor and timestamp'
);

select throws_ok(
  $$
    update atlas_admin.recipe_line_revisions
    set quantity_per_basis = 999
    where recipe_line_revision_id = '8a000000-0000-0000-0000-000000000510'
  $$,
  '23514',
  'recipe line revisions are immutable',
  'exact RecipeLineRevision facts cannot be updated'
);

select lives_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'RELEASED_FOR_PLANNING',
        released_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        released_at = timestamptz '2026-07-19 01:05:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  $$,
  'a validated complete RecipeVersion can be released for Planning'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.recipe_versions
    where recipe_id = '8a000000-0000-0000-0000-000000000200'
      and recipe_version_status = 'RELEASED_FOR_PLANNING'
  ),
  1,
  'one Recipe has exactly one current released RecipeVersion'
);

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'LOCKED',
        released_by_actor_id = '8a000000-0000-0000-0000-000000000002',
        released_at = timestamptz '2026-07-19 01:06:00+00',
        locked_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        locked_at = timestamptz '2026-07-19 01:07:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  $$,
  '23514',
  'established recipe release evidence is immutable',
  'RELEASED to LOCKED preserves its original release actor and timestamp'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id,
  recipe_id,
  version_number,
  predecessor_recipe_version_id,
  basis_portions,
  created_by_actor_id
) values (
  '8a000000-0000-0000-0000-000000000311',
  '8a000000-0000-0000-0000-000000000200',
  2,
  '8a000000-0000-0000-0000-000000000310',
  100,
  '8a000000-0000-0000-0000-000000000001'
);

insert into atlas_admin.recipe_lines (
  recipe_line_id,
  recipe_id,
  line_code
) values (
  '8a000000-0000-0000-0000-000000000405',
  '8a000000-0000-0000-0000-000000000200',
  null
);

select lives_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000520',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000311',
      '8a000000-0000-0000-0000-000000000400',
      2,
      '8a000000-0000-0000-0000-000000000510',
      '8a000000-0000-0000-0000-000000000030',
      11.125000,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  'quantity correction keeps the same stable RecipeLine and exact predecessor'
);

select lives_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000521',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000311',
      '8a000000-0000-0000-0000-000000000401',
      2,
      '8a000000-0000-0000-0000-000000000511',
      '8a000000-0000-0000-0000-000000000032',
      1.500000,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  'ingredient correction keeps the same stable RecipeLine and exact predecessor'
);

select lives_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      line_disposition,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000522',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000311',
      '8a000000-0000-0000-0000-000000000402',
      2,
      '8a000000-0000-0000-0000-000000000512',
      '8a000000-0000-0000-0000-000000000033',
      0,
      '8a000000-0000-0000-0000-000000000020',
      'REMOVED',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  'explicit removal is a zero-quantity successor on the same stable RecipeLine'
);

select lives_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000523',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000311',
      '8a000000-0000-0000-0000-000000000405',
      1,
      '8a000000-0000-0000-0000-000000000034',
      0.250000,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  'a genuinely new contribution uses a new stable RecipeLine without a predecessor'
);

select is(
  (
    select count(distinct ingredient_id)::integer
    from atlas_admin.recipe_line_revisions
    where recipe_line_id = '8a000000-0000-0000-0000-000000000401'
  ),
  2,
  'stable RecipeLine identity persists independently through ingredient correction'
);

select is(
  (
    select array_agg(quantity_per_basis order by line_revision_number)::numeric[]
    from atlas_admin.recipe_line_revisions
    where recipe_line_id = '8a000000-0000-0000-0000-000000000400'
  ),
  array[10.000000, 11.125000]::numeric[],
  'stable RecipeLine identity persists through quantity correction'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_lines (
      recipe_line_id,
      recipe_id,
      line_code
    ) values (
      '8a000000-0000-0000-0000-000000000406',
      '8a000000-0000-0000-0000-000000000200',
      'duplicate-rice'
    );
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000524',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000311',
      '8a000000-0000-0000-0000-000000000406',
      1,
      '8a000000-0000-0000-0000-000000000030',
      1,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "recipe_line_revisions_present_ingredient_key"',
  'duplicate PRESENT ingredients within one RecipeVersion are rejected'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id,
  recipe_id,
  version_number,
  predecessor_recipe_version_id,
  basis_portions,
  created_by_actor_id
) values
  (
    '8a000000-0000-0000-0000-000000000312',
    '8a000000-0000-0000-0000-000000000200',
    3,
    '8a000000-0000-0000-0000-000000000310',
    100,
    '8a000000-0000-0000-0000-000000000001'
  ),
  (
    '8a000000-0000-0000-0000-000000000313',
    '8a000000-0000-0000-0000-000000000200',
    4,
    '8a000000-0000-0000-0000-000000000311',
    100,
    '8a000000-0000-0000-0000-000000000001'
  );

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000530',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000312',
      '8a000000-0000-0000-0000-000000000400',
      2,
      '8a000000-0000-0000-0000-000000000510',
      '8a000000-0000-0000-0000-000000000030',
      12,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "recipe_line_revisions_line_number_key"',
  'one stable RecipeLine cannot fork into two successors from the same revision'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000531',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000313',
      '8a000000-0000-0000-0000-000000000400',
      3,
      '8a000000-0000-0000-0000-000000000510',
      '8a000000-0000-0000-0000-000000000030',
      12,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'line predecessor must belong to the exact predecessor recipe version',
  'line predecessor must belong to the exact RecipeVersion predecessor'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000532',
      '8a000000-0000-0000-0000-000000000200',
      '8a000000-0000-0000-0000-000000000313',
      '8a000000-0000-0000-0000-000000000401',
      3,
      '8a000000-0000-0000-0000-000000000520',
      '8a000000-0000-0000-0000-000000000032',
      2,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'line predecessor must retain exact recipe and stable line ownership',
  'cross-Line merge wiring is rejected by exact stable-Line ownership'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id,
  recipe_id,
  version_number,
  predecessor_recipe_version_id,
  basis_portions,
  created_by_actor_id
) values (
  '8a000000-0000-0000-0000-000000000314',
  '8a000000-0000-0000-0000-000000000200',
  5,
  '8a000000-0000-0000-0000-000000000311',
  100,
  '8a000000-0000-0000-0000-000000000001'
);

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id,
  recipe_id,
  recipe_version_id,
  recipe_line_id,
  line_revision_number,
  predecessor_recipe_line_revision_id,
  ingredient_id,
  quantity_per_basis,
  unit_id,
  created_by_actor_id
) values (
  '8a000000-0000-0000-0000-000000000533',
  '8a000000-0000-0000-0000-000000000200',
  '8a000000-0000-0000-0000-000000000314',
  '8a000000-0000-0000-0000-000000000405',
  2,
  '8a000000-0000-0000-0000-000000000523',
  '8a000000-0000-0000-0000-000000000034',
  0.5,
  '8a000000-0000-0000-0000-000000000020',
  '8a000000-0000-0000-0000-000000000001'
);

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        validated_at = timestamptz '2026-07-19 02:00:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000314'
  $$,
  '23514',
  'every previously present recipe line requires an explicit successor or removal',
  'silent omission of previously PRESENT lines blocks validation'
);

select lives_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        validated_at = timestamptz '2026-07-19 02:05:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000311'
  $$,
  'a complete successor with correction, removal, and new line validates'
);

select lives_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'RELEASED_FOR_PLANNING',
        released_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        released_at = timestamptz '2026-07-19 02:10:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000311'
  $$,
  'releasing a direct successor atomically locks the prior current release'
);

select is(
  (
    select array_agg(recipe_version_status order by version_number)::text[]
    from atlas_admin.recipe_versions
    where recipe_version_id in (
      '8a000000-0000-0000-0000-000000000310',
      '8a000000-0000-0000-0000-000000000311'
    )
  ),
  array['LOCKED', 'RELEASED_FOR_PLANNING']::text[],
  'old release is LOCKED while its successor is current released'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.recipe_versions
    where recipe_id = '8a000000-0000-0000-0000-000000000200'
      and recipe_version_status = 'RELEASED_FOR_PLANNING'
  ),
  1,
  'successor release preserves the one-current-release invariant'
);

select ok(
  (
    select validated_by_actor_id = '8a000000-0000-0000-0000-000000000001'
      and validated_at = timestamptz '2026-07-19 01:00:00+00'
      and released_by_actor_id = '8a000000-0000-0000-0000-000000000001'
      and released_at = timestamptz '2026-07-19 01:05:00+00'
      and locked_by_actor_id = '8a000000-0000-0000-0000-000000000001'
      and locked_at = timestamptz '2026-07-19 02:10:00+00'
    from atlas_admin.recipe_versions
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  ),
  'automatic predecessor locking preserves validation and release evidence and adds only lock evidence'
);

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set basis_portions = 200
    where recipe_version_id = '8a000000-0000-0000-0000-000000000311'
  $$,
  '23514',
  'validated, released, and locked recipe basis is immutable',
  'released RecipeVersion basis cannot be edited'
);

select throws_ok(
  $$
    delete from atlas_admin.recipe_line_revisions
    where recipe_line_revision_id = '8a000000-0000-0000-0000-000000000520'
  $$,
  '23514',
  'recipe line revisions are immutable',
  'released RecipeLineRevision facts cannot be deleted'
);

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        locked_by_actor_id = null,
        locked_at = null,
        released_by_actor_id = null,
        released_at = null
    where recipe_version_id = '8a000000-0000-0000-0000-000000000310'
  $$,
  '23514',
  'established recipe release evidence is immutable',
  'LOCKED RecipeVersions reject attempts to rewrite historical lifecycle evidence'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id,
  recipe_id,
  version_number,
  basis_portions,
  created_by_actor_id
) values (
  '8a000000-0000-0000-0000-000000000320',
  '8a000000-0000-0000-0000-000000000203',
  1,
  100,
  '8a000000-0000-0000-0000-000000000001'
);

insert into atlas_admin.recipe_lines (
  recipe_line_id,
  recipe_id,
  line_code
) values (
  '8a000000-0000-0000-0000-000000000406',
  '8a000000-0000-0000-0000-000000000200',
  'cross-recipe-fixture'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_line_revisions (
      recipe_line_revision_id,
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      created_by_actor_id
    ) values (
      '8a000000-0000-0000-0000-000000000540',
      '8a000000-0000-0000-0000-000000000203',
      '8a000000-0000-0000-0000-000000000320',
      '8a000000-0000-0000-0000-000000000406',
      1,
      '8a000000-0000-0000-0000-000000000033',
      1,
      '8a000000-0000-0000-0000-000000000020',
      '8a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503',
  'insert or update on table "recipe_line_revisions" violates foreign key constraint "recipe_line_revisions_line_fkey"',
  'typed ownership rejects a cross-Recipe RecipeLine revision'
);

select throws_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        validated_at = timestamptz '2026-07-19 03:00:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000320'
  $$,
  '23514',
  'a need-generation recipe version requires a present composition',
  'an empty composition cannot validate for a Need-Generation Dish'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id,
  recipe_id,
  version_number,
  basis_portions,
  created_by_actor_id
) values (
  '8a000000-0000-0000-0000-000000000321',
  '8a000000-0000-0000-0000-000000000207',
  1,
  1,
  '8a000000-0000-0000-0000-000000000001'
);

select lives_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        validated_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        validated_at = timestamptz '2026-07-19 03:05:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000321'
  $$,
  'a non-Need-Generation Dish may validate an empty reference composition'
);

select lives_ok(
  $$
    update atlas_admin.recipe_versions
    set recipe_version_status = 'RELEASED_FOR_PLANNING',
        released_by_actor_id = '8a000000-0000-0000-0000-000000000001',
        released_at = timestamptz '2026-07-19 03:10:00+00'
    where recipe_version_id = '8a000000-0000-0000-0000-000000000321'
  $$,
  'a non-Need-Generation empty reference RecipeVersion may be released'
);

update atlas_admin.dishes
set dish_status = 'INACTIVE',
    version = version + 1,
    updated_at = transaction_timestamp()
where dish_id = '8a000000-0000-0000-0000-000000000100';

update atlas_admin.recipes
set recipe_status = 'INACTIVE',
    version = version + 1,
    updated_at = transaction_timestamp()
where recipe_id = '8a000000-0000-0000-0000-000000000200';

update atlas_admin.ingredients
set ingredient_status = 'INACTIVE',
    version = version + 1,
    updated_at = transaction_timestamp()
where ingredient_id in (
  '8a000000-0000-0000-0000-000000000030',
  '8a000000-0000-0000-0000-000000000032'
);

update atlas_admin.units
set unit_status = 'INACTIVE'
where unit_id = '8a000000-0000-0000-0000-000000000020';

update atlas_admin.school_types
set school_type_status = 'INACTIVE',
    version = version + 1,
    updated_at = transaction_timestamp()
where school_type_id = '8a000000-0000-0000-0000-000000000010';

select is(
  (
    select count(*)::integer
    from atlas_admin.recipe_line_revisions line_revision
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = line_revision.ingredient_id
    join atlas_admin.units unit_reference
      on unit_reference.unit_id = line_revision.unit_id
    where line_revision.recipe_id = '8a000000-0000-0000-0000-000000000200'
      and ingredient.ingredient_status = 'INACTIVE'
      and unit_reference.unit_status = 'INACTIVE'
  ),
  3,
  'historical RecipeLineRevision references survive Ingredient and Unit deactivation'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.recipes recipe
    join atlas_admin.school_types school_type
      on school_type.school_type_id = recipe.school_type_id
    where recipe.recipe_id = '8a000000-0000-0000-0000-000000000203'
      and school_type.school_type_status = 'INACTIVE'
  ),
  1,
  'typed Recipe history survives SchoolType deactivation'
);

select throws_ok(
  $$delete from atlas_admin.dishes where dish_id = '8a000000-0000-0000-0000-000000000100'$$,
  '23503',
  'update or delete on table "dishes" violates foreign key constraint "recipes_dish_fkey" on table "recipes"',
  'Dish references use ON DELETE RESTRICT'
);

select throws_ok(
  $$delete from atlas_admin.school_types where school_type_id = '8a000000-0000-0000-0000-000000000010'$$,
  '23503',
  'update or delete on table "school_types" violates foreign key constraint "recipes_school_type_fkey" on table "recipes"',
  'SchoolType Recipe references use ON DELETE RESTRICT'
);

select throws_ok(
  $$delete from atlas_admin.ingredients where ingredient_id = '8a000000-0000-0000-0000-000000000030'$$,
  '23503',
  'update or delete on table "ingredients" violates foreign key constraint "recipe_line_revisions_ingredient_fkey" on table "recipe_line_revisions"',
  'Ingredient BOM references use ON DELETE RESTRICT'
);

select throws_ok(
  $$delete from atlas_admin.units where unit_id = '8a000000-0000-0000-0000-000000000020'$$,
  '23503',
  'update or delete on table "units" violates foreign key constraint "recipe_line_revisions_unit_fkey" on table "recipe_line_revisions"',
  'Unit BOM references use ON DELETE RESTRICT'
);

select throws_ok(
  $$delete from atlas_core.actors where actor_id = '8a000000-0000-0000-0000-000000000001'$$,
  '23503',
  'update or delete on table "actors" violates foreign key constraint "recipe_versions_created_by_actor_fkey" on table "recipe_versions"',
  'Actor lifecycle references use ON DELETE RESTRICT'
);

select ok(
  (
    select count(*) = 15 and bool_and(con.confdeltype = 'r')
    from pg_constraint con
    where con.conname in (
      'recipes_dish_fkey',
      'recipes_school_type_fkey',
      'recipe_versions_recipe_fkey',
      'recipe_versions_predecessor_fkey',
      'recipe_versions_created_by_actor_fkey',
      'recipe_versions_validated_by_actor_fkey',
      'recipe_versions_released_by_actor_fkey',
      'recipe_versions_locked_by_actor_fkey',
      'recipe_lines_recipe_fkey',
      'recipe_line_revisions_version_fkey',
      'recipe_line_revisions_line_fkey',
      'recipe_line_revisions_predecessor_fkey',
      'recipe_line_revisions_ingredient_fkey',
      'recipe_line_revisions_unit_fkey',
      'recipe_line_revisions_created_by_actor_fkey'
    )
  ),
  'every H0A2 operational foreign key uses ON DELETE RESTRICT'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conrelid in (
      'atlas_admin.recipes'::regclass,
      'atlas_admin.recipe_versions'::regclass,
      'atlas_admin.recipe_lines'::regclass,
      'atlas_admin.recipe_line_revisions'::regclass
    )
      and con.contype = 'f'
      and not exists (
        select 1
        from pg_index idx
        where idx.indrelid = con.conrelid
          and idx.indisvalid
          and (
            select array_agg(key_column.attnum::smallint order by key_column.ordinality)
            from unnest(idx.indkey::smallint[]) with ordinality
              as key_column(attnum, ordinality)
            where key_column.ordinality <= cardinality(con.conkey)
          ) = con.conkey
      )
  ),
  'every H0A2 foreign key has a matching leading-column index'
);

select ok(
  not exists (
    select 1
    from pg_class c
    where c.oid in (
      'atlas_admin.dishes'::regclass,
      'atlas_admin.recipes'::regclass,
      'atlas_admin.recipe_versions'::regclass,
      'atlas_admin.recipe_lines'::regclass,
      'atlas_admin.recipe_line_revisions'::regclass
    )
      and (not c.relrowsecurity or not c.relforcerowsecurity)
  ),
  'all five H0A2 relations have RLS enabled and forced'
);

select is(
  (
    select count(*)::integer
    from pg_policy policy
    where policy.polrelid in (
      'atlas_admin.dishes'::regclass,
      'atlas_admin.recipes'::regclass,
      'atlas_admin.recipe_versions'::regclass,
      'atlas_admin.recipe_lines'::regclass,
      'atlas_admin.recipe_line_revisions'::regclass
    )
  ),
  0,
  'H0A2 adds zero RLS policies'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_admin'
      and c.relkind = 'S'
      and c.relname like '%recipe%'
  ),
  0,
  'database-generated UUID identities add no H0A2 sequences or sequence grants'
);

select is(
  (
    select array_agg(owner.rolname order by c.relname)::text[]
    from pg_class c
    join pg_roles owner on owner.oid = c.relowner
    where c.oid in (
      'atlas_admin.dishes'::regclass,
      'atlas_admin.recipes'::regclass,
      'atlas_admin.recipe_versions'::regclass,
      'atlas_admin.recipe_lines'::regclass,
      'atlas_admin.recipe_line_revisions'::regclass
    )
  ),
  array[
    'atlas_owner',
    'atlas_owner',
    'atlas_owner',
    'atlas_owner',
    'atlas_owner'
  ]::text[],
  'all five H0A2 relations are owned by atlas_owner'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles owner on owner.oid = p.proowner
    where n.nspname = 'atlas_admin'
      and p.proname like 'pa_06e_h0a2_%'
      and owner.rolname = 'atlas_owner'
  ),
  3,
  'the three minimum private H0A2 guard functions are owned by atlas_owner'
);

select ok(
  not exists (
    select 1
    from pg_class c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) relation_acl
    left join pg_roles grantee on grantee.oid = relation_acl.grantee
    where c.oid in (
      'atlas_admin.dishes'::regclass,
      'atlas_admin.recipes'::regclass,
      'atlas_admin.recipe_versions'::regclass,
      'atlas_admin.recipe_lines'::regclass,
      'atlas_admin.recipe_line_revisions'::regclass
    )
      and (
        relation_acl.grantee = 0
        or grantee.rolname in ('anon', 'authenticated', 'service_role')
      )
      and relation_acl.privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
  ),
  'PUBLIC and API roles have no H0A2 relation privileges'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) function_acl
    left join pg_roles grantee on grantee.oid = function_acl.grantee
    where n.nspname = 'atlas_admin'
      and p.proname like 'pa_06e_h0a2_%'
      and (
        function_acl.grantee = 0
        or grantee.rolname in ('anon', 'authenticated', 'service_role')
      )
      and function_acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC and API roles cannot execute private H0A2 guard functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_admin'
      and p.proname like 'pa_06e_h0a2_%'
      and not coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  'every private H0A2 guard function has a hardened empty search path'
);

select is(
  (
    select array_agg(
      format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
      order by p.proname
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)',
    'apply_supplier_evidence_to_allocation(request jsonb)',
    'close_successful_trip(request jsonb)',
    'confirm_dispatch_load(request jsonb)',
    'confirm_successful_delivery(request jsonb)',
    'create_dispatch_plan(request jsonb)',
    'create_or_assign_dispatch_trip(request jsonb)',
    'get_command_audit_timeline(request jsonb)',
    'get_dispatch_evidence_readiness(request jsonb)',
    'get_operator_blockers(request jsonb)',
    'get_supplier_direct_trace(request jsonb)',
    'record_dispatch_departure(request jsonb)',
    'record_supplier_receiving_evidence(request jsonb)',
    'record_wholesale_source(request jsonb)',
    'release_dispatch_requirement(request jsonb)',
    'release_purchase_handoff(request jsonb)',
    'release_supplier_purchase_order(request jsonb)',
    'release_wholesale_order(request jsonb)'
  ]::text[],
  'the exact 18-function atlas_api registry remains unchanged'
);

select is(
  (select count(*)::integer from atlas_core.roles),
  0,
  'H0A2 seeds no roles'
);

select is(
  (select count(*)::integer from atlas_core.capabilities),
  0,
  'H0A2 seeds no capabilities'
);

select * from finish();

rollback;
