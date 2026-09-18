-- Owner-approved Atlas STAGING configuration, 18/09/2026.
-- Fourteen exact existing imported units: step=1, effective 14/09/2026.
-- NOT a migration seed, dimension default, unit creation, or kg policy change.
-- Execute only via the protected Staging runner. Caller owns BEGIN/COMMIT.
do $count_policies$
declare
  operator_id uuid;
  expected record;
  controlled_unit atlas_admin.units%rowtype;
  policy_id uuid;
  policy_revision_id uuid;
  accepted boolean;
begin
  if to_regclass('public.schools') is not null then
    raise exception 'STAGING_COUNT_POLICY_LIVE_SENTINEL';
  end if;
  select actor.actor_id into strict operator_id
  from atlas_core.actor_auth_subjects subject join atlas_core.actors actor using(actor_id)
  where subject.auth_subject_id='a1010000-0000-4000-8000-000000000101'
    and subject.subject_status='ACTIVE' and actor.actor_status='ACTIVE';
  perform pg_advisory_xact_lock(hashtextextended('atlas-staging-count-unit-policies.v1',0));
  for expected in select * from (values
    ('v1-unit-034ce34d3ff3','Quả'),
    ('v1-unit-2d183c73d76a','Bó'),
    ('v1-unit-469606e98b7e','Gói'),
    ('v1-unit-46bab433cc1a','Cốc'),
    ('v1-unit-83bea5cf6378','Miếng'),
    ('v1-unit-91a0b1c14124','Cái'),
    ('v1-unit-9837090d3b3f','Hũ'),
    ('v1-unit-b1e160b3fbfb','Chai'),
    ('v1-unit-c854d71627b2','Cây'),
    ('v1-unit-cac06658f903','Lon'),
    ('v1-unit-cad1515b85c4','Ổ'),
    ('v1-unit-dafac3b7da11','Bịch'),
    ('v1-unit-ea9046ea54e4','Hộp'),
    ('v1-unit-eb0ce03e77fa','Trái')
  ) approved(code,name) order by code loop
    select * into controlled_unit from atlas_admin.units where unit_code=expected.code for update;
    if not found or controlled_unit.unit_status<>'ACTIVE'
       or controlled_unit.unit_name<>expected.name or controlled_unit.dimension_code<>'COUNT' then
      raise exception 'STAGING_COUNT_POLICY_UNIT_MISMATCH';
    end if;
    select planning_quantity_policy_id into policy_id
    from atlas_planning.planning_quantity_policies where unit_id=controlled_unit.unit_id for update;
    if found then
      select count(*)=1 and bool_and(
        revision_number=1 and predecessor_policy_revision_id is null
        and unit_id=controlled_unit.unit_id and planning_step=1
        and effective_from=date '2026-09-14' and effective_to is null
        and policy_revision_status='ACTIVE'
        and created_by_actor_id=operator_id and approved_by_actor_id=operator_id
        and activated_by_actor_id=operator_id and approved_at is not null
        and activated_at is not null and retired_at is null
      ) into accepted
      from atlas_planning.planning_quantity_policy_revisions
      where planning_quantity_policy_id=policy_id;
      if accepted is distinct from true then raise exception 'STAGING_COUNT_POLICY_CONFLICT'; end if;
      continue;
    end if;
    insert into atlas_planning.planning_quantity_policies(unit_id,created_by_actor_id)
    values(controlled_unit.unit_id,operator_id) returning planning_quantity_policy_id into policy_id;
    insert into atlas_planning.planning_quantity_policy_revisions(
      planning_quantity_policy_id,unit_id,revision_number,planning_step,effective_from,created_by_actor_id)
    values(policy_id,controlled_unit.unit_id,1,1,date '2026-09-14',operator_id)
    returning planning_quantity_policy_revision_id into policy_revision_id;
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status='ACTIVE',approved_by_actor_id=operator_id,approved_at=now(),
        activated_by_actor_id=operator_id,activated_at=now()
    where planning_quantity_policy_revision_id=policy_revision_id;
  end loop;
end;
$count_policies$;
set constraints all immediate;
