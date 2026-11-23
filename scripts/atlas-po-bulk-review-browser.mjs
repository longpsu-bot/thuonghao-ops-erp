import assert from "node:assert/strict";

// The disposable browser can submit only after the dialog matches the intended documents.
export async function confirmReviewedOrders({
  evaluate,
  until,
  action,
  orders,
}) {
  const trigger = `button[data-po-bulk-review="${action}"]:enabled`;
  await until(
    () => evaluate(`Boolean(document.querySelector('${trigger}'))`),
    "PO_REVIEW_READY",
  );
  await evaluate(`document.querySelector('${trigger}').click()`);
  const confirm = `[role="dialog"] button[data-po-bulk-confirm="${action}"]:enabled`;
  await until(
    () => evaluate(`Boolean(document.querySelector('${confirm}'))`),
    "PO_REVIEW_CONFIRM_READY",
  );
  const rows = await evaluate(
    `Array.from(document.querySelectorAll('[role="dialog"] [aria-label="Danh sách đơn mua"] li'), row => row.innerText)`,
  );
  assert.equal(rows.length, orders.length);
  for (const order of orders) {
    const date = order.service_date.split("-").reverse().join("/");
    assert(
      rows.some(
        (row) =>
          row.includes(
            order.current_revision.supplier_name_snapshot ??
              order.supplier.supplier_name,
          ) &&
          row.includes(date) &&
          (!order.document_number || row.includes(order.document_number)),
      ),
      "Supplier, date and official number must identify the reviewed order.",
    );
  }
  await evaluate(`document.querySelector('${confirm}').click()`);
}
