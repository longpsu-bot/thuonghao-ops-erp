begin;

set local role atlas_owner;

create function atlas_core.command_receipt_integrity_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '23514',
      message = 'Command receipt history cannot be deleted.';
  end if;

  if tg_op = 'INSERT' then
    if new.outcome <> 'IN_PROGRESS' or new.completed_at is not null
       or new.response_payload is not null or new.error_code is not null then
      raise exception using errcode = '23514',
        message = 'A command receipt must start without terminal evidence.';
    end if;
    return new;
  end if;

  if row(new.command_receipt_id, new.command_name, new.scope_key,
         new.idempotency_key, new.command_id, new.correlation_id, new.actor_id,
         new.expected_version, new.request_hash, new.started_at)
     is distinct from
     row(old.command_receipt_id, old.command_name, old.scope_key,
         old.idempotency_key, old.command_id, old.correlation_id, old.actor_id,
         old.expected_version, old.request_hash, old.started_at) then
    raise exception using errcode = '23514',
      message = 'Command receipt identity is immutable.';
  end if;

  if new is not distinct from old then
    return new;
  end if;

  if old.outcome <> 'IN_PROGRESS' then
    raise exception using errcode = '23514',
      message = 'Terminal command receipt evidence is immutable.';
  end if;

  if new.outcome not in ('COMPLETED', 'FAILED_NON_RETRYABLE')
     or new.completed_at is null or new.response_payload is null then
    raise exception using errcode = '23514',
      message = 'A command receipt can only advance to a complete terminal result.';
  end if;
  return new;
end;
$$;

revoke all on function atlas_core.command_receipt_integrity_guard()
  from public, anon, authenticated, service_role;

create trigger command_receipts_integrity
before insert or update or delete on atlas_core.command_receipts
for each row execute function atlas_core.command_receipt_integrity_guard();

-- Nested Planning commands share the outer receipt; only its finalizer owns
-- the final atomic response, including failure after a nested rollback.
create or replace function atlas_core.pa_05b_finish_command(
  p_command_receipt_id uuid,
  p_response_payload jsonb,
  p_succeeded boolean
)
returns jsonb language plpgsql volatile security invoker set search_path = ''
as $$
begin
  update atlas_core.command_receipts cr
  set outcome = case when p_succeeded then 'COMPLETED' else 'FAILED_NON_RETRYABLE' end,
      response_payload = p_response_payload,
      error_code = case when p_succeeded then null else p_response_payload ->> 'error_code' end,
      completed_at = pg_catalog.transaction_timestamp()
  where cr.command_receipt_id = p_command_receipt_id
    and cr.outcome = 'IN_PROGRESS'
    and cr.command_name not in (
      'save_weekly_menu', 'save_attendance', 'save_pantry', 'execute_need_generation'
    );
  return p_response_payload;
end;
$$;

create or replace function atlas_core.planning_contract_01_finish_receipt(
  p_receipt_id uuid, p_response jsonb, p_succeeded boolean
)
returns jsonb language plpgsql volatile security invoker set search_path = ''
as $$
begin
  update atlas_core.command_receipts receipt
  set outcome = case when p_succeeded then 'COMPLETED' else 'FAILED_NON_RETRYABLE' end,
      response_payload = p_response,
      error_code = case when p_succeeded then null else p_response ->> 'error_code' end,
      completed_at = pg_catalog.transaction_timestamp()
  where receipt.command_receipt_id = p_receipt_id
    and receipt.outcome = 'IN_PROGRESS'
    and receipt.command_name in (
      'save_weekly_menu', 'save_attendance', 'save_pantry', 'execute_need_generation'
    );
  return p_response;
end;
$$;

reset role;
grant atlas_need_generation_runtime to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_core to atlas_need_generation_runtime;
set local role atlas_need_generation_runtime;

do $receipt_order$
declare
  definition text;
  old_flush constant text := $old$    -- Flush the private materializer's deferred cross-aggregate guards while
    -- the released run and its Confirmed Need pointer are mutually current.
    -- This keeps a later correction from rechecking an obsolete queued event
    -- after the predecessor has been deliberately invalidated.
    set constraints all immediate;
    set constraints all deferred;$old$;
  response_end constant text := $old$      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
  exception when sqlstate 'PC104' then$old$;
  materialized constant text := $old$      raise sqlstate 'PC104' using message = 'Confirmed Need materialization failed';
    end if;

$old$;
begin
  select pg_get_functiondef('atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure)
    into definition;
  if position(materialized || old_flush in definition) = 0
     or position(response_end in definition) = 0 then
    raise exception 'RECEIPT_INTEGRITY_PLANNING_BASELINE_MISMATCH';
  end if;
  definition := replace(definition, materialized || old_flush, materialized);
  definition := replace(definition, response_end, $new$      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
    -- Continuity guards require the final completed receipt. Complete inside
    -- this subtransaction so any guard failure rolls back completion and facts.
    perform atlas_core.planning_contract_01_finish_receipt(v_receipt_id, v_response, true);
    set constraints all immediate;
    set constraints all deferred;
  exception when sqlstate 'PC104' then$new$);
  execute definition;
end;
$receipt_order$;

reset role;
set local role atlas_owner;
revoke create on schema atlas_core from atlas_need_generation_runtime;
reset role;
-- Preserve the established ownership-inheritance edge while closing SET.
grant atlas_need_generation_runtime to postgres with set false;

commit;
