# Weekly Menu Google Sync Liveness — Implementation Plan

**Goal:** Ensure the Chakra Weekly Menu Google sync always reaches a visible terminal state without changing source authority or write semantics.

**Architecture:** Keep the existing Atlas → Edge Function → Apps Script → parser path. Bound only the browser Edge invocation and make UI cleanup request-owned. No retries, no Google/Retool writes, no database changes.

## Task 1 — Reproduce with tests

- Extend `src/modules/atlas/connection/atlasRpc.test.ts` to require a 45s timeout on the reviewed Google Edge invocation.
- Extend `src/vnext/atlas/planning/usePlanningSources.test.tsx` to prove an obsolete Google response cannot leave `syncing` stuck.
- Run the two focused tests and confirm the new assertions fail before production changes.

## Task 2 — Minimal liveness fix

- Add `timeout: 45_000` only to `invokeEdgeFunction`.
- Refactor `syncGoogle` cleanup so the current Google request always clears its spinner in `finally`, while superseded requests cannot clear a newer request's spinner.
- Preserve stale-response suppression and all existing parsing/source-authority checks.

## Task 3 — Verify and integrate

- Run focused Vitest, TypeScript/type generation, Prettier on touched files, and `git diff --check`.
- Commit and push a bounded branch; open a PR against `main`.
- After green CI, merge the approved fix, then refresh Draft PR #286 onto current `main` without changing its three-file cutover delta.
