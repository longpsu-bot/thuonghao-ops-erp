-- PANTRY-02 local/review-only Purpose fixture.
-- This file is never applied by migrations and creates no production rows.

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
