# Atlas School row measurement

This is the numeric measurement provenance for the School bands and `Theo hàng` School cells in `TASK-ATLAS-DOCUMENT-SCHOOL-GROUPING-02`. Native workbook rendering and export semantic acceptance are recorded separately in the task's QA evidence.

## Measurement source

On 10 October 2026, `scripts/measure-atlas-school-row-font.ps1` measured the installed **Times New Roman, 14 pt**, regular and bold, using Windows `System.Drawing.Graphics.MeasureString`. The bitmap resolution was 720 dpi; `GenericTypographic`, `MeasureTrailingSpaces`, `NoClip`, and `AntiAlias` retained advances without the ordinary `MeasureString` outer padding. Pixel advances were divided by ten to obtain points and rounded to six decimal places. No font binary is copied into the repository or exported workbooks.

| Installed font       | SHA-256                                                            |
| -------------------- | ------------------------------------------------------------------ |
| `times.ttf`, regular | `931c5de5c70401d9324d5014c123802b4fb753000360ceb2f56c589403cd58c5` |
| `timesbd.ttf`, bold  | `54fbe2c70af7c85a97bed0573227e3ccc4b2486012e3ca2a40c6bc77065846f5` |

The committed numeric file is `src/modules/atlas/documents/timesNewRoman14Metrics.json`, SHA-256 `11d8a28efc573f8e7e0223711e4863fba65774df837f688f95327502c1dcd4f6`. Its metadata records Excel version/build, font hashes, digit advances and native column-width checks. The measured repertoire covers printable ASCII, Latin-1/extended Latin, combining marks, Vietnamese extended Latin, general punctuation and replacement characters. NFC normalization gives canonically equivalent Vietnamese labels the same measured advances.

Examples: regular/bold space is 3.5 pt; regular `W` is 13.213867 pt; bold `W` is 14 pt; regular `I` is 4.662109 pt; bold `I` is 5.448242 pt. Glyph advances are summed deterministically; kerning is not subtracted, retaining a conservative width budget.

## Excel geometry

The script builds a new **ExcelJS workbook using its unchanged Normal style and theme**, sets physical `column.width` properties, and opens the temporary workbook read-only through hidden Excel COM. On the verified Vietnamese Office installation, Excel **16.0, build 20430** resolves Normal to **Arial 11 pt** through the theme's Vietnamese font mapping. It is independent of the explicit Times New Roman font on the School cells. The measured maximum digit advance rounds to **8 pixels at 96 dpi**.

The helper converts the actual worksheet column widths using the [Microsoft Open XML column-width formula](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.column?view=openxml-3.0.1): truncate `((256 × width + truncate(128 / maximum_digit_width)) / 256) × maximum_digit_width` to pixels, then multiply by `72 / 96` for points. All 15 measured columns matched this conversion exactly, including fractional and narrow columns.

| ExcelJS/OOXML column width | Native Excel points |
| -------------------------: | ------------------: |
|                       0.25 |                 1.5 |
|                        0.5 |                   3 |
|                          1 |                   6 |
|                          6 |                  36 |
|                       8.43 |               50.25 |
|                          9 |                  54 |
|                         12 |                  72 |
|                         16 |                  96 |
|                         18 |                 108 |
|                         25 |                 150 |
|                         28 |                 168 |
|                         30 |                 180 |
|                         36 |                 216 |
|                         42 |                 252 |
|                        110 |                 660 |

`actualVisibleWidthPoints()` sums the chosen worksheet's columns individually, skipping hidden columns. A visible column must have an explicit width or explicit worksheet `defaultColWidth`; the helper fails instead of inventing a width. `measuredSchoolRowHeight()` subtracts the documented five-pixel cell-edge allowance **once** from that sum, including merged bands. `Theo hàng` passes only its School column, with regular advances; School bands use bold advances.

The Normal-style/theme resolution is the verified reference environment for these deterministic exports. A different native Office locale or font substitution can change column geometry. Repeat native width/render QA in that target environment before asserting identical physical wrapping; do not silently change the measurement constants. Labels outside the measured repertoire retain their full text and use the widest measured glyph advance as a conservative reservation. Unmeasured font substitutions require native QA.

## Wrapping and validation

`schoolRowMeasurement.ts` wraps at spaces, preserves CRLF/LF/CR and blank explicit lines, and breaks long tokens by Unicode code point. It returns `28 + 16 × (line_count − 1)` without a line cap. Tabs reserve four measured spaces. There is no text-length/guessed-character-capacity path. Invalid geometry fails with `RangeError`.

The focused test file `schoolRowMeasurement.test.ts` was verified RED against behavior stubs (12 failing assertions), then GREEN with 13 tests. The cases cover native fractional widths, hidden metadata width exclusion, actual-cell versus full-band width, 1–6 line heights, word wrapping, empty and explicit lines, long tokens, wide versus narrow glyphs, regular versus bold, and Vietnamese composed/decomposed labels.

Reproduce with installed Windows fonts, native Excel and existing repository dependencies:

```powershell
./scripts/measure-atlas-school-row-font.ps1
pnpm exec vitest run src/modules/atlas/documents/schoolRowMeasurement.test.ts
```

The script creates and removes a disposable width-probe workbook, keeps Excel hidden, disables macros, opens the probe read-only, validates each native width, emits only numeric JSON, and formats it with the repository's existing Prettier. Re-measurement updates provenance when the installed fonts or native Office environment change. It does not connect to Atlas, Staging, live OPS or Retool.

## Native AutoFit investigation and printed acceptance

