# Shopping List XLSX V1/V2 — source evidence and comparison

## Current V2 School-band specimens — 2026-10-07

**Owner-approved structure; final geometry pending Owner choice.** This section supersedes the historical V1 print/layout observations below. Same Draft PR #355; no new PR, merge, hosted schema or business write. Business identity, precision, currentness, whole-workbook validation, local-only proposals and explicit Save remain unchanged.

The actual authorized `atlas_api.get_confirmed_need_shopping_list_export` read ran as the established authenticated Staging Actor in `begin read only … rollback` for `rnzxmxiiqgtdevzregff`, 2026-09-17, batch `a0311e0a-a4de-48b9-a529-fe7464a3352b`, version **3**. Offset 0 / limit 250 returned **248 complete DATA_LINE rows**, 20 Schools and accepted Supplier advice; no synthetic names or quantities. Migrations remain 92, tip `20261006112515_atlas_recipe_purchase_unit_read`. Earlier 249-line observations are historical, not specimen authority.

V2 uses one A3:Q Table, frozen rows 1–3, repeated print titles 1:3, global TRƯỜNG/THÀNH PHẦN/ĐVT/SỐ LƯỢNG/GHI CHÚ header, dedicated neutral School bands across A:E without merge, blank DATA_LINE A, locked band/identity cells and editable DATA_LINE D/E. P/Q append explicit row kind and repeated canonical School name. No full Table sort that scatters School groups is accepted. The only merge is title A1:E1.

### Actual native Excel / A4 results

Every candidate uses the same structure, fonts and 96% scale. Native column widths are exactly 6 pt per configured width unit. Usable widths reserve 5.5 pt; numbers below are logical workbook points before scaling. Native Excel on this host exported 620 × 876.88 pt pages despite A4 settings. All final specimen PDFs are uniformly scaled onto physical **595.276 × 841.890 pt A4**, with complete contents inside printable bounds.

| Result                                    | A Compact     | B Balanced     | C Spacious     |
| ----------------------------------------- | ------------- | -------------- | -------------- |
| A/B/C/D/E width units                     | 14/31/9/16/24 | 14/32/10/16/22 | 14/33/11/16/20 |
| PDF pages                                 | 12            | 13             | 15             |
| DATA_LINE count                           | 248           | 248            | 248            |
| Initial School bands                      | 20            | 20             | 20             |
| Continuation bands                        | 6             | 9              | 10             |
| All School bands                          | 26            | 29             | 30             |
| Wrapped Ingredient rows                   | 1             | 1              | 1              |
| Wrapped DATA_LINE rows including Supplier | 32            | 32             | 32             |
| Wrapped School bands                      | 0             | 0              | 0              |
| Maximum Unit advance                      | 46.99512 pt   | 46.99512 pt    | 46.99512 pt    |
| Usable Unit width                         | 48.5 pt       | 54.5 pt        | 60.5 pt        |
| Minimum/usable Note width                 | 138.5 pt      | 126.5 pt       | 114.5 pt       |
| Normal / wrapped / band heights           | 28/44/28 pt   | 30/46/30 pt    | 34/50/34 pt    |
| PRINT_OVERFLOW / clipping / cropping      | None          | None           | None           |

DATA_LINE rows per physical page:

- A: **21, 22, 21, 21, 22, 23, 21, 22, 23, 21, 21, 10**.
- B: **21, 21, 19, 21, 22, 19, 21, 21, 21, 21, 18, 21, 2**.
- C: **19, 15, 18, 16, 18, 18, 16, 18, 18, 17, 19, 19, 17, 18, 2**.

All eight actual Units fit unchanged: **kg, Cái, Miếng, Quả, Cốc, Hộp, Gói, Trái**. The shared resolver is preserved: kg/Kilogram displays kg, technical v1-unit codes fall back to the human name. Three real Miếng lines print in full. No technical Unit code is visible. The sole wrapped Ingredient is `Sữa trái cây Kun 110ml hương nhiệt đới`; Supplier text causes the other wrapped rows. No row striping is used; ruled rows and dominant bands already provide grayscale scanning clarity.

