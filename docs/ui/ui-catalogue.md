# UI Catalogue

**Status:** Baseline draft  
**Authority:** UI inventory and screen planning  
**Review required:** Later, before React screen implementation  

---

## 1. Purpose

This file records planned OPS ERP screens and UI patterns. It prevents screens from being invented independently of business workflows.

---

## 2. UI design principle

Screens should support business decisions. They should not duplicate backend business logic.

React may preview, organize, and validate user input for usability. Backend functions remain authoritative for operational decisions.

---

## 3. Planned screen groups

### Foundation

- login;
- app shell;
- navigation;
- user profile;
- access denied;
- system status.

### Master Data

- customers/schools;
- delivery locations;
- ingredients;
- suppliers;
- supplier-ingredient relationships;
- dishes;
- units.

### Demand

- catering demand review;
- wholesale order list;
- wholesale order detail;
- demand document history.

### Requirements

- unified requirement review;
- requirement warnings;
- substitution editor;
- quantity override editor;
- trace viewer.

### Procurement

- procurement planning board;
- supplier assignment;
- purchase order draft;
- released purchase order viewer;
- supplier confirmation.

### Fulfilment

- dispatch planning;
- dispatch document;
- delivery confirmation;
- shortage recording.

### Control

- audit timeline;
- exception dashboard;
- reconciliation reports.

---

## 4. First recommended screen

The first high-value screen after technical foundation is:

```text
Unified Requirement Review
```

It should show:

- service date;
- school/customer;
- ingredient;
- source demand;
- raw quantity;
- adjusted quantity;
- orderable quantity;
- warning state;
- substitution/override indicators;
- trace details.

---

## 5. UI standards to define later

- table density;
- Vietnamese labels;
- date format;
- quantity formatting;
- warning severity display;
- approval actions;
- unsaved changes pattern;
- export pattern;
- print layout.
