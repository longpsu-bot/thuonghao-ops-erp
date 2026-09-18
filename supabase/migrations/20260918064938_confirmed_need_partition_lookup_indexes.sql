-- EXPLAIN on the real 17/09 Staging shape (304 atomic / 248 grouped)
-- showed each partition check filtering 303 irrelevant contribution members
-- per source line and rescanning current revisions by release alone.
-- Add exact non-unique lookup paths. All guard bodies, constraints and truth
-- conditions remain byte-for-byte unchanged; these indexes confer no authority.
create index confirmed_need_contributions_release_member_lookup
  on atlas_planning.confirmed_need_line_revision_contributions (
    need_generation_release_snapshot_line_id,
    confirmed_need_batch_id,
    confirmed_need_line_revision_id
  );
create index confirmed_need_revisions_current_member_lookup
  on atlas_planning.confirmed_need_line_revisions (
    need_generation_release_snapshot_id,
    confirmed_need_line_revision_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version
  ) where source_kind = 'NEED_GENERATION' and is_current;

-- Keep the same global every-and-only check, but materialize its two exact
-- sets before joining them. The prior nested LEFT JOIN plan repeatedly scanned
-- an entire release for each member, amplified again by deferred row events.
do $partition_plan$
declare
  definition text;
  target regprocedure;
  first_position integer;
  remaining text;
  original text;
  replacement text;
begin
  foreach target in array array[
    'atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()'::regprocedure,
    'atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure
  ] loop
    definition:=pg_get_functiondef(target);
    if position('PARTITION_SET_PLAN:' in definition)>0 then raise exception 'PARTITION_PATCH_ALREADY_PRESENT'; end if;
    if target='atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()'::regprocedure then
      first_position:=position(E'  if exists (\n    select snapshot_line.need_generation_release_snapshot_line_id' in definition);
      replacement:=$body$  -- PARTITION_SET_PLAN: same complete global release partition, set-based.
  if exists (
    with expected as materialized (
      select snapshot_line.need_generation_release_snapshot_line_id as member_id
      from atlas_planning.need_generation_release_snapshot_lines snapshot_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id=snapshot_line.theoretical_need_line_id
      where snapshot_line.need_generation_release_snapshot_id=v_batch.current_need_generation_release_snapshot_id
        and theoretical.line_disposition='ACTIVE'
    ), actual as materialized (
      select contribution.need_generation_release_snapshot_line_id as member_id,
             count(revision.confirmed_need_line_revision_id) as copies
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_revision_id=contribution.confirmed_need_line_revision_id
      where contribution.confirmed_need_batch_id=v_batch_id
        and contribution.need_generation_run_id=v_batch.current_need_generation_run_id
        and contribution.need_generation_run_version=v_batch.current_need_generation_run_version
        and contribution.need_generation_release_snapshot_id=v_batch.current_need_generation_release_snapshot_id
        and revision.confirmed_need_batch_id=v_batch_id
        and revision.source_kind='NEED_GENERATION' and revision.is_current
        and revision.need_generation_run_id=v_batch.current_need_generation_run_id
        and revision.need_generation_run_version=v_batch.current_need_generation_run_version
        and revision.need_generation_release_snapshot_id=v_batch.current_need_generation_release_snapshot_id
      group by contribution.need_generation_release_snapshot_line_id
    )
    select 1 from expected left join actual using(member_id)
    where coalesce(actual.copies,0)<>1
  ) then
    raise exception using errcode='23514',message='Current Need Generation revisions must exactly partition the active release';
  end if;$body$;
    else
      first_position:=position(E'  if exists (\n    select snapshot_line.theoretical_need_line_id' in definition);
      replacement:=$body$  -- PARTITION_SET_PLAN: global membership coverage is not scoped to one row.
  if exists (
    with expected as materialized (
      select snapshot_line.need_generation_release_snapshot_line_id as member_id,
             snapshot_line.theoretical_need_line_id as line_id
      from atlas_planning.need_generation_release_snapshot_lines snapshot_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id=snapshot_line.theoretical_need_line_id
      where snapshot_line.need_generation_release_snapshot_id=v_current_snapshot_id
        and theoretical.line_disposition='ACTIVE'
    ), actual as materialized (
      select contribution.need_generation_release_snapshot_line_id as member_id,
             count(revision.confirmed_need_line_revision_id) as copies
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_revision_id=contribution.confirmed_need_line_revision_id
      where revision.confirmed_need_batch_id=v_batch_id and revision.is_current
      group by contribution.need_generation_release_snapshot_line_id
    )
    select expected.line_id from expected left join actual using(member_id)
    group by expected.line_id having sum(coalesce(actual.copies,0))<>1
  ) then
    raise exception using errcode='23514',message='Current Need Generation revisions must exactly partition the active release';
  end if;$body$;
    end if;
    if first_position=0 then raise exception 'PARTITION_PATCH_BOUNDARY_NOT_FOUND'; end if;
    remaining:=substring(definition from first_position);
    original:=substring(remaining from 1 for position('  end if;' in remaining)+length('  end if;')-1);
    if position('Current Need Generation revisions must exactly partition the active release' in original)=0
      or position('having count(revision.confirmed_need_line_revision_id) <> 1' in original)=0
    then raise exception 'PARTITION_PATCH_EXPECTED_PREDICATE_NOT_FOUND'; end if;
    execute replace(definition,original,replacement);
  end loop;
end;
$partition_plan$;
