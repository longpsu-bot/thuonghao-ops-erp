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
