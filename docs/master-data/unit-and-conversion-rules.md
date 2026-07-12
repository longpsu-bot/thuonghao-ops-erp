# Unit and Conversion Rules

**Document ID:** OPS-MD-003  
**Status:** Draft — depends on ingredient review  
**Authority:** Unit handling and conversion design  
**Review required:** Yes — product owner and operations review required before calculation engine implementation

---

## 1. Purpose

This document defines how OPS ERP should treat recipe units, purchase units, storage units, and unit conversions.

Wrong unit design will break requirement calculation, procurement, dispatch, and audit. Therefore, unit rules must be explicit and traceable.

---

## 2. Principle

Unit conversion must not be hidden logic.

Every conversion used by the system must be:

- stored as a rule;
- visible to authorized users;
- effective-dated if it can change;
- traceable in calculation output where relevant.

---

## 3. Unit categories

OPS ERP should distinguish at least three unit roles.

| Unit role | Meaning | Example |
|---|---|---|
| Recipe unit | Unit entered in recipe/BOM | g, kg, piece, ml |
| Purchase unit | Unit used for buying | kg, bó, bịch, thùng, chai |
| Storage unit | Unit used for inventory count | kg, pack, bottle, carton |

The same physical unit may appear in more than one role, but the role should still be clear.

---

## 4. Global conversions

Some conversions are global and safe:

```text
1 kg = 1000 g
1 liter = 1000 ml
```

Global conversions should be stored once and reused.

---

## 5. Ingredient-specific conversions

Some conversions are not globally valid.

Examples:

```text
1 bó hành lá = X gram
1 bó hẹ = Y gram
1 thùng sữa = Z bịch
1 chai nước mắm = X ml
```

These must be ingredient-specific or supplier-specific rules.

Do not define globally invalid conversions such as:

```text
1 bó = 100g
```

unless it is scoped to a specific ingredient or supplier package.

---

## 6. Candidate unit table

```text
unit_id
unit_code
unit_name_vi
unit_name_en
unit_type
is_base_unit
active_status
```

Candidate `unit_type` values:

```text
MASS
VOLUME
COUNT
PACKAGE
BUNDLE
OTHER
```

---

## 7. Candidate conversion tables

### 7.1 Global unit conversion

```text
from_unit_id
to_unit_id
factor
effective_from
effective_to
active_status
```

Example:

```text
g -> kg = 0.001
kg -> g = 1000
```

### 7.2 Ingredient-specific conversion

```text
ingredient_id
from_unit_id
to_unit_id
factor
effective_from
effective_to
source
notes
active_status
```

### 7.3 Supplier-specific package conversion

```text
supplier_id
ingredient_id
supplier_unit_id
internal_unit_id
factor
package_description
effective_from
effective_to
active_status
```

---

## 8. Conversion precedence

Preliminary precedence:

1. supplier-specific package conversion;
2. ingredient-specific conversion;
3. global unit conversion;
4. block calculation and raise warning if no valid conversion exists.

This precedence must be reviewed before implementation.

---

## 9. Warning conditions

The system should warn or block when:

- no conversion exists between recipe unit and calculation unit;
- conversion exists but is inactive;
- multiple active conversions conflict;
- ingredient uses package unit but no ingredient-specific factor exists;
- conversion factor changed after release and affects recalculation;
- purchase unit differs from recipe unit without conversion rule.

---

## 10. Open review questions

1. Which units currently appear in recipes?
2. Which units currently appear in purchasing?
3. Which bundle/package units need ingredient-specific conversion?
4. Which supplier package units need supplier-specific conversion?
5. Should staff be allowed to edit conversion factors directly, or should this require admin approval?

---

## 11. Implementation constraint

Codex must not hard-code unit conversions outside approved global conversions.

Any non-global conversion must be represented as data and must be traceable when used.
