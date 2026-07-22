begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(56);

insert into atlas_core.actors (actor_id, actor_type, display_name)
values ('b6200000-0000-0000-0000-000000000001', 'HUMAN', 'H0B1b wholesale planner');
insert into atlas_core.actor_auth_subjects (actor_id, auth_subject_id)
values ('b6200000-0000-0000-0000-000000000001', 'b6200000-0000-0000-0000-000000000101');
insert into atlas_core.roles (role_id, role_code, role_name)
values ('b6200000-0000-0000-0000-000000000201', 'h0b1b.wholesale.planner', 'H0B1b wholesale planner');
insert into atlas_core.capabilities (capability_id, capability_code, capability_name, owning_domain) values
  ('b6200000-0000-0000-0000-000000000211', 'wholesale_source.record', 'Record wholesale source', 'PLANNING'),
  ('b6200000-0000-0000-0000-000000000212', 'wholesale_order.release', 'Release wholesale order', 'PLANNING'),
  ('b6200000-0000-0000-0000-000000000213', 'purchase_handoff.release', 'Release purchase handoff', 'PLANNING'),
  ('b6200000-0000-0000-0000-000000000214', 'dispatch_requirement.release', 'Release dispatch requirement', 'PLANNING');
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'b6200000-0000-0000-0000-000000000201', capability_id
from atlas_core.capabilities
where capability_code in ('wholesale_source.record','wholesale_order.release','purchase_handoff.release','dispatch_requirement.release');
insert into atlas_core.actor_role_memberships (actor_id, role_id)
values ('b6200000-0000-0000-0000-000000000001', 'b6200000-0000-0000-0000-000000000201');

insert into atlas_admin.customers (customer_id, customer_code, customer_name)
values ('b6200000-0000-0000-0000-000000000301', 'h0b1b-wholesale-customer', 'H0B1b wholesale customer');
insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text)
values ('b6200000-0000-0000-0000-000000000302', 'b6200000-0000-0000-0000-000000000301', 'h0b1b-wholesale-location', 'H0B1b wholesale location', 'Local fixture');
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('b6200000-0000-0000-0000-000000000311', 'h0b1b-wholesale-kg', 'H0B1b kilogram', 'mass'),
  ('b6200000-0000-0000-0000-000000000312', 'h0b1b-wholesale-box', 'H0B1b box', 'count');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('b6200000-0000-0000-0000-000000000321', 'h0b1b-wholesale-rice', 'H0B1b wholesale rice'),
  ('b6200000-0000-0000-0000-000000000322', 'h0b1b-wholesale-oil', 'H0B1b wholesale oil');
insert into atlas_core.actor_scopes (actor_id, scope_kind, customer_id)
values ('b6200000-0000-0000-0000-000000000001', 'CUSTOMER', 'b6200000-0000-0000-0000-000000000301');

create temporary table h0b1b_wholesale_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert, update on h0b1b_wholesale_results to authenticated;

