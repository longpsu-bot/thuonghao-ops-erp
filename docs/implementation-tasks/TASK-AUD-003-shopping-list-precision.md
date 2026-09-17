# AUD-003 — Shopping List exact no-edit round trip

Owner-approved follow-on to AUD-001/002. Initial baseline `2f5ec284113c046ed28ec77898455f980e60230e`; reconcile with certified Planning fix before merge. Reuses the isolated E: worktree on its own `fix/aud-003-shopping-list-precision` branch; no other checkout edited.

## Bounded plan

1. Reproduce `1.234567` untouched export/import with the production ExcelJS exporter/importer; retain the `1.230000` control.
2. Validate existing workbook identity/version metadata before quantity handling. Parse six-decimal representations without rounding; distinguish unchanged exported values from true quantity edits. Only true edits must obey the existing two-decimal operator-entry rule and require a note.
3. Untouched imports preserve the current draft's exact representation and quantity-entered flag. Hidden workbook metadata must never introduce a new six-decimal business quantity. Changed-line reporting describes resulting local draft differences, not a quantity that was deliberately preserved.
4. Display up to six significant decimal places in the existing quantity cells; keep document marker, identities, groups, headers, widths and other templates intact.
5. Regress zero, comma/text/numeric representations, note-only edits, larger exact text values, stale/missing/duplicate identities, invalid baseline/quantities, actual edit restrictions, and local-draft preservation. No save/release call or business write.
6. Review the bounded diff, push a separate PR and merge only after required GitHub checks. No SQL, RLS, backend quantity-policy, PO/PXK, Google/Apps Script or #286 changes. No new dependencies or subagents.

This is not a relaxation of the entry rule. Existing authoritative numeric(20,6) values remain exact; new operator quantities remain at most two decimals. Rollback is code-only.

## Local verification

Existing exporter/importer baseline: 4/4 PASS. New production-XLSX round-trip suite: 12 expected failures + 13 controls on unchanged source, then 25/25 PASS after correction. Combined workbook regression: 29/29 PASS. No test timeout or operator-entry validator was weakened. Fixed test fixture nullability locally without changing product types or policy.

The exact-base review confirmed hidden baseline data is only compared: unchanged file quantities never replace a current local draft. Real file edits continue through the two-decimal validator and require notes; changed-line flags reflect resulting drafts. No hosted writes have been executed by this task.

PR #300 (AUD-001/002) merged as `d8684a10f09965e347b513ff18a86e48a7bd9607` after Frontend CI and Full Supabase Integration passed. This independent branch is rebased onto that certified main before publication. Extended draft-controller check: 47/47 PASS; an additional missing-line atomicity control is included. A non-failing React `act` environment warning is emitted by the unchanged controller test harness; no test or environment behavior was modified for it.