**Recommendation: B**, for 30 pt working rows and additional Miếng clearance at 13 pages. A saves a page and has more Note width. C adds writing height/Ingredient/Unit space but trades Note width and requires 15 pages. B/C end with a two-line continuation page; the page distribution is disclosed for Owner judgment, not hidden by shrinking text. **Retain SỐ LƯỢNG**: it fits every candidate, so SL would not recover body width. B is provisional, not approved final geometry.

### Native reopening, copying and import

Normal native Excel Open, PDF export, isolated SaveAs and read-only reopen succeeded for A/B/C, with one 17-column Table retained and no repair request. Original specimen XLSX files were not saved by Excel. Isolated copies exercise public-password unprotect → unhide F:Q → inspect/copy DATA_LINE → rehide/protect. All 248 native records carry School ID/Name, Ingredient/Unit IDs, line/revision evidence and baseline quantity. Clipboard copy of a complete DATA_LINE succeeds. The comparison's final page shows actual repeated School names and full hidden IDs from native inspection; staff do not reconstruct School context from bands.

Unchanged production-workbook import yields no changed proposal. An isolated D5 edit to `12,5` yields exactly one local quantity proposal; native SaveAs/reopen/import does likewise for all variants. The production codec and connected service perform no business command. Native Excel quantizes stored row heights by up to 0.1 pt; importer normalizes within 0.15 pt and rejects structural resizing. ExcelJS alone drops manual breaks on reserialization; QA restores the original IDs for its isolated edit, while native Excel preserves them. No malformed continuation is accepted for convenience.

Closed V2 envelope rejects old V1; `legacyAccepted=false`. Identity and row-kind/group tamper regressions cover changed data School ID/name, changed band name/ID, foreign-school row moves, kind swaps, missing/duplicate bands, missing/fake lines, stale authority and existing Unit/precision/package tamper cases. Complete business-line count excludes presentation bands.

All A/B/C physical pages were rendered and reviewed; automated PDF checks verify A4 dimensions, repeated headings/date, all Ingredient occurrences, three Miếng labels, continuation labels at native page starts and text bounds. The 14-page comparison contains first School/kg/Miếng, the 16-line THUẬN GIAO School, count/package Units, continuation pages and hidden flat records.

Artifacts are generated under `E:/Project/OPS ERP/atlas-artifacts/shopping-list-school-band-02/` using `scripts/certify-shopping-list-school-band.mjs`, `scripts/certify-shopping-list-school-band-excel.ps1`, and `scripts/compare-shopping-list-school-band.py`. Authoritative JSON and native/inspection reports stay outside the repository. The seven Owner deliverables are the three matching XLSX/PDF pairs and `ShoppingList-SchoolBand-Comparison.pdf`.

**Freeze recommendation: HOLD.** Owner geometry selection, final hosted export/import acceptance and final print review remain open. Historical V1 evidence follows for provenance only.

Original source audit 2026-10-02; Product redesign audit 2026-10-04.
Repository baseline: `d81b60ca63349794d28b0dcc5d34f5fd3e1ebfa1`, PR #345.
This records observations and proposed intentional differences. It does not amend an approved business contract or certify the current live Retool deployment.

**Current print status: READY_FOR_PRODUCT_APPROVAL.** Finalization starts from `c802b8f0e8f4ac771b51f2b94405928e06b857dd`. Product rejected Location presentation and the giant-row proposal. The compact final specimen passes native print and identity gates; owner approval is pending. Existing quantity/currentness/import boundaries remain unchanged.

## Sources inspected

