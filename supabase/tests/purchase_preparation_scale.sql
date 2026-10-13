begin;
set local track_functions='all';
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(31);
\ir ../local/purchase_preparation_scale_fixture.sql

select is(
  (select setting
    from pg_catalog.pg_proc function_row
    cross join lateral pg_catalog.unnest(function_row.proconfig) setting
    where function_row.oid =
        'atlas_api.prepare_school_catering_purchase_orders(jsonb)'::pg_catalog.regprocedure
      and setting like 'statement_timeout=%'),
  'statement_timeout=20s',
  'Purchase Preparation publishes the provisional 20-second function timeout'
);
select is(
  (select pg_catalog.split_part(setting, '=', 2)
    from pg_catalog.pg_db_role_setting config
    cross join lateral pg_catalog.unnest(config.setconfig) setting
    where setting like 'statement_timeout=%'
      and config.setrole in (
        0,
        (select oid from pg_catalog.pg_roles where rolname = 'authenticated')
      )
      and config.setdatabase in (
        0,
        (select oid from pg_catalog.pg_database where datname = pg_catalog.current_database())
      )
    order by (config.setrole <> 0) desc, (config.setdatabase <> 0) desc
    limit 1),
  '8s',
  'normal authenticated commands retain the global 8-second timeout'
);

do $seed_success_scale$
begin
  perform pg_temp.seed_purchase_preparation_scale(
    'purchase-preparation-scale',
    'scale',
    date '2027-01-18'
  );
end;
$seed_success_scale$;

-- Name the break: a 250-line ceiling, incomplete fixture lineage, or a client-
-- authoritative quantity shortcut makes this one real Save fail before the
-- preparation measurement can begin.
insert into scale_requests(name, request)
values (
  'save-confirmed-need',
  pg_temp.scale_confirmed_need_save_command(
    'save-confirmed-need',
    md5('purchase-preparation-scale:confirmed-need-batch')::uuid
  )
);

-- SET ROLE does not apply ALTER ROLE defaults to this existing psql session.
-- Emulate the unchanged authenticated transport budget for the ordinary Save.
set local statement_timeout = '8s';
set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101',
  true
);
insert into scale_results(name, response)
select 'save-confirmed-need', atlas_api.save_confirmed_needs(request)
from scale_requests
where name = 'save-confirmed-need';
set constraints all immediate;
reset role;
set constraints all deferred;

select is(
  (select response->>'success' from scale_results where name = 'save-confirmed-need'),
  'true',
  'scale setup saves all 236 Confirmed Need decisions through one authenticated public command'
);
select is(
  (select count(*) from atlas_planning.confirmed_need_line_decisions
    where confirmed_need_batch_id = md5('purchase-preparation-scale:confirmed-need-batch')::uuid),
  236::bigint,
  'scale setup has exactly 236 current positive Confirmed Need decisions'
);
select is(
  (select count(*) from atlas_procurement.school_catering_allocation_families
    where service_date = date '2027-01-18'),
  0::bigint,
  'scale setup begins with zero persisted allocation families'
);
select is(
  (select count(*)
    from atlas_core.purchase_review_confirmed_batch_sources(
      md5('purchase-preparation-scale:confirmed-need-batch')::uuid
    ) source(value)
    where source.value->>'complete' = 'true'
      and (source.value->>'family_quantity')::numeric > 0),
  236::bigint,
  'canonical source projection exposes exactly 236 complete positive families before preparation'
);
select is(
  (select count(*)
    from atlas_core.purchase_review_confirmed_batch_sources(
      md5('purchase-preparation-scale:confirmed-need-batch')::uuid
    ) source(value)
    where atlas_core.purchase_review_supplier_advice(
      (source.value->>'service_date')::date,
      (source.value->>'ingredient_id')::uuid,
      (source.value->>'family_quantity')::numeric
    )->'recommendation' <> 'null'::jsonb),
  236::bigint,
  'all 236 families have one safe current preferred-Supplier recommendation before preparation'
);

