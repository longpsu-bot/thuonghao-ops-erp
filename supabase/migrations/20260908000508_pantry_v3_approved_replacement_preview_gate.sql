-- PANTRY-02.v3 preview must expose the consequential Save boundary for a
-- genuine APPROVED replacement while leaving the correction-impact gate and
-- PANTRY-02.v1 compatibility lifecycle unchanged.

reset role;
grant atlas_owner, atlas_read_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

create or replace function atlas_api.preview_pantry_source(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_legacy_request jsonb;
  v_result jsonb;
  v_modes jsonb;
  v_batch_id uuid;
  v_actor_context jsonb;
  v_actor_id uuid;
begin
  if request->>'contract_version'='PANTRY-02.v1' then
    return atlas_core.direct_need_legacy_preview_pantry_source(request);
  end if;
  if request->>'contract_version'<>'PANTRY-02.v3'
    or jsonb_typeof(request#>'{payload,school_date_modes}')<>'array'
    or (request->'payload')-array['week_start','no_additions_confirmed','rows',
      'claimed_source_signature','school_date_modes']<>'{}'::jsonb
  then
    return atlas_core.pantry_02_read_error(request,'preview_pantry_source',
      'VALIDATION_FAILED','Direct Need preview requires School/date modes.');
  end if;
  v_legacy_request:=jsonb_set(
    jsonb_set(request,'{contract_version}','"PANTRY-02.v1"'::jsonb,true),
    '{payload}',(request->'payload')-'school_date_modes',true
  );
  v_result:=atlas_core.direct_need_legacy_preview_pantry_source(v_legacy_request);
  if v_result->>'success'<>'true' then return v_result; end if;
  v_modes:=atlas_core.direct_need_canonical_modes(
    atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}'),
    v_result#>'{preview,canonical_rows}',request#>'{payload,school_date_modes}'
  );
  if v_modes is null then
    return atlas_core.pantry_02_read_error(request,'preview_pantry_source',
      'VALIDATION_FAILED',
      'Provide exactly one ADDITIVE or COMPLETE mode for every School/date with direct lines.');
  end if;
  select pantry_need_batch_id into v_batch_id
  from atlas_planning.pantry_need_batches
  where week_start=atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}');
  v_result:=jsonb_set(v_result,'{contract_version}','"PANTRY-02.v3"'::jsonb,true);
  v_result:=jsonb_set(v_result,'{preview,school_date_modes}',v_modes,true);
  if v_batch_id is not null
    and not atlas_core.direct_need_modes_match(v_batch_id,v_modes)
  then
    v_result:=jsonb_set(v_result,'{preview,comparison,status}',
      '"REPLACEMENT"'::jsonb,true);
  end if;

  if v_result#>>'{preview,comparison,status}'='REPLACEMENT'
    and v_result#>>'{preview,comparison,current_status}'='APPROVED'
    and jsonb_array_length(v_result#>'{preview,issues,blockers}')=0
  then
    v_actor_context:=atlas_core.pa_05b_resolve_actor(
      request,'PLANNING','preview_pantry_source'
    );
    if not v_actor_context ? 'error' then
      v_actor_id:=atlas_core.pa_05b_safe_uuid(v_actor_context->>'actor_id');
      if atlas_core.pantry_02_actor_has_capability(
        v_actor_id,'planning.pantry.write'
      ) then
        v_result:=jsonb_set(v_result,'{preview,can_save}','true'::jsonb,true);
      end if;
    end if;
  end if;
  return v_result;
end;
$$;

revoke all on function atlas_api.preview_pantry_source(jsonb)
from public, anon, authenticated, service_role;
grant execute on function atlas_api.preview_pantry_source(jsonb)
to authenticated;

comment on function atlas_api.preview_pantry_source(jsonb) is
  'PANTRY-02.v3 no-write canonical preview; APPROVED replacements may proceed to the separate Planning correction-impact Save gate.';

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;
reset role;
grant atlas_owner, atlas_read_runtime to postgres with set false;
