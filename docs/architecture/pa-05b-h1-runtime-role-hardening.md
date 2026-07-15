# PA-05B-H1 — Runtime-role hardening

**Status:** Implemented for Issue #82

## Outcome

PA-05B-H1 narrows the first Atlas write runtime before any broader command expansion. The shared `atlas_command_runtime` role is retained only as a retired compatibility role with no Atlas schema, table, sequence, or function privilege.

The public API remains function-only. `anon` and `service_role` cannot use `atlas_api`; `authenticated` can execute only the reviewed PA-05B and PA-05C functions and has no direct private relation access.

## Runtime roles

| Role | Allowed responsibility |
| --- | --- |
| `atlas_evidence_command_runtime` | Owns and executes only `record_supplier_receiving_evidence` and `apply_supplier_evidence_to_allocation`. It cannot use the Dispatch schema. |
| `atlas_dispatch_command_runtime` | Owns and executes only `confirm_dispatch_load`, `record_dispatch_departure`, and `confirm_successful_delivery`. It cannot insert Evidence or Procurement facts. |
| `atlas_read_runtime` | Owns the supplier-direct trace and PA-05C read wrappers. It has select-only private relation access and no sequence mutation privilege. |
| `atlas_owner` | No-login owner for private helper functions and Atlas objects; it is not an API role. |

All SECURITY DEFINER entry functions retain an empty fixed `search_path`. No runtime role has `CREATE` on an Atlas schema. Row-lock-only `UPDATE` privileges remain only where PostgreSQL requires them for the approved command path; RLS does not allow cross-domain mutation.

## Verification and next gate

`supabase/tests/pa_05b_h1_runtime_role_hardening_test.sql` inventories effective schema, relation, sequence, function-ownership, callable API, and RLS-policy exposure. PA-04, PA-05B, and PA-05C regression tests continue to pass.

Issue #82 is safe to close because the shared write runtime no longer grants a future command owner access across both Evidence and Dispatch. A new write command still requires its approved contract, a command-family privilege review, and focused security tests; this task does not authorize a broader command surface.