Native Excel's **screen AutoFit height is advisory**, rather than a clipping oracle for the exported PDF. `scripts/probe-atlas-school-row-height.ps1` copies the exact source column's UI `ColumnWidth` into a disposable native workbook, retains the source Normal font and measures both explicit-line controls and actual School labels. The UI `ColumnWidth` must not be confused with the OOXML `width` attribute: copying it reproduces the native source column's 240 pt width exactly.

For explicit `DÒNG` lines in Times New Roman 14 pt, regular and bold, native AutoFit reserves 18.75 pt per line: one line is 18.75 pt, four are 75 pt, five are 93.75 pt and seven are 131.25 pt. Its screen allocation exceeds the Owner's row formula from five lines onward. That inequality alone does **not** establish clipping in the emitted document. The actual native printer wraps and positions glyphs differently. The C17 fixture, for example, receives 124 pt under the deterministic seven-line measurement, while AutoFit requests 131.25 pt; its exported PDF contains all source characters over six printed lines and leaves 6.2198 pt below the final glyph box.

Actual native PDF acceptance is recorded in `docs/testing/artifacts/atlas-document-school-grouping-02/school-row-printed-report.json`. `scripts/verify-atlas-school-row-pdf.py` reads the unchanged XLSX/manifest and the native Excel PDFs. For each School row, it requires the entire printed glyph sequence to equal the source after NFC and whitespace normalization, allowing only printer-added whitespace inside wrapped long tokens. It locates visible column and row border strokes from the PDF, then requires **every glyph box to stay inside all four borders with at least 0.5 pt clearance**. The unbordered PXK `A6:H6` headers use independently observed horizontal table borders and the preceding row 5 / following row 7 glyph bounds to require the same clearance from neighboring header content. Explicit newline fixtures also retain their observed line count in the report. Missing text, any border overlap or adjacent-header overlap fails verification; no AutoFit exception can bypass these checks.

All **25 School rows on nine native PDF pages passed** full-text and geometry checks, including the short explicit Dispatch Group, five-member Hùng Vương group and a separate School with 24 repeated Vietnamese phrases in its PXK header. The lowest School-row bottom clearance is 1.5398 pt. The contact sheets `School-rows-native-printed-contact.png`, `PXK-School-headers-native-printed-contact.png` and `PXK-Hung-Vuong-five-release-numbers-native.png` were also visually inspected across every page; all final lines, diacritics, long-token continuations and release numbers are visible.

The printed report binds acceptance to the exact `manifestSha256` and `evidenceFiles[{path,sha256}]` for all four clean workbooks and all six native PDFs. The native width/formula checker requires a matching `PASS` report and the complete expected School-row count. Regenerating or modifying a source workbook, manifest or native PDF invalidates that acceptance until the printed verifier runs again.

| Stressed cell                      | Measured lines | Printed lines | Final-glyph bottom clearance, pt | Full source text           |
| ---------------------------------- | -------------: | ------------: | -------------------------------: | -------------------------- |
| Theo hàng C16                      |              4 |             4 |                           1.5398 | Present                    |
| Theo hàng C17                      |              7 |             6 |                           6.2198 | Present                    |
| Theo hàng C19                      |             10 |             9 |                           3.6998 | Present                    |
| Theo hàng C20                      |             13 |            11 |                           8.3799 | Present                    |
| Theo hàng C22, 140-character token |              9 |             8 |                           4.5398 | All 140 `W` glyphs present |
| Theo hàng C23, explicit newlines   |              4 |             4 |                           1.5398 | All four lines present     |
| Theo trường A34                    |              5 |             4 |                           8.1398 | Present                    |
| Theo trường A37, long token        |              4 |             4 |                           1.6599 | All 140 `W` glyphs present |
| Theo trường A40, explicit newlines |              4 |             4 |                           1.6598 | All four lines present     |

The PXK grouped Vĩnh Tân A6 prints one complete line with 8.4 pt clearance to the following header. The separate long School A6 prints all 24 repeated phrases over seven lines, with 3.817 pt above and 3.84 pt below; all glyphs fit horizontally. Both were also visually inspected in the PXK contact sheet.

The five-member Hùng Vương fixture uses all five explicit School names and realistic released codes `PXK-20260924-2600000000004000` through `PXK-20260924-2600000000004004`. Its grouped A5 number header preserves every code over three printed lines at 68 pt row height, with 11.184 pt above, 13.417 pt below and 20.728 pt at the right edge. The date in F:H is excluded from the A:E glyph sequence and stays separate. The verifier locates complete multiline predecessor/follower glyph blocks so wrapped codes cannot invalidate the adjacent A6 School-bound check.

All three PXK A5 number rows pass their additional full-text and 0.5 pt geometry checks, recorded as `checkedDocumentNumberRows: 3` and `headerChecks` in the same hash-bound printed report. These document-number checks are separate from the fixed School-row height formula; the individual-document A5 remains at its existing 22 pt height.

The fixed `28 + 16 × (measured_line_count − 1)` rule, metrics and tests were preserved. Native screen AutoFit observations are retained in `school-row-height-investigation.json`; actual printed text and bounds establish acceptance for these fixtures. This does not imply a guarantee for every possible arbitrarily long label or for another Office/font/printer environment.

Reproduce the investigation after the native PDFs have been exported, using the bundled Python runtime with `pdfplumber` and `openpyxl`:

```powershell
./scripts/probe-atlas-school-row-height.ps1 -OutputDirectory docs/testing/artifacts/atlas-document-school-grouping-02
python scripts/verify-atlas-school-row-pdf.py docs/testing/artifacts/atlas-document-school-grouping-02
```
