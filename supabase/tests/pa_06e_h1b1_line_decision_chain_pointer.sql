begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(48);

-- Compact authoritative fixture. Replica mode is limited to arranging the
-- pre-H1B1 batch/line/revision state; every H1B1 assertion runs with triggers.
set local session_replication_role = replica;

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('c7100000-0000-0000-0000-000000000001', 'HUMAN', 'H1B1 chain planner'),
  ('c7100000-0000-0000-0000-000000000002', 'HUMAN', 'H1B1 other planner');
insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'c7100000-0000-0000-0000-000000000010',
  'h1b1-chain-customer',
  'H1B1 chain customer',
  'SCHOOL_CATERING'
);
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values (
  'c7100000-0000-0000-0000-000000000011',
  'c7100000-0000-0000-0000-000000000010',
  'h1b1-chain-location',
  'H1B1 chain location',
  'Local-only fixture'
);
insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'c7100000-0000-0000-0000-000000000012',
  'h1b1-chain-type',
  'H1B1 chain type'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id
) values (
  'c7100000-0000-0000-0000-000000000013',
  'c7100000-0000-0000-0000-000000000010',
  'h1b1-chain-school',
  'H1B1 chain school',
  'c7100000-0000-0000-0000-000000000012',
  'c7100000-0000-0000-0000-000000000011'
);
insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code
) values (
  'c7100000-0000-0000-0000-000000000014',
  'h1b1-chain-kg',
  'H1B1 chain kilogram',
  'MASS'
);
insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name
) values
  (
    'c7100000-0000-0000-0000-000000000015',
    'h1b1-chain-rice',
    'H1B1 chain rice'
  ),
  (
    'c7100000-0000-0000-0000-000000000016',
    'h1b1-chain-oil',
    'H1B1 chain oil'
  ),
  (
    'c7100000-0000-0000-0000-000000000017',
    'h1b1-chain-salt',
    'H1B1 chain salt'
  );

insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id, period_start, period_end, batch_status, version,
  created_by_actor_id, source_kind, origin_need_generation_run_id,
  origin_need_generation_run_version,
  origin_need_generation_release_snapshot_id, current_need_generation_run_id,
  current_need_generation_run_version,
  current_need_generation_release_snapshot_id
) values (
  'c7100000-0000-0000-0000-000000000500',
  date '2026-07-22',
  date '2026-07-22',
  'DRAFT_REVIEW',
  1,
  'c7100000-0000-0000-0000-000000000001',
  'NEED_GENERATION',
  'c7100000-0000-0000-0000-000000000100',
  1,
  'c7100000-0000-0000-0000-000000000190',
  'c7100000-0000-0000-0000-000000000100',
  1,
  'c7100000-0000-0000-0000-000000000190'
);
insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id, confirmed_need_batch_id, wholesale_order_line_id,
  source_kind, service_date, customer_id, school_id, delivery_location_id,
  ingredient_id, controlled_unit_id
) values
  (
    'c7100000-0000-0000-0000-000000000510',
    'c7100000-0000-0000-0000-000000000500',
    null,
    'NEED_GENERATION',
    date '2026-07-22',
    'c7100000-0000-0000-0000-000000000010',
    'c7100000-0000-0000-0000-000000000013',
    'c7100000-0000-0000-0000-000000000011',
    'c7100000-0000-0000-0000-000000000015',
    'c7100000-0000-0000-0000-000000000014'
  ),
  (
    'c7100000-0000-0000-0000-000000000511',
    'c7100000-0000-0000-0000-000000000500',
    null,
    'NEED_GENERATION',
    date '2026-07-22',
    'c7100000-0000-0000-0000-000000000010',
    'c7100000-0000-0000-0000-000000000013',
    'c7100000-0000-0000-0000-000000000011',
    'c7100000-0000-0000-0000-000000000016',
    'c7100000-0000-0000-0000-000000000014'
  ),
  (
    'c7100000-0000-0000-0000-000000000512',
    'c7100000-0000-0000-0000-000000000500',
    null,
    'NEED_GENERATION',
    date '2026-07-22',
    'c7100000-0000-0000-0000-000000000010',
    'c7100000-0000-0000-0000-000000000013',
    'c7100000-0000-0000-0000-000000000011',
    'c7100000-0000-0000-0000-000000000017',
    'c7100000-0000-0000-0000-000000000014'
  );
insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id, confirmed_need_line_id, revision_number,
  wholesale_order_line_revision_id, ingredient_id, theoretical_quantity,
  confirmed_quantity, unit_id, revision_status, is_current,
  predecessor_revision_id, command_id, created_by_actor_id, source_kind,
  confirmed_need_batch_id, need_generation_run_id,
  need_generation_run_version, need_generation_release_snapshot_id,
  service_date, customer_id, school_id, delivery_location_id
) values
  (
    'c7100000-0000-0000-0000-000000000520',
    'c7100000-0000-0000-0000-000000000510',
    1, null, 'c7100000-0000-0000-0000-000000000015', 10, 10,
    'c7100000-0000-0000-0000-000000000014', 'DRAFT', true, null, null,
    'c7100000-0000-0000-0000-000000000001', 'NEED_GENERATION',
    'c7100000-0000-0000-0000-000000000500',
    'c7100000-0000-0000-0000-000000000100', 1,
    'c7100000-0000-0000-0000-000000000190', date '2026-07-22',
    'c7100000-0000-0000-0000-000000000010',
    'c7100000-0000-0000-0000-000000000013',
    'c7100000-0000-0000-0000-000000000011'
  ),
  (
    'c7100000-0000-0000-0000-000000000521',
    'c7100000-0000-0000-0000-000000000511',
    1, null, 'c7100000-0000-0000-0000-000000000016', 10, 10,
    'c7100000-0000-0000-0000-000000000014', 'DRAFT', true, null, null,
    'c7100000-0000-0000-0000-000000000001', 'NEED_GENERATION',
    'c7100000-0000-0000-0000-000000000500',
    'c7100000-0000-0000-0000-000000000100', 1,
    'c7100000-0000-0000-0000-000000000190', date '2026-07-22',
    'c7100000-0000-0000-0000-000000000010',
    'c7100000-0000-0000-0000-000000000013',
    'c7100000-0000-0000-0000-000000000011'
  ),
  (
    'c7100000-0000-0000-0000-000000000522',
    'c7100000-0000-0000-0000-000000000512',
    1, null, 'c7100000-0000-0000-0000-000000000017', 10, 10,
    'c7100000-0000-0000-0000-000000000014', 'DRAFT', true, null, null,
    'c7100000-0000-0000-0000-000000000001', 'NEED_GENERATION',
    'c7100000-0000-0000-0000-000000000500',
    'c7100000-0000-0000-0000-000000000100', 1,
    'c7100000-0000-0000-0000-000000000190', date '2026-07-22',
    'c7100000-0000-0000-0000-000000000010',
    'c7100000-0000-0000-0000-000000000013',
    'c7100000-0000-0000-0000-000000000011'
  );

set local session_replication_role = origin;

-- The compact fixture intentionally omits the full H0B1b generation graph.
-- Keep its line-source recheck out of scope while all H1B1 guards stay active.
alter table atlas_planning.confirmed_need_lines
  disable trigger confirmed_need_lines_current_source_consistency;

insert into atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id, unit_id, created_by_actor_id, created_at
) values (
  'c7100000-0000-0000-0000-000000000700',
  'c7100000-0000-0000-0000-000000000014',
  'c7100000-0000-0000-0000-000000000001',
  timestamptz '2020-01-01 08:00:00+07'
);
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, planning_step, effective_from, created_by_actor_id, created_at
) values (
  'c7100000-0000-0000-0000-000000000701',
  'c7100000-0000-0000-0000-000000000700',
  'c7100000-0000-0000-0000-000000000014',
  1, 0.01, date '2020-01-01',
  'c7100000-0000-0000-0000-000000000001',
  timestamptz '2020-01-01 08:00:00+07'
);
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'c7100000-0000-0000-0000-000000000001',
  approved_at = timestamptz '2020-01-01 09:00:00+07',
  activated_by_actor_id = 'c7100000-0000-0000-0000-000000000001',
  activated_at = timestamptz '2020-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'c7100000-0000-0000-0000-000000000701';
