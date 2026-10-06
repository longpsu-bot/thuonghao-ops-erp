# Checkpoint E — Atlas v3 legibility comparison

Status: **three visual prototypes ready for Product evaluation; direction NOT approved**.

The Product Owner reopened the visual portions of Atlas Design Language v2 following real staff feedback. The previous Impeccable PASS does not certify operator readability. This comparison does not approve a winner or change the production theme. PR [#354](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/354) must remain unmerged until Product explicitly approves the v3 direction.

## Controlled scope

Question: which shared palette makes boundaries, controls, selection and operational text easiest to scan on the existing Atlas workspaces?

Prototype branch: `codex/atlas-v3-legibility-variants`, based on #354 commit `ea0d00a3cbf413588462873b8e03370e476f08d6`. The prototypes run through the local review route and are published on the separate comparison branch; they have not been applied to #354. D-048 owner architecture, retained drafts, commands, quantities, units, status lifecycles, backend authority, contracts, layout composition and responsive breakpoints remain fixed. No database migration, dependency, hosted write or production data change is involved.

Allowed files: the opt-in review entry, an optional system argument in the existing Atlas provider, one prototype token/recipe overlay, a capture script and this evidence. The normal production provider still defaults to the unchanged Atlas v2 system. These prototypes reuse its scoped system and portals.

All three variants share the same legibility adjustments:

- White workbench; toolbar, supporting and context surfaces use one shared supporting tone. Workspace and selection retain separate roles. Semantic roles remain distinct even where their palette values are equal.
- Table text and quantities are at least 14px. Labels render at 14px/600; the helper style is 13px. Larger text intentionally takes precedence over squeezing more information into a viewport.
- Stronger structural and enabled-control boundaries; white enabled inputs and textareas.
- Active tabs combine weight, underline and outline. Selected table rows combine fill, boundary, first-cell underline and a 4px inset action-color marker. A phone's existing open-workspace selector explicitly names the active owner.
- Primary actions are solid; secondary actions have a visible outline; tertiary actions have an underlined label. Existing enabled/disabled conditions remain authoritative.
- The captured invalid-menu alert combines a warning icon, amber fill/border and its existing diagnostic text. Status severity and business wording are unchanged. This capture demonstrates the warning/error direction, not every possible operation status.

## Evidence

Open the [interactive comparison](atlas-v3-legibility-comparison.html). It includes all four screens at **1440×900, 1366×768 and 360×800** for A, B and C: **36 primary PNGs**, plus **9 phone detail PNGs** showing menu cells, recipe quantity/unit pairs and allocation/save actions. Images are actual browser captures, not design mockups.

Use 100% mode for legibility; the fit overview scales pixels and is only useful for composition. Open individual images for native-size inspection. The gallery's own scrolling is separate from the application's table scrolling.

Every variant uses the same fixture date, records, drafts and open-owner set:

| Screen           | Fixed comparison state                                                                                                       |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Thực đơn         | Google source candidate with one valid soup cell and one unresolved dish; save remains blocked with its exact diagnostics.   |
| Xác nhận nhu cầu | Gạo thơm quantity 31, reason OTHER and the same explanatory note; other lines in the same six-line need workbench unchanged. |
| Công thức        | Canh bí đỏ thịt bằm selected; Bí đỏ draft quantity 2,25 with read-only Kilôgam derived from its Ingredient.                  |
| Phân bổ NCC      | Gạo thơm selected; 60/40 allocation and “Giao sớm” supplier note; existing save/close behavior.                              |

The capture check compares normalized owner text and control values across A/B/C for each screen/viewport. [Measurements](../testing/artifacts/atlas-v3-legibility-variants/measurements.json) record computed styles, selected-row markers, owners and focus/overflow checks. [Token contrast](../testing/artifacts/atlas-v3-legibility-variants/token-contrast.json) records palette values and computed luminance ratios.

## Comparative evaluation

These are engineering observations from the real browser evidence. They are **not invented staff ratings**. There is no aggregate aesthetic score.

| Criterion                  | A — Neutral High Contrast                                                                                            | B — Strong Atlas Green                                                                                                  | C — Neutral Operational + Atlas Accents                                                                                                                       |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Section/surface separation | Strongest workspace/white and selected/white fill differences; slate structure is easy to distinguish in grayscale.  | Strong borders, but broad green supporting surfaces remain relatively close to white.                                   | Strong neutral boundaries; supporting fill remains close to white, so borders carry much of the separation.                                                   |
| Control discoverability    | Dark neutral edges and white fields provide the strongest measured control contrast.                                 | Green edges and white fields are clear; control color repeats elsewhere in the workspace.                               | Neutral edges distinguish enabled fields; green is reserved mainly for meaningful actions and markers.                                                        |
| Selected/active clarity    | Strongest selected fill difference, plus shared outline, underline and marker.                                       | Strong green selection marker and fill; green also appears in navigation and supporting surfaces.                       | Shared cues make selection explicit, but its fill difference is the weakest. The marker is essential, not optional.                                           |
| Table readability          | Highest default and muted text contrast; 14px minimum.                                                               | 14px minimum and strong text contrast; green supporting tint is more pervasive.                                         | 14px minimum and strong text contrast; neutral rows let quantities and green actions retain emphasis.                                                         |
| Action hierarchy           | Solid slate primary, outlined secondary, underlined tertiary are distinct.                                           | Solid green primary is prominent, alongside more green context.                                                         | Solid green primary is distinct against mostly neutral surfaces; secondary and tertiary remain differentiated.                                                |
| Status/error visibility    | Same icon + amber fill/border + diagnostic text, distinct from slate selection.                                      | Same warning treatment, distinct from green selection. Green selection/action/success associations need staff checking. | Same warning treatment, distinct from neutral structure and green actions.                                                                                    |
| Density                    | Same enlarged text, control sizes, wrapping and scroll paths. No density advantage over B/C.                         | Same as A.                                                                                                              | Same as A.                                                                                                                                                    |
| Prolonged-use legibility   | Strongest measured separation; repeated strong gray boundaries may feel visually busy. This is a hypothesis to test. | Broad green tint may make states harder to distinguish during repeated scanning. This is a hypothesis to test.          | Neutral surface direction is suitable for a staff trial, but its weaker fill separation must be checked over repeated work. No prolonged-use PASS is claimed. |

The measured ratios below compare each token with white workbench. Surface ratios are descriptive, **not a sufficient acceptance test**; the former v2 problem is exactly why text contrast alone cannot decide this review.

| Token / white workbench  |     A |     B |     C |
| ------------------------ | ----: | ----: | ----: |
| Default text             | 16.29 | 15.64 | 15.42 |
| Muted text               |  7.88 |  7.64 |  7.46 |
| Enabled-control boundary |  4.97 |  4.74 |  4.66 |
| Structural boundary      |  3.56 |  3.73 |  3.59 |
| Workspace fill           |  1.38 |  1.30 |  1.32 |
| Supporting/toolbar fill  |  1.23 |  1.19 |  1.20 |
| Selected fill            |  1.47 |  1.31 |  1.20 |
| Primary action fill      | 12.54 |  7.38 |  7.42 |

A provides the strongest measured fill separation. C follows the requested neutral operational surfaces with Atlas green as action/accent. B demonstrates the cost and benefit of stronger brand-green presence. **These facts do not establish a staff-approved winner.** Product should choose from operator readability evidence, including any further adjustment request.

## Density and remaining limits

At 1440×900 the confirmed-need table shows all six fixture lines. The shorter desktop viewport and phone show less operational detail at once. Recipe quantity/unit editing and allocation save actions require existing scrolling on the phone; the detail images prove that those controls remain reachable. Menu columns retain their existing local horizontal scrolling and sticky School column. The phone menu detail shows the soup column, while a long invalid dish diagnostic can extend below the viewport.

The larger labels, selected marker and stronger boundaries improve scan cues but do not eliminate these geometry constraints. No new responsive architecture, pane arrangement or business interaction is proposed here. No prolonged-use study has been performed in this session. All variants use the same warning prototype treatment; success, loading and unknown-outcome presentation still need the approved v3 implementation's final state review.

Suggested staff exercise: on the same display at 100% zoom, perform the same four tasks in each variant—locate the bad menu cell, identify the changed need quantity and reason, verify recipe quantity/unit, then find the allocation save action. Rotate variant order. Record wrong-row/field choices, time to locate, missed state cues and a simple readability rating after 10–15 minutes. Staff errors and state recognition outrank brand preference; Product can reject or request adjustments to all three.

## Verification and approval gate

Acceptance for this comparison: three controlled variants, four equal-state screens, all three requested viewport sizes, non-fill selection cues, measured typography/control boundaries and an explicit operator-oriented evaluation. Browser capture assertions passed for **36 primary + 9 detail images**: equal state, table text ≥14px, labels 14px/600, selected-row marker present, one active owner, hidden owners inert, no hidden focus, no document horizontal overflow and zero hosted requests or page errors. The existing provider/system tests passed **12/12**. TypeScript and the vNext UI boundary check passed. The gallery was checked against all image paths and native dimensions.

This is prototype validation, not the requested post-approval final certification. Full #354 functional tests and final CI have not been rerun for an unapproved theme. Previous #354 CI applies to its unchanged `ea0d00a` head, not these local prototypes.

**Product decision required:** approve A, B or C as the v3 direction, or identify required changes. No approval is inferred from a recommendation, elapsed time or a previous Impeccable PASS.

After explicit Product approval: implement the chosen direction in production semantic tokens/recipes and shared visual components; remove the comparison overlays; update the design-language document as Atlas Design Language v3; rerun all #354 functional tests; recapture final browser evidence; perform Impeccable polish and Ponytail FULL review; obtain final CI and product/architecture review. #354 remains blocked from merge until that work passes.

Rollback of this comparison: return to `feat/atlas-product-corrections-01` at `ea0d00a`; the production theme and database remain unchanged. No migration or operational-document rollback is required.
