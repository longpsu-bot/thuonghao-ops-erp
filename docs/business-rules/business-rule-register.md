# OPS ERP Business Rule Register

This register records approved business rules. Module specifications may refine implementation details but must not contradict this register.

| ID | Rule | Status |
|---|---|---|
| BR-001 | Catering dish demand must resolve through an applicable recipe version before becoming ingredient demand. | Approved |
| BR-002 | Wholesale ingredient demand bypasses recipe explosion. | Approved |
| BR-003 | Catering and wholesale requirements may converge into a shared requirement and procurement process. Exact aggregation and rounding boundaries remain to be specified. | Approved |
| BR-004 | An order-specific ingredient substitution must not modify the permanent recipe. | Approved |
| BR-005 | A substitution and suppression of the original effective requirement must be processed atomically. | Approved |
| BR-006 | A quantity override changes an effective requirement quantity but does not redefine the permanent recipe. | Approved |
| BR-007 | Released purchase and dispatch documents must not be silently recalculated. | Approved |
| BR-008 | Every effective requirement must retain sufficient lineage to explain its source, recipe basis, adjustments, and calculation rules. | Approved |
| BR-009 | Only one system version may own writes for a workflow at a given point in rollout. | Approved |
| BR-010 | Frontend calculations are advisory until validated and committed by the backend. | Approved |
| BR-011 | Business facts and operational commitments are stored; derived requirements must be reproducible from facts and versioned rules. | Approved |
| BR-012 | A released document correction must be represented as a revision, cancellation, or compensating action rather than a silent historical rewrite. | Approved |
| BR-013 | Order-specific adjustments must be anchored to the actual demand or ordered-dish line, not only to school, date, and dish. | Approved |
| BR-014 | Structural adjustments must support at least ADD, REMOVE, REPLACE/SUBSTITUTE, and QUANTITY_OVERRIDE operations. | Approved |
| BR-015 | Quick substitution must preserve an explicit relationship between the original and replacement requirement. | Approved |
| BR-016 | Procurement rounding and packaging rules must be centralized in typed backend configuration and functions. | Approved |
| BR-017 | Rule and override precedence must be deterministic and documented. | Approved |
| BR-018 | Stable line identity must be preserved across requirements, supplier assignment, purchase-order lines, dispatch lines, and audit history. | Approved |
| BR-019 | Security authorization must be enforced in the backend through RLS and RPC privileges, not solely through hidden UI controls. | Approved |
| BR-020 | Service-role credentials must never be exposed in the React frontend. | Approved |
| BR-021 | A dual-use ingredient may be calculated as a main ingredient or as an herb/condiment depending on recipe-line usage context and configured quantity threshold. | Draft — product owner review required |
| BR-022 | Herb/condiment quantities below the configured threshold may use batch allowance calculation instead of exact per-portion proportional calculation. | Draft — product owner review required |
| BR-023 | Herb/condiment batch allowance rules must be backend-authoritative, configurable, traceable, and separate from procurement rounding. | Draft — product owner review required |
| BR-024 | Requirement traces must record when herb/condiment batch allowance is applied, including the original recipe quantity, threshold, batch size, allowance quantity, and rule identifier. | Draft — product owner review required |

## Planned rule domains

Future rules will be grouped under:

- Demand
- Recipes
- Adjustments and substitutions
- Requirement calculation
- Herb and condiment allowance
- Unit conversion
- Rounding and packaging
- Supplier allocation
- Purchase release
- Receiving and inventory
- Dispatch and delivery
- Access and approval
- Audit and correction
