-- Bound repeated Need Generation integrity work without changing an invariant.
-- Keep the full guard for run, input, selection and release-header events.
-- Immutable child INSERTs use cardinality witnesses and exact local membership.
-- No persisted queue/cache, custom-GUC bypass, timeout, privilege or API change.
do $migration$
declare
  definition text := pg_get_functiondef(
    'atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure
  );
  anchor text := $anchor$      message = 'stored generation line and issue counts must equal exact owned rows';
  end if;
$anchor$;
  fast_paths text := $paths$
  -- NG_SCALE: stored run counts have just been checked against exact rows.
  -- The generated line count is immutable. Issue counts can grow only with a
  -- checked run UPDATE; that event still runs the complete original guard.
  -- Thus a new counted package has a mandatory full run INSERT/UPDATE event,
  -- and uncounted later children fail above. Early constraint flushing cannot
  -- authorize an extra row after its matching complete check has finished.
  if tg_op = 'INSERT' and tg_table_name in (
    'theoretical_need_lines', 'need_generation_issues'
  ) then
    return new;
  end if;

  if tg_op = 'INSERT' and tg_table_name = 'need_generation_recipe_line_uses' then
    -- The immutable selection is checked by its own full guard. Each use still
    -- proves exact Recipe/Version/Line/Revision ownership. Uniqueness by
    -- (selection, RecipeLine), version ownership and equal composition counts
    -- imply every-and-only membership, including REMOVED revisions.
    if not exists (
      select 1
      from atlas_planning.need_generation_recipe_selections selection
      join atlas_admin.recipe_line_revisions revision
        on revision.recipe_line_revision_id = new.recipe_line_revision_id
      where selection.need_generation_recipe_selection_id = new.need_generation_recipe_selection_id
        and selection.need_generation_run_id = v_run.need_generation_run_id
        and selection.need_generation_input_snapshot_id = v_run.input_snapshot_id
        and new.need_generation_input_snapshot_id = v_run.input_snapshot_id
        and selection.recipe_id = new.recipe_id
        and selection.recipe_version_id = new.recipe_version_id
        and revision.recipe_id = new.recipe_id
        and revision.recipe_version_id = new.recipe_version_id
        and revision.recipe_line_id = new.recipe_line_id
    ) then
      raise exception using errcode = '23514',
        message = 'Recipe composition uses must preserve exact selection and H0A2 ownership';
    end if;
    if (
      select count(*) from atlas_planning.need_generation_recipe_line_uses line_use
      where line_use.need_generation_recipe_selection_id = new.need_generation_recipe_selection_id
    ) <> (
      select count(*) from atlas_admin.recipe_line_revisions revision
      where revision.recipe_version_id = new.recipe_version_id
    ) then
      raise exception using errcode = '23514',
        message = 'every selected RecipeVersion requires every-and-only its exact composition use';
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' and tg_table_name in (
    'need_generation_release_snapshot_lines', 'need_generation_release_snapshot_issues'
  ) then
    -- Immediate composite FKs bind each member to the exact release/run/version
    -- and owned line/issue; unique membership prevents duplicates. Equal counts
    -- therefore prove the complete set. The immutable header's full event
    -- verifies release metadata. A late member cannot fit an already-full set.
    if v_run.released_at is null or not exists (
      select 1 from atlas_planning.need_generation_release_snapshots release_snapshot
      where release_snapshot.need_generation_release_snapshot_id = new.need_generation_release_snapshot_id
        and release_snapshot.need_generation_run_id = v_run.need_generation_run_id
        and release_snapshot.released_run_version = new.released_run_version
        and release_snapshot.generated_line_count = v_run.generated_line_count
        and release_snapshot.warning_count = v_run.warning_count
        and release_snapshot.blocking_issue_count = 0
        and v_run.blocking_issue_count = 0
    ) then
      raise exception using errcode = '23514',
        message = 'release header, line membership, and issue membership must be exact and complete';
    end if;
    if tg_table_name = 'need_generation_release_snapshot_lines' then
      if (select count(*) from atlas_planning.need_generation_release_snapshot_lines member
          where member.need_generation_release_snapshot_id = new.need_generation_release_snapshot_id)
         <> v_run.generated_line_count then
        raise exception using errcode = '23514',
          message = 'release header, line membership, and issue membership must be exact and complete';
      end if;
    else
      if (select count(*) from atlas_planning.need_generation_release_snapshot_issues member
          where member.need_generation_release_snapshot_id = new.need_generation_release_snapshot_id)
         <> v_run.warning_count then
        raise exception using errcode = '23514',
          message = 'release header, line membership, and issue membership must be exact and complete';
      end if;
    end if;
    return new;
  end if;
