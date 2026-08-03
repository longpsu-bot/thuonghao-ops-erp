begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(64);

select ok(
  to_regclass('atlas_planning.confirmed_need_line_decisions') is not null
  and (
    select relkind = 'r'
    from pg_class
    where oid = 'atlas_planning.confirmed_need_line_decisions'::regclass
  ),
  'H1B1-STR-01 exactly one atlas_planning.confirmed_need_line_decisions ordinary relation exists'
);
select is(
  (
    select format(
      '%s|%s|%s',
      udt_name,
      is_nullable,
      coalesce(column_default, '<null>')
    )
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_lines'
      and column_name = 'current_confirmed_need_line_decision_id'
  ),
  'uuid|YES|<null>',
  'H1B1-STR-02 the stable-line pointer is exactly uuid, nullable, and has no default'
);
select columns_are(
  'atlas_planning',
  'confirmed_need_line_decisions',
  array[
    'confirmed_need_line_decision_id',
    'confirmed_need_batch_id',
    'confirmed_need_line_id',
    'confirmed_need_line_revision_id',
    'source_kind',
    'service_date',
    'customer_id',
    'school_id',
    'delivery_location_id',
    'ingredient_id',
    'unit_id',
    'decision_number',
    'predecessor_decision_id',
    'decision_kind',
    'planning_quantity_policy_id',
    'planning_quantity_policy_revision_id',
    'theoretical_quantity_before',
    'proposed_quantity_before',
    'confirmed_quantity_after',
    'planning_tick_count',
    'reason_code',
    'reason_note',
    'decided_by_actor_id',
    'decided_at',
    'command_id',
    'confirmed_need_batch_version',
    'created_at'
  ]::text[],
  'H1B1-STR-03 the decision relation has exactly the approved 27 columns in approved order'
);
select is(
  (
    select array_agg(
      format(
        '%s|%s|%s|%s|%s',
        column_name,
        udt_name,
        is_nullable,
        coalesce(numeric_precision::text, '-'),
        coalesce(numeric_scale::text, '-')
      )
      order by ordinal_position
    )::text[]
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decisions'
  ),
  array[
    'confirmed_need_line_decision_id|uuid|NO|-|-',
    'confirmed_need_batch_id|uuid|NO|-|-',
    'confirmed_need_line_id|uuid|NO|-|-',
    'confirmed_need_line_revision_id|uuid|NO|-|-',
    'source_kind|text|NO|-|-',
    'service_date|date|NO|-|-',
    'customer_id|uuid|NO|-|-',
    'school_id|uuid|NO|-|-',
    'delivery_location_id|uuid|NO|-|-',
    'ingredient_id|uuid|NO|-|-',
    'unit_id|uuid|NO|-|-',
    'decision_number|int8|NO|64|0',
    'predecessor_decision_id|uuid|YES|-|-',
    'decision_kind|text|NO|-|-',
    'planning_quantity_policy_id|uuid|NO|-|-',
    'planning_quantity_policy_revision_id|uuid|NO|-|-',
    'theoretical_quantity_before|numeric|NO|20|6',
    'proposed_quantity_before|numeric|NO|20|6',
    'confirmed_quantity_after|numeric|NO|20|6',
    'planning_tick_count|numeric|NO|20|0',
    'reason_code|text|NO|-|-',
    'reason_note|text|YES|-|-',
    'decided_by_actor_id|uuid|NO|-|-',
    'decided_at|timestamptz|NO|-|-',
    'command_id|uuid|NO|-|-',
    'confirmed_need_batch_version|int8|NO|64|0',
    'created_at|timestamptz|NO|-|-'
  ]::text[],
  'H1B1-STR-04 all 27 types, precision, scale, and nullability values match the catalog'
);
select is(
  (
    select array_agg(column_name order by ordinal_position)::text[]
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decisions'
      and column_default is not null
  ),
  array[
    'confirmed_need_line_decision_id',
    'created_at'
  ]::text[],
  'H1B1-STR-05 only decision ID and created_at have database defaults'
);
select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decisions'
      and column_name = 'confirmed_need_line_decision_id'
  ),
  'gen_random_uuid()',
  'H1B1-STR-06 decision ID default is exactly gen_random_uuid()'
);
select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decisions'
      and column_name = 'created_at'
  ),
  'transaction_timestamp()',
  'H1B1-STR-07 created_at default is exactly transaction_timestamp()'
);
select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'confirmed_need_line_decisions'
      and column_name not in (
        'confirmed_need_line_decision_id',
        'created_at'
      )
      and column_default is not null
  ),
  0,
  'H1B1-STR-08 every other decision evidence column has no default'
);

