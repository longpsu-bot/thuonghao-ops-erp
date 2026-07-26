begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(48);

-- Compact authoritative fixture. Replica mode arranges the pre-H1B1 source,
-- line, revision, and membership graph; all tested H1B1 behavior runs active.
set local session_replication_role = replica;

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('c7200000-0000-0000-0000-000000000001', 'HUMAN', 'H1B1 policy planner'),
  ('c7200000-0000-0000-0000-000000000002', 'HUMAN', 'H1B1 policy approver');
insert into atlas_planning.need_generation_release_snapshots (
  need_generation_release_snapshot_id, need_generation_run_id,
  released_run_version, need_generation_input_snapshot_id,
  released_by_actor_id, released_at, generated_line_count,
  active_line_count, removed_line_count, blocking_issue_count, warning_count
) values (
  'c7200000-0000-0000-0000-000000000190',
  'c7200000-0000-0000-0000-000000000100',
  1,
  'c7200000-0000-0000-0000-000000000103',
  'c7200000-0000-0000-0000-000000000001',
  timestamptz '2026-07-22 08:00:00+07',
  8, 8, 0, 0, 0
);
insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'c7200000-0000-0000-0000-000000000010',
  'h1b1-policy-customer',
  'H1B1 policy customer',
  'SCHOOL_CATERING'
);
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values (
  'c7200000-0000-0000-0000-000000000011',
  'c7200000-0000-0000-0000-000000000010',
  'h1b1-policy-location',
  'H1B1 policy location',
  'Local-only fixture'
);
insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'c7200000-0000-0000-0000-000000000012',
  'h1b1-policy-type',
  'H1B1 policy type'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id
) values (
  'c7200000-0000-0000-0000-000000000013',
  'c7200000-0000-0000-0000-000000000010',
  'h1b1-policy-school',
  'H1B1 policy school',
  'c7200000-0000-0000-0000-000000000012',
  'c7200000-0000-0000-0000-000000000011'
);
insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code
) values
  (
    'c7200000-0000-0000-0000-000000000014',
    'h1b1-policy-centi',
    'H1B1 policy centi-unit',
    'MASS'
  ),
  (
    'c7200000-0000-0000-0000-000000000024',
    'h1b1-policy-expired',
    'H1B1 expired-policy unit',
    'MASS'
  ),
  (
    'c7200000-0000-0000-0000-000000000034',
    'h1b1-policy-future',
    'H1B1 future-policy unit',
    'MASS'
  ),
  (
    'c7200000-0000-0000-0000-000000000044',
    'h1b1-policy-other',
    'H1B1 other-policy unit',
    'MASS'
  ),
  (
    'c7200000-0000-0000-0000-000000000054',
    'h1b1-policy-whole',
    'H1B1 whole-step unit',
    'COUNT'
  ),
  (
    'c7200000-0000-0000-0000-000000000064',
    'h1b1-policy-overlap',
    'H1B1 overlap-policy unit',
    'COUNT'
  );
insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name
)
select
  (
    'c7200000-0000-0000-0000-'
    || lpad((100 + ordinal)::text, 12, '0')
  )::uuid,
  'h1b1-policy-ingredient-' || ordinal,
  'H1B1 policy ingredient ' || ordinal
from generate_series(1, 8) as ordinal;

insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id, period_start, period_end, batch_status, version,
  created_by_actor_id, source_kind, origin_need_generation_run_id,
  origin_need_generation_run_version,
  origin_need_generation_release_snapshot_id, current_need_generation_run_id,
  current_need_generation_run_version,
  current_need_generation_release_snapshot_id
) values (
  'c7200000-0000-0000-0000-000000000500',
  date '2026-07-22', date '2028-07-22', 'DRAFT_REVIEW', 1,
  'c7200000-0000-0000-0000-000000000001', 'NEED_GENERATION',
  'c7200000-0000-0000-0000-000000000100', 1,
  'c7200000-0000-0000-0000-000000000190',
  'c7200000-0000-0000-0000-000000000100', 1,
  'c7200000-0000-0000-0000-000000000190'
);

insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id, confirmed_need_batch_id, wholesale_order_line_id,
  source_kind, service_date, customer_id, school_id, delivery_location_id,
  ingredient_id, controlled_unit_id
) values
  ('c7200000-0000-0000-0000-000000000510','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000101','c7200000-0000-0000-0000-000000000014'),
  ('c7200000-0000-0000-0000-000000000511','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000102','c7200000-0000-0000-0000-000000000014'),
  ('c7200000-0000-0000-0000-000000000512','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000103','c7200000-0000-0000-0000-000000000014'),
  ('c7200000-0000-0000-0000-000000000513','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2028-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000104','c7200000-0000-0000-0000-000000000014'),
  ('c7200000-0000-0000-0000-000000000514','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000105','c7200000-0000-0000-0000-000000000054'),
  ('c7200000-0000-0000-0000-000000000515','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000106','c7200000-0000-0000-0000-000000000014'),
  ('c7200000-0000-0000-0000-000000000516','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000107','c7200000-0000-0000-0000-000000000024'),
  ('c7200000-0000-0000-0000-000000000517','c7200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000108','c7200000-0000-0000-0000-000000000034');

insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id, confirmed_need_line_id, revision_number,
  wholesale_order_line_revision_id, ingredient_id, theoretical_quantity,
  confirmed_quantity, unit_id, revision_status, is_current,
  predecessor_revision_id, command_id, created_by_actor_id, source_kind,
  confirmed_need_batch_id, need_generation_run_id,
  need_generation_run_version, need_generation_release_snapshot_id,
  service_date, customer_id, school_id, delivery_location_id
) values
  ('c7200000-0000-0000-0000-000000000520','c7200000-0000-0000-0000-000000000510',1,null,'c7200000-0000-0000-0000-000000000101',10,10,'c7200000-0000-0000-0000-000000000014','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000521','c7200000-0000-0000-0000-000000000511',1,null,'c7200000-0000-0000-0000-000000000102',10.23,10.23,'c7200000-0000-0000-0000-000000000014','SUPERSEDED',false,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000525','c7200000-0000-0000-0000-000000000511',2,null,'c7200000-0000-0000-0000-000000000102',10.23,10.23,'c7200000-0000-0000-0000-000000000014','DRAFT',true,'c7200000-0000-0000-0000-000000000521',null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000522','c7200000-0000-0000-0000-000000000512',1,null,'c7200000-0000-0000-0000-000000000103',10.234,10.234,'c7200000-0000-0000-0000-000000000014','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000526','c7200000-0000-0000-0000-000000000512',2,null,'c7200000-0000-0000-0000-000000000103',10.234,10.23,'c7200000-0000-0000-0000-000000000014','DRAFT',false,'c7200000-0000-0000-0000-000000000522','c7220000-0000-0000-0000-000000000029','c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000523','c7200000-0000-0000-0000-000000000513',1,null,'c7200000-0000-0000-0000-000000000104',10,10,'c7200000-0000-0000-0000-000000000014','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2028-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000524','c7200000-0000-0000-0000-000000000514',1,null,'c7200000-0000-0000-0000-000000000105',12,12,'c7200000-0000-0000-0000-000000000054','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000528','c7200000-0000-0000-0000-000000000515',1,null,'c7200000-0000-0000-0000-000000000106',8,8,'c7200000-0000-0000-0000-000000000014','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000529','c7200000-0000-0000-0000-000000000515',2,null,'c7200000-0000-0000-0000-000000000106',8,8,'c7200000-0000-0000-0000-000000000014','DRAFT',false,'c7200000-0000-0000-0000-000000000528','c7220000-0000-0000-0000-000000000047','c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000527','c7200000-0000-0000-0000-000000000510',2,null,'c7200000-0000-0000-0000-000000000101',10,10,'c7200000-0000-0000-0000-000000000014','DRAFT',false,'c7200000-0000-0000-0000-000000000520','c7220000-0000-0000-0000-000000000046','c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000536','c7200000-0000-0000-0000-000000000516',1,null,'c7200000-0000-0000-0000-000000000107',5,5,'c7200000-0000-0000-0000-000000000024','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011'),
  ('c7200000-0000-0000-0000-000000000537','c7200000-0000-0000-0000-000000000517',1,null,'c7200000-0000-0000-0000-000000000108',5,5,'c7200000-0000-0000-0000-000000000034','DRAFT',true,null,null,'c7200000-0000-0000-0000-000000000001','NEED_GENERATION','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011');

