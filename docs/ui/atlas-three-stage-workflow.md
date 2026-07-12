# Atlas Three-Stage Workflow Prototype

**Status:** Approved task implementation record
**Scope:** React and TypeScript mock prototype only

## Active workflow

Atlas presents exactly three active operational stages:

1. **Requirement Planning** — review what is needed, who needs it, and the outbound destination. Destination may be a school, kitchen, route, or another outbound target; it remains inseparable from demand and requirement planning.
2. **Purchase Planning** — assign suppliers and prepare the supplier order list. Supplier coordination may be displayed as an optional lightweight status or note. It is not a separate stage and the system must not require daily supplier confirmation for a 24-hour catering cycle.
3. **Warehouse Receiving** — compare the prepared order list with delivered quantities and make discrepancies visible.

## Explicitly inactive workflow areas

Driver handoff, kitchen or school handoff, QA, payment, document generation, and full accounting are outside this prototype's active scope. They must not be represented as active workflow stages.

Accounting is a later read and reconciliation layer. It will consume the same source-of-truth requirement, purchase, and receiving records; it does not own or recalculate those operational facts.

## Prototype boundaries

The current interface uses static fixtures only. It creates no backend records, authoritative calculations, inventory accounting movements, purchase documents, confirmations, or integrations.

## Mock discrepancy

The Warehouse Receiving fixture compares an order for 250 kg of Jasmine rice with a receipt of 240 kg and displays a 10 kg shortage. This is a visual workflow example, not an inventory or accounting transaction.