-- Fresh disposable fixtures need ordinary planner statistics, as a populated
-- operating database has after ANALYZE/autovacuum. Do this once immediately
-- before the FIRST preparation attempt; no warm-up command, discarded sample
-- or runtime setting change substitutes for the authenticated performance gate.
do $scale_statistics$
declare relation record;
begin
  for relation in select schemaname,relname from pg_catalog.pg_stat_user_tables
    where schemaname in ('atlas_admin','atlas_planning','atlas_procurement','atlas_core')
  loop
    execute pg_catalog.format('analyze %I.%I',relation.schemaname,relation.relname);
  end loop;
end;
$scale_statistics$;

insert into scale_requests(name, request)
select
  'prepare',
  pg_temp.scale_command(
    'prepare',
    'PURCHASE-COMMITMENT.v1',
    'PURCHASE_ORDERS_PREPARED',
    batch.version,
    pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id', batch.confirmed_need_batch_id,
      'service_date', batch.period_start
    )
  )
from atlas_planning.confirmed_need_batches batch
where batch.confirmed_need_batch_id = md5('purchase-preparation-scale:confirmed-need-batch')::uuid;

-- PostgREST hoists the API function's proconfig before invoking the RPC. Direct
-- psql does not, so this separate statement emulates that transport behavior
-- before the outer public RPC statement. No service role or private helper is
-- used as the acceptance path.
set local role authenticated;
select pg_catalog.set_config(
  'statement_timeout',
  pg_catalog.split_part(setting, '=', 2),
  true
)
from pg_catalog.pg_proc function_row
cross join lateral pg_catalog.unnest(function_row.proconfig) setting
where function_row.oid =
    'atlas_api.prepare_school_catering_purchase_orders(jsonb)'::pg_catalog.regprocedure
  and setting like 'statement_timeout=%';
\echo purchase_preparation_scale public_prepare statement_timeout=20s families=236
\timing on
with started as materialized (
  select pg_catalog.clock_timestamp() as started_at
), invoked as materialized (
  select atlas_api.prepare_school_catering_purchase_orders(request) as response,
    started.started_at
  from scale_requests
  cross join started
  where name = 'prepare'
)
insert into scale_results(name, response, started_at, command_finished_at)
select
  'prepare',
  invoked.response,
  invoked.started_at,
  pg_catalog.clock_timestamp()
from invoked;
\timing off

-- A real durable result also has to survive the deferred integrity guards.
-- Force them now while the same authenticated test transaction and 20-second
-- statement timeout remain active, then include that cost in total_elapsed_ms.
set constraints all immediate;
reset role;
set local statement_timeout = '8s';
update scale_results
set guards_finished_at = pg_catalog.clock_timestamp()
where name = 'prepare';
set constraints all deferred;

select diag(pg_catalog.format(
  'purchase_preparation_scale success_command_ms=%s success_guard_ms=%s success_total_ms=%s families=236 statement_timeout=20s',
  (select pg_catalog.round(pg_catalog.date_part('epoch', command_finished_at - started_at)::numeric * 1000, 3)
    from scale_results where name = 'prepare'),
  (select pg_catalog.round(pg_catalog.date_part('epoch', guards_finished_at - command_finished_at)::numeric * 1000, 3)
    from scale_results where name = 'prepare'),
  (select pg_catalog.round(pg_catalog.date_part('epoch', guards_finished_at - started_at)::numeric * 1000, 3)
    from scale_results where name = 'prepare')
));

select diag(pg_catalog.format(
  'Purchase Preparation returned success=false: %s',
  response
))
from scale_results
where name = 'prepare'
  and response->>'success' is distinct from 'true';

select diag(jsonb_build_object('preparation_stage_functions',(
  select jsonb_agg(jsonb_build_object('function',funcname,'calls',calls,
    'total_ms',total_time,'self_ms',self_time) order by total_time desc)
  from pg_stat_xact_user_functions
  where calls>0 and funcname in ('prepare_school_catering_purchase_orders',
    'purchase_review_materialize_default_allocations','release_confirmed_needs',
    'release_school_catering_purchase_handoff','purchase_review_promote_allocations',
    'create_school_catering_purchase_order_drafts'))
)::text);