-- Exact matching predecessor/successor source membership for the adjusted case.
insert into atlas_planning.confirmed_need_line_revision_contributions (
  confirmed_need_line_revision_contribution_id, confirmed_need_batch_id,
  confirmed_need_line_id, confirmed_need_line_revision_id,
  need_generation_run_id, need_generation_run_version,
  need_generation_release_snapshot_id,
  need_generation_release_snapshot_line_id, theoretical_need_line_id,
  service_date, customer_id, school_id, delivery_location_id, ingredient_id,
  source_unit_id, controlled_unit_id, source_theoretical_quantity,
  controlled_contribution_quantity
) values
  ('c7200000-0000-0000-0000-000000000622','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000512','c7200000-0000-0000-0000-000000000522','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190','c7200000-0000-0000-0000-000000000191','c7200000-0000-0000-0000-000000000192',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000103','c7200000-0000-0000-0000-000000000014','c7200000-0000-0000-0000-000000000014',10.234,10.234),
  ('c7200000-0000-0000-0000-000000000626','c7200000-0000-0000-0000-000000000500','c7200000-0000-0000-0000-000000000512','c7200000-0000-0000-0000-000000000526','c7200000-0000-0000-0000-000000000100',1,'c7200000-0000-0000-0000-000000000190','c7200000-0000-0000-0000-000000000191','c7200000-0000-0000-0000-000000000192',date '2026-07-22','c7200000-0000-0000-0000-000000000010','c7200000-0000-0000-0000-000000000013','c7200000-0000-0000-0000-000000000011','c7200000-0000-0000-0000-000000000103','c7200000-0000-0000-0000-000000000014','c7200000-0000-0000-0000-000000000014',10.234,10.234);

set local session_replication_role = origin;

-- The fixture omits the full generation graph. Keep only the pre-existing H0B1b
-- deferred source rechecks out of scope; H1B1 line/revision checks remain active.
alter table atlas_planning.confirmed_need_lines
  disable trigger confirmed_need_lines_current_source_consistency;
alter table atlas_planning.confirmed_need_line_revisions
  disable trigger confirmed_need_line_revisions_current_source_consistency;
alter table atlas_planning.confirmed_need_line_revisions
  disable trigger confirmed_need_line_revisions_membership_total;

insert into atlas_core.command_receipts (
  command_receipt_id, command_name, scope_key, idempotency_key, command_id,
  correlation_id, actor_id, expected_version, request_hash, outcome,
  completed_at
)
select
  ('c7210000-0000-0000-0000-' || lpad(ordinal::text,12,'0'))::uuid,
  'pa_06e_h1b1_test', 'confirmed-need-line-policy',
  'h1b1-policy-' || ordinal,
  ('c7220000-0000-0000-0000-' || lpad(ordinal::text,12,'0'))::uuid,
  ('c7230000-0000-0000-0000-' || lpad(ordinal::text,12,'0'))::uuid,
  'c7200000-0000-0000-0000-000000000001', 1, repeat('b',64),
  'COMPLETED', timestamptz '2026-07-22 10:00:00+07'
from generate_series(1,60) as ordinal;

create function pg_temp.h1b1_policy_decide(
  p_decision uuid,
  p_line uuid default 'c7200000-0000-0000-0000-000000000515',
  p_revision uuid default 'c7200000-0000-0000-0000-000000000528',
  p_policy uuid default 'c7200000-0000-0000-0000-000000000700',
  p_policy_revision uuid default 'c7200000-0000-0000-0000-000000000701',
  p_number bigint default 1,
  p_predecessor uuid default null,
  p_kind text default 'UNCHANGED_PROPOSAL_ACCEPTED',
  p_theoretical numeric default 8,
  p_proposed numeric default 8,
  p_after numeric default 8,
  p_ticks numeric default 800,
  p_reason text default 'PROPOSAL_ACCEPTED',
  p_note text default null,
  p_command_ordinal integer default 1,
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
    line.controlled_unit_id, p_number, p_predecessor, p_kind, p_policy,
    p_policy_revision, p_theoretical, p_proposed, p_after, p_ticks, p_reason,
    p_note, 'c7200000-0000-0000-0000-000000000001',
    timestamptz '2026-07-22 10:00:00+07',
    ('c7220000-0000-0000-0000-'
      || lpad(p_command_ordinal::text,12,'0'))::uuid,
    1, timestamptz '2026-07-22 10:00:00+07'
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

select lives_ok(
  $$
    insert into atlas_planning.planning_quantity_policies (
      planning_quantity_policy_id, unit_id, created_by_actor_id, created_at
    ) values (
      'c7200000-0000-0000-0000-000000000700',
      'c7200000-0000-0000-0000-000000000014',
      'c7200000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 08:00:00+07'
    );
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id, planning_quantity_policy_id,
      unit_id, revision_number, planning_step, effective_from,
      created_by_actor_id, created_at
    ) values (
      'c7200000-0000-0000-0000-000000000701',
      'c7200000-0000-0000-0000-000000000700',
      'c7200000-0000-0000-0000-000000000014',
      1, 0.01, date '2020-01-01',
      'c7200000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 08:00:00+07'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1B1-POL-01 Draft policy with zero decisions remains valid'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='ACTIVE',
      approved_by_actor_id='c7200000-0000-0000-0000-000000000002',
      approved_at=timestamptz '2020-01-01 09:00:00+07',
      activated_by_actor_id='c7200000-0000-0000-0000-000000000001',
      activated_at=timestamptz '2020-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      ='c7200000-0000-0000-0000-000000000701';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1B1-POL-02 H1A activation with zero decisions remains valid'
);
select lives_ok(
  $$
    insert into atlas_planning.planning_quantity_policies
    values ('c7200000-0000-0000-0000-000000000740','c7200000-0000-0000-0000-000000000044','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07');
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
      revision_number,planning_step,effective_from,created_by_actor_id,created_at
    ) values ('c7200000-0000-0000-0000-000000000741','c7200000-0000-0000-0000-000000000740','c7200000-0000-0000-0000-000000000044',1,0.01,date '2020-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07');
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='ACTIVE',approved_by_actor_id='c7200000-0000-0000-0000-000000000002',approved_at=timestamptz '2020-01-01 09:00+07',activated_by_actor_id='c7200000-0000-0000-0000-000000000001',activated_at=timestamptz '2020-01-01 10:00+07'
    where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000741';
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='RETIRED',effective_to=date '2027-01-01',retired_by_actor_id='c7200000-0000-0000-0000-000000000001',retired_at=timestamptz '2021-01-01 10:00+07'
    where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000741';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1B1-POL-03 H1A retirement with zero decisions remains valid'
);
select lives_ok(
  $$
    select pg_temp.h1b1_policy_decide(
      p_decision=>'c7200000-0000-0000-0000-000000000804',
      p_line=>'c7200000-0000-0000-0000-000000000510',
      p_revision=>'c7200000-0000-0000-0000-000000000520',
      p_theoretical=>10,p_proposed=>10,p_after=>10,p_ticks=>1000,
      p_command_ordinal=>4
    )
  $$,
  'H1B1-POL-04 unchanged acceptance binds the sole ACTIVE policy revision'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='RETIRED',effective_to=date '2027-01-01',
      retired_by_actor_id='c7200000-0000-0000-0000-000000000001',
      retired_at=timestamptz '2021-01-01 10:00+07'
    where planning_quantity_policy_revision_id
      ='c7200000-0000-0000-0000-000000000701';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1B1-POL-05 an eligible historically RETIRED policy remains bound'
);

-- Main future successor and Draft tail.
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
  revision_number,predecessor_policy_revision_id,planning_step,effective_from,
  created_by_actor_id,created_at
) values ('c7200000-0000-0000-0000-000000000702','c7200000-0000-0000-0000-000000000700','c7200000-0000-0000-0000-000000000014',2,'c7200000-0000-0000-0000-000000000701',0.01,date '2027-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2021-01-02 08:00+07');
update atlas_planning.planning_quantity_policy_revisions
set policy_revision_status='ACTIVE',approved_by_actor_id='c7200000-0000-0000-0000-000000000002',approved_at=timestamptz '2021-01-02 09:00+07',activated_by_actor_id='c7200000-0000-0000-0000-000000000001',activated_at=timestamptz '2021-01-02 10:00+07'
where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000702';
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
  revision_number,predecessor_policy_revision_id,planning_step,effective_from,
  created_by_actor_id,created_at
) values ('c7200000-0000-0000-0000-000000000703','c7200000-0000-0000-0000-000000000700','c7200000-0000-0000-0000-000000000014',3,'c7200000-0000-0000-0000-000000000702',0.01,date '2030-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2021-01-03 08:00+07');

