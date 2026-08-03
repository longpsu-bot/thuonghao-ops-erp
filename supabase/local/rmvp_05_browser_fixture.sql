-- GitHub-only disposable acceptance fixture for RMVP-05.
-- It binds no production role and installs no business seed. The local browser
-- journey creates the real RMVP-04/CMD-15 batch before this fixture is applied.

do $$
begin
insert into atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id,
  unit_id,
  created_by_actor_id
)
select
  gen_random_uuid(),
  source.unit_id,
  'b6000000-0000-0000-0000-000000000001'::uuid
from (
  select distinct line.controlled_unit_id as unit_id
  from atlas_planning.confirmed_need_batches batch
  join atlas_planning.confirmed_need_lines line
    on line.confirmed_need_batch_id = batch.confirmed_need_batch_id
  where batch.source_kind = 'NEED_GENERATION'
    and batch.batch_status = 'DRAFT_REVIEW'
) source
on conflict (unit_id) do nothing;

insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,
  planning_quantity_policy_id,
  unit_id,
  revision_number,
  predecessor_policy_revision_id,
  planning_step,
  effective_from,
  policy_revision_status,
  created_by_actor_id,
  created_at,
  approved_by_actor_id,
  approved_at,
  activated_by_actor_id,
  activated_at
)
select
  gen_random_uuid(),
  policy.planning_quantity_policy_id,
  policy.unit_id,
  1,
  null,
  0.000001,
  date '2000-01-01',
  'DRAFT',
  'b6000000-0000-0000-0000-000000000001'::uuid,
  transaction_timestamp() - interval '2 minutes',
  null,
  null,
  null,
  null
from atlas_planning.planning_quantity_policies policy
where exists (
  select 1
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_batches batch
    on batch.confirmed_need_batch_id = line.confirmed_need_batch_id
  where line.controlled_unit_id = policy.unit_id
    and batch.source_kind = 'NEED_GENERATION'
    and batch.batch_status = 'DRAFT_REVIEW'
)
and not exists (
  select 1
  from atlas_planning.planning_quantity_policy_revisions revision
  where revision.planning_quantity_policy_id = policy.planning_quantity_policy_id
);

update atlas_planning.planning_quantity_policy_revisions revision
set policy_revision_status = 'ACTIVE',
    approved_by_actor_id = 'b6000000-0000-0000-0000-000000000001'::uuid,
    approved_at = transaction_timestamp() - interval '1 minute',
    activated_by_actor_id = 'b6000000-0000-0000-0000-000000000001'::uuid,
    activated_at = transaction_timestamp()
where revision.policy_revision_status = 'DRAFT'
  and revision.revision_number = 1
  and revision.planning_step = 0.000001
  and revision.effective_from = date '2000-01-01'
  and revision.created_by_actor_id = 'b6000000-0000-0000-0000-000000000001'::uuid
  and exists (
    select 1
    from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_batches batch
      on batch.confirmed_need_batch_id = line.confirmed_need_batch_id
    where line.controlled_unit_id = revision.unit_id
      and batch.source_kind = 'NEED_GENERATION'
      and batch.batch_status = 'DRAFT_REVIEW'
  );

end
$$;