select is(
  (select response->>'success' from scale_results where name = 'prepare'),
  'true',
  'one authenticated public Purchase Preparation succeeds for 236 families'
);
select ok(
  (select pg_catalog.date_part('epoch', command_finished_at - started_at) * 1000 < 20000
    from scale_results where name = 'prepare'),
  'outer Purchase Preparation statement completes within the hoisted 20-second budget'
);
select ok(
  (select pg_catalog.date_part('epoch', guards_finished_at - started_at) * 1000 < 15000
    from scale_results where name = 'prepare'),
  'complete public Purchase Preparation command satisfies the provisional 15-second performance target'
);
select ok(
  (select pg_catalog.date_part('epoch', guards_finished_at - started_at) * 1000 < 20000
    from scale_results where name = 'prepare'),
  'Purchase Preparation plus all deferred integrity guards completes within 20 seconds'
);

-- The generated supporting revisions carry the one outer operator command;
-- no 236 per-row Save receipts or MANUAL decisions may appear.
select is(
  (select count(*)
    from atlas_procurement.school_catering_allocation_family_revisions revision
    where revision.source_kind = 'CONFIRMED_NEED'
      and revision.source_confirmed_need_batch_id = md5('purchase-preparation-scale:confirmed-need-batch')::uuid
      and revision.decision_origin = 'PRIORITY_RECOMMENDATION'),
  236::bigint,
  'preparation materializes exactly 236 preferred-Supplier default revisions'
);
select ok(
  not exists (
    select 1
    from atlas_procurement.school_catering_allocation_family_revisions revision
    where revision.source_confirmed_need_batch_id = md5('purchase-preparation-scale:confirmed-need-batch')::uuid
      and (
        revision.decision_origin = 'MANUAL'
        or revision.command_id <> (
          select (request->>'command_id')::uuid from scale_requests where name = 'prepare'
        )
        or revision.accepted_by_actor_id <> 'b6000000-0000-0000-0000-000000000001'
        or revision.source_confirmed_need_batch_version <> 2
      )
  ),
  'every generated default preserves outer command, Actor, source batch and version lineage'
);
select is(
  (select count(*)
    from atlas_core.command_receipts receipt
    where receipt.command_name in (
      'save_confirmed_supplier_allocation',
      'confirm_school_catering_supplier_recommendations'
    )),
  0::bigint,
  'preparation manufactures no per-row allocation Save or confirmation receipt'
);

select is(
  (select count(*)
    from atlas_procurement.school_catering_allocation_families family
    where family.service_date = date '2027-01-18'),
  236::bigint,
  'preparation creates exactly 236 allocation families'
);
select ok(
  not exists (
    select 1
    from atlas_procurement.school_catering_allocation_families family
    where family.service_date = date '2027-01-18'
    group by family.service_date, family.delivery_location_id, family.ingredient_id, family.unit_id
    having count(*) <> 1
  ),
  'scale preparation creates no duplicate family identity'
);
select ok(
  not exists (
    select 1
    from atlas_procurement.school_catering_allocation_families family
    left join atlas_procurement.school_catering_allocation_family_revisions revision
      on revision.family_id = family.family_id and revision.is_current
    where family.service_date = date '2027-01-18'
    group by family.family_id
    having count(revision.family_revision_id) <> 1
  ),
  'every scale family has exactly one current revision'
);
select is(
  (select count(*)
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
    where family.service_date = date '2027-01-18'
      and revision.is_current
      and revision.source_kind = 'PURCHASE_HANDOFF'
      and revision.decision_origin = 'PRIORITY_RECOMMENDATION'),
  236::bigint,
  'all 236 families are current promoted Handoff defaults'
);
select ok(
  not exists (
    select 1
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
    where family.service_date = date '2027-01-18'
      and revision.is_current
      and (
        revision.predecessor_revision_id is null
        or revision.source_purchase_handoff_revision_id is null
        or revision.source_confirmed_need_batch_id is not null
      )
  ),
  'current Handoff revisions retain their confirmed predecessor and strict source kind'
);

