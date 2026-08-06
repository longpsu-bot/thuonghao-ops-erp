-- GitHub-only RMVP-06/RMVP-07 capability bindings for the deterministic
-- Planning actor.
-- The short journey installs the RMVP-05 two-line batch first; the full journey
-- reuses the batch materialized and confirmed through RMVP-04/RMVP-05.

do $rmvp_06_browser_fixture$
begin
  insert into atlas_core.role_capabilities (role_id, capability_id)
  select
    'b6000000-0000-0000-0000-000000000003'::uuid,
    capability.capability_id
  from atlas_core.capabilities capability
  where capability.capability_code in (
    'confirmed_need_validation.validate',
    'confirmed_need_approval.approve',
    'confirmed_need_release.release'
  )
  on conflict do nothing;

  if not exists (
    select 1
    from atlas_core.role_capabilities role_capability
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where role_capability.role_id = 'b6000000-0000-0000-0000-000000000003'
      and capability.capability_code in (
        'confirmed_need_validation.validate',
        'confirmed_need_approval.approve',
        'confirmed_need_release.release'
      )
      and capability.capability_status = 'ACTIVE'
    group by role_capability.role_id
    having count(*) = 3
  ) then
    raise exception 'RMVP-06/RMVP-07 fixture requires all active lifecycle capabilities.';
  end if;
end;
$rmvp_06_browser_fixture$;
