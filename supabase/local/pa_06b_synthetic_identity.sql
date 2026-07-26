do $pa_06b_identity$
begin

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name
) values (
  'b6000000-0000-0000-0000-000000000201',
  'PA06B-LOCAL-CUSTOMER',
  'PA-06B Synthetic Local Customer'
)
on conflict (customer_id) do update set
  customer_code = excluded.customer_code,
  customer_name = excluded.customer_name,
  customer_status = 'ACTIVE',
  updated_at = transaction_timestamp();

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values (
  'b6000000-0000-0000-0000-000000000001',
  'HUMAN',
  'PA-06B Synthetic Local Operator'
)
on conflict (actor_id) do update set
  display_name = excluded.display_name,
  actor_status = 'ACTIVE',
  deactivated_at = null;

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values (
  'b6000000-0000-0000-0000-000000000002',
  'b6000000-0000-0000-0000-000000000001',
  'b6000000-0000-0000-0000-000000000101'
)
on conflict (actor_auth_subject_id) do update set
  actor_id = excluded.actor_id,
  auth_subject_id = excluded.auth_subject_id,
  subject_status = 'ACTIVE',
  revoked_at = null;

insert into atlas_core.roles (
  role_id,
  role_code,
  role_name
) values (
  'b6000000-0000-0000-0000-000000000003',
  'pa06b_local_read_operator',
  'PA-06B local read operator'
)
on conflict (role_id) do update set
  role_code = excluded.role_code,
  role_name = excluded.role_name,
  role_status = 'ACTIVE',
  updated_at = transaction_timestamp();

insert into atlas_core.capabilities (
  capability_id,
  capability_code,
  capability_name,
  owning_domain
) values (
  'b6000000-0000-0000-0000-000000000004',
  'operator_blockers.read',
  'Read bounded operator blockers',
  'DISPATCH'
)
on conflict (capability_id) do update set
  capability_code = excluded.capability_code,
  capability_name = excluded.capability_name,
  owning_domain = excluded.owning_domain,
  capability_status = 'ACTIVE';

insert into atlas_core.role_capabilities (
  role_capability_id,
  role_id,
  capability_id,
  granted_by_actor_id
) values (
  'b6000000-0000-0000-0000-000000000005',
  'b6000000-0000-0000-0000-000000000003',
  'b6000000-0000-0000-0000-000000000004',
  'b6000000-0000-0000-0000-000000000001'
)
on conflict (role_capability_id) do update set
  role_id = excluded.role_id,
  capability_id = excluded.capability_id,
  granted_by_actor_id = excluded.granted_by_actor_id;

insert into atlas_core.actor_role_memberships (
  actor_role_membership_id,
  actor_id,
  role_id,
  granted_by_actor_id,
  reason_note
) values (
  'b6000000-0000-0000-0000-000000000006',
  'b6000000-0000-0000-0000-000000000001',
  'b6000000-0000-0000-0000-000000000003',
  'b6000000-0000-0000-0000-000000000001',
  'Deterministic synthetic PA-06B local connection verification only.'
)
on conflict (actor_role_membership_id) do update set
  membership_status = 'ACTIVE',
  effective_to = null,
  reason_note = excluded.reason_note;

insert into atlas_core.actor_scopes (
  actor_scope_id,
  actor_id,
  scope_kind,
  customer_id,
  granted_by_actor_id,
  reason_note
) values (
  'b6000000-0000-0000-0000-000000000007',
  'b6000000-0000-0000-0000-000000000001',
  'CUSTOMER',
  'b6000000-0000-0000-0000-000000000201',
  'b6000000-0000-0000-0000-000000000001',
  'Least-privilege synthetic customer scope for PA-06B local verification.'
)
on conflict (actor_scope_id) do update set
  scope_status = 'ACTIVE',
  effective_to = null,
  reason_note = excluded.reason_note;

insert into atlas_core.role_capabilities (
  role_capability_id,
  role_id,
  capability_id,
  granted_by_actor_id
)
select
  source.role_capability_id,
  'b6000000-0000-0000-0000-000000000003',
  capability.capability_id,
  'b6000000-0000-0000-0000-000000000001'
from (
  values
    ('b6000000-0000-0000-0000-000000000010'::uuid, 'master_data.read'),
    ('b6000000-0000-0000-0000-000000000011'::uuid, 'master_data.schools.write'),
    ('b6000000-0000-0000-0000-000000000012'::uuid, 'master_data.ingredients.write'),
    ('b6000000-0000-0000-0000-000000000013'::uuid, 'master_data.suppliers.write'),
    ('b6000000-0000-0000-0000-000000000014'::uuid, 'master_data.priorities.write')
) source(role_capability_id, capability_code)
join atlas_core.capabilities capability
  on capability.capability_code = source.capability_code
on conflict (role_capability_id) do update set
  role_id = excluded.role_id,
  capability_id = excluded.capability_id,
  granted_by_actor_id = excluded.granted_by_actor_id;

insert into atlas_core.actor_scopes (
  actor_scope_id,
  actor_id,
  scope_kind,
  granted_by_actor_id,
  reason_note
) values (
  'b6000000-0000-0000-0000-000000000015',
  'b6000000-0000-0000-0000-000000000001',
  'GLOBAL',
  'b6000000-0000-0000-0000-000000000001',
  'Synthetic global scope for connected RMVP-01 master-data acceptance only.'
)
on conflict (actor_scope_id) do update set
  scope_status = 'ACTIVE',
  effective_to = null,
  reason_note = excluded.reason_note;

end;
$pa_06b_identity$;
