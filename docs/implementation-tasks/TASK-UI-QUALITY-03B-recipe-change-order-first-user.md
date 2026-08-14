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
- system Recipe changes require one explicit `Loại công thức`, while one-School Recipe changes derive that type from the selected School;
- Recipe-line and representative-School choices are restricted to the authoritative Recipe type so cross-type targets cannot be proposed;
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

Focused frontend tests cover the table-first surface, human search/labels, authority-first decision order and exact scope mapping, unchanged action filtering, stale-field reset, modal fields, preview/save gating and invalidation, representative preview context, aligned ADD/REPLACE/ADJUST_QUANTITY/REMOVE consequences, history/correction/cancellation surfaces, absence of browser prompt/confirm, legacy attribution, backend-shaped status and the secondary effective-composition surface.

The final review correction keeps that workflow and all RMVP-02B contracts unchanged while improving first-use clarity in the existing Change Order modal:

- the Edit state expresses authority in the human order Business Object → all schools/one school → allowed business action → command payload, while mapping those choices to the existing four RMVP-02B scopes internally;
- changing Business Object, authority or action clears incompatible hidden payload fields and invalidates the preview; correction mode presents Business Object, authority and action as fixed business context;
- the form retains Mantine business controls, responsive field grouping and only `Xem ảnh hưởng` as its forward action;
- a successful authoritative preview opens a separate Review state with the business summary, effective period and representative preview context before `Lưu điều chỉnh` becomes available;
- `Quay lại` preserves the draft, while any material edit invalidates the preview and requires a fresh authoritative preview;
- the review fixture now resolves the exact Ingredient or Recipe-line target from the proposal, preserves the existing quantity and Unit when a replacement does not override them, and blocks safely if the deterministic target is missing;
- Review shows one complete aligned Before/After Recipe comparison keyed by existing Recipe-line identity; unchanged rows remain visible but subdued, while changed ADD/REPLACE/ADJUST_QUANTITY/REMOVE rows carry a directional marker and emphasis;
- normal modal/review markup exposes no backend scope/action enums, UUIDs or revision vocabulary.

The final Recipe-type targeting correction keeps the existing RMVP-02B contract and makes the OPS v1 Recipe variant boundary explicit in the Application:

- `Công thức của một món` + `Tất cả trường` still maps to `SYSTEM_DISH`, but now requires exactly one `Loại công thức`; there is no blank, optional or both-types choice, and the existing proposal carries that `school_type_id`;
- `Công thức của một món` + `Một trường` still maps to `SCHOOL_DISH`; the selected School supplies its authoritative School Type as read-only business context and the command retains the existing School/Dish target shape;
- changing Dish, School or Recipe Type clears stale stable-line/action payload values and invalidates any prior preview;
- target Recipe lines are filtered by exact Dish + School Type, and system-Recipe preview Schools are filtered to the same School Type; absence of a compatible School blocks preview with operator-facing guidance;
- Review and correction context identify the exact `Món · Loại công thức`, while the aligned comparison contains only that selected Recipe variant;
- no Recipe Swap, system-wide Ingredient retirement, multi-Recipe command, new scope, new action, new API or database change is introduced.

Focused pgTAP covers current, future, scheduled correction, scheduled cancellation, effective cancellation, finite successor, mandatory predecessor resumption, finite-first expiry, explicit-date behavior, function security and v1 callability. RMVP-02B, RMVP-02A/UI-QUALITY-03A and the current platform/security catalog remain required regressions.

No Atlas Staging, live OPS or Retool mutation is authorized. No Supabase deployment is part of this task. Disposable local database rollback is a clean reset; any deployed rollback would be forward-only and preserve immutable Recipe adjustment evidence.

## Final new-Change-Order target-safety correction

The Application no longer converts catalog ordering into operator intent when a new Change Order opens or when its Business Object, authority, School, Dish, or Recipe Type changes.

- Recipe + all schools starts with Dish and Recipe Type unset. Recipe Type presents one placeholder followed by exactly `Tiểu học` and `Trung học`; the representative School remains unset and filtered by the explicit Recipe Type.
- Recipe + one School starts with School and Dish unset. Recipe Type remains read-only and is derived only after the operator selects a School.
- Ingredient scopes start with School where applicable, current Ingredient, representative School, and representative Dish unset.
- Recipe-line, substitute Ingredient, quantity/Unit payload, and authoritative preview state clear whenever their parent target changes; hidden stale IDs cannot flow into a proposal.
- Preview remains unavailable until every authoritative target, action-specific payload, representative preview context, effective date, and reason required by the existing contract is supplied.
- Correction mode continues to hydrate and freeze the authoritative context of the existing adjustment. The accepted Review comparison and Preview-before-Save gate are unchanged.

This is an Application-only safety correction. `RMVP-02B.v1`, the additive `RMVP-02B.v2` read, scope/action semantics, precedence, persistence, authorization, correction, cancellation, immutable history, and all Supabase artifacts remain unchanged.

## Final modal and Unit-context polish

- The Change Order modal uses a responsive `1000px` target width with `20px` viewport offsets, an `86dvh` content cap, internal vertical scrolling and no horizontal overflow. Quantity/Unit and effective-period fields share two columns when space permits and stack at constrained widths.
- Unit is no longer an operator choice. ADD derives the selected Ingredient purchase Unit; quantity-bearing REPLACE derives the substitute Ingredient purchase Unit; ADJUST_QUANTITY displays the target Recipe-line Unit while sending `unit_id = null`; REMOVE and REPLACE without quantity override expose no Unit field.
- Missing required Ingredient purchase Unit blocks Preview with a safe Vietnamese explanation and no fallback. Existing Recipe-line Units are never normalized to current Ingredient master data.
- `RMVP-02B.v2` enriches only its Ingredient catalog with `purchase_unit_id` and `purchase_unit_name`; all six v1 functions and the v1 Ingredient shape remain unchanged, with no new capability or persistence.
- Broad typography normalization is explicitly deferred as cross-flow UI review debt until Attendance → Menu → Need generation → Need confirmation can be evaluated together. This task changes no global font sizes, theme typography, label sizing, table typography or typography tokens.
