# Journey closeout — 21 October 2026

The Owner requested completion of the remaining work after the Need and Unit-label improvement. This bounded change resolves the recorded Attendance, PO-impact and export presentation defects. Backend authority, explicit operator actions, exact quantities/Units and frozen document contents remain unchanged. No API, dependency, schema, lifecycle, hosted setting or OPSv1/Retool change is included.

## Repairs and evidence

- Attendance warnings use the existing Vietnamese guidance and one disclosure per code. Every warning instance, original message, code and source coordinate remains available; unknown blockers retain their original diagnostic. Save authority is unchanged. Regression cases fail before and pass after.
- PO dispatch-impact reads are bound synchronously to the API, operator, selected PO and refresh identity, including the committed paint before passive effects. Previous selection data cannot appear under a new selection. Effect cleanup still rejects late results; no command is added.
- PDF and Excel add the issuer address prefix only when absent. Captured source addresses and metadata are unchanged.
- PXK inspection headers retain the accepted Roboto15 body size; the bold header's measured 69.214 pt width has 70 pt of content space. Inspection cells remain blank for handwriting.
- PXK final tables use measured pagination to keep ordinary final food rows with signatures, including one/two-line documents with long notes. Tables and rows remain breakable: tall content must flow across pages rather than disappear. Repeated headers have independent cells and widths because pdfmake mutates them during layout.
- A local 20,876-byte OFL arrow-only font subset supplies missing glyphs in PO/PXK notes. Roboto remains the normal font, quantities and raw note metadata stay exact, and no runtime package or network font is added. Provenance and license accompany the asset.

An independent source review found two Important PDF edge cases and one Minor diagnostic regression in the first candidate. All three are fixed; its focused follow-up found no remaining actionable concern in those fixes. Source review is not runtime or release certification.

Actual PDF RED → GREEN checks reproduce orphan signatures for one/two-line documents with a valid 30-line note; the corrected food rows and signatures share page two. Two final 25-line Ingredient names retain every line and signatures across three pages. A single 95-line name also retains all 95 lines and signatures across three pages after removing the unsafe row-level keep-together rule. Normal frozen 10/12-line successor examples remain two pages. Native rendered pages are visually inspected. The rendered PDF arrow regression checks the actual embedded Unicode mapping.

Focused verification: 168 tests across 8 files pass after review repairs; the final row-pagination change passes the affected 23 tests across 2 files. TypeScript, UI boundary and whitespace checks pass. Full normal Frontend and executed Full Integration remain required release gates.

Native Excel16 inspection of all four retained workbooks opens them read-only with macros/link updates disabled and verifies source hashes unchanged. It exposes a second presentation issue in the spreadsheet version: the inspection label clips and a manual break comes after all food rows. F widens11→14 and H narrows23→20, preserving total width; continuation pages repeat inspection headers9:10 and the break moves before the final two food rows. Fonts, exact cells/metadata and handwriting rows are retained. Native rendering of the corrected10/12-line frozen examples shows both complete headers and final food/signatures together on two pages. A fixed-scale experiment produced unwanted horizontal pages in native QA and was rejected; the existing portrait width-fitting remains intact. ExcelJS does not restore row breaks on import, so the regression checks the emitted workbook XML.

Initial exact-source Frontend CI `39609838606` fails a historical document-reproduction assertion because newly allocated layout callbacks have different identity. No printed fact differs. State-independent callbacks now use stable module constants; the original exact-definition and immutable-source assertions remain unchanged and pass. Final affected verification passes27tests across3files; TypeScript passes. Changed-source certification is required again; the failed run remains part of the record.

Native PO review also exposes the summary logo covering the start of the issuer name and clipped two-line date labels. The summary issuer/address use the existing detail-header centering pattern; detail date row5 and summary date row7 allow32pt for the same12pt text. Cell identities, exact dates and metadata are unchanged. All14 original native-workbook pages were reviewed; seven corrected pages (two frozen PXK examples and a three-view PO fixture) are then rendered and inspected. Final affected export/reproduction verification passes119tests across8files. The intentionally revised PXK continuation-header assertion is updated from1:10 to9:10; its exact-quantity, destination, status and footer assertions remain.

The initial source's executed Full Integration `39609853563` passes, but this does not certify the changed source. Normal Frontend and executed Full must both pass on the final revision.

Final-source Frontend `39613614684` passes3193tests (two existing skips) and fails only the historical PO worksheet-model hash: the deliberate header layout fixes change that model. The original historical golden is retained unchanged. The amended regression asserts the new exact row heights and both merged ranges' alignment, projects only those already-checked presentation fields back to their previous representation in the in-memory test model, then matches the original full-model hashes for all four modes. PDF-definition hashes remain exact. Every other layout field, quantity, Unit, note, date, Supplier/School identity, hidden source and metadata is still covered by the same baseline. The targeted case fails before and passes after this amendment. This follows the Owner-authorized visual repair scope and the business freeze's explicit statement that PO presentation is not globally frozen; it introduces no document-version or commitment authority.

## Runtime measurements

[All 30 additional observations](artifacts/need-generation-improvement/closeout-small-comparison.json) use five fresh equivalent clones per build, three daily generations per clone and alternating build order. Every generation, receipt, currentness and valid-path semantic assertion passes (28 assertions per clone). The baseline function body is checked exactly before applying the candidate. All synthetic facts roll back. No runtime is rejected for being slow.