set constraints all immediate;
set constraints all deferred;

insert into atlas_core.command_receipts (
  command_receipt_id, command_name, scope_key, idempotency_key, command_id,
  correlation_id, actor_id, expected_version, request_hash, outcome,
  completed_at
)
select
  (
    'c7110000-0000-0000-0000-' || lpad(ordinal::text, 12, '0')
  )::uuid,
  'pa_06e_h1b1_test',
  'confirmed-need-line-chain',
  'h1b1-chain-' || ordinal,
  (
    'c7120000-0000-0000-0000-' || lpad(ordinal::text, 12, '0')
  )::uuid,
  (
    'c7130000-0000-0000-0000-' || lpad(ordinal::text, 12, '0')
  )::uuid,
  case
    when ordinal = 21
      then 'c7100000-0000-0000-0000-000000000002'::uuid
    else 'c7100000-0000-0000-0000-000000000001'::uuid
  end,
  1,
  repeat('a', 64),
  case when ordinal = 20 then 'IN_PROGRESS' else 'COMPLETED' end,
  case
    when ordinal = 20 then null
    else timestamptz '2026-07-22 09:00:00+07'
  end
from generate_series(1, 30) as ordinal;

create function pg_temp.h1b1_chain_decide(
  p_decision uuid,
  p_line uuid default 'c7100000-0000-0000-0000-000000000510',
  p_revision uuid default 'c7100000-0000-0000-0000-000000000520',
  p_number bigint default 1,
  p_predecessor uuid default null,
  p_kind text default 'UNCHANGED_PROPOSAL_ACCEPTED',
  p_theoretical numeric default 10,
  p_proposed numeric default 10,
  p_after numeric default 10,
  p_ticks numeric default 1000,
  p_reason text default 'PROPOSAL_ACCEPTED',
  p_note text default null,
  p_actor uuid default 'c7100000-0000-0000-0000-000000000001',
  p_command_ordinal integer default 1,
  p_batch_version bigint default 1,
  p_make_current boolean default true
) returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_decision_id, confirmed_need_batch_id,
    confirmed_need_line_id, confirmed_need_line_revision_id, source_kind,
    service_date, customer_id, school_id, delivery_location_id, ingredient_id,
    unit_id, decision_number, predecessor_decision_id, decision_kind,
    planning_quantity_policy_id, planning_quantity_policy_revision_id,
    theoretical_quantity_before, proposed_quantity_before,
    confirmed_quantity_after, planning_tick_count, reason_code, reason_note,
    decided_by_actor_id, decided_at, command_id,
    confirmed_need_batch_version, created_at
  )
  select
    p_decision, line.confirmed_need_batch_id, line.confirmed_need_line_id,
    p_revision, line.source_kind, line.service_date, line.customer_id,
    line.school_id, line.delivery_location_id, line.ingredient_id,
    line.controlled_unit_id, p_number, p_predecessor, p_kind,
    'c7100000-0000-0000-0000-000000000700',
    'c7100000-0000-0000-0000-000000000701',
    p_theoretical, p_proposed, p_after, p_ticks, p_reason, p_note, p_actor,
    timestamptz '2026-07-22 09:00:00+07',
    (
      'c7120000-0000-0000-0000-'
      || lpad(p_command_ordinal::text, 12, '0')
    )::uuid,
    p_batch_version,
    timestamptz '2026-07-22 09:00:00+07'
  from atlas_planning.confirmed_need_lines as line
  where line.confirmed_need_line_id = p_line;

  if p_make_current then
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id = p_decision
    where confirmed_need_line_id = p_line;
  end if;

  set constraints all immediate;
  set constraints all deferred;
end;
$$;

