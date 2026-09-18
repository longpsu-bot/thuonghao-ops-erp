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


create index confirmed_need_contributions_line_partition_lookup
  on atlas_planning.confirmed_need_line_revision_contributions (
    confirmed_need_batch_id, confirmed_need_line_id,
    need_generation_release_snapshot_line_id
  );

-- The batch owns the COMPLETE partition. Its INSERT/source-advance UPDATE
-- retains the original full check. A child can affect only the members attached
-- to its immutable stable-line/revision history. Recheck those members against
-- ALL current owners: duplicate cross-line ownership must still fail.
-- No marker, cache, constraint or trigger is skipped.
do $partition_scope$
declare
  definition text;
  target regprocedure;
  first_position integer;
  remaining text;
  original text;
  replacement text;
  predicate text;
  scope_filter text;
begin
  foreach target in array array[
    'atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()'::regprocedure,
    'atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure
  ] loop
    definition:=pg_get_functiondef(target);
    if position('PARTITION_SCOPE:' in definition)>0 then raise exception 'PARTITION_PATCH_ALREADY_PRESENT'; end if;
    if target='atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()'::regprocedure then
      first_position:=position(E'  if exists (\n    select snapshot_line.need_generation_release_snapshot_line_id' in definition);
      predicate:='      and theoretical.line_disposition = ''ACTIVE''';
      scope_filter:=$filter$
      -- PARTITION_SCOPE: null stable-line scope is the full batch event.
      and (v_line_id is null or exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions affected
        where affected.confirmed_need_batch_id=v_batch_id
          and affected.confirmed_need_line_id=v_line_id
          and affected.need_generation_release_snapshot_line_id=snapshot_line.need_generation_release_snapshot_line_id
      ))$filter$;
    else
      first_position:=position(E'  if exists (\n    select snapshot_line.theoretical_need_line_id' in definition);
      predicate:='      and theoretical.line_disposition = ''ACTIVE''';
      scope_filter:=$filter$
      -- PARTITION_SCOPE: historical changes retain NULL and full coverage.
      -- Current inserts keep the complete group membership validation above;
      -- immutable contributions cannot silently disappear from an old revision.
      and (v_revision_id is null or exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions affected
        where affected.confirmed_need_line_revision_id=v_revision_id
          and affected.need_generation_release_snapshot_line_id=snapshot_line.need_generation_release_snapshot_line_id
      ))$filter$;
    end if;
    if first_position=0 then raise exception 'PARTITION_PATCH_BOUNDARY_NOT_FOUND'; end if;
    remaining:=substring(definition from first_position);
    original:=substring(remaining from 1 for position('  end if;' in remaining)+length('  end if;')-1);
    if position('having count(revision.confirmed_need_line_revision_id) <> 1' in original)=0
       or (length(original)-length(replace(original,predicate,'')))/length(predicate)<>1
    then raise exception 'PARTITION_PATCH_EXPECTED_PREDICATE_NOT_FOUND'; end if;
    replacement:=replace(original,predicate,predicate||scope_filter);
    execute replace(definition,original,replacement);
  end loop;
end;
$partition_scope$;

-- Immutable contribution facts and the mutable School/customer reference have
-- different dependency scopes. Preserve the latter as an independent GLOBAL
-- check; validate immutable facts for the changed current revision only. The
-- prior history fallback leaves v_revision_id NULL and still scans all facts.
do $contribution_fact_scope$
declare
  definition text:=pg_get_functiondef('atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure);
  anchor text:=$anchor$    where contribution.confirmed_need_batch_id = v_batch_id
      and ($anchor$;
  original_check text:=$anchor$  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision$anchor$;
  ownership_check text:=$owner$  -- LIVE_OWNER_SCOPE: changes outside this revision remain checked globally.
  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id=contribution.confirmed_need_line_id
    join atlas_admin.schools school on school.school_id=contribution.school_id
    where contribution.confirmed_need_batch_id=v_batch_id
      and school.customer_id<>line.customer_id
  ) then
    raise exception using errcode='23514',message='Need Generation contribution facts are not exact active release facts';
  end if;

$owner$;
begin
  if position('LIVE_OWNER_SCOPE:' in definition)>0
    or (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1
    or (length(definition)-length(replace(definition,original_check,'')))/length(original_check)<>1
  then raise exception 'CONTRIBUTION_FACT_SCOPE_BOUNDARY_MISMATCH'; end if;
  definition:=replace(definition,anchor,$anchor$    where contribution.confirmed_need_batch_id = v_batch_id
      and (v_revision_id is null or contribution.confirmed_need_line_revision_id=v_revision_id)
      and ($anchor$);
  execute replace(definition,original_check,ownership_check||original_check);
end;
$contribution_fact_scope$;
