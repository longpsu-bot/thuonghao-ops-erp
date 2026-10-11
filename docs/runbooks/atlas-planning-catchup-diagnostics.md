# Planning catchup execution diagnostics

The protected catchup runner emits fixed phase markers to stderr. They contain no source values, SQL text, credentials, row IDs or exception prose. The JSON result and plan checksum do not include diagnostics.

The transport retains only exact approved client lines and PostgreSQL NOTICE SQLSTATE codes. It forwards recognized markers through the runner's existing `onPhase` callback before returning or throwing, including on a client timeout. Since transport uses `spawnSync`, these inner markers are delivered after the child finishes or times out; their order identifies completed boundaries, but their log timestamps do not measure server phase duration.

| Marker                                        | Completed boundary                                                                                         |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `CATCHUP_CLIENT_SCRIPT_BEGIN`                 | psql reached the submitted script                                                                          |
| `CATCHUP_CLIENT_SETTINGS_DONE`                | Existing statement/lock timeouts, NOTICE visibility and session generic-plan mode were set                 |
| `CATCHUP_CLIENT_HELPERS_DONE`                 | All session-local helper definitions were submitted successfully                                           |
| `CATCHUP_CLIENT_QUERY_BEGIN`                  | psql reached the final catchup query                                                                       |
| `CATCHUP_SERVER_ENTRY` (`PZ001`)              | The catchup entry function started                                                                         |
| `CATCHUP_SERVER_SOURCE_CHECKED` (`PZ002`)     | Source contract, canonical checksum, read-only access evidence, shape and duplicate identity checks passed |
| `CATCHUP_SERVER_SCOPE_DONE` (`PZ007`)         | Missing-Dish dependency scope was derived                                                                  |
| `CATCHUP_SERVER_DEPENDENCIES_DONE` (`PZ008`)  | Core dependency identity, collision, lifecycle and drift checks completed                                  |
| `CATCHUP_SERVER_EMPTY_ROOTS_DONE` (`PZ009`)   | Empty Recipe root planning completed                                                                       |
| `CATCHUP_SERVER_RECIPE_INPUT_READY` (`PZ010`) | The unchanged composed-Recipe projection is ready for the legacy planner                                   |
| `CATCHUP_SERVER_RECIPE_PLAN_DONE` (`PZ003`)   | Dependency validation, empty-root handling and the existing Recipe planner returned                        |
| `CATCHUP_SERVER_PROTECTED_DONE` (`PZ004`)     | School/plan preparation and protected-table fingerprints completed                                         |
| `CATCHUP_SERVER_MAPPING_HASH_DONE` (`PZ005`)  | The whole OPS_V1 mapping fingerprint completed                                                             |
| `CATCHUP_SERVER_PLAN_HASH_DONE` (`PZ006`)     | The final plan checksum completed                                                                          |
| `CATCHUP_CLIENT_QUERY_DONE`                   | psql completed the final query                                                                             |

The first absent marker narrows the next investigation; it does not by itself prove a specific slow expression. For apply, the query continues through existing authorization, write, reconciliation and replay checks after plan hashing. A completed client query can still return a business `BLOCKED` result. Missing NOTICE markers may also reflect an interrupted connection before buffered stderr is recovered.

This instrumentation changes no source canonicalization, fingerprints, planner actions, migration-parity requirements or apply authorization. Normal execution retains its existing timeout budgets. Diagnostic failures must not trigger an automatic hosted retry or apply.

## Optional diagnostic boundary preview

Use `--diagnostic-boundary` only for an explicitly authorized preview investigation. It rejects apply before source access, emits `PLANNING_CATCHUP_DIAGNOSTIC_BOUNDARY_MODE`, and limits the catchup execution client to 60 seconds so buffered phase markers become available promptly. The normal 20-minute client budget remains unchanged when the flag is absent.

Only this mode adds session-local `SET client_connection_check_interval='2s'` before helper definitions, allowing PostgreSQL to check for a disconnected client during execution. It does not guarantee cancellation during every kind of server wait or establish the restart cause. The existing generic-plan candidate, complete signed source, SQL statement/lock timeouts, helpers, actions and hashes remain unchanged.

A completed result is explicitly marked `diagnostic_boundary: true`, `execution_mode: DIAGNOSTIC_PREVIEW` and `status: DIAGNOSTIC_PREVIEW`; `backend_status` retains the underlying result status. A diagnostic run, including one that completes successfully, is not final preview certification or apply authorization. A timeout yields only recovered phase evidence, not a completed plan. No automatic retry follows it.

## Bounded generic-plan candidate

The observed preview reached `SERVER_ENTRY` and `SOURCE_CHECKED`, but not `RECIPE_PLAN_DONE`, before a PostgreSQL restart. This narrows the failure to scope/dependency/Recipe preparation or planning. It does not prove an out-of-memory failure or identify a specific expression. Separate read-only measurements completed the full mapping canonical hash and historical missing-action loop in a few seconds each; those measurements do not reproduce the full nested planner workload.

The next candidate changes only the session planning strategy: `SET plan_cache_mode='force_generic_plan'` before helper definitions. It applies to the isolated psql catchup session for preview and apply; it changes no role, database or persistent function configuration. The repository already uses a bounded generic-plan setting for a separate high-fanout command in migration `20260920154302`; that precedent supports testing this hypothesis, not assuming the same root cause here.

All source payloads, actions, hashes, dependency checks and legacy helpers remain unchanged. The four additional markers distinguish scope creation, core dependency checks, empty roots and the legacy planner input boundary. The rolled-back pgTAP fixture compares the same complete signed source under `auto` and `force_generic_plan`, asserting identical plan checksum, actions and issues, successful previews, unchanged source and protected target facts. Remaining catchup regressions execute under the candidate mode. The session setting disappears when psql exits; reverting this candidate removes the single builder setting.