| Source                                     | Locator / evidence                                                                                                                                                                                                                                                                                           |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Atlas exporter/parser                      | `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedShoppingList.ts`, exact starting SHA                                                                                                                                                                                                         |
| Atlas layout/round-trip tests              | `confirmedNeedShoppingList.test.ts` and `confirmedNeedShoppingListPrecision.test.ts` in the same directory                                                                                                                                                                                                   |
| Connected interaction                      | `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.tsx`, `useConfirmedNeedWorkbench.ts`, `useConfirmedNeedDraft.ts`, `confirmedNeedDraft.ts`                                                                                                                                                         |
| Authority                                  | `docs/api/rmvp-05-connected-confirmed-need-review.md`, AUD-003 amendment/task, `confirmed-need-save-release-v2.md`, ARCH-002, model convergence, D-041, Atlas design language                                                                                                                                |
| Supplied layout reference                  | Read-only `C:/Users/hp/Downloads/DanhSachMuaHang_2026-04-20_2026-04-25_ALL(1).xlsx`; SHA256 `88b67577e8a06057c9d61b10ef8aeed9d587ed688733f0b06dbf8f5e54de612e` (same bytes as originally reviewed `1-DanhSachMuaHang...`)                                                                                    |
| Retool `js_shop_Export`                    | Read-only local retained `OPS - Lên đơn, Đặt hàng - building.zip`, `lib/js_shop_Export.js`; ZIP SHA256 `65a87fe06834733079725c3764bdaf24abbd99130e78e03220760040e0249720`                                                                                                                                    |
| Retool Purchase Planner export/import/save | Read-only local retained `OPS - Lên đơn, Đặt hàng (2).zip`, `lib/js_ppwb_export_xlsx.js`, `lib/js_import_master_sl_from_xlsx.js`, `lib/js_ppwb_save_actual_need.js`, `src/PurchasePlanner.rsx` and included operator controls; ZIP SHA256 `107ce8faf5b4beb582bfea48d6142d4b7895ab5d67936347ed0e401cb6fc589b` |
| Retool retained JSON provenance            | Corresponding `(2).json` SHA256 `f0542f12b703743184ab47896a6482ea0a6b4fb8fb5a156b86b7b8eb9c8c4ab2`                                                                                                                                                                                                           |

Both retained Retool ZIPs were read directly from the user's local Downloads directory. No live Retool session or hosted data was queried or changed. The named `js_shop_Export` is present in the older building export; the later PurchasePlanner snapshot uses `js_ppwb_export_xlsx` instead. This naming distinction is explicit rather than pretending the two are one current script. Raw business workbooks and source dumps are not copied into Git.

The reference contains one worksheet `2026-04-20` despite the six-day period in its filename. Its left region is A:H; its preferred right staff table is J:Q, with N:P hidden technical columns. The actual right region has 39 rows in three 13-line Schools. Right header row 3 is `TRƯỜNG / THÀNH PHẦN / ĐVT / SL / service_date / school_id / ingredient_id / GHI CHÚ`. Date title J1 is Times New Roman 20 bold and about 36 pt high; visible headings are 18 bold at 36 pt; body is 18 regular, normally 23.25 pt, with 30 pt School starts and taller wrapped rows. Widths J/K/L/M/Q are about `17.57 / 42 / 8 / 8 / 12`. J4 contains bold `Tân Định`; later cells in the School are blank, with a strong black group boundary. Native Excel 16 printed the isolated right region on two portrait A4 pages. It is the visual benchmark, not an Atlas import fixture. The saved print area incorrectly points to left A:H, and the used dimension reaches row 1,048,575 because of propagated formatting; neither defect is copied.

The old #347 specimen was also printed through native Excel before revision. It used Arial 11 body, a dark green/white header, beige edit cells, widths `38 / 53 / 8 / 16 / 33`, 34 pt body rows, a 46 pt instruction block, School repeated on every row and landscape A4. Its printed page resembles an application export, with School text dominating Ingredient scanning and abundant horizontal width but weaker writing-form rhythm. This comparison motivated the Product revision; technical identity and precision protections remain valuable.

## Retool behavioral recovery

`js_shop_Export` uses `q_shop_list`, per-date sheets, canonical `display_order` when present and original SQL Ingredient order. It exports quantity through `Number`; Kg below 2 is rounded to one decimal, other quantities to integers. It creates merged School bands, spacers, repeated print titles and a simple autofilter. Its labels start with `TÊN TRƯỜNG`; hidden keys are service date, School numeric ID and Ingredient numeric ID. No stable Atlas line, location, controlled Unit, version or decision evidence exists.

The retained later `js_ppwb_export_xlsx` prefers table/master-state rows, uses selected period naming `DanhSachMuaHang_<start>_<end>_<mode>.xlsx`, permits ALL/TYPE1/NON1 export modes, groups by School name, orders School groups by `display_order` then lexical fallback, orders Ingredients by shopping-type rank (3→1→2) then name, and places `X` in column A for shopping type 2. It exports master quantity and note, retaining the same numeric rounding and School-band layout. Visible columns are A:D and H; E:G are hidden keys.

