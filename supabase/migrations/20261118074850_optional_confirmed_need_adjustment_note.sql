-- Free text is optional for row decisions. Keep the reason family, first
-- acceptance, note format and immutable predecessor/evidence checks.
alter table atlas_planning.confirmed_need_line_decisions
  drop constraint confirmed_need_line_decisions_correction_note_check,
  drop constraint confirmed_need_line_decisions_kind_reason_note_check,
  add constraint confirmed_need_line_decisions_kind_reason_note_check check (
    (decision_kind = 'UNCHANGED_PROPOSAL_ACCEPTED'
      and reason_code = 'PROPOSAL_ACCEPTED'
      and (predecessor_decision_id is not null or reason_note is null))
    or (decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
      and reason_code in ('PLANNING_STEP_ADJUSTMENT', 'OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER'))
  );

-- Retain the installed function definitions, including their ownership, ACLs
-- and downstream amendments. Each removed predicate must match exactly once.
do $migration$
declare
  patch record;
  definition text;
begin
  for patch in select * from (values
    ('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure,
$remove$      if v_reason in ('OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER') and v_note is null then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'REASON_NOTE_REQUIRED', 'field', 'reason_note',
          'message', 'This adjustment reason requires a nonblank note.'
        ));
      end if;
$remove$),
    ('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure,
$remove$    if v_line.current_confirmed_need_line_decision_id is not null and v_note is null then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'REASON_NOTE_REQUIRED', 'field', 'reason_note',
        'message', 'Replacement decision evidence requires a nonblank correction note.'
      ));
    end if;
$remove$),
    ('atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()'::regprocedure,
$remove$          or (
            decision.predecessor_decision_id is not null
            and decision.reason_note is null
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_decision_continuity continuity
              where continuity.confirmed_need_line_id = decision.confirmed_need_line_id
                and continuity.source_confirmed_need_line_decision_id =
                  decision.predecessor_decision_id
                and continuity.continuity_kind in (
                  'INVALIDATED_PROPOSAL_CHANGE',
                  'INVALIDATED_POLICY_INCOMPATIBLE',
                  'INVALIDATED_LINE_REMOVED'
                )
            )
          )
$remove$),
    ('atlas_core.rmvp_06_canonical_evaluation(uuid,text)'::regprocedure,
$remove$          or (
            v_decision.reason_code in ('OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER')
            and v_decision.reason_note is null
          )
$remove$),
    ('atlas_core.rmvp_06_canonical_evaluation(uuid,text)'::regprocedure,
$remove$ or (
        v_decision.predecessor_decision_id is not null
        and v_decision.reason_note is null
        and not exists (
          select 1
          from atlas_planning.confirmed_need_line_decision_continuity continuity
          where continuity.confirmed_need_line_id = v_line.confirmed_need_line_id
            and continuity.source_confirmed_need_line_decision_id =
              v_decision.predecessor_decision_id
            and continuity.continuity_kind in (
              'INVALIDATED_PROPOSAL_CHANGE',
              'INVALIDATED_POLICY_INCOMPATIBLE',
              'INVALIDATED_LINE_REMOVED'
            )
        )
      )$remove$)
  ) as edits(target, fragment)
  loop
    definition := replace(pg_get_functiondef(patch.target), E'\r\n', E'\n');
    if cardinality(string_to_array(definition, patch.fragment)) <> 2 then
      raise exception 'Expected one optional-note predicate in %', patch.target;
    end if;
    execute replace(definition, patch.fragment, '');
  end loop;

  -- Released documents use a distinct correction command with a mandatory
  -- explanation. Keep that check on its normalized preview lines.
  definition := pg_get_functiondef('atlas_api.save_confirmed_needs(jsonb)'::regprocedure);
  if cardinality(string_to_array(definition, $old$or item->>'current_decision_id' is null) then$old$)) <> 2 then
    raise exception 'Expected the released correction decision guard';
  end if;
  execute replace(definition, $old$or item->>'current_decision_id' is null) then$old$,
    $new$or item->>'current_decision_id' is null or item->>'reason_note' is null) then$new$);
end;
$migration$;