select is(
  (
    select count(*)::integer
    from atlas_planning.confirmed_need_line_decisions
  ),
  0,
  'H1B1-CHN-01 zero decisions with null pointers remains valid'
);
select lives_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      'c7100000-0000-0000-0000-000000000801'
    )
  $$,
  'H1B1-CHN-02 first unchanged decision and pointer commit atomically'
);
select is(
  (
    select row(decision_number, predecessor_decision_id)
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000801'
  ),
  row(1::bigint, null::uuid),
  'H1B1-CHN-03 first decision is number one with no predecessor'
);
select is(
  (
    select current_confirmed_need_line_decision_id
    from atlas_planning.confirmed_need_lines
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  ),
  'c7100000-0000-0000-0000-000000000801'::uuid,
  'H1B1-CHN-04 stable-line pointer owns the first decision'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.confirmed_need_line_revisions
    where confirmed_need_line_id
        = 'c7100000-0000-0000-0000-000000000510'
      and command_id = 'c7120000-0000-0000-0000-000000000001'
  ),
  0,
  'H1B1-CHN-05 unchanged acceptance creates no command-authored successor revision'
);
select ok(
  (
    select
      decided_by_actor_id
        = 'c7100000-0000-0000-0000-000000000001'
      and decided_at = timestamptz '2026-07-22 09:00:00+07'
      and command_id = 'c7120000-0000-0000-0000-000000000001'
      and confirmed_need_batch_version = 1
      and created_at = timestamptz '2026-07-22 09:00:00+07'
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000801'
  ),
  'H1B1-CHN-06 decision retains actor, time, command, batch-version, and creation evidence'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000807',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_number => 2,
      p_predecessor => 'c7100000-0000-0000-0000-000000000801',
      p_note => 'invalid first numbering',
      p_command_ordinal => 3
    )
  $$,
  '23503',
  null,
  'H1B1-CHN-07 a first decision numbered above one is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000808',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_predecessor => 'c7100000-0000-0000-0000-000000000801',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-08 a first decision with a predecessor is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000809',
      p_number => 2,
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-09 a later decision without a predecessor is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000810',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000801',
      p_note => 'skipped successor',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-10 a skipped successor number is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000811',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_number => 2,
      p_predecessor => 'c7100000-0000-0000-0000-000000000801',
      p_note => 'cross-line predecessor',
      p_command_ordinal => 3
    )
  $$,
  '23503',
  null,
  'H1B1-CHN-11 a cross-line predecessor is rejected'
);

select pg_temp.h1b1_chain_decide(
  p_decision => 'c7100000-0000-0000-0000-000000000802',
  p_number => 2,
  p_predecessor => 'c7100000-0000-0000-0000-000000000801',
  p_note => 'corrected decision evidence',
  p_command_ordinal => 2
);

select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000812',
      p_number => 2,
      p_predecessor => 'c7100000-0000-0000-0000-000000000801',
      p_note => 'fork',
      p_command_ordinal => 3
    )
  $$,
  '23505',
  null,
  'H1B1-CHN-12 a second successor fork is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000813',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => 'duplicate command',
      p_command_ordinal => 2
    )
  $$,
  '23505',
  null,
  'H1B1-CHN-13 a second decision for the same line and command is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000814',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => 'incomplete receipt',
      p_command_ordinal => 20
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-14 an incomplete command receipt is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000815',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => 'actor mismatch',
      p_command_ordinal => 21
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-15 command-receipt actor mismatch is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000816',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => 'wrong batch version',
      p_command_ordinal => 3,
      p_batch_version => 2
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-16 a newly current decision with the wrong batch version is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000817',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_kind => 'UNKNOWN',
      p_note => 'unknown kind',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-17 an unknown decision kind is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000818',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_reason => 'UNKNOWN',
      p_note => 'unknown reason',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-18 an unknown reason code is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000819',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_kind => 'ADJUSTED_QUANTITY_CONFIRMED',
      p_after => 9.99,
      p_ticks => 999,
      p_reason => 'PROPOSAL_ACCEPTED',
      p_note => 'wrong reason family',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-19 PROPOSAL_ACCEPTED on an adjusted decision is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000820',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_reason => 'PLANNING_STEP_ADJUSTMENT',
      p_note => 'wrong reason family',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-20 an adjustment reason on unchanged acceptance is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000821',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_note => 'first unchanged note',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-21 a first unchanged decision cannot carry a correction note'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000822',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_kind => 'ADJUSTED_QUANTITY_CONFIRMED',
      p_after => 9.99,
      p_ticks => 999,
      p_reason => 'OPERATIONAL_QUANTITY_ADJUSTMENT',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-22 operational adjustment without a note is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000823',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_kind => 'ADJUSTED_QUANTITY_CONFIRMED',
      p_after => 9.99,
      p_ticks => 999,
      p_reason => 'OTHER',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-23 OTHER without a note is rejected'
);