select ok(
  not exists (
    select 1
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
    left join lateral (
      select
        count(*) as split_count,
        pg_catalog.sum(split.allocated_quantity) as split_total,
        pg_catalog.min(split.allocated_quantity) as minimum_split,
        pg_catalog.min(split.split_ratio) as minimum_ratio,
        pg_catalog.max(split.split_ratio) as maximum_ratio,
        pg_catalog.min(split.supplier_id::text)::uuid as supplier_id
      from atlas_procurement.school_catering_allocation_supplier_splits split
      where split.family_revision_id = revision.family_revision_id
    ) split_summary on true
    left join atlas_admin.supplier_eligibilities eligibility
      on eligibility.ingredient_id = family.ingredient_id
     and eligibility.supplier_id = split_summary.supplier_id
     and eligibility.priority = 1
     and eligibility.eligibility_status = 'ACTIVE'
     and eligibility.effective_from <= family.service_date
     and (eligibility.effective_to is null or eligibility.effective_to > family.service_date)
    where family.service_date = date '2027-01-18'
      and revision.is_current
      and (
        split_summary.split_count <> 1
        or split_summary.split_total <> revision.family_quantity
        or split_summary.minimum_split <= 0
        or split_summary.minimum_ratio <> 1
        or split_summary.maximum_ratio <> 1
        or eligibility.supplier_eligibility_id is null
      )
  ),
  'every current family has one exact positive 100-percent split to its unique preferred Supplier'
);

-- Confirmed-source fingerprints bind the exact 236 saved decisions. Current
-- Handoff fingerprints bind the exact promoted line membership and quantities.
select is(
  (select count(*)
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
    join lateral atlas_core.purchase_review_confirmed_batch_sources(
      md5('purchase-preparation-scale:confirmed-need-batch')::uuid
    ) source(value)
      on (source.value->>'service_date')::date = family.service_date
     and (source.value->>'delivery_location_id')::uuid = family.delivery_location_id
     and (source.value->>'ingredient_id')::uuid = family.ingredient_id
     and (source.value->>'unit_id')::uuid = family.unit_id
     and source.value->>'source_fingerprint' = revision.source_fingerprint
     and (source.value->>'family_quantity')::numeric = revision.family_quantity
    where family.service_date = date '2027-01-18'
      and revision.source_kind = 'CONFIRMED_NEED'
      and revision.decision_origin = 'PRIORITY_RECOMMENDATION'),
  236::bigint,
  'all generated default fingerprints and quantities match canonical Confirmed Need authority'
);
select is(
  (select count(*)
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        family.service_date,
        family.delivery_location_id,
        family.ingredient_id,
        family.unit_id
      ) as projection
    ) current_source
    where family.service_date = date '2027-01-18'
      and revision.is_current
      and revision.source_kind = 'PURCHASE_HANDOFF'
      and revision.source_fingerprint = current_source.projection->>'source_fingerprint'
      and revision.family_quantity = (current_source.projection->>'family_quantity')::numeric),
  236::bigint,
  'all current Handoff fingerprints and quantities match canonical Handoff authority'
);

select is(
  (select count(*)
    from atlas_planning.purchase_handoff_batches handoff
    where handoff.confirmed_need_batch_id = md5('purchase-preparation-scale:confirmed-need-batch')::uuid
      and handoff.handoff_status = 'RELEASED_TO_PROCUREMENT'),
  1::bigint,
  'preparation creates one current released Handoff batch'
);
select is(
  (select count(*)
    from atlas_planning.purchase_handoff_batches handoff
    join atlas_planning.purchase_handoff_revisions header using (purchase_handoff_batch_id)
    join atlas_planning.purchase_handoff_line_revisions line
      on line.purchase_handoff_revision_id = header.purchase_handoff_revision_id
    join atlas_planning.confirmed_need_line_revisions confirmed
      on confirmed.confirmed_need_line_revision_id = line.confirmed_need_line_revision_id
    where handoff.confirmed_need_batch_id = md5('purchase-preparation-scale:confirmed-need-batch')::uuid
      and header.is_current
      and header.revision_status = 'RELEASED_TO_PROCUREMENT'
      and line.handoff_quantity = confirmed.confirmed_quantity
      and line.ingredient_id = confirmed.ingredient_id
      and line.unit_id = confirmed.unit_id
      and line.service_date = confirmed.service_date
      and line.delivery_location_id = confirmed.delivery_location_id),
  236::bigint,
  'current Handoff preserves all 236 exact Confirmed Need quantities and identities'
);

