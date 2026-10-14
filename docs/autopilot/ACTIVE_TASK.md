# Atlas Autopilot — Active Task

Task: ATLAS-PXK-SHARED-LOCATION-SCOPE-DECISION-01
Status: AWAITING PRODUCT DECISION — read-only evidence preparation only
Navigator: Terra/read-only role
Implementer: Sol 6.1 after an explicit bounded implementation decision
Current business main: d254c099098a1f004f4eaaf78092f1aab9c32bd3
Atlas Staging: rnzxmxiiqgtdevzregff — migration 108
OPS v1 / Retool: read-only evidence; no writes.

## Previous task accepted

ATLAS-AUTH-SCOPE-ALIGNMENT-01 was merged through [PR #380](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/380) and deployed at the business SHA above. The Product Owner's 14 October 2026 “Please proceed” advanced the concrete reviewed handoff through merge, protected Atlas Staging deployment and rollback-only acceptance. It did not approve Production, real supplier/PXK commitments, OPS v1/Retool writes or a new shared-location policy.

- Merged-head [Frontend CI](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38545264913) and [Full Integration](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38545264875) passed. Guarded [Staging deployment](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38546830503) passed, including platform verification.
- Independent review accepted the bounded helper: canonical positive contribution/supplier overlap, complete line coverage, exact `SCHOOL` identity and captured Confirmed Need customer lineage. Generic/PXK scope helpers were preserved. Local focused suites passed all 492 assertions; exact migration-107 catalog cross-check and bounded two-line/two-School timing were retained in PR #380.
- Hosted rollback acceptance at reviewed source `8340e9a38fcdd27755a8c5cecbe70da8eafb053e` passed 16 workload checks across eight public RPC cases plus 27 isolated synthetic checks. Three independent read-only checks each reported 36 clear relations / zero probes, unchanged 17 real Draft POs and fingerprint `cefbff23b30cbc15dac0b890a956d884`. No real document was released.
- The earlier aggregate-statement timeout stopped probe execution and is retained with its clear postflight and read-only diagnosis. Revised acceptance kept the 8-second statement / 1-second lock caps and assigned one public RPC per top-level statement. No product timeout or currentness semantics changed.
- [Acceptance evidence](../testing/atlas-auth-scope-alignment-staging-108.md) and its [JSON reports](../testing/evidence/atlas-auth-scope-alignment-staging-108.json) contain exact source/deployment identities and bounded measurements. [Draft PR #381](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/381) holds the acceptance artifacts and this next baton; its review/CI/merge gate remains separate from the accepted deployed business correction.

## Decision required

The inherited PXK/reconciliation predicate accepts a matching School scope when the target delivery location equals that scoped School's default delivery location. Two Schools sharing that location can therefore match through location coverage. Existing accepted task B/C required preserving this guard; the atomic PO rule was explicitly stricter and was implemented locally in the new whole-PO predicate.

Product must select the intended PXK/reconciliation meaning:

1. `SCHOOL` authorizes that exact School only; explicit Customer/location scopes retain their separately approved meanings.
2. Preserve existing scoped-School default-location coverage, including another School sharing that location.

Neither choice is selected. A pending response is not approval. Do not infer policy from the PO rule or silently rewrite the generic authorizer.

## Allowed work while pending

- Read approved security, Procurement, PXK and reconciliation contracts; trace existing callers and distinguish School, Customer and delivery-location authority.
- Gather read-only examples and identify the smallest affected caller/helper/test/document boundary for either choice.
- Prepare a concrete Product decision with compatibility and historical-document implications. Preserve immutable released content, identity, numbering and source lineage.
- Keep acceptance PR #381 reviewable and resolve bounded review/CI defects without changing business behavior.

## Implementation gate and hard stops

No new runtime/migration/role/scope change is authorized by this baton. After Product chooses policy, record the decision in repository authority and issue a bounded implementation task with explicit allowed files and acceptance criteria before code changes.

Do not grant broad authority, change persisted role memberships, bypass RLS, alter PO/PXK grouping or lifecycles, relax Preparation's GLOBAL gate, issue real commitments, mutate OPS v1/Retool, create/use Production, or implement Warehouse under this task. Do not merge PR #381 before its exact-head CI and independent review pass. No further hosted probe writes are needed merely to restate the completed acceptance.