`PurchasePlanner.rsx` registers separate import/export/Save JavaScript queries and includes the master editor and export modal. `js_import_master_sl_from_xlsx` consumes parsed workbook rows with header/`__EMPTY_*` aliases; maps `date|Number(school_id)|Number(ingredient_id)` against local master rows; skips headers, invalid keys and unmatched rows; counts errors and continues rather than requiring a complete artifact. It patches `st_ppwb_master_rows` and `st_ppwb_master_patches` only. Note blank handling uses a nonblank `pick`, so an empty note generally means no note update, not explicit clearing. Quantity parsing removes commas and uses `Number`; change detection uses `EPS = 1e-6`. It marks matched rows dirty even if their values are unchanged. Repeated keys can overwrite earlier patches.

`js_ppwb_save_actual_need` is the separate persistence action. It validates pending patches, compares against baseline with epsilon, can clear existing quantity override when returning to baseline, and triggers `q_ppwb_save_actual_need` only on explicit Save. Note-only patches without an existing override or a differing quantity may produce no payload under this logic; the mere presence of a GHI CHÚ cell is not proof of independent note persistence. Atlas must preserve the interaction principle, not copy these numeric, state, lookup or SQL semantics.

## Current Atlas observations

The unchanged production workbook has five visible contiguous columns A:E, `SL` in D, ISO-date sheets, date title row 1, blank row 2, header row 3, and no School bands or data-region merges. School appears only on the first row of each group. Font is Times New Roman 18 body/header and 20 title; widths are `17.57 / 42 / 8 / 11 / 12`; prominent black cell borders; landscape page fitting and frozen first three rows. The simple filter currently covers A3:E3. No structured Table, `_ATLAS_META`, explicit print area or repeat-title definition is written by this module.

Seventeen hidden F:V columns repeat batch/version, run/release snapshot, stable line, revision UUID/number, decision UUID/number, date, School, Location, Ingredient, Unit, exported draft quantity/reason and constant marker. D/E alone are unlocked; sheet protection allows selecting and filtering. File name uses English `Shopping-List-<start>-<end>.xlsx`.

Exporter order is date, School first occurrence in workbench lines, then source index; it does not use an explicit School display rank. Actual shaped RMVP-05 reads historically order by date/School display text/location/Ingredient/UUID, so the current first occurrence can inherit lexical order. V1's canonical-rank branch is conditional on evidence being supplied; this design does not silently add a read field.

Parser checks hidden identities/version/source, rejects duplicate/missing/unknown lines, clones the current draft and publishes only on success. It does not validate visible locked labels, sheet-name/date binding, exact header/column/Table shape, or lifecycle itself. Workbench controls gate both export/import for released state, while the shared parser relies on caller context. It accepts real changed quantities through the two-decimal entry parser; effective-step feedback is in `confirmedNeedDraft.ts` and authoritative Save, rather than this XLSX parser. V1 specifies full entry/step validation before apply while preserving backend final checks.

AUD-003 tests cover untouched `1.234567`, `0.000001`, `12.345600`, `1.230000`, `0`, large exact text quantities, dot/comma/numeric equality, note-only edits, stale/missing/duplicate lines, invalid exported quantity, and current-local-quantity preservation. Hidden baseline changes alone cannot inject a new six-decimal quantity because an unchanged visible quantity preserves the local draft. The current parser reads hidden exported reason and overwrites note from the file; proposed V1 removes note import and exported reason/note baselines, and requires saved/current export plus fresh per-date authoritative readback instead of a session manifest. Current real-quantity export still uses a `Number` candidate with a safe-micro-integer test, and parsing goes through ExcelJS values. Future raw numeric XML capture is explicitly specified; no production precision code is changed in this task.

Current connected import callback returns drafts, `applyShoppingListImport` sets local state and a Vietnamese notice, and `save` separately invokes `confirmedNeedApi.save`. No import-time write is present. PR #345 concerns responsive editing; it does not approve the proposed format. The older UI-QUALITY-02C workbook idea is marked removed/superseded at the top of its task record and is historical evidence, not current XLSX authority.