create function pg_temp.h0b1b_wholesale_request(
  p_command_id uuid,
  p_idempotency_key text,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'PA-05D.v1',
    'command_id', p_command_id,
    'correlation_id', 'b6200000-0000-0000-0000-000000000901'::uuid,
    'idempotency_key', p_idempotency_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', 'b6200000-0000-0000-0000-000000000101'::uuid,
    'requested_at', '2026-07-22T08:00:00+07:00',
    'reason_code', 'H0B1B_WHOLESALE_TEST',
    'reason_note', 'H0B1b rolled-back compatibility fixture',
    'payload', p_payload
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b6200000-0000-0000-0000-000000000101', true);
insert into h0b1b_wholesale_results values (
  'record',
  atlas_api.record_wholesale_source(pg_temp.h0b1b_wholesale_request(
    'b6200000-0000-0000-0000-000000000401',
    'h0b1b-wholesale-record',
    1,
    jsonb_build_object(
      'customer_id', 'b6200000-0000-0000-0000-000000000301',
      'delivery_location_id', 'b6200000-0000-0000-0000-000000000302',
      'customer_order_reference', 'H0B1B-WHOLESALE-ORDER',
      'service_date', '2026-07-23',
      'lines', jsonb_build_array(
        jsonb_build_object('source_line_number', 1, 'ingredient_id', 'b6200000-0000-0000-0000-000000000321', 'requested_quantity', 10, 'unit_id', 'b6200000-0000-0000-0000-000000000311'),
        jsonb_build_object('source_line_number', 2, 'ingredient_id', 'b6200000-0000-0000-0000-000000000322', 'requested_quantity', 3, 'unit_id', 'b6200000-0000-0000-0000-000000000312')
      )
    )
  ))
);
insert into h0b1b_wholesale_results values (
  'release',
  atlas_api.release_wholesale_order(pg_temp.h0b1b_wholesale_request(
    'b6200000-0000-0000-0000-000000000402',
    'h0b1b-wholesale-release',
    1,
    jsonb_build_object('wholesale_order_id', (select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from h0b1b_wholesale_results where result_name = 'record'))
  ))
);
insert into h0b1b_wholesale_results values (
  'release_replay',
  atlas_api.release_wholesale_order(pg_temp.h0b1b_wholesale_request(
    'b6200000-0000-0000-0000-000000000402',
    'h0b1b-wholesale-release',
    1,
    jsonb_build_object('wholesale_order_id', (select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from h0b1b_wholesale_results where result_name = 'record'))
  ))
);
insert into h0b1b_wholesale_results values (
  'handoff',
  atlas_api.release_purchase_handoff(pg_temp.h0b1b_wholesale_request(
    'b6200000-0000-0000-0000-000000000403',
    'h0b1b-wholesale-handoff',
    1,
    jsonb_build_object('confirmed_need_batch_id', (select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from h0b1b_wholesale_results where result_name = 'release'))
  ))
);
insert into h0b1b_wholesale_results values (
  'requirement',
  atlas_api.release_dispatch_requirement(pg_temp.h0b1b_wholesale_request(
    'b6200000-0000-0000-0000-000000000404',
    'h0b1b-wholesale-requirement',
    1,
    jsonb_build_object('purchase_handoff_revision_id', (select response_payload #>> '{affected_aggregate_ids,purchase_handoff_revision_id}' from h0b1b_wholesale_results where result_name = 'handoff'))
  ))
);
reset role;

select lives_ok($$ set constraints all immediate; set constraints all deferred $$, 'unchanged PA-05D path satisfies H0B1b deferred integrity');
select ok((select (response_payload ->> 'success')::boolean from h0b1b_wholesale_results where result_name = 'record'), 'unchanged PA-05D source recording succeeds');
select ok((select (response_payload ->> 'success')::boolean from h0b1b_wholesale_results where result_name = 'release'), 'unchanged PA-05D Wholesale release succeeds');
select ok((select (response_payload ->> 'success')::boolean from h0b1b_wholesale_results where result_name = 'release_replay'), 'unchanged PA-05D release replay succeeds');
select is((select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from h0b1b_wholesale_results where result_name = 'release_replay'), (select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from h0b1b_wholesale_results where result_name = 'release'), 'release replay returns the original Confirmed Need identity');
select ok((select (response_payload ->> 'success')::boolean from h0b1b_wholesale_results where result_name = 'handoff'), 'unchanged PA-05D Purchase Handoff release succeeds');
select ok((select (response_payload ->> 'success')::boolean from h0b1b_wholesale_results where result_name = 'requirement'), 'unchanged PA-05D Dispatch Requirement release succeeds');
select ok((select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' is not null from h0b1b_wholesale_results where result_name = 'release'), 'Wholesale release response retains the generated Confirmed Need identity');
select is((select count(*)::integer from atlas_audit.domain_events where event_type = 'WholesaleOrderReleased' and command_id = 'b6200000-0000-0000-0000-000000000402'), 1, 'Wholesale release event name and command identity are unchanged');

select is((select source_kind from atlas_planning.confirmed_need_batches), 'WHOLESALE', 'PA-05D batch is classified WHOLESALE');
select is((select wholesale_order_id is not null from atlas_planning.confirmed_need_batches), true, 'WHOLESALE batch retains its exact source order');
select is((select num_nulls(origin_need_generation_run_id,origin_need_generation_run_version,origin_need_generation_release_snapshot_id,current_need_generation_run_id,current_need_generation_run_version,current_need_generation_release_snapshot_id) from atlas_planning.confirmed_need_batches), 6, 'WHOLESALE batch has no Need Generation source fields');
select is((select batch_status from atlas_planning.confirmed_need_batches), 'RELEASED_FOR_PURCHASE_HANDOFF', 'PA-05D batch lifecycle is unchanged');
select is((select version from atlas_planning.confirmed_need_batches), 1::bigint, 'PA-05D batch version is unchanged');
select is((select row(period_start,period_end)::text from atlas_planning.confirmed_need_batches), '(2026-07-23,2026-07-23)', 'PA-05D batch period remains the service date');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines), 2, 'PA-05D release creates the same two stable lines');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where source_kind = 'WHOLESALE'), 2, 'every PA-05D stable line is WHOLESALE');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where wholesale_order_line_id is not null), 2, 'every WHOLESALE stable line retains exact line lineage');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where num_nonnulls(service_date,customer_id,school_id,delivery_location_id,ingredient_id,controlled_unit_id) <> 0), 0, 'WHOLESALE stable lines have zero school-catering identity fields');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions), 2, 'PA-05D release creates the same two line revisions');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where source_kind = 'WHOLESALE'), 2, 'every PA-05D revision is WHOLESALE');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id is not null), 2, 'compatibility guard fills exact batch ownership on unchanged inserts');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where wholesale_order_line_revision_id is not null), 2, 'every WHOLESALE revision retains exact source revision lineage');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where num_nonnulls(need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,service_date,customer_id,school_id,delivery_location_id) <> 0), 0, 'WHOLESALE revisions have zero Need Generation and school identity fields');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where theoretical_quantity = confirmed_quantity), 2, 'WHOLESALE theoretical and confirmed quantities remain pass-through equal');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions revision join atlas_planning.wholesale_order_line_revisions source using (wholesale_order_line_revision_id) where revision.theoretical_quantity = source.requested_quantity), 2, 'WHOLESALE theoretical quantities equal exact source quantities');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions revision join atlas_planning.wholesale_order_line_revisions source using (wholesale_order_line_revision_id) where revision.unit_id = source.unit_id), 2, 'WHOLESALE Units equal exact source Units');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions revision join atlas_planning.wholesale_order_line_revisions source using (wholesale_order_line_revision_id) where revision.ingredient_id = source.ingredient_id), 2, 'WHOLESALE Ingredients equal exact source Ingredients');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where is_current), 2, 'WHOLESALE current-row behavior is unchanged');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where revision_status = 'RELEASED'), 2, 'WHOLESALE revision lifecycle is unchanged');
select is((select count(*)::integer from atlas_planning.confirmed_need_approval_snapshots), 1, 'PA-05D still creates one approval snapshot');
select is((select count(*)::integer from atlas_planning.confirmed_need_snapshot_lines), 2, 'PA-05D still creates exact approval snapshot membership');
select is((select count(*)::integer from atlas_planning.confirmed_need_snapshot_lines snapshot_line join atlas_planning.confirmed_need_line_revisions revision using (confirmed_need_line_revision_id) where snapshot_line.approved_quantity = revision.confirmed_quantity), 2, 'approval snapshot quantities remain exact');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions), 0, 'WHOLESALE revisions have zero contribution memberships');
select is((select order_status from atlas_planning.wholesale_orders), 'RELEASED', 'Wholesale Order lifecycle remains released');
select is((select count(*)::integer from atlas_planning.wholesale_order_line_revisions where revision_status = 'RELEASED'), 2, 'Wholesale source revisions retain released lifecycle');
select is((select count(*)::integer from atlas_planning.purchase_handoff_batches), 1, 'unchanged PA-05D creates one Purchase Handoff');
select is((select count(*)::integer from atlas_planning.purchase_handoff_lines), 2, 'unchanged PA-05D creates two handoff lines');
select is((select count(*)::integer from atlas_planning.purchase_demand_references), 2, 'unchanged PA-05D preserves two exact demand references');
select is((select count(*)::integer from atlas_planning.dispatch_requirements), 1, 'unchanged PA-05D creates one Dispatch Requirement');
select is((select count(*)::integer from atlas_planning.dispatch_requirement_lines), 2, 'unchanged PA-05D preserves two requirement lines');
select is((select count(*)::integer from atlas_audit.domain_events where command_id in ('b6200000-0000-0000-0000-000000000401','b6200000-0000-0000-0000-000000000402','b6200000-0000-0000-0000-000000000403','b6200000-0000-0000-0000-000000000404')), 4, 'four successful commands retain four domain events');
select is((select count(*)::integer from atlas_audit.audit_events where command_id in ('b6200000-0000-0000-0000-000000000401','b6200000-0000-0000-0000-000000000402','b6200000-0000-0000-0000-000000000403','b6200000-0000-0000-0000-000000000404')), 4, 'four successful commands retain four audit events');
select is((select count(*)::integer from atlas_core.command_receipts where command_id in ('b6200000-0000-0000-0000-000000000401','b6200000-0000-0000-0000-000000000402','b6200000-0000-0000-0000-000000000403','b6200000-0000-0000-0000-000000000404')), 4, 'four successful commands retain four completed receipts');