select ok(
  (
    select contype = 'p'
      and pg_get_constraintdef(oid)
        = 'PRIMARY KEY (confirmed_need_line_decision_id)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_pkey'
  ),
  'H1B1-STR-09 confirmed_need_line_decisions_pkey is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (confirmed_need_line_id, confirmed_need_line_decision_id)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_line_id_decision_id_key'
  ),
  'H1B1-STR-10 same-line decision-ID unique key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (confirmed_need_line_id, decision_number)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_line_decision_number_key'
  ),
  'H1B1-STR-11 one decision_number per line unique key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (confirmed_need_line_id, predecessor_decision_id)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_line_predecessor_key'
  ),
  'H1B1-STR-12 same-line predecessor non-fork unique key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (command_id, confirmed_need_line_id)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_command_line_key'
  ),
  'H1B1-STR-13 one decision per command per line unique key is exact'
);
select ok(
  (
    select contype = 'c'
      and regexp_replace(pg_get_constraintdef(oid), '\s+', '', 'g')
        = 'CHECK((decision_number>0))'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_decision_number_check'
  ),
  'H1B1-STR-14 positive decision-number CHECK is exact'
);
select ok(
  (
    select pg_get_constraintdef(oid) like '%decision_number = 1%'
      and pg_get_constraintdef(oid) like '%decision_number > 1%'
      and pg_get_constraintdef(oid) like '%predecessor_decision_id%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_predecessor_shape_check'
  )
  and (
    select pg_get_constraintdef(oid)
      like '%predecessor_decision_id <> confirmed_need_line_decision_id%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_predecessor_self_check'
  ),
  'H1B1-STR-15 first-null, later-non-null, and non-self predecessor CHECKs are exact'
);
select ok(
  (
    select pg_get_constraintdef(oid) like '%NEED_GENERATION%'
      and pg_get_constraintdef(oid) not like '%WHOLESALE%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_source_kind_check'
  ),
  'H1B1-STR-16 source_kind CHECK admits only NEED_GENERATION'
);
select ok(
  (
    select regexp_count(
      pg_get_constraintdef(oid),
      'UNCHANGED_PROPOSAL_ACCEPTED|ADJUSTED_QUANTITY_CONFIRMED'
    ) = 2
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_decision_kind_check'
  ),
  'H1B1-STR-17 decision-kind CHECK admits exactly two approved values'
);
select ok(
  (
    select regexp_count(
      pg_get_constraintdef(oid),
      'PROPOSAL_ACCEPTED|PLANNING_STEP_ADJUSTMENT|OPERATIONAL_QUANTITY_ADJUSTMENT|OTHER'
    ) = 4
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_reason_code_check'
  ),
  'H1B1-STR-18 reason-code CHECK admits exactly four approved values'
);
select ok(
  (
    select pg_get_constraintdef(oid) like '%btrim(reason_note)%'
      and pg_get_constraintdef(oid) like '%char_length(reason_note)%'
      and pg_get_constraintdef(oid) like '%500%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_reason_note_check'
  ),
  'H1B1-STR-19 present notes are trimmed, nonblank Unicode text of at most 500 characters'
);
select ok(
  (
    select pg_get_constraintdef(oid)
        like '%UNCHANGED_PROPOSAL_ACCEPTED%'
      and pg_get_constraintdef(oid)
        like '%ADJUSTED_QUANTITY_CONFIRMED%'
      and pg_get_constraintdef(oid) like '%PROPOSAL_ACCEPTED%'
      and pg_get_constraintdef(oid) like '%PLANNING_STEP_ADJUSTMENT%'
      and pg_get_constraintdef(oid)
        like '%OPERATIONAL_QUANTITY_ADJUSTMENT%'
      and pg_get_constraintdef(oid) like '%OTHER%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_kind_reason_note_check'
  ),
  'H1B1-STR-20 decision kind, business reason, and first-note compatibility CHECK is exact'
);
select ok(
  (
    select pg_get_constraintdef(oid)
      like '%predecessor_decision_id IS NULL%reason_note IS NOT NULL%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_correction_note_check'
  ),
  'H1B1-STR-21 every non-first decision requires a correction note'
);
select ok(
  (
    select pg_get_constraintdef(oid) like '%theoretical_quantity_before >=%'
      and pg_get_constraintdef(oid) like '%proposed_quantity_before >=%'
      and pg_get_constraintdef(oid) like '%confirmed_quantity_after >=%'
      and pg_get_constraintdef(oid) like '%planning_tick_count >=%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_quantity_check'
  ),
  'H1B1-STR-22 all three quantities and planning_tick_count are nonnegative'
);
select ok(
  (
    select pg_get_constraintdef(oid) like '%confirmed_quantity_after = proposed_quantity_before%'
      and pg_get_constraintdef(oid) like '%confirmed_quantity_after <> proposed_quantity_before%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_decision_quantity_shape_check'
  ),
  'H1B1-STR-23 unchanged means after equals proposal; adjusted means after differs from proposal'
);
select ok(
  (
    select pg_get_constraintdef(oid)
      like '%confirmed_need_batch_version >%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_batch_version_check'
  ),
  'H1B1-STR-24 confirmed_need_batch_version must be positive'
);