## Comparison and intentional V1 differences

| Concern              | Current Atlas                                                     | Retained Retool evidence                       | Proposed Atlas XLSX V1                                                                                                                                                                               |
| -------------------- | ----------------------------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Authority            | One supplied batch, local draft round trip                        | Selected period/master-row editor              | Generated 1–7 date collection; each date has its own authoritative saved/current daily batch; no weekly aggregate or persisted artifact.                                                             |
| Export state         | Can include local draft                                           | Uses local master table                        | Blocks unsaved local draft; exports complete saved/current daily facts.                                                                                                                              |
| Import after restart | Current parser uses workbook technical cells and supplied context | Patches local master state                     | Fresh complete read for all dates; no browser manifest; exact batch/version/run/snapshot/revision/decision/line identity validation.                                                                 |
| Imported edit        | Quantity and note behavior coupled to Confirmed Need draft        | Quantity/note patches, epsilon comparison      | SỐ LƯỢNG only, exact decimal and current Planning step; local draft then explicit `Lưu`.                                                                                                             |
| GHI CHÚ              | Mapped to governed `reason_note`                                  | Arbitrary note, persistence not assured        | First preferred Supplier name at export plus working space; ignored on import, never persisted or allocated.                                                                                         |
| Hidden evidence      | F:V repeats batch/source per row                                  | Numeric date/School/Ingredient keys            | F:O row identity and exact quantity; `_ATLAS_META` six global fields plus per-date batch/source table.                                                                                               |
| Completeness         | Rejects missing/duplicate/unknown lines                           | Skips unmatched rows, partial patch possible   | Every-and-only row set per date; one stale date rejects whole local import.                                                                                                                          |
| Display              | Five-column layout, limited sheet/label validation                | Merged School bands and spacers                | Accepted black/white A4 form, first School row and continuation; School-only labels; hidden Location has zero presentation effect; different business identities with identical labels block export. |
| Sort/filter          | Simple filter                                                     | Permissive spreadsheet actions                 | Full Table keeps identities attached; protected filtering best effort; safety independent of filtering/sorting.                                                                                      |
| Supplier drift       | No derived first-Supplier contract                                | Notes reflect source at export                 | Export-time derived advice only; later Supplier master changes do not stale quantity import by themselves.                                                                                           |
| Precision            | AUD-003 exact comparison, some Number/ExcelJS paths               | Number rounding and epsilon                    | Exact XML decimal read and equality; new entries ≤2 decimals and exact Planning step.                                                                                                                |
| Persistence          | Import to draft, Save separately                                  | Import to local patches, Save query separately | Retains `XLSX → local state → explicit Lưu`; zero import writes, no note persistence.                                                                                                                |

Retool supplies useful workflow evidence for local import followed by explicit Save. Its date/numeric School/Ingredient lookup, skipped unmatched rows, epsilon comparison and potential duplicate overwrite are inadequate for Atlas's stable line, Delivery Location, controlled Unit and per-date currentness requirements. The supplied right-hand form remains visual evidence only. No live Retool or hosted business data was written.

## Finalization review from c802b8f

### Product decision and read-only evidence

Delivery address belongs to the School operational context; Phiếu đi chợ displays only the School name. Required hidden `__location_id` remains row-bound lineage/currentness; stable `__line_id` remains the primary mapping identity. Location cannot affect School grouping, ambiguity, added rows, text, widths, wrapping, heights, page breaks or certification. The previously considered Location subtitles/subgroups and 72/168 pt solution were rejected by Product and removed from active V1 machinery.

The user supplied already-established read-only Atlas Staging evidence: **256 current NEED_GENERATION Confirmed Need lines; 256 use School.default_delivery_location_id; 0 non-default lines; 0 School/date groups with multiple Locations.** This is design evidence, not a database invariant. This pass performed no hosted read or write and adds no database constraint. Printed synthetic data does not copy those business names.

Visibility ambiguity compares expanded School/Ingredient/operator Unit labels with `(school_id, ingredient_id, unit_id)` within a date. Identical labels for different business identities block export. Separate stable rows for the same business identity triple remain permitted even when hidden Locations differ; Location does not create an export eligibility or presentation branch.