select is(
  (select count(*)
    from atlas_procurement.purchase_orders purchase_order
    where purchase_order.school_catering_service_date = date '2027-01-18'
      and purchase_order.purchase_order_kind = 'SCHOOL_CATERING'
      and purchase_order.purchase_order_status = 'DRAFT'
      and purchase_order.version = 1),
  12::bigint,
  'preparation consolidates 236 families into 12 valid Supplier PO Drafts'
);
select is(
  (select count(*)
    from atlas_procurement.purchase_orders purchase_order
    join atlas_procurement.purchase_order_lines line using (purchase_order_id)
    where purchase_order.school_catering_service_date = date '2027-01-18'
      and purchase_order.purchase_order_kind = 'SCHOOL_CATERING'
      and purchase_order.purchase_order_status = 'DRAFT'),
  236::bigint,
  'the 12 current Draft POs contain exactly 236 stable PO lines in total'
);
select ok(
  (select count(*) = 236
      and count(distinct revision_line.school_catering_allocation_supplier_split_id) = 236
      and count(distinct stable_line.school_catering_allocation_family_id) = 236
    from atlas_procurement.purchase_orders purchase_order
    join atlas_procurement.purchase_order_revisions revision using (purchase_order_id)
    join atlas_procurement.purchase_order_line_revisions revision_line
      using (purchase_order_revision_id)
    join atlas_procurement.purchase_order_lines stable_line
      on stable_line.purchase_order_line_id = revision_line.purchase_order_line_id
    where purchase_order.school_catering_service_date = date '2027-01-18'
      and purchase_order.purchase_order_kind = 'SCHOOL_CATERING'
      and purchase_order.purchase_order_status = 'DRAFT'
      and revision.is_current
      and revision.revision_status = 'DRAFT'),
  'current PO Draft lines map one-to-one to 236 unique Supplier splits and allocation families'
);
with current_draft_lines as materialized (
  select
    purchase_order.supplier_id,
    stable_line.school_catering_allocation_family_id as stable_family_id,
    line.school_catering_allocation_supplier_split_id as supplier_split_id,
    line.ordered_quantity,
    line.ingredient_id,
    line.unit_id,
    line.delivery_location_id,
    line.service_date
  from atlas_procurement.purchase_orders purchase_order
  join atlas_procurement.purchase_order_revisions revision using (purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions line
    using (purchase_order_revision_id)
  join atlas_procurement.purchase_order_lines stable_line
    on stable_line.purchase_order_line_id = line.purchase_order_line_id
  where purchase_order.school_catering_service_date = date '2027-01-18'
    and purchase_order.purchase_order_kind = 'SCHOOL_CATERING'
    and purchase_order.purchase_order_status = 'DRAFT'
    and revision.is_current
    and revision.revision_status = 'DRAFT'
), traced_lines as materialized (
  select
    current_line.*,
    split.supplier_id as split_supplier_id,
    split.allocated_quantity,
    allocation.family_id as traced_family_id,
    family.ingredient_id as family_ingredient_id,
    family.unit_id as family_unit_id,
    family.delivery_location_id as family_delivery_location_id,
    family.service_date as family_service_date
  from current_draft_lines current_line
  left join atlas_procurement.school_catering_allocation_supplier_splits split
    on split.supplier_split_id = current_line.supplier_split_id
  left join atlas_procurement.school_catering_allocation_family_revisions allocation
    on allocation.family_revision_id = split.family_revision_id
  left join atlas_procurement.school_catering_allocation_families family
    on family.family_id = allocation.family_id
)
select ok(
  (select count(*) = 236
      and count(*) filter (
        where supplier_id = split_supplier_id
          and ordered_quantity = allocated_quantity
          and ingredient_id = family_ingredient_id
          and unit_id = family_unit_id
          and delivery_location_id = family_delivery_location_id
          and service_date = family_service_date
          and stable_family_id = traced_family_id
      ) = 236
    from traced_lines),
  'all 236 PO Draft lines preserve exact Supplier, family, quantity and split lineage'
);

create temporary table scale_after_success as
select
  pg_temp.scale_business_snapshot() as business_snapshot,
  (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(receipt)
    order by pg_catalog.to_jsonb(receipt)::text)
    from atlas_core.command_receipts receipt) as receipt_snapshot;