select throws_ok($$ insert into atlas_planning.confirmed_need_batches (confirmed_need_batch_id,wholesale_order_id,period_start,period_end,created_by_actor_id,source_kind) values ('b6200000-0000-0000-0000-000000000501',(select wholesale_order_id from atlas_planning.wholesale_orders),date '2026-07-23',date '2026-07-23','b6200000-0000-0000-0000-000000000001','OTHER') $$, '23514', null, 'unknown batch source kind is rejected');
select throws_ok($$ insert into atlas_planning.confirmed_need_batches (confirmed_need_batch_id,period_start,period_end,created_by_actor_id,source_kind) values ('b6200000-0000-0000-0000-000000000502',date '2026-07-23',date '2026-07-23','b6200000-0000-0000-0000-000000000001','WHOLESALE') $$, '23514', null, 'WHOLESALE batch cannot omit its order');
select throws_ok($$ insert into atlas_planning.confirmed_need_batches (confirmed_need_batch_id,wholesale_order_id,period_start,period_end,created_by_actor_id,source_kind,origin_need_generation_run_id,origin_need_generation_run_version,origin_need_generation_release_snapshot_id,current_need_generation_run_id,current_need_generation_run_version,current_need_generation_release_snapshot_id) values ('b6200000-0000-0000-0000-000000000503',(select wholesale_order_id from atlas_planning.wholesale_orders),date '2026-07-23',date '2026-07-23','b6200000-0000-0000-0000-000000000001','WHOLESALE','b6200000-0000-0000-0000-000000000601',1,'b6200000-0000-0000-0000-000000000602','b6200000-0000-0000-0000-000000000601',1,'b6200000-0000-0000-0000-000000000602') $$, '23514', null, 'WHOLESALE batch rejects Need Generation fields');
select throws_ok($$ insert into atlas_planning.confirmed_need_lines (confirmed_need_batch_id,wholesale_order_line_id,source_kind) select confirmed_need_batch_id,wholesale_order_line_id,'OTHER' from atlas_planning.confirmed_need_batches cross join lateral (select wholesale_order_line_id from atlas_planning.wholesale_order_lines limit 1) source $$, '23514', null, 'unknown stable-line source kind is rejected');
select throws_ok($$ insert into atlas_planning.confirmed_need_lines (confirmed_need_batch_id,wholesale_order_line_id,source_kind,service_date,customer_id,school_id,delivery_location_id,ingredient_id,controlled_unit_id) select confirmed_need_batch_id,wholesale_order_line_id,'WHOLESALE',date '2026-07-23','b6200000-0000-0000-0000-000000000301','b6200000-0000-0000-0000-000000000701','b6200000-0000-0000-0000-000000000302','b6200000-0000-0000-0000-000000000321','b6200000-0000-0000-0000-000000000311' from atlas_planning.confirmed_need_batches cross join lateral (select wholesale_order_line_id from atlas_planning.wholesale_order_lines limit 1) source $$, '23514', null, 'WHOLESALE stable line rejects school identity fields');
select throws_ok($$ insert into atlas_planning.confirmed_need_lines (confirmed_need_batch_id,source_kind) select confirmed_need_batch_id,'WHOLESALE' from atlas_planning.confirmed_need_batches $$, '23514', null, 'WHOLESALE stable line cannot omit its source line');
select throws_ok($$ insert into atlas_planning.confirmed_need_line_revisions (confirmed_need_line_id,revision_number,wholesale_order_line_revision_id,ingredient_id,theoretical_quantity,confirmed_quantity,unit_id,created_by_actor_id,source_kind) select confirmed_need_line_id,2,wholesale_order_line_revision_id,ingredient_id,theoretical_quantity,confirmed_quantity,unit_id,'b6200000-0000-0000-0000-000000000001','OTHER' from atlas_planning.confirmed_need_line_revisions limit 1 $$, '23514', null, 'unknown revision source kind is rejected');
select throws_ok($$ insert into atlas_planning.confirmed_need_line_revisions (confirmed_need_line_id,revision_number,ingredient_id,theoretical_quantity,confirmed_quantity,unit_id,created_by_actor_id,source_kind) select confirmed_need_line_id,2,ingredient_id,theoretical_quantity,confirmed_quantity,unit_id,'b6200000-0000-0000-0000-000000000001','WHOLESALE' from atlas_planning.confirmed_need_line_revisions limit 1 $$, '23514', null, 'WHOLESALE revision cannot omit its source revision');
select throws_ok($$ update atlas_planning.confirmed_need_lines target set wholesale_order_line_id = (select source.wholesale_order_line_id from atlas_planning.wholesale_order_lines source where source.wholesale_order_line_id <> target.wholesale_order_line_id order by source.wholesale_order_line_id limit 1) where target.confirmed_need_line_id = (select confirmed_need_line_id from atlas_planning.confirmed_need_lines order by confirmed_need_line_id limit 1) $$, '23514', 'Confirmed Need stable-line source identity is immutable', 'WHOLESALE stable-line identity cannot be cross-wired');
select throws_ok($$ update atlas_planning.confirmed_need_line_revisions set theoretical_quantity = theoretical_quantity + 1 where confirmed_need_line_revision_id = (select confirmed_need_line_revision_id from atlas_planning.confirmed_need_line_revisions order by confirmed_need_line_revision_id limit 1) $$, '23514', 'Confirmed Need revision source identity and theoretical total are immutable', 'WHOLESALE revision theoretical source total is immutable');
select throws_ok($$ update atlas_planning.confirmed_need_batches set period_end = period_end + 1 where confirmed_need_batch_id = (select confirmed_need_batch_id from atlas_planning.confirmed_need_batches) $$, '23514', 'Confirmed Need batch origin identity is immutable', 'WHOLESALE batch source period is immutable');
select throws_ok($$ insert into atlas_planning.confirmed_need_line_revision_contributions (confirmed_need_batch_id,confirmed_need_line_id,confirmed_need_line_revision_id,need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,need_generation_release_snapshot_line_id,theoretical_need_line_id,service_date,customer_id,school_id,delivery_location_id,ingredient_id,source_unit_id,controlled_unit_id,source_theoretical_quantity,controlled_contribution_quantity) select confirmed_need_batch_id,confirmed_need_line_id,confirmed_need_line_revision_id,'b6200000-0000-0000-0000-000000000601',1,'b6200000-0000-0000-0000-000000000602','b6200000-0000-0000-0000-000000000603','b6200000-0000-0000-0000-000000000604',date '2026-07-23','b6200000-0000-0000-0000-000000000301','b6200000-0000-0000-0000-000000000701','b6200000-0000-0000-0000-000000000302',ingredient_id,unit_id,unit_id,theoretical_quantity,theoretical_quantity from atlas_planning.confirmed_need_line_revisions limit 1 $$, '23514', 'Confirmed Need contribution does not match the exact active release member', 'WHOLESALE revision cannot receive contribution membership');

select * from finish();
rollback;