### Compact candidate measurements

All candidates were regenerated from the cleaned fixture, opened read-only through native Excel 16 and exported to A4 portrait PDF. Required starting candidates used body/School 18, quantity 18, Supplier 16, 30/44 pt rows and explicit 95%. Their observed PDF primary size was 17.04 pt, corresponding to 94.67% glyph scale on this host. They passed the body-size floor but failed the observed scale floor and other gates below.

| Candidate        | A:E Excel widths             | Native pages / body rows | Native result                                                                                                                   |
| ---------------- | ---------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| F1               | 18/41/7/13/15                | 4; 23/21/12/3            | Rejected: School32 loses final words; two quantity rows show hashes; wrapped Supplier crowding/clipping; observed scale 94.67%. |
| F2               | 19/40/7/13/15                | 4; 23/21/12/3            | Rejected: same School, quantity and Supplier failures; observed scale 94.67%.                                                   |
| F3               | 18/42/7/12/15                | 4; 23/21/12/3            | Rejected: same School/Supplier failures and narrower quantity hashes; observed scale 94.67%.                                    |
| F4–F6            | Total 97; A 22–23, D 16      | 8                        | Rejected: widening clears quantities but splits horizontally; School still clips.                                               |
| F7/F8            | 25/33/6/16/14; 26/32/6/16/14 | 4                        | School, Ingredient and quantities complete; Supplier needs three lines and crowds/clips the rule despite extractable PDF text.  |
| F10              | 25/32/6/16/15                | 4                        | All body content fits at 96%; 18 pt ĐVT header touches its rule.                                                                |
| F11              | 25/31/6/16/16                | 4                        | Rejected: Ingredient48 loses its final word.                                                                                    |
| **F13 selected** | **25/32/6/16/15**            | **4; 24/20/12/3**        | **Header 17, body/School 18, quantity 16, Supplier 14; all cells fit at 96%, effective primary 17.28 pt.**                      |

F9 was an unexported fractional-font experiment rejected by the artifact authoring API; it is not a certified candidate. F13 retains F10 body proportions and gives the header clearance at 17 pt. No character-dependent auto-fit or enlarged row was used.

### Final native print certification

- Times New Roman: title 20 bold, header 17 bold, body 18, School 18 bold, quantity 16, Supplier 14 pt. Native effective primary 17.28, quantity 15.36 and Supplier 13.44 pt, measured scale 96%.
- A:E widths 25/32/6/16/15, total 94 Excel units; native physical widths 150/192/36/96/90 pt, total 564 pt. A4 portrait PDF pages 595.2 × 841.92 pt, one page wide, zero horizontal splits.
- NORMAL 28 / WRAPPED 44 pt; exactly two body classes, hard maximum 44. The 59 lines contain 53 NORMAL and 6 WRAPPED rows. School starts have bold text and medium rules within this same system.
- Title/gap/header heights 32/5/48 pt; margins 0.20 inch left/right, 0.25 top/bottom, header/footer 0.12; explicit scale 96%. Budget 708.89 pt, conservative height-scale upper bound 0.97. Authored page body heights 720/576/352/100 pt.
- Date sheets 2026-04-20, 2026-04-21 and 2026-04-22 have 44/12/3 data rows. Native PDF has 2/1/1 pages with 24/20/12/3 rows. The five-line School stays together; the large School continuation uses only `(tiếp)` in a 44 pt row.
- All canonical School32, Ingredient48, Supplier25 and quantity12 stress content is complete, with clear row boundaries. All 59 quantities and 52 populated Supplier suggestions match the workbook. Five six-decimal values and exact large text quantities remain intact; no hashes, hidden IDs or Location text print.
- Visible envelope 84 counts only expanded canonical School + Ingredient + operator Unit + shortest exact quantity + Supplier. Independent stress combined counts are 56/68/46/38; realistic composite and printed maximum 79. The isolated nonprinted extreme control is 158, Ingredient68/Supplier46. Location contributes zero characters and no typography case.