set local role authenticated;
select pg_catalog.set_config(
  'statement_timeout',
  pg_catalog.split_part(setting, '=', 2),
  true
)
from pg_catalog.pg_proc function_row
cross join lateral pg_catalog.unnest(function_row.proconfig) setting
where function_row.oid =
    'atlas_api.prepare_school_catering_purchase_orders(jsonb)'::pg_catalog.regprocedure
  and setting like 'statement_timeout=%';
insert into scale_results(name, response)
select
  'prepare-replay',
  atlas_api.prepare_school_catering_purchase_orders(request)
from scale_requests
where name = 'prepare';
set constraints all immediate;
reset role;
set local statement_timeout = '8s';
set constraints all deferred;

select is(
  (select response from scale_results where name = 'prepare-replay'),
  (select response from scale_results where name = 'prepare'),
  'identical scale replay returns the exact original durable response'
);
select is(
  pg_temp.scale_business_snapshot(),
  (select business_snapshot from scale_after_success),
  'identical scale replay creates no new Need, allocation, Handoff, PO, event or audit fact'
);
select is(
  (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(receipt)
    order by pg_catalog.to_jsonb(receipt)::text)
    from atlas_core.command_receipts receipt),
  (select receipt_snapshot from scale_after_success),
  'identical scale replay creates no new receipt'
);

select * from finish();
rollback;

-- The controlled late failure runs in a second transaction in the same SQL
-- suite. Rolling back the successful case removes its 236 logical families,
-- Handoff and PO facts, so this case measures an independent 236-family daily
-- workload rather than a database containing the successful workload's rows.
-- Schema metadata and server cache remain shared, as they would for consecutive
-- operating days; the second ANALYZE below describes only the new daily facts.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(11);
\ir ../local/purchase_preparation_scale_fixture.sql

do $seed_failure_scale$
begin
  perform pg_temp.seed_purchase_preparation_scale(
    'purchase-preparation-scale-failure',
    'scale-failure',
    date '2027-01-25'
  );
end;
$seed_failure_scale$;

insert into scale_requests(name, request)
values (
  'save-confirmed-need-failure',
  pg_temp.scale_confirmed_need_save_command(
    'save-confirmed-need-failure',
    md5('purchase-preparation-scale-failure:confirmed-need-batch')::uuid
  )
);
-- The first rollback removes transaction-local JWT state as well as data and
-- TEMP objects. Re-establish the same operator subject for both public calls.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000101',
  true
);
set local statement_timeout = '8s';
set local role authenticated;
insert into scale_results(name, response)
select 'save-confirmed-need-failure', atlas_api.save_confirmed_needs(request)
from scale_requests
where name = 'save-confirmed-need-failure';
set constraints all immediate;
reset role;
set constraints all deferred;