-- Expired, future, whole-step, and overlap fixtures.
insert into atlas_planning.planning_quantity_policies values
 ('c7200000-0000-0000-0000-000000000720','c7200000-0000-0000-0000-000000000024','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07'),
 ('c7200000-0000-0000-0000-000000000730','c7200000-0000-0000-0000-000000000034','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07'),
 ('c7200000-0000-0000-0000-000000000750','c7200000-0000-0000-0000-000000000054','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07'),
 ('c7200000-0000-0000-0000-000000000760','c7200000-0000-0000-0000-000000000064','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07');
insert into atlas_planning.planning_quantity_policy_revisions (
 planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
 revision_number,planning_step,effective_from,created_by_actor_id,created_at
) values
 ('c7200000-0000-0000-0000-000000000721','c7200000-0000-0000-0000-000000000720','c7200000-0000-0000-0000-000000000024',1,0.01,date '2020-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07'),
 ('c7200000-0000-0000-0000-000000000731','c7200000-0000-0000-0000-000000000730','c7200000-0000-0000-0000-000000000034',1,0.01,date '2027-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07'),
 ('c7200000-0000-0000-0000-000000000751','c7200000-0000-0000-0000-000000000750','c7200000-0000-0000-0000-000000000054',1,1,date '2020-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07'),
 ('c7200000-0000-0000-0000-000000000761','c7200000-0000-0000-0000-000000000760','c7200000-0000-0000-0000-000000000064',1,1,date '2020-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2020-01-01 08:00+07');
update atlas_planning.planning_quantity_policy_revisions
set policy_revision_status='ACTIVE',approved_by_actor_id='c7200000-0000-0000-0000-000000000002',approved_at=timestamptz '2020-01-01 09:00+07',activated_by_actor_id='c7200000-0000-0000-0000-000000000001',activated_at=timestamptz '2020-01-01 10:00+07'
where planning_quantity_policy_revision_id in (
 'c7200000-0000-0000-0000-000000000721','c7200000-0000-0000-0000-000000000731',
 'c7200000-0000-0000-0000-000000000751','c7200000-0000-0000-0000-000000000761'
);
update atlas_planning.planning_quantity_policy_revisions
set policy_revision_status='RETIRED',effective_to=date '2025-01-01',
 retired_by_actor_id='c7200000-0000-0000-0000-000000000001',
 retired_at=timestamptz '2021-01-01 10:00+07'
where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000721';
insert into atlas_planning.planning_quantity_policy_revisions (
 planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
 revision_number,predecessor_policy_revision_id,planning_step,effective_from,
 created_by_actor_id,created_at
) values ('c7200000-0000-0000-0000-000000000762','c7200000-0000-0000-0000-000000000760','c7200000-0000-0000-0000-000000000064',2,'c7200000-0000-0000-0000-000000000761',1,date '2025-01-01','c7200000-0000-0000-0000-000000000001',timestamptz '2021-01-01 08:00+07');
set constraints all immediate;
set constraints all deferred;

