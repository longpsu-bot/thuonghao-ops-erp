# Desktop review fixes — 26 October 2026

Local in-memory fixture captures only; no hosted business reads or writes.
Base is `c9641522`, on `codex/atlas-desktop-review-fixes`. The preceding review's
before captures share the same affected source. The large Change Order diff is
predominantly indentation; its field and command bindings are retained.

- `change-order-before/after-1366.png`: focused reason input and action footer at
  1366×768, before/after separating the desktop scroller and footer.
- `pxk-loading-before-1366.png`, `pxk-loading-1366.png`, `pxk-error-1366.png`:
  known-zero versus loading/unknown summary presentation.
- `change-facts-after-1366.png`, `pantry-guidance-after-1366.png`: desktop-only
  decision typography and add-time School label/instruction.
- `planning/recipes/reconciliation-error-after-1366.png`: desktop feedback
  anatomy. These isolated captures use real workbenches with existing failed-read
  fixture factories; they do not certify full-app navigation or business recovery.
- The four JSON files record desktop measurements, focus/hit tests and 360×800
  preservation comparisons. No 390px or 768px-width preservation claim is made.

The local fixture bundle's existing chunk-size advisory is unrelated to the
production entry. Source changes introduce no dependency or backend operation.
Normal GitHub Actions remains the full frontend certificate.
