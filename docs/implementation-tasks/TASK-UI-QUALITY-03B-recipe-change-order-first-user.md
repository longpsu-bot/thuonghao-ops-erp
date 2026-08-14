# UI-QUALITY-03B — Recipe Change Order First-User Redesign

**Status:** Implemented on bounded draft branch; independent Product/Architecture review pending
**Baseline:** `931ef987b49f4024f5662c6bd8dc3f3864ea50d7`
**Contracts:** `RMVP-02B.v1` unchanged; additive `RMVP-02B.v2` operator read

## Bounded capability

Present the accepted post-lock Recipe composition adjustment job as a Vietnamese business correction / Change Order workbench. The Application is table-first, collects a business intent and valid scope, requires the existing authoritative preview before commitment, and keeps correction, cancellation, history and effective composition subordinate to the ordinary operator job.

## Workflow preserved

- locked Recipe composition changes remain Change Orders;
- the existing four scope semantics remain unchanged;
- the existing four business actions remain available only where the accepted matrix allows them;
- authoritative preview remains required before commitment;
- dated correction and cancellation continue through the existing commands;
- immutable history remains intact;
- the explicit-date effective composition resolver remains available.

## Workflow improved

- table-first operator surface with search by Dish, School and Ingredient names;
- business-language creation, correction and cancellation in application modal/drawer surfaces;
- authoritative preview gating, with every material edit invalidating the prior preview;
- explicit representative School/Dish context for broad-scope preview without claiming global blast-radius enumeration;
- backend-shaped temporal status for an explicit reference date, including finite-successor resumption;
- native issuance and unavailable OPS v1 attribution are distinguished safely;
- legacy OPS v1 business issuance date and issuer both remain unavailable rather than reusing Atlas import provenance;
- cancelled rows retain their authoritative pre-cancellation business content while cancellation evidence remains in status and history;
- operator calendar defaults use the Asia/Ho_Chi_Minh local date;
- technical revision machinery is removed from the normal UI;
- `Công thức hiệu lực` remains a secondary read-only surface with technical lineage behind disclosure.

## Workflow intentionally changed

NONE.

## Explicit deferred OPS v1 cutover capabilities

Known OPS v1 capabilities intentionally deferred from UI-QUALITY-03B pending separate Product disposition before final Recipe cutover:

- whole-Recipe swap;
- system-wide Ingredient retirement.

This is a deliberate scope boundary, not a claim that the capabilities no longer exist. UI-QUALITY-03B does not emulate either capability with RMVP-02B actions and does not change the accepted action/scope matrix.

## Additive backend read

`atlas_api.get_recipe_adjustment_operator_workbench(request jsonb)` requires `RMVP-02B.v2` and an explicit `as_of_date`. It reuses the existing read capability/runtime, Recipe adjustment relations and immutable revisions; adds no persistence, role, capability, write API, action, scope or generic status infrastructure; and leaves all six `RMVP-02B.v1` functions physically callable.

The read returns human-reference catalogs, enriched released Recipe-line choices, narrow operator rows, internal command identity, display/content/current command revisions, immutable business history, native/legacy issuance provenance and server-derived temporal state. For cancelled roots the backend selects the preceding business content revision; React supplies Vietnamese labels but does not infer revision lineage or decide applicability.

## Verification and boundaries

Focused frontend tests cover the table-first surface, human search/labels, modal fields, preview/save gating and invalidation, representative preview context, history/correction/cancellation surfaces, absence of browser prompt/confirm, legacy attribution, backend-shaped status and the secondary effective-composition surface.

Focused pgTAP covers current, future, scheduled correction, scheduled cancellation, effective cancellation, finite successor, mandatory predecessor resumption, finite-first expiry, explicit-date behavior, function security and v1 callability. RMVP-02B, RMVP-02A/UI-QUALITY-03A and the current platform/security catalog remain required regressions.

No Atlas Staging, live OPS or Retool mutation is authorized. No Supabase deployment is part of this task. Disposable local database rollback is a clean reset; any deployed rollback would be forward-only and preserve immutable Recipe adjustment evidence.
