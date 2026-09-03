import { runPinnedSupabase } from "./local-supabase-status.mjs";

// Local verifier prerequisite only; never invoked by a hosted/Staging workflow.
// Fixture evidence is seeded locally, but allocations use the real public command.
export async function saveLocalConfirmedAllocations(
  client,
  subject,
  workbench,
  invoke,
  seedLocal = (sql) =>
    runPinnedSupabase(["db", "query", "--local", "--agent", "no", sql], {
      stdio: "ignore",
    }),
) {
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const batch = workbench.confirmed_need_batch_id;
  if (!uuid.test(subject) || !uuid.test(batch))
    throw new Error("Local allocation fixture requires exact UUIDs.");
  const supplier = "c7100000-0000-4000-8000-000000000001";
  seedLocal(`insert into atlas_core.role_capabilities(role_id,capability_id)
    select distinct membership.role_id,capability.capability_id
    from atlas_core.actor_auth_subjects identity
    join atlas_core.actor_role_memberships membership using(actor_id)
    cross join atlas_core.capabilities capability
    where identity.auth_subject_id='${subject}'::uuid and membership.membership_status='ACTIVE'
      and capability.capability_code in ('procurement.school_catering.read','procurement.school_catering.write')
    on conflict do nothing;
    insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status)
    values('${supplier}','PR-A-VERIFY-A','PR-A Verify Supplier A','ACTIVE') on conflict do nothing;
    insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority,reason_note)
    select distinct '${supplier}'::uuid,line.ingredient_id,'2020-01-01'::date,1,'Local confirmed allocation verifier'
    from atlas_planning.confirmed_need_lines line where line.confirmed_need_batch_id='${batch}'::uuid
      and not exists(select 1 from atlas_admin.supplier_eligibilities existing
        where existing.supplier_id='${supplier}'::uuid and existing.ingredient_id=line.ingredient_id)
    on conflict do nothing;`);
  const read = await invoke(
    client,
    "get_confirmed_supplier_allocation_workbench",
    {
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      requested_by_auth_subject: subject,
      correlation_id: crypto.randomUUID(),
      payload: {
        date_start: workbench.service_period.period_start,
        date_end: workbench.service_period.period_end,
      },
    },
  );
  for (const row of read.rows ?? []) {
    if (
      row.family.source_confirmed_need_batch_id !== batch ||
      row.state === "BALANCED"
    )
      continue;
    if (!row.complete || row.family_quantity === null)
      throw new Error("Local confirmed source is incomplete.");
    const commandId = crypto.randomUUID();
    await invoke(client, "save_confirmed_supplier_allocation", {
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      command_id: commandId,
      correlation_id: crypto.randomUUID(),
      idempotency_key: `local-confirmed-allocation:${commandId}`,
      expected_version: row.family.version,
      requested_by_auth_subject: subject,
      requested_at: new Date(Date.now() - 1_000).toISOString(),
      reason_code: "CONFIRMED_SUPPLIER_ALLOCATION_SAVED",
      reason_note: null,
      payload: {
        family: {
          service_date: row.service_date,
          delivery_location_id: row.delivery_location_id,
          ingredient_id: row.ingredient_id,
          unit_id: row.unit_id,
          expected_source_fingerprint: row.family.source_fingerprint,
          expected_source_batch_id: batch,
          expected_source_batch_version:
            row.family.source_confirmed_need_batch_version,
        },
        splits: [
          { supplier_id: supplier, allocated_quantity: row.family_quantity },
        ],
      },
    });
  }
}
