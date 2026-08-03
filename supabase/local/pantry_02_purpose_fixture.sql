-- PANTRY-02 local/review-only Purpose fixture.
-- This file is never applied by migrations and creates no production rows.

do $pantry_02_fixture$
begin
execute $baseline_table$
  create unlogged table if not exists extensions.pantry_02_downstream_baseline (
    singleton boolean primary key default true check (singleton),
    downstream_counts jsonb not null
  )
$baseline_table$;

truncate table extensions.pantry_02_downstream_baseline;

insert into extensions.pantry_02_downstream_baseline (downstream_counts)
select jsonb_build_object(
  'planning_input_sets', (select count(*) from atlas_planning.planning_input_sets),
  'need_generation_runs', (select count(*) from atlas_planning.need_generation_runs),
  'confirmed_need_batches', (select count(*) from atlas_planning.confirmed_need_batches),
  'purchase_handoff_batches', (select count(*) from atlas_planning.purchase_handoff_batches),
  'wholesale_orders', (select count(*) from atlas_planning.wholesale_orders),
  'fulfilment_allocations', (select count(*) from atlas_procurement.fulfilment_allocations),
  'purchase_orders', (select count(*) from atlas_procurement.purchase_orders),
  'supplier_receiving_evidence', (select count(*) from atlas_evidence.supplier_receiving_evidence),
  'dispatch_plans', (select count(*) from atlas_dispatch.dispatch_plans)
);

insert into atlas_planning.pantry_need_purposes (
  pantry_need_purpose_id,
  purpose_code,
  purpose_name_vi,
  purpose_description,
  note_rule,
  purpose_status,
  display_order
) values
  (
    'a7200000-0000-4000-8000-000000000001',
    'school_requested_supplement',
    'Bổ sung theo yêu cầu của trường',
    'An identified School has explicitly requested an additional Ingredient quantity for the stated service date beyond the demand already represented by controlled Planning sources.',
    'REQUIRED',
    'ACTIVE',
    10
  ),
  (
    'a7200000-0000-4000-8000-000000000002',
    'planning_identified_supplement',
    'Bổ sung do bộ phận Kế hoạch xác định',
    'Planning or catering operations has identified a specific additional Ingredient quantity required to deliver service for the stated School and service date, and that quantity is not represented by another controlled Planning source.',
    'REQUIRED',
    'ACTIVE',
    20
  )
on conflict (pantry_need_purpose_id) do update
set
  purpose_code = excluded.purpose_code,
  purpose_name_vi = excluded.purpose_name_vi,
  purpose_description = excluded.purpose_description,
  note_rule = excluded.note_rule,
  purpose_status = excluded.purpose_status,
  display_order = excluded.display_order,
  version = atlas_planning.pantry_need_purposes.version + 1,
  updated_at = transaction_timestamp();

end
$pantry_02_fixture$;
