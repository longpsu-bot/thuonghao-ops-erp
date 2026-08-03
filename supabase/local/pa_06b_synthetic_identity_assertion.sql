do $$
begin
  if not exists (
    select 1
    from atlas_admin.customers c
    where c.customer_id = 'b6000000-0000-0000-0000-000000000201'
      and c.customer_code = 'PA06B-LOCAL-CUSTOMER'
      and c.customer_status = 'ACTIVE'
  ) then
    raise exception 'PA-06B local customer assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.actors a
    join atlas_core.actor_auth_subjects aas on aas.actor_id = a.actor_id
    where a.actor_id = 'b6000000-0000-0000-0000-000000000001'
      and a.actor_type = 'HUMAN'
      and a.actor_status = 'ACTIVE'
      and aas.actor_auth_subject_id = 'b6000000-0000-0000-0000-000000000002'
      and aas.auth_provider = 'SUPABASE_AUTH'
      and aas.auth_subject_id = 'b6000000-0000-0000-0000-000000000101'
      and aas.subject_status = 'ACTIVE'
      and aas.revoked_at is null
  ) then
    raise exception 'PA-06B local actor and Auth subject assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.roles r
    join atlas_core.role_capabilities rc on rc.role_id = r.role_id
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where r.role_id = 'b6000000-0000-0000-0000-000000000003'
      and r.role_code = 'pa06b_local_read_operator'
      and r.role_status = 'ACTIVE'
      and rc.role_capability_id = 'b6000000-0000-0000-0000-000000000005'
      and c.capability_id = 'b6000000-0000-0000-0000-000000000004'
      and c.capability_code = 'operator_blockers.read'
      and c.owning_domain = 'DISPATCH'
      and c.capability_status = 'ACTIVE'
  ) then
    raise exception 'PA-06B local role and capability assertion failed.';
  end if;

  if (
    select count(*)
    from atlas_core.role_capabilities rc
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where rc.role_id = 'b6000000-0000-0000-0000-000000000003'
      and c.capability_code in (
        'master_data.recipe_adjustments.read',
        'master_data.recipe_adjustments.write',
        'master_data.recipe_adjustments.cancel'
      )
  ) <> 3 then
    raise exception 'RMVP-02B local Recipe adjustment capabilities assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.role_capabilities rc
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where rc.role_capability_id = 'b6000000-0000-0000-0000-000000000029'
      and rc.role_id = 'b6000000-0000-0000-0000-000000000003'
      and c.capability_code = 'planning.input_readiness.write'
      and c.owning_domain = 'PLANNING'
      and c.capability_status = 'ACTIVE'
  ) then
    raise exception 'RMVP-03B local readiness-write capability assertion failed.';
  end if;

  if (
    select count(*)
    from atlas_core.role_capabilities rc
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where rc.role_id = 'b6000000-0000-0000-0000-000000000003'
      and rc.role_capability_id in (
        'b6000000-0000-0000-0000-000000000030',
        'b6000000-0000-0000-0000-000000000031'
      )
      and c.capability_code in (
        'planning.need_generation.write',
        'confirmed_need_generation.materialize'
      )
      and c.capability_status = 'ACTIVE'
  ) <> 2 then
    raise exception 'RMVP-04 local Need Generation capabilities assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.actor_role_memberships arm
    where arm.actor_role_membership_id = 'b6000000-0000-0000-0000-000000000006'
      and arm.actor_id = 'b6000000-0000-0000-0000-000000000001'
      and arm.role_id = 'b6000000-0000-0000-0000-000000000003'
      and arm.membership_status = 'ACTIVE'
      and arm.effective_from <= transaction_timestamp()
      and (arm.effective_to is null or arm.effective_to > transaction_timestamp())
  ) then
    raise exception 'PA-06B local active role membership assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.actor_scopes s
    where s.actor_scope_id = 'b6000000-0000-0000-0000-000000000007'
      and s.actor_id = 'b6000000-0000-0000-0000-000000000001'
      and s.scope_kind = 'CUSTOMER'
      and s.customer_id = 'b6000000-0000-0000-0000-000000000201'
      and s.delivery_location_id is null
      and s.dispatch_trip_id is null
      and s.scope_status = 'ACTIVE'
      and s.effective_from <= transaction_timestamp()
      and (s.effective_to is null or s.effective_to > transaction_timestamp())
  ) then
    raise exception 'PA-06B local customer scope assertion failed.';
  end if;
end;
$$;
