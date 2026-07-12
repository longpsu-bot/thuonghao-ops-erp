# Test Strategy

**Status:** Baseline draft  
**Authority:** Testing approach  
**Review required:** Technical review before implementation  

---

## 1. Purpose

This document defines the testing strategy for OPS ERP.

OPS ERP must be tested because small errors in calculation, release, dispatch, or permissions can create real operational losses.

---

## 2. Testing principle

Business rules must be testable.

The most important tests are not UI snapshot tests. They are tests proving that quantities, statuses, permissions, and release behavior are correct.

---

## 3. Test categories

### Business-rule tests

Cover calculation, adjustment, substitution, rounding, approval, release, and correction rules.

### Database tests

Cover database functions, constraints, views, RLS behavior, and migration safety.

### API contract tests

Cover request/response shape, validation errors, permissions, and side effects.

### Frontend tests

Cover forms, tables, loading states, validation display, and key user interactions.

### End-to-end tests

Cover full workflows such as wholesale order to dispatch.

---

## 4. Critical test scenarios

- catering dish demand explodes into correct ingredient requirements;
- wholesale demand bypasses recipe explosion;
- substitution preserves traceability;
- quantity override records original and override quantity;
- rounding produces correct orderable quantity;
- released purchase order is immutable;
- correction does not silently rewrite released history;
- unauthorized user cannot release purchase order;
- frontend cannot bypass backend validation.

---

## 5. Test data rule

Test fixtures should use realistic Vietnamese catering examples but must avoid sensitive production data unless explicitly sanitized.

---

## 6. Codex rule

Codex tasks that implement business logic must include or update tests.

Codex must not delete tests or weaken assertions merely to pass CI.

---

## 7. Acceptance rule

A module cannot be considered production-ready without tests for its critical business rules.