select is(
  (select response->>'success' from scale_results where name = 'save-confirmed-need-failure'),
  'true',
  'independent rollback setup saves all 236 Confirmed Need decisions through one authenticated public command'
);
select ok(
  (select count(*) = 236
     from atlas_planning.confirmed_need_line_decisions
     where confirmed_need_batch_id = md5('purchase-preparation-scale-failure:confirmed-need-batch')::uuid)
  and not exists (
    select 1
    from atlas_procurement.school_catering_allocation_families
    where service_date = date '2027-01-25'
  ),
  'independent rollback setup has 236 current decisions and zero persisted allocation families'
);
select ok(
  (select count(*) = 236
     from atlas_core.purchase_review_confirmed_batch_sources(
       md5('purchase-preparation-scale-failure:confirmed-need-batch')::uuid
     ) source(value)
     where source.value->>'complete' = 'true'
       and (source.value->>'family_quantity')::numeric > 0)
  and (select count(*) = 236
     from atlas_core.purchase_review_confirmed_batch_sources(
       md5('purchase-preparation-scale-failure:confirmed-need-batch')::uuid
     ) source(value)
     where atlas_core.purchase_review_supplier_advice(
       (source.value->>'service_date')::date,
       (source.value->>'ingredient_id')::uuid,
       (source.value->>'family_quantity')::numeric
     )->'recommendation' <> 'null'::jsonb),
  'independent rollback setup has 236 complete sources and 236 safe preferred recommendations'
);

-- Refresh ordinary statistics for the newly inserted independent failure seed.
-- The next public preparation remains the first attempt for that namespace.
do $scale_failure_statistics$
declare relation record;
begin
  for relation in select schemaname,relname from pg_catalog.pg_stat_user_tables
    where schemaname in ('atlas_admin','atlas_planning','atlas_procurement','atlas_core')
  loop
    execute pg_catalog.format('analyze %I.%I',relation.schemaname,relation.relname);
  end loop;
end;
$scale_failure_statistics$;

insert into scale_requests(name, request)
select
  'late-po-failure',
  pg_temp.scale_command(
    'late-po-failure',
    'PURCHASE-COMMITMENT.v1',
    'PURCHASE_ORDERS_PREPARED',
    batch.version,
    pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id', batch.confirmed_need_batch_id,
      'service_date', batch.period_start
    )
  )
from atlas_planning.confirmed_need_batches batch
where batch.confirmed_need_batch_id = md5('purchase-preparation-scale-failure:confirmed-need-batch')::uuid;

create temporary table scale_before_failure as
select
  pg_temp.scale_business_snapshot() as business_snapshot,
  (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(receipt)
    order by pg_catalog.to_jsonb(receipt)::text)
    from atlas_core.command_receipts receipt) as receipt_snapshot;

-- Sequences are deliberately nontransactional observation channels. The late
-- trigger records that all 236 defaults and all 236 promoted Handoff families
-- existed before it rejects the first PO insert; the command then must roll all
-- of them back.
create temporary sequence scale_po_attempt minvalue 0 start 0;
create temporary sequence scale_seen_defaults minvalue 0 start 0;
create temporary sequence scale_seen_handoff_families minvalue 0 start 0;
create function pg_temp.reject_scale_purchase_order() returns trigger
language plpgsql security definer
set search_path=''
as $$
declare
  failure_command_id uuid := (
    select (request->>'command_id')::uuid
    from pg_temp.scale_requests
    where name = 'late-po-failure'
  );
  default_count bigint;
  handoff_count bigint;
begin
  select count(*)
  into default_count
  from atlas_procurement.school_catering_allocation_families family
  join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
  where family.service_date = date '2027-01-25'
    and revision.source_kind = 'CONFIRMED_NEED'
    and revision.decision_origin = 'PRIORITY_RECOMMENDATION'
    and revision.command_id = failure_command_id;

  select count(*)
  into handoff_count
  from atlas_procurement.school_catering_allocation_families family
  join atlas_procurement.school_catering_allocation_family_revisions revision using (family_id)
  where family.service_date = date '2027-01-25'
    and revision.is_current
    and revision.source_kind = 'PURCHASE_HANDOFF'
    and revision.decision_origin = 'PRIORITY_RECOMMENDATION';

  perform pg_catalog.setval('pg_temp.scale_seen_defaults'::regclass, default_count, true);
  perform pg_catalog.setval('pg_temp.scale_seen_handoff_families'::regclass, handoff_count, true);
  perform pg_catalog.nextval('pg_temp.scale_po_attempt'::regclass);
  raise exception using errcode = 'PPR98', message = 'Synthetic scale PO failure';
