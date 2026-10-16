# TASK-ATLAS-UX-ART-DIRECTION-02 — operator-facing design-first reset

**Owner-approved:** 15 October 2026; **promoted to active priority:** 16 October 2026.  
**Authority:** [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389), [ACTIVE_TASK](../autopilot/ACTIVE_TASK.md), design language v3, UI convergence, D-048 persistent workspace and Planning/Procurement business freeze.  
**Execution limit:** D1 skills and diagnosis + D2 competing prototypes. Do not implement a final UI direction before Owner selects it.

## Business job to improve

Atlas serves staff preparing daily/weekly meals, confirming exact needs, allocating ingredients to suppliers and issuing purchase orders. Operators need a coherent compact desktop workspace with connected tabs and a scannable supplier-first PO review. The legacy OPS v1 Retool purchase planner is evidence for staff workflow only.

The screenshot approved by Owner shows **browser/document-like angled tabs** and is a visual reference, not an instruction to replicate Chrome's colors or old Windows chrome. Design in the current Chakra v3 ecosystem, with 13 persistent owners, natural Vietnamese, readable numeric Units and local horizontal scroll where essential.

## D1 — skill and actual-interface audit

Examine actual repo `.agents/skills` (currently official Chakra builder/refactor), `.codex/agents`, the existing workbench shell/PO components and real rendered screen evidence. Review licensing, installation scripts and provenance before installing any third-party skill.

Skill candidates: [Anthropic Frontend Design](https://agenticskills.io/skills/frontend-design), [Emil Design Engineering](https://agenticskills.io/skills/emil-design-eng), [Impeccable](https://agenticskills.io/skills/impeccable), [Vercel Web Design Guidelines](https://agenticskills.io/skills/web-design-guidelines); [Anthropic Design Plugin](https://agenticskills.io/skills/anthropic-design) is **optional Claude Code tooling, not a Codex skill**. The creative direction must become more independent; never turn off business guards to improve a screenshot.

Output a diagnosis tied to actual files and screenshots: tab shapes/hierarchy, PO concatenated recipients, unreadable tables, bulk action affordances, information hierarchy and poor density at laptop width. Distinguish what merged main already supports from still-Draft PR #385–#388.

## D2 — differentiated presentations (not production code)

Produce **2–3 different complete alternatives** on real-looking Vietnamese content using isolated React/Chakra mockups. Every alternative must show both:
- Connected, subtly angled workbench tabs: clear joined active plane, strong inactive separation, 13-tab horizontal navigation, explicit close, dirty/blocked status, focus and keyboard behavior, without persistent-navigation rewrites.
- PO review redesigned for supplier-first scan, date/status/document/actions, and useful School/detail breakdown without clipping. Avoid 7 wide rigid columns, empty state confusion and treating export as issue/release.

Show first at **1366×768**, then 1440×900, 1920×1080, 768 and 390 where applicable; populated, selected, busy, empty and blocked states must be credible. Contact sheet, trade-off comparison and one recommendation must be easy for Owner to review.

**STOP for Product selection.** Only after this gate can a separate bounded code task replace `AtlasVNextShell.tsx` / `ProcurementOrdersStage.tsx` presentation; no unauthorized backend changes.

## Safety and progress discipline

Use `OPS_SYSTEM_MAP v1.0` and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. Staging/production/Retool data unchanged. Do not touch A/B/C unmerged operator corrections, do not modify Warehouse design policy, do not spin up repetitive CI/performance runs or extra agents without a concrete blocker. One task branch, one Draft PR/evidence handoff for design alternatives is sufficient.

Owner selects among rendered alternatives before implementation; an issue/PR alone cannot launch a local Codex process. If no local runner is connected, stop with complete GitHub task specification and explicitly report that limitation.