select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000806',p_policy=>'c7200000-0000-0000-0000-000000009999',p_policy_revision=>'c7200000-0000-0000-0000-000000009998',p_command_ordinal=>6)$$,'23503',null,'H1B1-POL-06 a missing policy identity is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000807',p_policy_revision=>'c7200000-0000-0000-0000-000000000703',p_command_ordinal=>7)$$,'23514',null,'H1B1-POL-07 a Draft policy revision is ineligible');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000808',p_line=>'c7200000-0000-0000-0000-000000000517',p_revision=>'c7200000-0000-0000-0000-000000000537',p_policy=>'c7200000-0000-0000-0000-000000000730',p_policy_revision=>'c7200000-0000-0000-0000-000000000731',p_theoretical=>5,p_proposed=>5,p_after=>5,p_ticks=>500,p_command_ordinal=>8)$$,'23514',null,'H1B1-POL-08 a future-only policy revision is ineligible');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000809',p_line=>'c7200000-0000-0000-0000-000000000516',p_revision=>'c7200000-0000-0000-0000-000000000536',p_policy=>'c7200000-0000-0000-0000-000000000720',p_policy_revision=>'c7200000-0000-0000-0000-000000000721',p_theoretical=>5,p_proposed=>5,p_after=>5,p_ticks=>500,p_command_ordinal=>9)$$,'23514',null,'H1B1-POL-09 an expired policy revision is ineligible');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000810',p_line=>'c7200000-0000-0000-0000-000000000513',p_revision=>'c7200000-0000-0000-0000-000000000523',p_policy_revision=>'c7200000-0000-0000-0000-000000000701',p_theoretical=>10,p_proposed=>10,p_after=>10,p_ticks=>1000,p_command_ordinal=>10)$$,'23514',null,'H1B1-POL-10 a stale policy revision is rejected when its successor is sole eligible');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000811',p_policy=>'c7200000-0000-0000-0000-000000000740',p_policy_revision=>'c7200000-0000-0000-0000-000000000741',p_command_ordinal=>11)$$,'23503',null,'H1B1-POL-11 a policy revision for the wrong exact Unit is rejected');
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='ACTIVE',
      approved_by_actor_id='c7200000-0000-0000-0000-000000000002',
      approved_at=timestamptz '2021-01-01 09:00+07',
      activated_by_actor_id='c7200000-0000-0000-0000-000000000001',
      activated_at=timestamptz '2021-01-01 10:00+07'
    where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000762';
    set constraints all immediate
  $$,
  '23514',null,
  'H1B1-POL-12 overlapping policy activation is rejected even with no decision'
);
set constraints all deferred;
select ok((select planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000701' and service_date>=date '2020-01-01' and service_date<date '2027-01-01' from atlas_planning.confirmed_need_line_decisions where confirmed_need_line_decision_id='c7200000-0000-0000-0000-000000000804'),'H1B1-POL-13 the bound policy is the sole eligible exact-Unit revision');

select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000814',p_theoretical=>-1,p_command_ordinal=>14)$$,'23514',null,'H1B1-POL-14 negative theoretical-before is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000815',p_proposed=>-1,p_after=>-1,p_command_ordinal=>15)$$,'23514',null,'H1B1-POL-15 negative proposed-before is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000816',p_after=>-1,p_command_ordinal=>16)$$,'23514',null,'H1B1-POL-16 negative confirmed-after is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000817',p_ticks=>-1,p_command_ordinal=>17)$$,'23514',null,'H1B1-POL-17 negative tick count is rejected');
select lives_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000818',p_line=>'c7200000-0000-0000-0000-000000000511',p_revision=>'c7200000-0000-0000-0000-000000000525',p_theoretical=>10.23,p_proposed=>10.23,p_after=>10.23,p_ticks=>1023,p_command_ordinal=>18)$$,'H1B1-POL-18 10.23 at step 0.01 persists as exactly 1023 ticks');
select lives_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000819',p_line=>'c7200000-0000-0000-0000-000000000514',p_revision=>'c7200000-0000-0000-0000-000000000524',p_policy=>'c7200000-0000-0000-0000-000000000750',p_policy_revision=>'c7200000-0000-0000-0000-000000000751',p_theoretical=>12,p_proposed=>12,p_after=>12,p_ticks=>12,p_command_ordinal=>19)$$,'H1B1-POL-19 12 at step 1 persists as exactly 12 ticks');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000820',p_ticks=>799,p_command_ordinal=>20)$$,'23514',null,'H1B1-POL-20 a wrong tick count is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000821',p_line=>'c7200000-0000-0000-0000-000000000512',p_revision=>'c7200000-0000-0000-0000-000000000522',p_theoretical=>10.234,p_proposed=>10.234,p_after=>10.234,p_ticks=>1023,p_command_ordinal=>21)$$,'23514',null,'H1B1-POL-21 10.234 is not representable at exact step 0.01');
select is((select confirmed_quantity_after from atlas_planning.confirmed_need_line_decisions where confirmed_need_line_decision_id='c7200000-0000-0000-0000-000000000818'),(select planning_tick_count*0.01 from atlas_planning.confirmed_need_line_decisions where confirmed_need_line_decision_id='c7200000-0000-0000-0000-000000000818'),'H1B1-POL-22 confirmed quantity equals ticks multiplied by step exactly');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000823',p_theoretical=>7,p_command_ordinal=>23)$$,'23514',null,'H1B1-POL-23 theoretical-before differing from the bound revision is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000824',p_proposed=>7,p_after=>7,p_ticks=>700,p_command_ordinal=>24)$$,'23514',null,'H1B1-POL-24 unchanged proposed-before differing from current revision is rejected');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000825',p_after=>7,p_ticks=>700,p_command_ordinal=>25)$$,'23514',null,'H1B1-POL-25 unchanged confirmed-after differing from proposal is rejected');
select is((select confirmed_need_line_revision_id from atlas_planning.confirmed_need_line_decisions where confirmed_need_line_decision_id='c7200000-0000-0000-0000-000000000818'),'c7200000-0000-0000-0000-000000000525'::uuid,'H1B1-POL-26 unchanged acceptance binds the existing current revision');
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000827',p_line=>'c7200000-0000-0000-0000-000000000511',p_revision=>'c7200000-0000-0000-0000-000000000521',p_number=>2,p_predecessor=>'c7200000-0000-0000-0000-000000000818',p_theoretical=>10.23,p_proposed=>10.23,p_after=>10.23,p_ticks=>1023,p_note=>'noncurrent binding',p_command_ordinal=>27)$$,'23514',null,'H1B1-POL-27 unchanged acceptance cannot bind a noncurrent revision');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='c7200000-0000-0000-0000-000000000511' and command_id='c7220000-0000-0000-0000-000000000018'),0,'H1B1-POL-28 unchanged decision command creates no revision');