end;
$$;
create trigger reject_scale_purchase_order
before insert on atlas_procurement.purchase_orders
for each row execute function pg_temp.reject_scale_purchase_order();

set local role authenticated;
select pg_catalog.set_config(
  'statement_timeout',
  pg_catalog.split_part(setting, '=', 2),
  true
)
from pg_catalog.pg_proc function_row
cross join lateral pg_catalog.unnest(function_row.proconfig) setting
where function_row.oid =
    'atlas_api.prepare_school_catering_purchase_orders(jsonb)'::pg_catalog.regprocedure
  and setting like 'statement_timeout=%';
\echo purchase_preparation_scale public_prepare statement_timeout=20s families=236
\timing on
with started as materialized (
  select pg_catalog.clock_timestamp() as started_at
), invoked as materialized (
  select atlas_api.prepare_school_catering_purchase_orders(request) as response,
    started.started_at
  from scale_requests
  cross join started
  where name = 'late-po-failure'
)
insert into scale_results(name, response, started_at, command_finished_at)
select
  'late-po-failure',
  invoked.response,
  invoked.started_at,
  pg_catalog.clock_timestamp()
from invoked;
\timing off
reset role;
drop trigger reject_scale_purchase_order on atlas_procurement.purchase_orders;
set constraints all immediate;
set local statement_timeout = '8s';
update scale_results
set guards_finished_at = pg_catalog.clock_timestamp()
where name = 'late-po-failure';
set constraints all deferred;

select diag(pg_catalog.format(
  'purchase_preparation_scale late_failure_command_ms=%s late_failure_guard_ms=%s late_failure_total_ms=%s families=236 statement_timeout=20s',
  (select pg_catalog.round(pg_catalog.date_part('epoch', command_finished_at - started_at)::numeric * 1000, 3)
    from scale_results where name = 'late-po-failure'),
  (select pg_catalog.round(pg_catalog.date_part('epoch', guards_finished_at - command_finished_at)::numeric * 1000, 3)
    from scale_results where name = 'late-po-failure'),
  (select pg_catalog.round(pg_catalog.date_part('epoch', guards_finished_at - started_at)::numeric * 1000, 3)
    from scale_results where name = 'late-po-failure')
));

select ok(
  (select is_called from scale_po_attempt),
  'scale rollback reaches the late PO insert'
);
select is(
  (select last_value from scale_seen_defaults),
  236::bigint,
  'late PO failure observes all 236 generated default revisions before rollback'
);
select is(
  (select last_value from scale_seen_handoff_families),
  236::bigint,
  'late PO failure observes all 236 promoted current Handoff families before rollback'
);
select is(
  (select response->>'success' from scale_results where name = 'late-po-failure'),
  'false',
  'late PO failure returns a safe failed preparation response'
);
select ok(
  (select pg_catalog.date_part('epoch', command_finished_at - started_at) * 1000 < 20000
    from scale_results where name = 'late-po-failure'),
  'late PO rollback pipeline reaches the controlled rejection within the hoisted 20-second budget'
);
select is(
  pg_temp.scale_business_snapshot(),
  (select business_snapshot from scale_before_failure),
  'late PO failure rolls back defaults, release, Handoff, promotion, PO and audit facts exactly'
);
select is(
  (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(receipt)
    order by pg_catalog.to_jsonb(receipt)::text)
    from atlas_core.command_receipts receipt
    where receipt.command_id <> (
      select (request->>'command_id')::uuid
      from scale_requests
      where name = 'late-po-failure'
    )),
  (select receipt_snapshot from scale_before_failure),
  'failed scale preparation leaves no accepted child receipt'
);
select ok(
  (select batch_status = 'DRAFT_REVIEW' and version = 2
    from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id = md5('purchase-preparation-scale-failure:confirmed-need-batch')::uuid),
  'failed scale preparation preserves the saved Confirmed Need authority'
);

select * from finish();
rollback;
