# RECIPE-SYSTEM-COMMAND-CONTEXT-01

**Status:** Implemented and locally validated on a bounded Draft branch; merge blocked on PR #258 and exact combined-head review
**Baseline:** `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`
**Contract:** backward-compatible `RMVP-02B.v1` JSONB amendment

## Bounded correction

`SYSTEM_DISH` Preview, Create, and Supersede now use the business context Dish + one active canonical School Type + explicit as-of date. The three existing RPCs accept `school_type_id` for Preview and `preview_school_type_id` for Create or Supersede. `school_id` and `preview_school_id` are absent or null on this path.

The backend verifies the proposal and reviewed context name the same Dish and School Type. It resolves both current and hypothetical composition through the strict typed Recipe authority:

```text
typed released Recipe
→ SYSTEM_INGREDIENT
→ SYSTEM_DISH
```

No representative School, `SCHOOL` layer, `SCHOOL_DISH` layer, or nullable GENERAL fallback participates. `SCHOOL` and `SCHOOL_DISH` retain their existing School-based context, and `SYSTEM_INGREDIENT` retains its existing explicit impact-preview semantics.

## Safety retained

The correction replaces the bodies of the existing three JSONB functions in place. It creates no business object, lifecycle, table, helper API, role, capability, policy, or dependency. Function owners, fixed empty `search_path`, authenticated execution grants, forced RLS, typed target locks, root lock, optimistic concurrency, immutable revisions, receipts, events, audit records, and safe error envelopes remain unchanged.

The established request hash already covers the full payload except its documented time/correlation exclusions, so `school_type_id` and `preview_school_type_id` are part of replay and changed-content conflict semantics without a new hashing path. Non-ADD stable target identity remains exactly one of base `target_recipe_line_id` or prior-ADD `adjustment_line_id`.

## Acceptance evidence

| Acceptance                     | Focused evidence                                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------------------------ |
| A07-1 true system Preview      | canonical typed Preview succeeds without a School                                                |
| A07-2 no School contamination  | a same-type School exception cannot change system before/after or lineage                        |
| A07-3 no representative School | a valid canonical typed Recipe with no same-type School previews successfully                    |
| A07-4 base-origin target       | Preview/Create retain `target_recipe_line_id` and null `adjustment_line_id`                      |
| A07-5 prior system ADD target  | Preview/Create retain the prior stable `adjustment_line_id`                                      |
| A07-6 Create                   | one root/revision plus receipt, event, audit, and strict system readback                         |
| A07-7 Supersede                | predecessor, root version, stable target, system-only result, and old-row immutability           |
| A07-8 invalid context          | mismatch, noncanonical/inactive, mixed, missing, and wrong-Dish cases fail closed                |
| A07-9 School regression        | existing `SCHOOL` and `SCHOOL_DISH` Preview/Create/Supersede suite remains green                 |
| A07-10 concurrency/idempotency | exact replay, changed-content conflict, stale version, and context-bound revalidation            |
| A07-11 security                | intended capability succeeds; subject/capability/anonymous access and private grants stay closed |

Focused SQL tests and the authenticated browser-key verifier provide the executable evidence. The existing broader RMVP-02B suite remains the School-path regression authority.

The pre-migration RED run rejected the new A07 system-context cases. After the migration, a clean local reset and one combined run passed 158 tests across the current platform security catalog, Recipe effective product model, focused effective contract, and broader RMVP-02B suite. The authenticated browser-key verifier also passed all 11 scope/action Preview and Save combinations, strict system readback, exact precedence, replay, Supersede, dated Cancel, stale rejection, immutable lineage, and reauthentication.

The focused effective-contract fixture now uses fixed validation and release timestamps. Its previous wall-clock-relative timestamps had crossed the scenario's explicit September 2026 dates and made existing date assertions depend on the day the suite ran; the change affects test data only.

## Boundaries and rollback

A12 legacy issuance provenance is unchanged. Cancel is unchanged. No frontend, Planning, Procurement, Warehouse, Staging, live OPS, Retool, deployment, or hosted-data write belongs to this task.

## Integration gate

This branch starts directly from the required `origin/main` baseline. That baseline's connected admin UI still emits the older representative-School payload for `SYSTEM_DISH`; the corrected UI contract is owned by the separate Draft PR #258 and is explicitly excluded from this branch. This Draft PR must not merge or deploy before #258 is merged and this branch is rebased or otherwise updated onto that accepted frontend. The resulting combined head must pass the connected UI and backend contract checks before either change is considered releasable. Keeping this dependency explicit avoids accepting the invalid proxy-School contract or copying unmerged frontend work across branches.

The migration is forward-only. A disposable local database may be reset before use. After business use, correction requires another reviewed forward migration or a whole-database restore that preserves immutable adjustment, receipt, event, and audit evidence.
