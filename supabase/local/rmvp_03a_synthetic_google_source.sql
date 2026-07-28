insert into atlas_planning.weekly_menu_google_sources (
  weekly_menu_google_source_id,
  source_code,
  source_name,
  spreadsheet_id,
  sheet_name_pattern,
  range_a1_template,
  source_status,
  display_order
) values (
  'a1030000-0000-4000-8000-000000000080',
  'rmvp03a.local.synthetic',
  'RMVP-03A Local Synthetic Google Source',
  'local-synthetic-spreadsheet-id',
  'Tuần {DD-MM-YYYY}',
  '''{sheet}''!A3:Z500',
  'ACTIVE',
  1
)
on conflict (source_code) do update
set source_name = excluded.source_name,
    spreadsheet_id = excluded.spreadsheet_id,
    sheet_name_pattern = excluded.sheet_name_pattern,
    range_a1_template = excluded.range_a1_template,
    source_status = excluded.source_status,
    display_order = excluded.display_order,
    version = atlas_planning.weekly_menu_google_sources.version + 1,
    updated_at = transaction_timestamp();