set local session_replication_role = replica;
update atlas_planning.confirmed_need_line_revisions set is_current=false,revision_status='SUPERSEDED' where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000522';
update atlas_planning.confirmed_need_line_revisions set is_current=true where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000526';
set local session_replication_role = origin;
select lives_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000829',p_line=>'c7200000-0000-0000-0000-000000000512',p_revision=>'c7200000-0000-0000-0000-000000000526',p_kind=>'ADJUSTED_QUANTITY_CONFIRMED',p_theoretical=>10.234,p_proposed=>10.234,p_after=>10.23,p_ticks=>1023,p_reason=>'PLANNING_STEP_ADJUSTMENT',p_command_ordinal=>29)$$,'H1B1-POL-29 adjusted confirmation and direct successor commit atomically');
select ok(
  (
    select
      line.current_confirmed_need_line_decision_id
        = decision.confirmed_need_line_decision_id
      and decision.confirmed_need_line_revision_id
        = successor.confirmed_need_line_revision_id
      and successor.is_current
      and successor.revision_number = predecessor.revision_number + 1
      and successor.predecessor_revision_id
        = predecessor.confirmed_need_line_revision_id
    from atlas_planning.confirmed_need_line_decisions as decision
    join atlas_planning.confirmed_need_lines as line
      on line.confirmed_need_line_id = decision.confirmed_need_line_id
    join atlas_planning.confirmed_need_line_revisions as successor
      on successor.confirmed_need_line_revision_id
        = decision.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_line_revisions as predecessor
      on predecessor.confirmed_need_line_revision_id
        = successor.predecessor_revision_id
    where decision.confirmed_need_line_decision_id
      = 'c7200000-0000-0000-0000-000000000829'
  ),
  'H1B1-POL-30 adjusted decision binds the current direct successor'
);
select ok(
  (
    select
      revision.command_id = decision.command_id
      and (
        select count(*)
        from atlas_planning.confirmed_need_line_revisions as command_revision
        where command_revision.confirmed_need_line_id
            = decision.confirmed_need_line_id
          and command_revision.command_id = decision.command_id
      ) = 1
    from atlas_planning.confirmed_need_line_decisions as decision
    join atlas_planning.confirmed_need_line_revisions as revision
      on revision.confirmed_need_line_revision_id
        = decision.confirmed_need_line_revision_id
    where decision.confirmed_need_line_decision_id
      = 'c7200000-0000-0000-0000-000000000829'
  ),
  'H1B1-POL-31 changed quantity uses exactly one command-authored revision'
);
select ok(
  (
    select
      successor.theoretical_quantity = 10.234::numeric
      and decision.proposed_quantity_before
        = predecessor.confirmed_quantity
    from atlas_planning.confirmed_need_line_decisions as decision
    join atlas_planning.confirmed_need_line_revisions as successor
      on successor.confirmed_need_line_revision_id
        = decision.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_line_revisions as predecessor
      on predecessor.confirmed_need_line_revision_id
        = successor.predecessor_revision_id
    where decision.confirmed_need_line_decision_id
      = 'c7200000-0000-0000-0000-000000000829'
  ),
  'H1B1-POL-32 successor preserves theory and proposal-before evidence'
);
select is((select confirmed_quantity_after from atlas_planning.confirmed_need_line_decisions where confirmed_need_line_decision_id='c7200000-0000-0000-0000-000000000829'),(select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000526'),'H1B1-POL-33 confirmed-after equals successor confirmed quantity');
select ok(
  not exists (
    (select need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,need_generation_release_snapshot_line_id,theoretical_need_line_id,source_theoretical_quantity,controlled_contribution_quantity from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000522'
     except all
     select need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,need_generation_release_snapshot_line_id,theoretical_need_line_id,source_theoretical_quantity,controlled_contribution_quantity from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000526')
    union all
    (select need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,need_generation_release_snapshot_line_id,theoretical_need_line_id,source_theoretical_quantity,controlled_contribution_quantity from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000526'
     except all
     select need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,need_generation_release_snapshot_line_id,theoretical_need_line_id,source_theoretical_quantity,controlled_contribution_quantity from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000522')
  ),
  'H1B1-POL-34 adjusted successor preserves exact source, release, and contribution membership'
);
select lives_ok(
  $$
    select pg_temp.h1b1_policy_decide(
      p_decision => 'c7200000-0000-0000-0000-000000000835',
      p_line => 'c7200000-0000-0000-0000-000000000512',
      p_revision => 'c7200000-0000-0000-0000-000000000526',
      p_number => 2,
      p_predecessor => 'c7200000-0000-0000-0000-000000000829',
      p_kind => 'ADJUSTED_QUANTITY_CONFIRMED',
      p_theoretical => 10.234,
      p_proposed => 10.234,
      p_after => 10.23,
      p_ticks => 1023,
      p_reason => 'OPERATIONAL_QUANTITY_ADJUSTMENT',
      p_note => 'Corrected adjusted evidence without changing quantity',
      p_command_ordinal => 35
    )
  $$,
  'H1B1-POL-35 adjusted evidence correction may bind the same revision'
);
select ok(
  (
    select
      prior.confirmed_need_line_decision_id
        = correction.predecessor_decision_id
      and prior.confirmed_need_line_revision_id
        = correction.confirmed_need_line_revision_id
      and correction.decision_number = prior.decision_number + 1
      and correction.decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
      and correction.reason_code = 'OPERATIONAL_QUANTITY_ADJUSTMENT'
      and correction.reason_note
        = 'Corrected adjusted evidence without changing quantity'
      and row(
        correction.theoretical_quantity_before,
        correction.proposed_quantity_before,
        correction.confirmed_quantity_after,
        correction.planning_tick_count
      ) = row(
        prior.theoretical_quantity_before,
        prior.proposed_quantity_before,
        prior.confirmed_quantity_after,
        prior.planning_tick_count
      )
      and line.current_confirmed_need_line_decision_id
        = correction.confirmed_need_line_decision_id
      and receipt.outcome = 'COMPLETED'
      and receipt.actor_id = correction.decided_by_actor_id
      and not exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions as command_revision
        where command_revision.confirmed_need_line_id
            = correction.confirmed_need_line_id
          and command_revision.command_id = correction.command_id
      )
    from atlas_planning.confirmed_need_line_decisions as correction
    join atlas_planning.confirmed_need_line_decisions as prior
      on prior.confirmed_need_line_decision_id
        = correction.predecessor_decision_id
    join atlas_planning.confirmed_need_lines as line
      on line.confirmed_need_line_id = correction.confirmed_need_line_id
    join atlas_core.command_receipts as receipt
      on receipt.command_id = correction.command_id
    where correction.confirmed_need_line_decision_id
      = 'c7200000-0000-0000-0000-000000000835'
  ),
  'H1B1-POL-36 same-revision correction retains history, evidence, receipt, and advances the pointer'
);
select throws_ok(
  $$
    select pg_temp.h1b1_policy_decide(
      p_decision => 'c7200000-0000-0000-0000-000000000837',
      p_line => 'c7200000-0000-0000-0000-000000000512',
      p_revision => 'c7200000-0000-0000-0000-000000000526',
      p_number => 3,
      p_predecessor => 'c7200000-0000-0000-0000-000000000835',
      p_kind => 'ADJUSTED_QUANTITY_CONFIRMED',
      p_theoretical => 10.234,
      p_proposed => 10.234,
      p_after => 10.22,
      p_ticks => 1022,
      p_reason => 'PLANNING_STEP_ADJUSTMENT',
      p_note => 'Quantity correction requires a successor revision',
      p_command_ordinal => 37
    )
  $$,
  '23514',
  null,
  'H1B1-POL-37 same-revision adjusted replacement cannot change quantity without a direct successor'
);
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000838',p_line=>'c7200000-0000-0000-0000-000000000515',p_revision=>'c7200000-0000-0000-0000-000000000528',p_kind=>'ADJUSTED_QUANTITY_CONFIRMED',p_proposed=>8,p_after=>7.99,p_ticks=>799,p_reason=>'PLANNING_STEP_ADJUSTMENT',p_command_ordinal=>38)$$,'23514',null,'H1B1-POL-38 adjusted decision cannot bind an already-current preexisting revision');

set local session_replication_role = replica;
insert into atlas_planning.confirmed_need_line_revisions
select 'c7200000-0000-0000-0000-000000000539',confirmed_need_line_id,3,wholesale_order_line_revision_id,ingredient_id,theoretical_quantity,7.99,unit_id,'DRAFT',false,'c7200000-0000-0000-0000-000000000528','c7220000-0000-0000-0000-000000000039',created_by_actor_id,created_at,source_kind,confirmed_need_batch_id,need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,service_date,customer_id,school_id,delivery_location_id
from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000528';
update atlas_planning.confirmed_need_line_revisions set is_current=false where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000528';
update atlas_planning.confirmed_need_line_revisions set is_current=true where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000539';
set local session_replication_role = origin;
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000839',p_line=>'c7200000-0000-0000-0000-000000000515',p_revision=>'c7200000-0000-0000-0000-000000000539',p_kind=>'ADJUSTED_QUANTITY_CONFIRMED',p_proposed=>8,p_after=>7.99,p_ticks=>799,p_reason=>'PLANNING_STEP_ADJUSTMENT',p_command_ordinal=>39)$$,'23514',null,'H1B1-POL-39 an indirect successor revision is rejected');
set local session_replication_role = replica;
delete from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000539';
update atlas_planning.confirmed_need_line_revisions
set is_current=true,confirmed_quantity=7.99,
  need_generation_release_snapshot_id='c7200000-0000-0000-0000-000000000191',
  command_id='c7220000-0000-0000-0000-000000000040'
where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000529';
set local session_replication_role = origin;
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000840',p_line=>'c7200000-0000-0000-0000-000000000515',p_revision=>'c7200000-0000-0000-0000-000000000529',p_kind=>'ADJUSTED_QUANTITY_CONFIRMED',p_proposed=>8,p_after=>7.99,p_ticks=>799,p_reason=>'PLANNING_STEP_ADJUSTMENT',p_command_ordinal=>40)$$,'23514',null,'H1B1-POL-40 a successor with different release identity is rejected');
set local session_replication_role = replica;
update atlas_planning.confirmed_need_line_revisions
set is_current=false,confirmed_quantity=8,
  need_generation_release_snapshot_id='c7200000-0000-0000-0000-000000000190',
  command_id='c7220000-0000-0000-0000-000000000047'
where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000529';
update atlas_planning.confirmed_need_line_revisions set is_current=true where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000528';
set local session_replication_role = origin;
select throws_ok($$select pg_temp.h1b1_policy_decide(p_decision=>'c7200000-0000-0000-0000-000000000841',p_kind=>'ADJUSTED_QUANTITY_CONFIRMED',p_after=>8,p_ticks=>800,p_reason=>'PLANNING_STEP_ADJUSTMENT',p_command_ordinal=>41)$$,'23514',null,'H1B1-POL-41 adjusted confirmed-after cannot equal the reviewed proposal');
select ok((select policy_revision_status='RETIRED' and effective_to>date '2026-07-22' from atlas_planning.planning_quantity_policy_revisions where planning_quantity_policy_revision_id=(select planning_quantity_policy_revision_id from atlas_planning.confirmed_need_line_decisions where confirmed_need_line_decision_id='c7200000-0000-0000-0000-000000000804')),'H1B1-POL-42 retirement after the service date preserves the historical binding');
select throws_ok(
  $$update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='RETIRED',effective_to=date '2026-07-22',retired_by_actor_id='c7200000-0000-0000-0000-000000000001',retired_at=timestamptz '2021-01-01 10:00+07' where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000751'; set constraints all immediate$$,
  '23514',null,
  'H1B1-POL-43 retirement on or before service cannot invalidate a bound decision'
);
set constraints all deferred;
insert into atlas_planning.planning_quantity_policy_revisions (
 planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
 revision_number,predecessor_policy_revision_id,planning_step,effective_from,
 created_by_actor_id,created_at
) values ('c7200000-0000-0000-0000-000000000752','c7200000-0000-0000-0000-000000000750','c7200000-0000-0000-0000-000000000054',2,'c7200000-0000-0000-0000-000000000751',1,date '2026-07-22','c7200000-0000-0000-0000-000000000001',timestamptz '2021-01-02 08:00+07');
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='RETIRED',effective_to=date '2026-07-22',
      retired_by_actor_id='c7200000-0000-0000-0000-000000000001',
      retired_at=timestamptz '2021-01-02 10:00+07'
    where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000751';
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='ACTIVE',
      approved_by_actor_id='c7200000-0000-0000-0000-000000000002',
      approved_at=timestamptz '2021-01-02 09:00+07',
      activated_by_actor_id='c7200000-0000-0000-0000-000000000001',
      activated_at=timestamptz '2021-01-02 10:00+07'
    where planning_quantity_policy_revision_id='c7200000-0000-0000-0000-000000000752';
    set constraints all immediate
  $$,
  '23514',null,
  'H1B1-POL-44 replacement activation cannot make an existing binding stale'
);
set constraints all deferred;
select throws_ok($$update atlas_planning.planning_quantity_policies set unit_id='c7200000-0000-0000-0000-000000000044' where planning_quantity_policy_id='c7200000-0000-0000-0000-000000000700'$$,'23514',null,'H1B1-POL-45 H1A root and Unit identity remain immutable');
select throws_ok(
  $$
    update atlas_planning.confirmed_need_line_revisions
    set is_current=false,revision_status='SUPERSEDED'
    where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000520';
    update atlas_planning.confirmed_need_line_revisions
    set is_current=true
    where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000527';
    set constraints all immediate
  $$,
  '23514',null,
  'H1B1-POL-46 H0C-style revision rebind is rejected when a decision pointer exists'
);
set constraints all deferred;
select lives_ok(
  $$
    update atlas_planning.confirmed_need_line_revisions
    set is_current=false,revision_status='SUPERSEDED'
    where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000528';
    update atlas_planning.confirmed_need_line_revisions
    set is_current=true
    where confirmed_need_line_revision_id='c7200000-0000-0000-0000-000000000529';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1B1-POL-47 the same valid revision transition remains allowed with a null pointer'
);
select ok(
  (
    select
      lower(pg_get_functiondef(
        'atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()'
          ::regprocedure
      )) like '%mod(%'
      and lower(pg_get_functiondef(
        'atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()'
          ::regprocedure
      )) like '%planning_tick_count * policy_revision.planning_step%'
      and lower(pg_get_functiondef(
        'atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()'
          ::regprocedure
      )) !~ '\m(double precision|real|epsilon|round|trunc|convert|resolver)\M'
  ),
  'H1B1-POL-48 exact numeric modulo and multiplication use no float, epsilon, rounding, conversion, or resolver'
);

set constraints all immediate;
set constraints all deferred;
alter table atlas_planning.confirmed_need_lines
  enable trigger confirmed_need_lines_current_source_consistency;
alter table atlas_planning.confirmed_need_line_revisions
  enable trigger confirmed_need_line_revisions_current_source_consistency;
alter table atlas_planning.confirmed_need_line_revisions
  enable trigger confirmed_need_line_revisions_membership_total;

select * from finish();
rollback;