select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and confrelid = 'atlas_planning.confirmed_need_lines'::regclass
      and pg_get_constraintdef(oid) like
        '%confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, unit_id%'
      and pg_get_constraintdef(oid) like
        '%confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, controlled_unit_id%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_line_owner_fkey'
  ),
  'H1B1-STR-25 exact stable-line operational-owner FK is restrictive and maps unit_id to controlled_unit_id'
);
select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and confrelid
        = 'atlas_planning.confirmed_need_line_revisions'::regclass
      and pg_get_constraintdef(oid)
        like '%confirmed_need_line_revision_id, confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, unit_id%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_revision_owner_fkey'
  ),
  'H1B1-STR-26 exact bounded line-revision decision-owner FK is restrictive'
);
select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and confrelid
        = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and pg_get_constraintdef(oid)
        like '%planning_quantity_policy_id, planning_quantity_policy_revision_id, unit_id%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_policy_revision_owner_fkey'
  ),
  'H1B1-STR-27 exact H1A policy root, revision, and Unit FK is restrictive'
);
select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and confrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and pg_get_constraintdef(oid)
        like '%confirmed_need_line_id, predecessor_decision_id%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_predecessor_fkey'
  ),
  'H1B1-STR-28 predecessor FK is same-line and restrictive'
);
select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and confrelid = 'atlas_core.actors'::regclass
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname
        = 'confirmed_need_line_decisions_decided_by_actor_fkey'
  ),
  'H1B1-STR-29 decided_by_actor_id FK to atlas_core.actors is restrictive'
);
select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and confrelid = 'atlas_core.command_receipts'::regclass
      and pg_get_constraintdef(oid) like '%FOREIGN KEY (command_id)%'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and conname = 'confirmed_need_line_decisions_command_fkey'
  ),
  'H1B1-STR-30 command_id FK to atlas_core.command_receipts(command_id) is restrictive'
);
select ok(
  (
    select contype = 'f'
      and confdeltype = 'r'
      and condeferrable
      and condeferred
      and confrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and pg_get_constraintdef(oid)
        like '%confirmed_need_line_id, current_confirmed_need_line_decision_id%'
    from pg_constraint
    where conrelid = 'atlas_planning.confirmed_need_lines'::regclass
      and conname = 'confirmed_need_lines_current_decision_fkey'
  ),
  'H1B1-STR-31 same-line current-pointer FK is restrictive, deferrable, and initially deferred'
);
select is(
  (
    select jsonb_build_object(
      'count', count(*),
      'restrictive', count(*) filter (where confdeltype = 'r'),
      'targets', to_jsonb(array_agg(
        confrelid::regclass::text
        order by conname
      ))
    )
    from pg_constraint
    where (
      conrelid = 'atlas_planning.confirmed_need_line_decisions'::regclass
      or (
        conrelid = 'atlas_planning.confirmed_need_lines'::regclass
        and conname = 'confirmed_need_lines_current_decision_fkey'
      )
    )
      and contype = 'f'
      and (
        conrelid = 'atlas_planning.confirmed_need_line_decisions'::regclass
        or conname = 'confirmed_need_lines_current_decision_fkey'
      )
  ),
  jsonb_build_object(
    'count', 7,
    'restrictive', 7,
    'targets', to_jsonb(
      array[
        'atlas_core.command_receipts',
        'atlas_core.actors',
        'atlas_planning.confirmed_need_lines',
        'atlas_planning.planning_quantity_policy_revisions',
        'atlas_planning.confirmed_need_line_decisions',
        'atlas_planning.confirmed_need_line_revisions',
        'atlas_planning.confirmed_need_line_decisions'
      ]::text[]
    )
  ),
  'H1B1-STR-32 the complete H1B1 FK catalog has no cascade or unapproved target'
);
select ok(
  (
    select pg_get_constraintdef(oid)
      = 'UNIQUE (confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, controlled_unit_id)'
    from pg_constraint
    where conrelid = 'atlas_planning.confirmed_need_lines'::regclass
      and conname = 'confirmed_need_lines_exact_owner_key'
  ),
  'H1B1-STR-33 existing confirmed_need_lines_exact_owner_key is reused unchanged'
);
select ok(
  (
    select pg_get_constraintdef(oid)
      = 'UNIQUE (confirmed_need_line_revision_id, confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, unit_id)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.confirmed_need_line_revisions'::regclass
      and conname = 'confirmed_need_line_revisions_decision_owner_key'
  ),
  'H1B1-STR-34 new confirmed_need_line_revisions_decision_owner_key has the exact bounded columns'
);
select ok(
  (
    select pg_get_constraintdef(oid)
      = 'UNIQUE (planning_quantity_policy_id, planning_quantity_policy_revision_id, unit_id)'
    from pg_constraint
    where conrelid
        = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_exact_owner_key'
  ),
  'H1B1-STR-35 existing planning_quantity_policy_revisions_exact_owner_key is reused unchanged'
);
select is(
  (
    select array_agg(ci.relname order by ci.relname)::text[]
    from pg_index as i
    join pg_class as ci on ci.oid = i.indexrelid
    where i.indrelid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and (i.indisprimary or i.indisunique)
  ),
  array[
    'confirmed_need_line_decisions_command_line_key',
    'confirmed_need_line_decisions_line_decision_number_key',
    'confirmed_need_line_decisions_line_id_decision_id_key',
    'confirmed_need_line_decisions_line_predecessor_key',
    'confirmed_need_line_decisions_pkey'
  ]::text[],
  'H1B1-STR-36 PK and four exact unique constraints own exactly five constraint indexes'
);
select ok(
  (
    select pg_get_indexdef(indexrelid)
      like '%(confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, unit_id)%'
    from pg_index
    where indexrelid
      = 'atlas_planning.confirmed_need_line_decisions_line_owner_idx'::regclass
  ),
  'H1B1-STR-37 stable-line owner FK-leading index is exact'
);
select ok(
  (
    select pg_get_indexdef(indexrelid)
      like '%(confirmed_need_line_revision_id, confirmed_need_line_id, confirmed_need_batch_id, source_kind, service_date, customer_id, school_id, delivery_location_id, ingredient_id, unit_id)%'
    from pg_index
    where indexrelid
      = 'atlas_planning.confirmed_need_line_decisions_revision_owner_idx'::regclass
  ),
  'H1B1-STR-38 revision-owner FK-leading index is exact'
);
select ok(
  (
    select pg_get_indexdef(indexrelid)
      like '%(planning_quantity_policy_id, planning_quantity_policy_revision_id, unit_id)%'
    from pg_index
    where indexrelid
      = 'atlas_planning.confirmed_need_line_decisions_policy_owner_idx'::regclass
  ),
  'H1B1-STR-39 policy-owner FK-leading index is exact'
);
select ok(
  (
    select pg_get_indexdef(indexrelid) like '%(decided_by_actor_id)%'
    from pg_index
    where indexrelid
      = 'atlas_planning.confirmed_need_line_decisions_decided_by_actor_idx'::regclass
  ),
  'H1B1-STR-40 decided-by actor FK-leading index is exact'
);
select ok(
  (
    select pg_get_indexdef(indexrelid)
        like '%(confirmed_need_line_id, current_confirmed_need_line_decision_id)%'
      and pg_get_expr(indpred, indrelid)
        = '(current_confirmed_need_line_decision_id IS NOT NULL)'
    from pg_index
    where indexrelid
      = 'atlas_planning.confirmed_need_lines_current_decision_idx'::regclass
  ),
  'H1B1-STR-41 non-null current-pointer partial index is exact'
);
select is(
  (
    select count(*)::integer
    from pg_index
    where indrelid
      = 'atlas_planning.confirmed_need_line_decisions'::regclass
  ),
  9,
  'H1B1-STR-42 chain, predecessor, and command unique indexes cover required paths without a redundant chain index'
);