All four native PDF pages were rendered at 100 dpi and inspected, including long School on pages 1/4, long Ingredient on page 3, Supplier25 on page 1, exact quantities, continued School on page 2 and repeated titles/headers throughout. The result has consistent compact row rhythm, large primary text, black boundaries and no giant rows or address clutter. The sparse third date is intentional daily-batch evidence rather than an overflow page.

### Benchmarks and native editing

The preferred right-hand reference was opened read-only and temporarily printed as J1:Q42 at A4 portrait 100%; its source was not saved. It prints two pages, 18 pt primary text, compact School-first rhythm and black rules. The retained OPS v1 export `C:/Users/HOME/Downloads/DanhSachMuaHang_2026-03-16_2026-03-20_ALL.xlsx` (SHA256 `da124cfea2c549614ee248a05a03400cda23f7bd2cd7a63a887939e185dc787e`) was likewise bounded to A1:H42 for comparison without saving: two portrait pages, 18 pt primary text. Both favor large primary Ingredient text. The preferred reference supplies sparse first-row School labels; retained OPS v1 instead uses merged School bands and spacers, which V1 does not copy. F13 preserves that rhythm while accommodating exact quantities, Supplier advice and hidden Atlas evidence. The raw starting c802b8f G3-Q specimen was also printed read-only on this host: four pages, primary 17.04 pt at configured 95%, with conspicuous giant rows and Location clutter. F13 visibly removes those gaps and clutter while retaining full certified text.

Native Excel normal Open succeeded without requesting repair. An isolated final-workbook copy was edited at unlocked D4 from 0.2 to 2, Save As completed and reopening retained the edit. After intentional unprotection, a full 15-column Table sort by Ingredient descending reordered the first date's 44 rows. After another Save As and reopen, every visible and hidden cell remained attached to the same stable line ID, including quantity 2 and hidden Location. Native page-break preview, zero vertical breaks and native PDF export confirmed pagination. The committed specimen was never saved by Excel. Cross-version protected filtering remains BEST_EFFORT.

### Unit projection and validation boundary

The authoritative RMVP-05 read already selects Unit code and Unit name and serializes `controlled_unit: {id, code, name, status}` (`20260803102941_rmvp_05_connected_confirmed_need_review.sql`, read selection and JSON projection). Migration `20260915153000_master_data_rehearsal_import.sql` retains technical `v1-unit-...` codes separately from operator `unit_name` (lines 161–162). The original specimen projected the human name. The approved `ATLAS-SHOPPING-LIST-UNIT-DISPLAY-01` amendment (2026-10-07) uses one shared resolver for connected export/import: trimmed human-facing code first (`kg` for `kg`/`Kilogram`), otherwise the trimmed human name (`Quả`, `Gói` for technical adoption codes). Missing/unsuitable candidates fail closed; normalized fixture `unit_display` remains presentation only, with no Unit-model, identity, or print-geometry change.

Static validation retains existing identity/currentness/precision controls and adds explicit School/Location/Ingredient hidden-ID tamper checks: **43 negative controls plus 7 certification controls**. It checks two height classes, cap44, scale/body floors, complete row sets and restart/currentness behavior. Positive Location mutation checks metric, grouping and pagination; an independently regenerated probe changes every hidden Location ID and supplies very long unprinted address text, then compares every visible cell/style, height, width, page setup/break and style definition with the original. Separate stable lines sharing one business identity triple remain allowed.

Native PDF validation matches every A:E cell and quantity in order, repeated headers, A4 geometry, hashes, hidden-ID exclusion, font sizes and each glyph's bounds within its row/column. Extractable but clipped Supplier text in rejected F7 is a regression control for this stronger gate. Native sort/edit checks remain evidence rather than a claim that a connected V1 importer has been implemented.

Specimen SHA256: `cd18ed71614b7d42965de2e553fb3bf47a824b1609c384621345c63e332f348a` (deterministic regeneration). Focused production Shopping List and precision suites remain unchanged; full routine validation belongs to GitHub Actions on the pushed PR head.

No production, migration, API, RLS, privilege or hosted-data changes. Supabase, Retool, OPS v1 and hosted business writes: **0 each**. Remaining Product decisions: **NONE — contract/specimen ready for owner approval**. PR #347 stays Draft and unmerged; connected implementation remains a separate approved task.
