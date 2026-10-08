# Tab border legibility — 8 October 2026

Owner-approved presentation change: neutral tab boundaries, accent selected outlines, 3px selected underlines, neutral hover and visible keyboard focus. Scope is the workspace shell and shared primary/secondary task-tab styles. No handlers, business contracts, API calls, permissions or state ownership changed.

## Verification

- Local fixture review of the production workbenches at 1920×1080, 1440×900, 1366×768, 650×900 and 360×800: all eleven owners reachable; no document overflow or browser errors.
- Rendered CSS checks: 1px resting boundaries, 3px selected underline, distinct selected/hover treatment and at least 2px keyboard focus outlines. The secondary underline uses the accent token despite Chakra's selected/horizontal recipe specificity.
- Workspace Home/End switching and the narrow open-owner selector passed. Internal source selection retains its existing heading-focus handoff. Narrow targets retain 44px height.
- 71 focused system/shell/persistent-workspace/handoff tests passed; the 44 system/navigation tests passed again after the final underline correction. UI boundary, changed-file formatting and diff whitespace checks passed.
- Independent read-only review found no actionable issues. Full frontend validation runs in GitHub Actions; hosted and real staff usage are not claimed by this fixture review.

![Desktop: eleven open owners and internal source tabs](planning-1440x900.png)

![Narrow: existing open-owner selector and outlined source tabs](planning-360x800.png)

## Security and rollback

No backend, RLS, data, migration or dependency changes. Revert this frontend/docs change to restore the previous presentation; no data rollback is required. Product review and merge remain separate.
