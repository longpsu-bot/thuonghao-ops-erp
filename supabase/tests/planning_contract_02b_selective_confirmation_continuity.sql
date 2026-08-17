begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;

select plan(42);

select ok(
  to_regclass('atlas_planning.confirmed_need_line_decision_continuity')
    is not null,
  'PCT02B-STR-01 the private continuity relation exists'
);
select is(
  (
    select relkind
    from pg_class
    where oid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  'r'::"char",
  'PCT02B-STR-02 continuity evidence is one ordinary relation'
);
select columns_are(
  'atlas_planning',
  'confirmed_need_line_decision_continuity',
  array[
    'confirmed_need_line_decision_continuity_id',
    'confirmed_need_batch_id',
    'confirmed_need_line_id',
    'source_confirmed_need_line_decision_id',
    'predecessor_confirmed_need_line_revision_id',
    'successor_confirmed_need_line_revision_id',
    'predecessor_need_generation_run_id',
    'predecessor_need_generation_run_version',
    'predecessor_need_generation_release_snapshot_id',
    'successor_need_generation_run_id',
    'successor_need_generation_run_version',
    'successor_need_generation_release_snapshot_id',
    'source_kind',
    'service_date',
    'customer_id',
    'school_id',
    'delivery_location_id',
    'ingredient_id',
    'unit_id',
    'continuity_kind',
    'command_id',
    'initiated_by_actor_id',
    'recorded_at'
  ]::text[],
  'PCT02B-STR-03 continuity evidence has the exact bounded columns'
);
select is(
  (
    select array_agg(column_name order by ordinal_position)::text[]
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decision_continuity'
      and column_default is not null
  ),
  array[
    'confirmed_need_line_decision_continuity_id',
    'source_kind',
    'recorded_at'
  ]::text[],
  'PCT02B-STR-04 only ID, fixed source kind, and timestamp have defaults'
);
select is(
  (
    select array_agg(column_name order by ordinal_position)::text[]
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decision_continuity'
      and is_nullable = 'YES'
  ),
  array['successor_confirmed_need_line_revision_id']::text[],
  'PCT02B-STR-05 only a removed line may omit the successor revision'
);
select is(
  (
    select pg_get_userbyid(relowner)
    from pg_class
    where oid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  'atlas_owner',
  'PCT02B-STR-06 atlas_owner owns continuity persistence'
);
select ok(
  (
    select relrowsecurity and relforcerowsecurity
    from pg_class
    where oid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  'PCT02B-STR-07 continuity persistence has enabled and forced RLS'
);
select ok(
  (
    select pg_get_constraintdef(oid) like
      '%CARRIED_FORWARD%INVALIDATED_PROPOSAL_CHANGE%INVALIDATED_POLICY_INCOMPATIBLE%INVALIDATED_LINE_REMOVED%'
    from pg_constraint
    where conrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and conname = 'confirmed_need_line_decision_continuity_kind_check'
  ),
  'PCT02B-STR-08 the check freezes exactly four continuity kinds'
);
select ok(
  (
    select pg_get_constraintdef(oid) like
      '%INVALIDATED_LINE_REMOVED%successor_confirmed_need_line_revision_id IS NULL%'
    from pg_constraint
    where conrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and conname = 'confirmed_need_line_decision_continuity_shape_check'
  ),
  'PCT02B-STR-09 only removal evidence has no successor revision'
);
select ok(
  (
    select pg_get_constraintdef(oid) =
      'CHECK (((predecessor_need_generation_run_version > 0) AND (successor_need_generation_run_version > 0)))'
    from pg_constraint
    where conrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and conname = 'confirmed_need_line_decision_continuity_version_check'
  ),
  'PCT02B-STR-10 both generated contexts require positive versions'
);
select is(
  (
    select count(*)::integer
    from pg_constraint
    where conrelid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  16,
  'PCT02B-STR-11 fifteen relational constraints plus one deferred constraint trigger are exact'
);
select is(
  (
    select count(*)::integer
    from pg_constraint
    where conrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and contype = 'f'
      and confdeltype = 'r'
  ),
  8,
  'PCT02B-STR-12 all eight relational links restrict deletion'
);
select is(
  (
    select count(*)::integer
    from pg_index
    where indrelid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  6,
  'PCT02B-STR-13 three constraint indexes and three access indexes are exact'
);
select ok(
  (
    select pg_get_indexdef(indexrelid) like
      '%(source_confirmed_need_line_decision_id, confirmed_need_line_id)%'
    from pg_index
    where indexrelid =
      'atlas_planning.confirmed_need_line_decision_continuity_decision_idx'::regclass
  ),
  'PCT02B-STR-14 decision history access is indexed'
);
select ok(
  (
    select pg_get_expr(indpred, indrelid) =
      '(successor_confirmed_need_line_revision_id IS NOT NULL)'
    from pg_index
    where indexrelid =
      'atlas_planning.confirmed_need_line_decision_continuity_successor_idx'::regclass
  ),
  'PCT02B-STR-15 successor lookup is an exact non-null partial index'
);
select ok(
  (
    select pg_get_indexdef(indexrelid) like
      '%(confirmed_need_batch_id, successor_need_generation_run_id, successor_need_generation_run_version, continuity_kind)%'
    from pg_index
    where indexrelid =
      'atlas_planning.confirmed_need_line_decision_continuity_batch_context_idx'::regclass
  ),
  'PCT02B-STR-16 batch successor support counts are indexed'
);
select is(
  (
    select array_agg(tgname order by tgname)::text[]
    from pg_trigger
    where tgrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and not tgisinternal
  ),
  array[
    'confirmed_need_line_decision_continuity_immutable',
    'confirmed_need_line_decision_continuity_integrity'
  ]::text[],
  'PCT02B-STR-17 continuity evidence has exactly immutable and integrity triggers'
);
select ok(
  (
    select not tgdeferrable
      and pg_get_triggerdef(oid) like '%BEFORE DELETE OR UPDATE%'
    from pg_trigger
    where tgrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and tgname = 'confirmed_need_line_decision_continuity_immutable'
  ),
  'PCT02B-STR-18 update and delete fail immediately'
);
select ok(
  (
    select tgdeferrable and tginitdeferred
      and pg_get_triggerdef(oid) like '%AFTER INSERT%'
    from pg_trigger
    where tgrelid =
        'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and tgname = 'confirmed_need_line_decision_continuity_integrity'
  ),
  'PCT02B-STR-19 semantic integrity is deferred and initially deferred'
);
select is(
  (
    select count(*)::integer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('atlas_core', 'atlas_planning')
      and p.proname like '%planning_contract_02b%'
  ),
  9,
  'PCT02B-STR-20 exactly nine private 02B functions exist'
);
select is(
  (
    select count(*)::integer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('atlas_core', 'atlas_planning')
      and p.proname like '%planning_contract_02b%'
      and coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  9,
  'PCT02B-STR-21 every private 02B function fixes an empty search_path'
);
select ok(
  (
    select bool_and(pg_get_userbyid(proowner) =
      'atlas_planning_materialization_runtime')
    from pg_proc
    where oid in (
      'atlas_core.planning_contract_02b_apply_decision_continuity(uuid,uuid,bigint,uuid,uuid,bigint,uuid,uuid,uuid)'::regprocedure,
      'atlas_core.planning_contract_02b_policy_incompatible_batch(uuid,date,date)'::regprocedure
    )
  ),
  'PCT02B-STR-22 only the materializer owns continuity mutation and policy detection'
);
select ok(
  not has_function_privilege(
      'authenticated',
      'atlas_core.planning_contract_02b_apply_decision_continuity(uuid,uuid,bigint,uuid,uuid,bigint,uuid,uuid,uuid)'::regprocedure,
      'EXECUTE'
    )
    and not has_function_privilege(
      'authenticated',
      'atlas_core.planning_contract_02b_policy_incompatible_batch(uuid,date,date)'::regprocedure,
      'EXECUTE'
    )
    and not has_function_privilege(
      'authenticated',
      'atlas_core.planning_contract_02b_removed_business_fact_count(uuid,uuid,bigint,uuid,uuid,bigint,uuid)'::regprocedure,
      'EXECUTE'
    ),
  'PCT02B-STR-23 browser operators cannot execute private continuity helpers'
);
select ok(
  not has_function_privilege(
      'service_role',
      'atlas_core.planning_contract_02b_apply_decision_continuity(uuid,uuid,bigint,uuid,uuid,bigint,uuid,uuid,uuid)'::regprocedure,
      'EXECUTE'
    )
    and not has_function_privilege(
      'service_role',
      'atlas_core.planning_contract_02b_policy_incompatible_batch(uuid,date,date)'::regprocedure,
      'EXECUTE'
    )
    and not has_function_privilege(
      'service_role',
      'atlas_core.planning_contract_02b_removed_business_fact_count(uuid,uuid,bigint,uuid,uuid,bigint,uuid)'::regprocedure,
      'EXECUTE'
    ),
  'PCT02B-STR-24 service_role cannot execute private continuity helpers'
);
select ok(
  not has_function_privilege(
    'atlas_command_runtime',
    'atlas_core.planning_contract_02b_apply_decision_continuity(uuid,uuid,bigint,uuid,uuid,bigint,uuid,uuid,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'PCT02B-STR-25 the retired runtime cannot execute the continuity writer'
);
select ok(
  has_function_privilege(
    'atlas_confirmed_need_review_runtime',
    'atlas_core.planning_contract_02b_extend_workbench(jsonb)'::regprocedure,
    'EXECUTE'
  ) and has_function_privilege(
    'atlas_confirmed_need_review_runtime',
    'atlas_core.planning_contract_02b_removed_business_fact_count(uuid,uuid,bigint,uuid,uuid,bigint,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'PCT02B-STR-26 only the authoritative review runtime receives the read extension'
);
select is(
  (
    select count(*)::integer
    from pg_policy
    where polrelid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  4,
  'PCT02B-STR-27 continuity persistence has exactly four backend policies'
);
select is(
  (
    select array_agg(polname order by polname)::text[]
    from pg_policy
    where polrelid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
  ),
  array[
    'planning_contract_02b_generation_select',
    'planning_contract_02b_materialization_insert',
    'planning_contract_02b_materialization_select',
    'planning_contract_02b_review_select'
  ]::text[],
  'PCT02B-STR-28 policy names expose only backend read/write purposes'
);
select is(
  (
    select count(*)::integer
    from pg_class c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) privilege
    where c.oid =
      'atlas_planning.confirmed_need_line_decision_continuity'::regclass
      and privilege.privilege_type in ('SELECT', 'INSERT')
      and privilege.grantee <> c.relowner
  ),
  4,
  'PCT02B-STR-29 relation ACL has exactly three reads and one insert'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'atlas_planning.confirmed_need_line_decision_continuity',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'PCT02B-STR-30 browser operators have no direct continuity-table privilege'
);
select ok(
  not has_table_privilege(
    'service_role',
    'atlas_planning.confirmed_need_line_decision_continuity',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'PCT02B-STR-31 service_role has no direct continuity-table privilege'
);
select is(
  (
    select count(*)::integer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api' and p.proname like '%02b%'
  ),
  0,
  'PCT02B-STR-32 no public 02B API was added'
);
select is(
  (
    select count(*)::integer
    from atlas_core.capabilities
    where capability_code like '%continuity%'
  ),
  0,
  'PCT02B-STR-33 no operator continuity capability was added'
);
select ok(
  (
    select prosrc like '%planning_contract_02b_invalidation_authorizes_clear%'
    from pg_proc
    where oid =
      'atlas_planning.pa_06e_h1b1_confirmed_need_line_pointer_guard()'::regprocedure
  ),
  'PCT02B-STR-34 pointer clearing requires exact invalidation evidence'
);
select ok(
  (
    select prosrc like '%planning_contract_02b_decision_authorizes_revision%'
    from pg_proc
    where oid =
      'atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()'::regprocedure
  ),
  'PCT02B-STR-35 current-decision integrity accepts only exact carry evidence'
);
select ok(
  (
    select prosrc like '%planning_contract_02b_apply_decision_continuity%'
      and prosrc like '%planning_contract_02b_removed_business_fact_count%'
    from pg_proc
    where oid =
      'atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure
  ),
  'PCT02B-STR-36 the existing atomic materializer owns continuity application'
);
select ok(
  (
    select prosrc like '%theoretical_quantity is distinct from%'
      and prosrc like '%planning_quantity_policy_revision_id%'
    from pg_proc
    where oid =
      'atlas_core.planning_contract_02b_apply_decision_continuity(uuid,uuid,bigint,uuid,uuid,bigint,uuid,uuid,uuid)'::regprocedure
  ),
  'PCT02B-STR-37 carry eligibility uses exact numeric and policy revision equality'
);
select ok(
  (
    select prosrc not like '%recipe_id%'
      and prosrc not like '%dish_id%'
      and prosrc not like '%source_signature%'
    from pg_proc
    where oid =
      'atlas_core.planning_contract_02b_apply_decision_continuity(uuid,uuid,bigint,uuid,uuid,bigint,uuid,uuid,uuid)'::regprocedure
  ),
  'PCT02B-STR-38 source lineage is not a carry eligibility predicate'
);
select ok(
  (
    select prosrc like '%planning_contract_02b_decision_authorizes_revision%'
    from pg_proc
    where oid =
      'atlas_core.rmvp_06_canonical_evaluation(uuid,text)'::regprocedure
  ),
  'PCT02B-STR-39 RMVP-06 release eligibility recognizes exact carried authority'
);
select ok(
  (
    select prosrc like '%planning_contract_02b_decision_authorizes_revision%'
    from pg_proc
    where oid =
      'atlas_core.rmvp_07_validation_evidence_complete(uuid,uuid,bigint)'::regprocedure
  ),
  'PCT02B-STR-40 RMVP-07 validation evidence recognizes exact carried authority'
);
select ok(
  (
    select prosrc like '%planning_contract_02b_extend_workbench%'
    from pg_proc
    where oid = 'atlas_core.d037_extend_workbench(jsonb,uuid)'::regprocedure
  ) and (
    select prosrc like '%planning_contract_02b_removed_business_fact_count%'
    from pg_proc
    where oid =
      'atlas_core.planning_contract_02b_extend_workbench(jsonb)'::regprocedure
  ),
  'PCT02B-STR-41 all v2 readbacks receive backend classifications and counts'
);
select ok(
  obj_description(
    'atlas_planning.confirmed_need_line_decision_continuity'::regclass,
    'pg_class'
  ) like '%system evidence%human%decision%',
  'PCT02B-STR-42 relation documentation distinguishes system continuity from human authorship'
);

select * from finish();
rollback;
