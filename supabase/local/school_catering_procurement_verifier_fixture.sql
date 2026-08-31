do $school_catering_procurement_fixture$
begin

insert into atlas_core.role_capabilities(
  role_capability_id,role_id,capability_id,granted_by_actor_id
)
select source.binding_id,'b6000000-0000-0000-0000-000000000003'::uuid,
  capability.capability_id,'b6000000-0000-0000-0000-000000000001'::uuid
from (values
  ('b6000000-0000-4000-8000-000000000035'::uuid,'procurement.school_catering.read'),
  ('b6000000-0000-4000-8000-000000000036'::uuid,'procurement.school_catering.write')
) source(binding_id,capability_code)
join atlas_core.capabilities capability using(capability_code)
where true
on conflict(role_capability_id) do update set capability_id=excluded.capability_id;

insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status)
values
  ('c7100000-0000-4000-8000-000000000001','PR-A-VERIFY-A','PR-A Verify Supplier A','ACTIVE'),
  ('c7100000-0000-4000-8000-000000000002','PR-A-VERIFY-B','PR-A Verify Supplier B','ACTIVE')
on conflict(supplier_id) do update set supplier_status='ACTIVE';

insert into atlas_admin.supplier_eligibilities(
  supplier_id,ingredient_id,effective_from,priority,reason_note
)
values
  ('c7100000-0000-4000-8000-000000000001','b6500000-0000-0000-0000-000000000006','2020-01-01',1,'Local PR-A verifier'),
  ('c7100000-0000-4000-8000-000000000002','b6500000-0000-0000-0000-000000000006','2020-01-01',2,'Local PR-A verifier'),
  ('c7100000-0000-4000-8000-000000000001','b6500000-0000-0000-0000-000000000007','2020-01-01',1,'Local PR-A verifier'),
  ('c7100000-0000-4000-8000-000000000002','b6500000-0000-0000-0000-000000000007','2020-01-01',2,'Local PR-A verifier')
on conflict do nothing;

end;
$school_catering_procurement_fixture$;
