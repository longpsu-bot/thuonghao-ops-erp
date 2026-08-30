# Planning bounded UI polish implementation plan

> Approved scope: presentation and component composition only on PR #236. Atlas remains the backend/domain authority; Retool remains operator-density evidence only.

## Guardrails

- Preserve the Compact Workbench architecture and all existing command ownership.
- Preserve complete Menu, Attendance, Pantry, and Confirmed Need payloads.
- Preserve multi-school display-only filtering and PR #235 service-date/no-demand safety.
- Add no API, schema, dependency, business concept, automation, Retool, Procurement, or Live OPS change.
- Keep PR #236 Draft and stop at the hosted review gate.

## Implementation sequence

1. Add focused regressions for compact rail actions, conditional local controls, a two-column daily navigator, localized Confirmed Need issues, single-date filter removal, and Pantry table/date ergonomics.
2. Recompose the existing Planning components so those regressions pass without moving backend-authorized commands out of their owning workbenches.
3. Consolidate the existing Planning CSS: fixed-height rail, bounded Confirmed Need navigator, denser toolbars, locally contained table overflow, and narrower Pantry/Confirmed Need tables.
4. Run focused tests, typecheck, formatting, and a boundary/diff audit.
5. Commit and push the existing branch, leave PR #236 Draft, wait for the exact-head Cloudflare deployment, and inspect 1366x768 plus 1920x1080 including console, sticky behavior, and overflow.
