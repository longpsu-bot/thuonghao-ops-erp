# Staging weekday default sync

`scripts/sync-atlas-staging-weekday-defaults.mjs` is a manual, bounded source sync
for the 34 configured active OPS v1 Schools observed on 5 November 2026. It is
not a periodic sync, School importer or schema installer. It uses the existing
[governed School default commands](../architecture/rmvp-01-independent-atlas-master-data.md#weekday-attendance-defaults-amendment--5-november-2026).

Source project is fixed to `qnthofvccilhnefdcxnz`; target is fixed to approved
Atlas Staging `rnzxmxiiqgtdevzregff`. Source reads use only the Management API's
`/database/query/read-only` endpoint with a fixed SELECT over School identity,
active status and the two weekday arrays. The response must prove the current
database role is `supabase_read_only_user`, without elevated role/database
privileges or School table/column write privileges, and with SELECT permission.
Source data is never written.

## Values and scope

The source arrays `default_students_weekday` and `default_teachers_weekday` are
Monday–Friday. A null array means no overrides for that population. A present
array must contain exactly five elements, each null or an integer from 0 through 2147483647. Null elements produce missing fields; zero produces an explicit
zero. Strings, PostgreSQL array text, nested arrays, fractions, negative values,
overflow and malformed lengths fail closed.

Only Schools with at least one non-null weekday value are configured. Exactly
34 must be present, active and uniquely mapped to an existing active Atlas
School by `school_code = v1-school-<source-id>`. Missing, ambiguous, inactive or
duplicate identities block the run. This count is deliberately pinned to the
reviewed date scope; changed source scope requires another review. Unconfigured
School 54 is excluded and is not created. Other unconfigured Schools retain
their current defaults and weekday facts.

The source object replaces the configured School's complete weekday object;
null source fields therefore use the target's existing general default rather
than retaining an old weekday override. The runner supplies unchanged target
`default_student_portions` and `default_teacher_portions` in every change. A
source-null field never becomes zero.

## Preview and apply

The workflow `.github/workflows/atlas-staging-weekday-defaults.yml` is manual and
defaults `apply` to false. Both modes use protected `atlas-staging` values,
`verifyExactMainCheckout` and `verifyExactHeadCertification`. Current exact main
must have successful Frontend CI and an executed Full Integration job. No local
override or skip-certification option is provided. The Staging migration that
adds weekday defaults must already be deployed; a missing shaped weekday field
blocks the runner.

Preview requires `--commit-sha <40-hex-current-main-sha>`. It reads source and
authenticates with the protected existing test Actor's email/password using the
publishable key, verifies that session through `/auth/v1/user`, then calls
`get_school_master_data`. It makes **zero School command calls**. Session tokens
remain in memory and are never impersonated or constructed from JWT claims.
The source Management credential is not used for target reads or writes.

The stable SHA-256 plan covers normalized configured source facts and every
configured target's UUID, code, active status, version, general default counts
and complete current weekday object. Row ordering does not change it. The
summary contains only status, contract, counts and checksums; no raw rows,
identities, names, credentials, SQL result bodies or command payloads are
uploaded. Inspect the preview summary and its separately authorized source
evidence before accepting the checksum.

Apply additionally requires `--apply`,
`--target-project-ref rnzxmxiiqgtdevzregff` and
`--plan-checksum <reviewed-preview-checksum>`. The initial fresh plan must match.
Immediately before the command, the runner rechecks current main/certification,
re-reads the source and complete authenticated School list, and rejects any
source, version or other School drift. Only changed configured Schools enter
one atomic `update_school_portion_defaults_bulk` command using RMVP-01.v2,
their current versions, the actual authenticated subject and reason
`OPS_V1_WEEKDAY_DEFAULT_SYNC`.

After known success, the exact request is repeated once to prove receipt replay;
both response objects must match. This is deliberate replay verification, not a
retry after failure. Authenticated readback checks all configured Schools and
every unrelated School. Only the intended weekday facts and one version
increment per changed School may differ. An already matching plan produces
`NO_CHANGE` with zero command calls. A new invocation after a successful apply
needs a new preview because target versions/current weekday facts changed.

The runner signs out its own session in `finally`, with explicit local scope so
other sessions for that Actor are preserved. See [Supabase sign-out scopes](https://supabase.com/docs/guides/auth/signout).

## Failure and recovery

A missing confirmation, stale checksum, changed source scope, reference problem,
failed certification, drift or denied command stops the run. There is no
automatic command retry. `APPLY_OUTCOME_UNKNOWN`, replay failure or readback
failure can occur after a committed command: inspect governed receipts and
authoritative School readback before choosing any next action. Do not blindly
rerun Apply. Sign-out failure is reported unless a primary failure already
exists; the primary error is retained. Diagnostics never include upstream
bodies or raw credentials.

The runner creates no table, RPC, role, capability or policy, and uses no direct
target SQL or service-role key. It changes no saved Attendance, approval
snapshot, released document or other operational row. Roll back incorrect
values only through a separately reviewed governed School correction; do not
erase audit/receipt history. Implementation and local mocked tests do not prove
that the hosted workflow has run or that the 34 Schools have been synced.