$paths$;
begin
  if position('NG_SCALE:' in definition) > 0
    or (length(definition)-length(replace(definition,anchor,''))) / length(anchor) <> 1
  then
    raise exception 'Need Generation integrity scale patch requires the exact reviewed count boundary';
  end if;
  execute replace(definition,anchor,anchor||fast_paths);
end;
$migration$;

-- The same atomic command materializes Confirmed Need. After the generation
-- guard is bounded, profiling exposes batch-wide checks repeated per revision
-- and contribution. Validate the affected immutable ownership set locally;
-- KEEP the global active-release partition checks on EVERY invocation.
do $confirmed_source$
declare
  definition text := pg_get_functiondef(
    'atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()'::regprocedure
  );
  anchor text := $anchor$  if not exists (
    select 1
    from atlas_planning.need_generation_runs origin_run$anchor$;
  prefix text;
  scoped text;
  target text;
begin
  if position('NG_SCALE_SOURCE:' in definition)>0
    or (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1
  then raise exception 'Confirmed Need source scale patch requires its exact reviewed boundary'; end if;
  definition:=replace(definition,'  v_batch_id uuid;',E'  v_batch_id uuid;\n  v_line_id uuid;');
  prefix:=substring(definition from 1 for position(anchor in definition)-1);
  scoped:=substring(definition from position(anchor in definition));
  foreach target in array array[
    'where line.confirmed_need_batch_id = v_batch_id',
    'where revision.confirmed_need_batch_id = v_batch_id'
  ] loop
    if (length(scoped)-length(replace(scoped,target,'')))/length(target)<>1 then
      raise exception 'Confirmed Need source scale patch found unexpected ownership predicates';
    end if;
    scoped:=replace(scoped,target,target||E'\n      and (v_line_id is null or '||
      case when target like 'where line.%' then 'line' else 'revision' end||
      '.confirmed_need_line_id = v_line_id)');
  end loop;
  definition:=prefix||$scope$  -- NG_SCALE_SOURCE: child events recheck their stable line and history.
  -- Batch INSERT/UPDATE events retain the complete source scan; advancing a
  -- batch source therefore still checks ALL lines/revisions. Wholesale and
  -- the final global active-release partition query remain unchanged.
  if tg_table_name in ('confirmed_need_lines','confirmed_need_line_revisions') then
    v_line_id:=new.confirmed_need_line_id;
  end if;

$scope$||scoped;
  execute definition;
end;
$confirmed_source$;

do $confirmed_membership$
declare
  definition text := pg_get_functiondef(
    'atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure
  );
  target text;
  expected_count integer;
begin
  if position('NG_SCALE_MEMBERSHIP:' in definition)>0 then
    raise exception 'Confirmed Need membership scale patch is already present';
  end if;
  definition:=replace(definition,'  v_batch_id uuid;',E'  v_batch_id uuid;\n  v_revision_id uuid;');
  target:='  v_batch_id := new.confirmed_need_batch_id;';
  if (length(definition)-length(replace(definition,target,'')))/length(target)<>1 then
    raise exception 'Confirmed Need membership scale patch requires its exact reviewed assignment';
  end if;
  definition:=replace(definition,target,target||$scope$
  -- NG_SCALE_MEMBERSHIP: both registered trigger tables identify one revision.
  -- Its nonempty membership, every exact contribution, sum, predecessor and
  -- completeness checks all remain. Unchanged immutable sibling revisions do
  -- not need revalidation. The final GLOBAL partition check is NOT filtered.
  v_revision_id:=new.confirmed_need_line_revision_id;
$scope$);
  target:=$predicate$where revision.confirmed_need_batch_id = v_batch_id
      and revision.source_kind = 'NEED_GENERATION'$predicate$;
  expected_count:=2;
  if (length(definition)-length(replace(definition,target,'')))/length(target)<>expected_count then
    raise exception 'Confirmed Need membership scale patch found unexpected revision predicates';
  end if;
  definition:=replace(definition,target,$predicate$where revision.confirmed_need_batch_id = v_batch_id
      and revision.confirmed_need_line_revision_id = v_revision_id
      and revision.source_kind = 'NEED_GENERATION'$predicate$);
  target:=$predicate$where contribution.confirmed_need_batch_id = v_batch_id
      and ($predicate$;
  if (length(definition)-length(replace(definition,target,'')))/length(target)<>1 then
    raise exception 'Confirmed Need membership scale patch found unexpected contribution predicates';
  end if;
  definition:=replace(definition,target,$predicate$where contribution.confirmed_need_batch_id = v_batch_id
      and contribution.confirmed_need_line_revision_id = v_revision_id
      and ($predicate$);
  execute definition;
end;
$confirmed_membership$;