This synthetic 19-line shape has two Schools, two School types, 32 atomic recipe contributions and 9/10 School/Ingredient groups. It uses 95 student/5 teacher portions and explicit no-additions Pantry. It represents the cardinality of the older hosted shape; it does not reconstruct that date's actual sources. Effective-composition changes, zero-demand Schools, direct additions and correction remain covered by the existing unchanged semantic suites and complete disposable/hosted journeys.

| Local database command |             Before |            Revised |
| ---------------------- | -----------------: | -----------------: |
| Generations            |                 15 |                 15 |
| Median                 |         192.277 ms |         189.913 ms |
| Minimum–maximum        | 165.110–605.621 ms | 165.201–569.336 ms |

The small difference does not support a meaningful speed promise for small workloads. The prior matched 248-line result remains separately reported: median 3,859.730 → 3,003.547 ms. Neither experiment establishes hosted p95, cold-cache behavior or an infrastructure guarantee.

[Complete first-generation function profiles](artifacts/need-generation-improvement/closeout-function-profiles.json) retain all 79 observed functions in each shape, with call counts and self/inclusive times. Separate nested plans capture statements taking at least 1 ms; inlined SQL is not separately visible in function statistics. These instrumented observations are not paired latency samples and nested inclusive times are not additive.

[Non-overlapping phase boundaries](artifacts/need-generation-improvement/closeout-phase-boundaries.json) come from a diagnostic timing copy inside an owned database transaction. Removing only the diagnostic lines recovers the original function exactly; rollback restores its source and all synthetic facts. Exact idempotent replay shares a command ID, so aggregation separates the first invocation at the next prepare boundary. The initial aggregation included replay preparation; raw observations are retained and the report is corrected without rerunning samples.

| First-generation diagnostic phase     |   19 lines |    248 lines |
| ------------------------------------- | ---------: | -----------: |
| Receipt preparation                   |   1.273 ms |     1.376 ms |
| Preflight                             |   5.065 ms |     6.107 ms |
| Readiness evaluation                  |  29.237 ms |    30.091 ms |
| Handoff                               |   8.033 ms |     8.072 ms |
| Generation / effective composition    | 262.312 ms | 1,161.879 ms |
| Validation                            |  10.117 ms |    61.315 ms |
| Release                               |  70.368 ms |   197.915 ms |
| Confirmed Need materialization        |  38.326 ms |   249.795 ms |
| Authoritative preflight readback      |   6.731 ms |    38.348 ms |
| Response / workbench construction     |   2.524 ms |    28.021 ms |
| Final deferred-constraint flush       |  65.724 ms |   843.488 ms |
| Other orchestration / instrumentation |   5.885 ms |     6.822 ms |
| Whole observed command                | 505.595 ms | 2,633.229 ms |

The separate function profile ranks the Need integrity guard at 109/993 calls and 263.476/931.841 ms self time, and revision-membership totals at 51/552 calls and 52.391/823.553 ms. These overlap the phase table; do not add them. They identify the next bounded investigation: reduce repeated integrity work while proving the same source, revision-membership and transaction-end invariants. No guard is removed in this change.

The first nested-plan attempt could not load `auto_explain` as the local `postgres` role. Its failure is retained; it wrote no fixture facts. The diagnostic-only run uses the existing `supabase_admin` identity in fresh owned clones. No hosted privilege changes occur. The local container was idle before samples (each container at most 0.17% CPU); this cannot explain past hosted latency. PostgreSQL17, `jit=off`, historical clone migration-metadata limitations and all earlier contended/failed observations remain disclosed in the prior report.

## Release and actual-app closeout

PR [428](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/428) merges as `30f0f8f16365e7111323bc0daeede24907cb91f4`; its tree exactly matches reviewed head `c4643e3c`. Exact-head Frontend `39616292654` and the actually executed Full Integration job `39616292623` both pass. The final 62 historical/all-view checks also pass locally, retaining the original historical golden.

The automatic main-branch jobs and production build did not appear after the merge. The existing certification workflows are explicitly requested on exact main: Frontend `39619675611` and Supabase Integration `39619681800` (including executed Full). These are the unchanged workflows, with no bypass or modified gate. Cloudflare's dashboard still shows automatic production deployments enabled and source `457f8135`; no new main deployment exists at this checkpoint. This documentation-only checkpoint is published through the reviewed Git push path to deliver a normal repository push event. No hosting configuration, credential, access or hook is changed.

Exact-main certification, guarded Staging deployment and fresh actual-app/download verification remain pending at this checkpoint. The prior app's Attendance warning repetition is reproduced with a preview-only 100→101 edit and restored to100; no Save occurs. Post-release verification must repeat that check on the new build and inspect all captured warning details.

The complete hosted original → correction → reallocation → replacement PO → successor dispatch journey already passes on the deployed Need/Unit source, with 638 lineage/history checks, 117 export-data checks and all 22 final detail deltas exactly zero. This presentation change must preserve that result. Existing 21/23 October facts and all released originals remain frozen.

Rollback is a source revert and guarded redeployment; there is no database migration or data rewrite. Recipe3529's pork-name/ground-beef discrepancy still needs the Owner/kitchen's factual decision. Hosting CPU/I/O/memory correlation remains unavailable. The prior Staging authenticated role-wide timeout0 lease is unchanged; a scoped resource policy requires proof through the real authenticated transport before replacing it. No paid capacity or region change is justified by the present evidence.
