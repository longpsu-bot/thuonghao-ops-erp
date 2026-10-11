# Planning catchup execution diagnostics

The protected catchup runner emits fixed phase markers to stderr. They contain no source values, SQL text, credentials, row IDs or exception prose. The JSON result and plan checksum do not include diagnostics.

The transport retains only exact approved client lines and PostgreSQL NOTICE SQLSTATE codes. It forwards recognized markers through the runner's existing `onPhase` callback before returning or throwing, including on a client timeout. Since transport uses `spawnSync`, these inner markers are delivered after the child finishes or times out; their order identifies completed boundaries, but their log timestamps do not measure server phase duration.

| Marker                                       | Completed boundary                                                                                         |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `CATCHUP_CLIENT_SCRIPT_BEGIN`                | psql reached the submitted script                                                                          |
| `CATCHUP_CLIENT_SETTINGS_DONE`               | Existing statement/lock timeouts and NOTICE visibility were set                                            |
| `CATCHUP_CLIENT_HELPERS_DONE`                | All session-local helper definitions were submitted successfully                                           |
| `CATCHUP_CLIENT_QUERY_BEGIN`                 | psql reached the final catchup query                                                                       |
| `CATCHUP_SERVER_ENTRY` (`PZ001`)             | The catchup entry function started                                                                         |
| `CATCHUP_SERVER_SOURCE_CHECKED` (`PZ002`)    | Source contract, canonical checksum, read-only access evidence, shape and duplicate identity checks passed |
| `CATCHUP_SERVER_RECIPE_PLAN_DONE` (`PZ003`)  | Dependency validation, empty-root handling and the existing Recipe planner returned                        |
| `CATCHUP_SERVER_PROTECTED_DONE` (`PZ004`)    | School/plan preparation and protected-table fingerprints completed                                         |
| `CATCHUP_SERVER_MAPPING_HASH_DONE` (`PZ005`) | The whole OPS_V1 mapping fingerprint completed                                                             |
| `CATCHUP_SERVER_PLAN_HASH_DONE` (`PZ006`)    | The final plan checksum completed                                                                          |
| `CATCHUP_CLIENT_QUERY_DONE`                  | psql completed the final query                                                                             |

The first absent marker narrows the next investigation; it does not by itself prove a specific slow expression. For apply, the query continues through existing authorization, write, reconciliation and replay checks after plan hashing. A completed client query can still return a business `BLOCKED` result. Missing NOTICE markers may also reflect an interrupted connection before buffered stderr is recovered.

This instrumentation changes no source canonicalization, fingerprints, planner actions, migration-parity requirements, apply authorization or timeout budgets. Diagnostic failures must not trigger an automatic hosted retry or apply.
