# Operations Runbook

**Status:** Baseline draft  
**Authority:** Production operations and incident response  
**Review required:** Later, before production deployment  

---

## 1. Purpose

This runbook defines how OPS ERP should be operated after production deployment.

It is intentionally created early so production readiness is considered from the beginning.

---

## 2. Production principle

Do not deploy operational software without a rollback, backup, and incident response plan.

---

## 3. Areas to define before production

- deployment process;
- environment variables;
- Supabase project configuration;
- backup procedure;
- restore procedure;
- incident response;
- rollback process;
- access review;
- audit review;
- monitoring;
- staff support procedure.

---

## 4. Incident categories

- login failure;
- incorrect requirement calculation;
- purchase order generation error;
- dispatch document error;
- data import failure;
- supplier assignment issue;
- permission error;
- production outage;
- accidental data modification.

---

## 5. Emergency rule

Emergency fixes must be documented after the incident. Emergency access must not become normal workflow.

---

## 6. Backup and restore placeholder

Final backup and restore procedures must be written after the Supabase project and deployment model are finalized.

---

## 7. Release checklist placeholder

Before production release, define:

- release owner;
- release date;
- affected workflow;
- test evidence;
- rollback plan;
- staff notice;
- post-release validation.