select is(
  (
    select array_agg(proname order by proname)::text[]
    from pg_proc
    where pronamespace = 'atlas_planning'::regnamespace
      and proname like 'pa_06e_h1b1_confirmed_need_line%'
  ),
  array[
    'pa_06e_h1b1_confirmed_need_line_decision_guard',
    'pa_06e_h1b1_confirmed_need_line_decision_integrity',
    'pa_06e_h1b1_confirmed_need_line_pointer_guard'
  ]::text[],
  'H1B1-STR-43 exactly the three approved private H1B1 functions exist'
);
select is(
  (
    select count(*)::integer
    from pg_proc
    where pronamespace = 'atlas_planning'::regnamespace
      and proname like 'pa_06e_h1b1_confirmed_need_line%'
      and prorettype = 'trigger'::regtype
      and pronargs = 0
  ),
  3,
  'H1B1-STR-44 all three functions return trigger and have no overload'
);
select is(
  (
    select count(*)::integer
    from pg_proc
    where pronamespace = 'atlas_planning'::regnamespace
      and proname like 'pa_06e_h1b1_confirmed_need_line%'
      and pg_get_userbyid(proowner) = 'atlas_owner'
      and not prosecdef
      and coalesce(proconfig, array[]::text[]) @> array['search_path=""']
  ),
  3,
  'H1B1-STR-45 all functions are atlas_owner invokers with empty search_path'
);
select ok(
  not exists (
    select 1
    from pg_proc
    where pronamespace = 'atlas_planning'::regnamespace
      and proname like 'pa_06e_h1b1_confirmed_need_line%'
      and prosrc ~* '\mexecute\M'
  )
  and (
    select count(*)::integer
    from pg_proc
    where pronamespace = 'atlas_planning'::regnamespace
      and proname in (
        'pa_06e_h1b1_confirmed_need_line_pointer_guard',
        'pa_06e_h1b1_confirmed_need_line_decision_integrity'
      )
      and prosrc like '%atlas_planning.%'
  ) = 2
  and (
    select
      prosrc like
        '%from atlas_planning.planning_quantity_policies as policy%'
      and prosrc like
        '%where policy.planning_quantity_policy_id = v_policy_id%for update;%'
      and prosrc like
        '%order by decision.planning_quantity_policy_id%'
      and prosrc like
        '%order by line.confirmed_need_line_id%'
      and position(
        'from atlas_planning.planning_quantity_policies as policy'
        in prosrc
      ) < position(
        'from atlas_planning.confirmed_need_lines as line'
          || chr(10)
          || '    where line.confirmed_need_line_id = v_line_id'
          || chr(10)
          || '    for update;'
        in prosrc
      )
    from pg_proc
    where oid =
      'atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()'
        ::regprocedure
  ),
  'H1B1-STR-46 static qualified integrity locks the exact policy root before the stable line'
);
select is(
  (
    select count(*)::integer
    from pg_proc as p
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) as privilege
    left join pg_roles as role on role.oid = privilege.grantee
    where p.pronamespace = 'atlas_planning'::regnamespace
      and p.proname like 'pa_06e_h1b1_confirmed_need_line%'
      and privilege.privilege_type = 'EXECUTE'
      and (
        privilege.grantee = 0
        or role.rolname in (
          'anon',
          'authenticated',
          'service_role',
          'atlas_command_runtime',
          'atlas_confirmed_need_review_runtime',
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
          'atlas_planning_command_runtime',
          'atlas_planning_materialization_runtime',
          'atlas_procurement_command_runtime',
          'atlas_read_runtime'
        )
      )
  ),
  0,
  'H1B1-STR-47 PUBLIC, API, service, and every runtime role execute zero H1B1 functions'
);
select is(
  (
    select array_agg(
      format('%s.%s|%s', n.nspname, c.relname, t.tgname)
      order by t.tgname
    )::text[]
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    join pg_namespace as n on n.oid = c.relnamespace
    where not t.tgisinternal
      and t.tgname like '%h1b1%'
  ),
  array[
    'atlas_planning.confirmed_need_line_decisions|confirmed_need_line_decisions_h1b1_guard',
    'atlas_planning.confirmed_need_line_decisions|confirmed_need_line_decisions_h1b1_integrity',
    'atlas_planning.planning_quantity_policy_revisions|confirmed_need_line_decisions_h1b1_policy_integrity',
    'atlas_planning.confirmed_need_line_revisions|confirmed_need_line_revisions_h1b1_decision_integrity',
    'atlas_planning.confirmed_need_lines|confirmed_need_lines_h1b1_decision_integrity',
    'atlas_planning.confirmed_need_lines|confirmed_need_lines_h1b1_pointer_guard'
  ]::text[],
  'H1B1-STR-48 exactly six proposed trigger names exist on the exact four relations'
);
select ok(
  (
    select c.relname = 'confirmed_need_line_decisions'
      and not t.tgdeferrable
      and pg_get_triggerdef(t.oid) like '%BEFORE DELETE OR UPDATE%'
      and pg_get_triggerdef(t.oid)
        like '%pa_06e_h1b1_confirmed_need_line_decision_guard()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname = 'confirmed_need_line_decisions_h1b1_guard'
      and not t.tgisinternal
  ),
  'H1B1-STR-49 decision ordinary guard has exact BEFORE UPDATE OR DELETE events and function'
);
select ok(
  (
    select c.relname = 'confirmed_need_lines'
      and not t.tgdeferrable
      and pg_get_triggerdef(t.oid)
        like '%BEFORE INSERT OR UPDATE OF current_confirmed_need_line_decision_id%'
      and pg_get_triggerdef(t.oid)
        like '%pa_06e_h1b1_confirmed_need_line_pointer_guard()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname = 'confirmed_need_lines_h1b1_pointer_guard'
      and not t.tgisinternal
  ),
  'H1B1-STR-50 pointer ordinary guard has exact BEFORE INSERT OR pointer UPDATE events and function'
);
select ok(
  (
    select c.relname = 'confirmed_need_line_decisions'
      and pg_get_triggerdef(t.oid) like '%AFTER INSERT OR UPDATE%'
      and pg_get_triggerdef(t.oid)
        like '%pa_06e_h1b1_confirmed_need_line_decision_integrity()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname = 'confirmed_need_line_decisions_h1b1_integrity'
      and not t.tgisinternal
  ),
  'H1B1-STR-51 decision integrity trigger has exact AFTER INSERT OR UPDATE event and function'
);
select ok(
  (
    select c.relname = 'confirmed_need_lines'
      and pg_get_triggerdef(t.oid) like '%AFTER INSERT OR UPDATE%'
      and pg_get_triggerdef(t.oid)
        like '%pa_06e_h1b1_confirmed_need_line_decision_integrity()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname = 'confirmed_need_lines_h1b1_decision_integrity'
      and not t.tgisinternal
  ),
  'H1B1-STR-52 stable-line integrity trigger has exact AFTER INSERT OR UPDATE event and function'
);
select ok(
  (
    select c.relname = 'confirmed_need_line_revisions'
      and pg_get_triggerdef(t.oid) like '%AFTER INSERT OR UPDATE%'
      and pg_get_triggerdef(t.oid)
        like '%pa_06e_h1b1_confirmed_need_line_decision_integrity()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname
      = 'confirmed_need_line_revisions_h1b1_decision_integrity'
      and not t.tgisinternal
  ),
  'H1B1-STR-53 line-revision integrity trigger has exact AFTER INSERT OR UPDATE event and function'
);
select ok(
  (
    select c.relname = 'planning_quantity_policy_revisions'
      and pg_get_triggerdef(t.oid) like '%AFTER INSERT OR UPDATE%'
      and pg_get_triggerdef(t.oid)
        like '%pa_06e_h1b1_confirmed_need_line_decision_integrity()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname
      = 'confirmed_need_line_decisions_h1b1_policy_integrity'
      and not t.tgisinternal
  ),
  'H1B1-STR-54 policy-revision integrity trigger has exact AFTER INSERT OR UPDATE event and function'
);
select is(
  (
    select count(*)::integer
    from pg_trigger
    where tgname in (
      'confirmed_need_line_decisions_h1b1_integrity',
      'confirmed_need_lines_h1b1_decision_integrity',
      'confirmed_need_line_revisions_h1b1_decision_integrity',
      'confirmed_need_line_decisions_h1b1_policy_integrity'
    )
      and not tgisinternal
      and tgdeferrable
      and tginitdeferred
  ),
  4,
  'H1B1-STR-55 the four integrity triggers are constraint triggers, deferrable, and initially deferred'
);
select is(
  (
    select pg_get_userbyid(relowner)
    from pg_class
    where oid = 'atlas_planning.confirmed_need_line_decisions'::regclass
  ),
  'atlas_owner',
  'H1B1-STR-56 atlas_owner owns the new relation'
);
select ok(
  (
    select relrowsecurity and relforcerowsecurity
    from pg_class
    where oid = 'atlas_planning.confirmed_need_line_decisions'::regclass
  ),
  'H1B1-STR-57 the new relation has RLS enabled and forced'
);
select is(
  (
    select count(*)::integer
    from pg_policy
    where polrelid
      = 'atlas_planning.confirmed_need_line_decisions'::regclass
  ),
  2,
  'H1B1-STR-58 the decision relation has exact RMVP-05 read and insert policies'
);
select ok(
  not exists (
    select 1
    from pg_class as c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) as privilege
    left join pg_roles as role on role.oid = privilege.grantee
    where c.oid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and (
        privilege.grantee = 0
        or role.rolname in (
          'anon',
          'authenticated',
          'service_role',
          'atlas_command_runtime',
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
          'atlas_planning_command_runtime',
          'atlas_planning_materialization_runtime',
          'atlas_procurement_command_runtime',
          'atlas_read_runtime'
        )
      )
  )
  and not exists (
    select 1
    from pg_proc as p
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) as privilege
    left join pg_roles as role on role.oid = privilege.grantee
    where p.pronamespace = 'atlas_planning'::regnamespace
      and p.proname like 'pa_06e_h1b1_confirmed_need_line%'
      and (
        privilege.grantee = 0
        or role.rolname in (
          'anon',
          'authenticated',
          'service_role',
          'atlas_command_runtime',
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
          'atlas_planning_command_runtime',
          'atlas_planning_materialization_runtime',
          'atlas_procurement_command_runtime',
          'atlas_read_runtime'
        )
      )
  )
  and
  (
    select count(*) = 2
    from pg_class as c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) as privilege
    join pg_roles as role on role.oid = privilege.grantee
    where c.oid
        = 'atlas_planning.confirmed_need_line_decisions'::regclass
      and role.rolname = 'atlas_confirmed_need_review_runtime'
      and privilege.privilege_type in ('SELECT', 'INSERT')
  ),
  'H1B1-STR-59 only the dedicated RMVP-05 runtime receives exact SELECT and INSERT while decision functions remain private'
);
select ok(
  to_regclass('public.confirmed_need_line_decisions') is null
  and to_regclass('ops_v2.confirmed_need_line_decisions') is null
  and not exists (
    select 1
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'S'
      and c.relname like '%line_decision%'
  ),
  'H1B1-STR-60 no public, OPS v1/v2, sequence, or copied legacy decision object exists'
);
select is(
  jsonb_build_object(
    'roles',
    (select count(*) from pg_roles where rolname like '%h1b1%'),
    'capabilities',
    (
      select count(*)
      from atlas_core.capabilities
      where capability_code like '%decision%'
    ),
    'api_functions',
    (
      select count(*)
      from pg_proc
      where pronamespace = 'atlas_api'::regnamespace
        and proname like '%decision%'
    ),
    'api_total',
    (
      select count(*)
      from pg_proc
      where pronamespace = 'atlas_api'::regnamespace
    ),
    'rmvp_03b_api_names',
    (
      select array_agg(proname order by proname)::text[]
      from pg_proc
      where pronamespace = 'atlas_api'::regnamespace
        and proname in (
          'evaluate_planning_input_readiness',
          'get_planning_input_readiness_workbench',
          'invalidate_planning_input_readiness',
          'request_planning_input_need_generation'
        )
    ),
    'views',
    (
      select count(*)
      from pg_class as c
      join pg_namespace as n on n.oid = c.relnamespace
      where n.nspname like 'atlas\_%' escape '\'
        and c.relkind in ('v', 'm')
        and c.relname like '%decision%'
    )
  ),
  jsonb_build_object(
    'roles', 0,
    'capabilities', 0,
    'api_functions', 0,
    'api_total', 76,
    'rmvp_03b_api_names', array[
      'evaluate_planning_input_readiness',
      'get_planning_input_readiness_workbench',
      'invalidate_planning_input_readiness',
      'request_planning_input_need_generation'
    ]::text[],
    'views', 0
  ),
  'H1B1-STR-61 H1B1 retains no own role, capability, API, or view while the current RMVP-05 API catalog retains the four approved RMVP-03B APIs'
);
select ok(
  not exists (
    select 1
    from atlas_planning.confirmed_need_line_decisions
  )
  and not exists (
    select 1
    from atlas_planning.confirmed_need_lines
    where current_confirmed_need_line_decision_id is not null
  ),
  'H1B1-STR-62 the decision relation is seedless and every pre-H1B1 line pointer is null'
);
select ok(
  not exists (
    select 1
    from pg_extension
    where extname like '%decision%'
  )
  and not exists (
    select 1
    from pg_proc
    where pronamespace = 'atlas_planning'::regnamespace
      and proname like 'pa_06e_h1b1%'
      and proname not in (
        'pa_06e_h1b1_confirmed_need_line_decision_guard',
        'pa_06e_h1b1_confirmed_need_line_pointer_guard',
        'pa_06e_h1b1_confirmed_need_line_decision_integrity'
      )
  ),
  'H1B1-STR-63 no extension, resolver, generic helper, conversion, or fallback object exists'
);
select is(
  jsonb_build_object(
    'relations',
    (
      select count(*)
      from pg_class
      where relnamespace = 'atlas_planning'::regnamespace
        and relkind = 'r'
        and relname = 'confirmed_need_line_decisions'
    ),
    'pointer_columns',
    (
      select count(*)
      from information_schema.columns
      where table_schema = 'atlas_planning'
        and table_name = 'confirmed_need_lines'
        and column_name = 'current_confirmed_need_line_decision_id'
    ),
    'functions',
    (
      select count(*)
      from pg_proc
      where pronamespace = 'atlas_planning'::regnamespace
        and proname like 'pa_06e_h1b1_confirmed_need_line%'
    ),
    'triggers',
    (
      select count(*)
      from pg_trigger
      where not tgisinternal
        and tgname like '%h1b1%'
    )
  ),
  jsonb_build_object(
    'relations', 1,
    'pointer_columns', 1,
    'functions', 3,
    'triggers', 6
  ),
  'H1B1-STR-64 the executable scope is exactly +1 relation, +1 column, +3 functions, and +6 triggers'
);

select * from finish();

rollback;