set local session_replication_role = replica;
update atlas_planning.confirmed_need_line_revisions
set is_current = false, revision_status = 'SUPERSEDED'
where confirmed_need_line_revision_id
  = 'c7100000-0000-0000-0000-000000000521';
insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id, confirmed_need_line_id, revision_number,
  wholesale_order_line_revision_id, ingredient_id, theoretical_quantity,
  confirmed_quantity, unit_id, revision_status, is_current,
  predecessor_revision_id, command_id, created_by_actor_id, source_kind,
  confirmed_need_batch_id, need_generation_run_id,
  need_generation_run_version, need_generation_release_snapshot_id,
  service_date, customer_id, school_id, delivery_location_id
) select
  'c7100000-0000-0000-0000-000000000524',
  confirmed_need_line_id, 2, wholesale_order_line_revision_id, ingredient_id,
  theoretical_quantity, 9.99, unit_id, 'DRAFT', true,
  confirmed_need_line_revision_id,
  'c7120000-0000-0000-0000-000000000024',
  created_by_actor_id, source_kind, confirmed_need_batch_id,
  need_generation_run_id, need_generation_run_version,
  need_generation_release_snapshot_id, service_date, customer_id, school_id,
  delivery_location_id
from atlas_planning.confirmed_need_line_revisions
where confirmed_need_line_revision_id
  = 'c7100000-0000-0000-0000-000000000521';
set local session_replication_role = origin;

select lives_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000824',
      p_line => 'c7100000-0000-0000-0000-000000000511',
      p_revision => 'c7100000-0000-0000-0000-000000000524',
      p_kind => 'ADJUSTED_QUANTITY_CONFIRMED',
      p_after => 9.99,
      p_ticks => 999,
      p_reason => 'PLANNING_STEP_ADJUSTMENT',
      p_command_ordinal => 24
    )
  $$,
  'H1B1-CHN-24 Planning-step adjustment permits an omitted note'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000825',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => '',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-25 a blank reason note is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000826',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => ' untrimmed ',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-26 an untrimmed reason note is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000827',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_note => repeat('đ', 501),
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-27 a reason note above 500 Unicode characters is rejected'
);
select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000828',
      p_number => 3,
      p_predecessor => 'c7100000-0000-0000-0000-000000000802',
      p_command_ordinal => 3
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-28 a replacement without a correction note is rejected'
);
select ok(
  (
    select
      confirmed_need_line_revision_id
        = 'c7100000-0000-0000-0000-000000000520'
      and reason_code = 'PROPOSAL_ACCEPTED'
      and reason_note = 'corrected decision evidence'
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000802'
  ),
  'H1B1-CHN-29 unchanged replacement may bind the same revision with a correction note'
);
select ok(
  (
    select
      decision_number = 2
      and predecessor_decision_id
        = 'c7100000-0000-0000-0000-000000000801'
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000802'
  ),
  'H1B1-CHN-30 replacement number and predecessor are the exact direct successor'
);
select ok(
  (
    select count(*) = 2
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
      and (
        confirmed_need_line_decision_id
          = 'c7100000-0000-0000-0000-000000000801'
        or predecessor_decision_id
          = 'c7100000-0000-0000-0000-000000000801'
      )
  ),
  'H1B1-CHN-31 predecessor evidence remains retained beside its successor'
);
select is(
  (
    select current_confirmed_need_line_decision_id
    from atlas_planning.confirmed_need_lines
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  ),
  'c7100000-0000-0000-0000-000000000802'::uuid,
  'H1B1-CHN-32 pointer is the unique chain tip'
);
select throws_ok(
  $$
    update atlas_planning.confirmed_need_line_decisions
    set reason_note = 'mutated'
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000801'
  $$,
  '23514',
  'Confirmed Need line decisions are immutable',
  'H1B1-CHN-33 decision UPDATE is rejected'
);
select throws_ok(
  $$
    delete from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000801'
  $$,
  '23514',
  'Confirmed Need line decisions cannot be deleted',
  'H1B1-CHN-34 decision DELETE is rejected'
);
select throws_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id = null
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  $$,
  '23514',
  null,
  'H1B1-CHN-35 clearing a nonnull pointer is rejected'
);
select throws_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000824'
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  $$,
  '23514',
  null,
  'H1B1-CHN-36 a cross-line pointer is rejected'
);

