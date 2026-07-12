# OPS ERP Open Questions Register

Open questions are design matters that must be resolved before the affected capability becomes implementation-ready.

| ID | Question | Status | Blocking |
|---|---|---|---|
| OQ-001 | At which level should procurement aggregation and rounding occur: customer/date, ingredient/date, supplier/date, or purchase-order group? | Open | Requirement and procurement specifications |
| OQ-002 | Should catering and wholesale requirements always aggregate before procurement rounding, or may contracts require separation? | Open | Requirement and procurement specifications |
| OQ-003 | What approval is required before a requirement becomes frozen for procurement? | Open | Status and approval lifecycle |
| OQ-004 | How should corrections be handled after a purchase order has been released? | Open | Procurement lifecycle |
| OQ-005 | What inventory scope is required for the first release: none, receiving-only, or full stock movement? | Open | Inventory scope and first-release boundary |
| OQ-006 | Which roles may create, approve, release, cancel, and correct each document type? | Open | Security and approval model |
| OQ-007 | Which existing OPS v1 master-data objects remain authoritative during initial coexistence? | Open | Legacy adapter and migration design |
| OQ-008 | How should recurring school-specific recipe variations differ from order-specific substitutions? | Open | Recipe and adjustment domain model |
| OQ-009 | What is the canonical demand-document lifecycle for catering and wholesale? | Open | Demand module specification |
| OQ-010 | Should replacement quantity default to preserved source requirement, an explicit factor, or a fixed quantity? | Open | Substitution command design |
| OQ-011 | When should a calculation run be persisted versus calculated on demand? | Open | Requirement-engine architecture |
| OQ-012 | Which unit conversions are globally valid and which must be ingredient-specific? | Open | Unit and calculation specification |
| OQ-013 | Which supplier assignment rules are automatic, suggested, or manually authoritative? | Open | Procurement specification |
| OQ-014 | What historical PO and dispatch information must be migrated versus retained in legacy read-only access? | Open | Migration matrix |

## Resolution procedure

When a question is resolved:

1. record the approved answer in the appropriate handbook or module document;
2. add or amend the corresponding decision and business rules;
3. mark the question `Resolved` with the resolution reference;
4. update affected acceptance criteria before implementation begins.
