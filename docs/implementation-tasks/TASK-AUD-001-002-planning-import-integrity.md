# AUD-001/002 — Planning import integrity

Owner-approved correction of the 17/09/2026 audit. Baseline: `2f5ec284113c046ed28ec77898455f980e60230e`.

## Authority and scope

Apply OPS_SYSTEM_MAP v1.0 / ARCH-002 and BR-037: source evidence is parsed without inventing identity; backend Preview owns canonicalization and blocks unresolved references. Google Sheet remains the only operator Menu source. Retool is behavioral evidence, not an identity resolver to copy.

1. Reproduce order-dependent School identity and lost duplicate columns using the actual shared parser. Cover Menu matrix/workbook, Attendance workbook and tab-separated paste.
2. School resolution is blank-safe and order-independent: exactly one normalized code match first, then exactly one name match only where name input is supported. Explicit Mã trường/school_code columns cannot fall back to labels. Ambiguity stays unresolved for existing backend blockers; no new API/schema/lifecycle.
3. Retain every normalized header position until validation. Duplicate recognized headers/aliases and conflicting active Dish Type mappings block parsing; no arbitrary winning column or partial candidate. Empty/presentation-only duplicate headings remain harmless.
4. Run focused tests, format/typecheck as needed, self-review the bounded diff, push one PR. Full CI remains authoritative and no check is weakened.
5. After certified merge, rerun the existing protected 21/09/2026 shadow workflow, verify parser/Preview and unchanged Menu/Attendance counts. Do not Save or Approve.

AUD-003 (Shopping List precision) is a separate follow-on PR. Do not change #286, Apps Script, live v1, Retool, SQL migrations, quantity rules or unrelated existing edits. No new dependencies or parallel agents.

## Acceptance and rollback

Ambiguous School references never become a valid UUID due to array order. Known unique inputs retain behavior, source-row references and explicit Attendance zero/blank semantics. All source-header ambiguity returns errors with zero candidate rows. Google source counts remain reported independently of generated assignments.

Rollback is code-only; no data migration or hosted business mutation is part of this task. Hosted recertification is read/preview only via the existing integration workflow (its idempotent source/Edge setup remains unchanged).

## Local evidence

Baseline parser tests: 6/6 PASS. Added integrity suite: 30 expected failures + 6 controls on the unchanged audited source, then 36/36 PASS after correction. Affected parser/Google transport/shadow-verifier regression: 81/81 PASS in five files. Repository TypeScript target is preserved; new tests use non-mutating copied-array reversal, not ES2023-only methods. Local npm script nesting cannot find bare `pnpm`; equivalent pinned `corepack pnpm exec chakra typegen` + `corepack pnpm exec tsc -b --pretty false` is used without global toolchain edits.

No schema, Apps Script, transport, Retool, live OPS or operational facts changed. Staging preflight: 4 Menus, 4 Attendance batches, 1 active Google source, 44 Schools (41 active). Hosted re-certification pending exact-main merge.