set local session_replication_role = replica;
insert into atlas_planning.confirmed_need_line_decisions
select
  'c7100000-0000-0000-0000-000000000837',
  confirmed_need_batch_id, confirmed_need_line_id,
  confirmed_need_line_revision_id, source_kind, service_date, customer_id,
  school_id, delivery_location_id, ingredient_id, unit_id, 3,
  'c7100000-0000-0000-0000-000000009999',
  decision_kind, planning_quantity_policy_id,
  planning_quantity_policy_revision_id, theoretical_quantity_before,
  proposed_quantity_before, confirmed_quantity_after, planning_tick_count,
  reason_code, 'lateral fixture', decided_by_actor_id, decided_at,
  'c7120000-0000-0000-0000-000000000003',
  confirmed_need_batch_version, created_at
from atlas_planning.confirmed_need_line_decisions
where confirmed_need_line_decision_id
  = 'c7100000-0000-0000-0000-000000000802';
insert into atlas_planning.confirmed_need_line_decisions
select
  'c7100000-0000-0000-0000-000000000839',
  confirmed_need_batch_id, confirmed_need_line_id,
  confirmed_need_line_revision_id, source_kind, service_date, customer_id,
  school_id, delivery_location_id, ingredient_id, unit_id, 9,
  'c7100000-0000-0000-0000-000000000802',
  decision_kind, planning_quantity_policy_id,
  planning_quantity_policy_revision_id, theoretical_quantity_before,
  proposed_quantity_before, confirmed_quantity_after, planning_tick_count,
  reason_code, 'jump fixture', decided_by_actor_id, decided_at,
  'c7120000-0000-0000-0000-000000000004',
  confirmed_need_batch_version, created_at
from atlas_planning.confirmed_need_line_decisions
where confirmed_need_line_decision_id
  = 'c7100000-0000-0000-0000-000000000802';
set local session_replication_role = origin;

select throws_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000837'
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  $$,
  '23514',
  null,
  'H1B1-CHN-37 a lateral same-line pointer move is rejected'
);
select throws_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000801'
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  $$,
  '23514',
  null,
  'H1B1-CHN-38 rolling the pointer back to an ancestor is rejected'
);
select throws_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000839'
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  $$,
  '23514',
  null,
  'H1B1-CHN-39 jumping the pointer over a direct successor is rejected'
);

set local session_replication_role = replica;
delete from atlas_planning.confirmed_need_line_decisions
where confirmed_need_line_decision_id in (
  'c7100000-0000-0000-0000-000000000837',
  'c7100000-0000-0000-0000-000000000839'
);
set local session_replication_role = origin;

