-- Local regression prerequisite only. Call after saving b650...050 decisions.
-- Public allocation commands run with ordinary triggers and authenticated Actor.
\ir school_catering_procurement_verifier_fixture.sql
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
do $allocate_saved_need$
declare row_data jsonb;result jsonb;command_id uuid;
begin
  for row_data in select value from jsonb_array_elements(atlas_api.get_confirmed_supplier_allocation_workbench(
    jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
      'payload',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02')))->'rows') loop
    command_id:=gen_random_uuid();
    result:=atlas_api.save_confirmed_supplier_allocation(jsonb_build_object(
      'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','command_id',command_id,'correlation_id',gen_random_uuid(),
      'idempotency_key','regression-allocation:'||command_id,'expected_version',(row_data#>>'{family,version}')::bigint,
      'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101','requested_at',transaction_timestamp()-interval '1 second',
      'reason_code','CONFIRMED_SUPPLIER_ALLOCATION_SAVED','reason_note',null,
      'payload',jsonb_build_object('family',jsonb_build_object(
        'service_date',row_data->'service_date','delivery_location_id',row_data->'delivery_location_id',
        'ingredient_id',row_data->'ingredient_id','unit_id',row_data->'unit_id',
        'expected_source_fingerprint',row_data#>'{family,source_fingerprint}',
        'expected_source_batch_id',row_data->'source_confirmed_need_batch_id',
        'expected_source_batch_version',row_data->'source_confirmed_need_batch_version'),
        'splits',jsonb_build_array(jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001',
          'allocated_quantity',row_data->'family_quantity')))));
    if result->>'success' is distinct from 'true' then raise exception 'Allocation fixture rejected: %',result; end if;
  end loop;
end;
$allocate_saved_need$;
reset role;
