do $pa_06c_stale_versions$
begin
  update atlas_procurement.purchase_orders
  set version = 2,
      updated_at = transaction_timestamp()
  where purchase_order_id = 'b6c30000-0000-0000-0000-000000000700'
    and version = 1;

  update atlas_procurement.fulfilment_allocations
  set version = 2,
      updated_at = transaction_timestamp()
  where fulfilment_allocation_id = 'b6c30000-0000-0000-0000-000000000600'
    and version = 1;

  if not exists (
    select 1 from atlas_procurement.purchase_orders
    where purchase_order_id = 'b6c30000-0000-0000-0000-000000000700'
      and version = 2
  ) or not exists (
    select 1 from atlas_procurement.fulfilment_allocations
    where fulfilment_allocation_id = 'b6c30000-0000-0000-0000-000000000600'
      and version = 2
  ) then
    raise exception 'PA-06C local stale-version fixture failed.';
  end if;
end;
$pa_06c_stale_versions$;