select throws_ok(
  $$
    select pg_temp.h1b1_chain_decide(
      p_decision => 'c7100000-0000-0000-0000-000000000840',
      p_line => 'c7100000-0000-0000-0000-000000000512',
      p_revision => 'c7100000-0000-0000-0000-000000000522',
      p_command_ordinal => 3,
      p_make_current => false
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-40 a decision left without an atomic current pointer is rejected'
);

alter table atlas_planning.confirmed_need_lines
  disable trigger confirmed_need_lines_h1b1_pointer_guard;
alter table atlas_planning.confirmed_need_lines
  disable trigger confirmed_need_lines_h1b1_decision_integrity;
select throws_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000009999'
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000512';
    set constraints all immediate
  $$,
  '23503',
  null,
  'H1B1-CHN-41 the deferred pointer foreign key rejects a nonexistent decision'
);
alter table atlas_planning.confirmed_need_lines
  enable trigger confirmed_need_lines_h1b1_pointer_guard;
alter table atlas_planning.confirmed_need_lines
  enable trigger confirmed_need_lines_h1b1_decision_integrity;
set constraints all deferred;

select throws_ok(
  $$
    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_line_id, confirmed_need_batch_id,
      wholesale_order_line_id, source_kind, service_date, customer_id,
      school_id, delivery_location_id, ingredient_id, controlled_unit_id,
      current_confirmed_need_line_decision_id
    ) values (
      'c7100000-0000-0000-0000-000000000542',
      'c7100000-0000-0000-0000-000000000500',
      null, 'NEED_GENERATION', date '2026-07-23',
      'c7100000-0000-0000-0000-000000000010',
      'c7100000-0000-0000-0000-000000000013',
      'c7100000-0000-0000-0000-000000000011',
      'c7100000-0000-0000-0000-000000000017',
      'c7100000-0000-0000-0000-000000000014',
      'c7100000-0000-0000-0000-000000000801'
    )
  $$,
  '23514',
  null,
  'H1B1-CHN-42 a new stable line cannot begin with decision authority'
);
select lives_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id = null
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000512'
  $$,
  'H1B1-CHN-43 an unrelated update on a null-pointer line remains allowed'
);
select lives_ok(
  $$
    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000802'
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  $$,
  'H1B1-CHN-44 an unrelated update retaining the same pointer remains allowed'
);
select ok(
  (
    select
      reason_code = 'PROPOSAL_ACCEPTED'
      and reason_note = 'corrected decision evidence'
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_decision_id
      = 'c7100000-0000-0000-0000-000000000802'
  ),
  'H1B1-CHN-45 replacement retains the business reason and explicit correction note'
);
select is(
  (
    select array_agg(decision_number order by decision_number)
    from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  ),
  array[1::bigint, 2::bigint],
  'H1B1-CHN-46 history has deterministic decision-number order'
);
select ok(
  (
    select
      receipt.outcome = 'COMPLETED'
      and receipt.actor_id = decision.decided_by_actor_id
    from atlas_planning.confirmed_need_lines as line
    join atlas_planning.confirmed_need_line_decisions as decision
      on decision.confirmed_need_line_decision_id
        = line.current_confirmed_need_line_decision_id
    join atlas_core.command_receipts as receipt
      on receipt.command_id = decision.command_id
    where line.confirmed_need_line_id
      = 'c7100000-0000-0000-0000-000000000510'
  ),
  'H1B1-CHN-47 current tip joins one completed receipt owned by the deciding actor'
);
select ok(
  (
    select
      (
        select count(*)
        from atlas_audit.domain_events
        where command_id in (
          'c7120000-0000-0000-0000-000000000001',
          'c7120000-0000-0000-0000-000000000002',
          'c7120000-0000-0000-0000-000000000024'
        )
      ) = 0
      and (
        select count(*)
        from atlas_audit.audit_events
        where command_id in (
          'c7120000-0000-0000-0000-000000000001',
          'c7120000-0000-0000-0000-000000000002',
          'c7120000-0000-0000-0000-000000000024'
        )
      ) = 0
  ),
  'H1B1-CHN-48 private persistence emits zero domain or audit events directly'
);

set constraints all immediate;
set constraints all deferred;
alter table atlas_planning.confirmed_need_lines
  enable trigger confirmed_need_lines_current_source_consistency;

select * from finish();
rollback;
