import { useEffect, useMemo, useState } from "react";
import type {
  PurchaseOrdersData,
  SchoolCateringPurchaseOrder,
} from "./schoolCateringProcurementModel";
import { procurementOperatorMessages } from "./procurementOperatorCopy";

const purchaseOrderFallback =
  "Đơn mua chưa thể tiếp tục; hãy tải lại và kiểm tra thông tin hiện tại.";

function dateLabel(value: string) {
  return value.split("-").reverse().join("/");
}

function quantityLabel(value: string) {
  const [integer, fraction] = value.split(".");
  const trimmed = fraction?.replace(/0+$/, "");
  return trimmed ? `${integer}.${trimmed}` : integer;
}

function locationNames(order: SchoolCateringPurchaseOrder) {
  return [
    ...new Set(order.lines.map((line) => line.delivery_location.location_name)),
  ];
}

export function PurchaseOrderStage({
  data,
  busy,
  mutationLocked,
  loadMessage,
  search,
  onMaterialize,
  onRelease,
  onExportXlsx,
  onExportPdf,
}: {
  data: PurchaseOrdersData | null;
  busy: boolean;
  mutationLocked: boolean;
  loadMessage: string | null;
  search: string;
  onMaterialize: () => void;
  onRelease: (order: SchoolCateringPurchaseOrder) => void;
  onExportXlsx: (order: SchoolCateringPurchaseOrder) => void;
  onExportPdf: (order: SchoolCateringPurchaseOrder) => void;
}) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const visibleOrders = useMemo(() => {
    const query = search.trim().toLocaleLowerCase("vi-VN");
    if (!query) return data?.purchase_orders ?? [];
    return (data?.purchase_orders ?? []).filter((order) =>
      [
        order.supplier.supplier_name,
        order.service_date,
        order.document_number ?? "",
        ...order.lines.flatMap((line) => [
          line.ingredient.ingredient_name,
          line.delivery_location.location_name,
        ]),
      ]
        .join(" ")
        .toLocaleLowerCase("vi-VN")
        .includes(query),
    );
  }, [data, search]);

  useEffect(() => {
    setSelectedId((current) =>
      data?.purchase_orders.some((order) => order.purchase_order_id === current)
        ? current
        : null,
    );
  }, [data]);

  const selected = data?.purchase_orders.find(
    (order) => order.purchase_order_id === selectedId,
  );
  const hasPurchaseOrders = (data?.purchase_orders.length ?? 0) > 0;
  const selectedMessages = selected
    ? procurementOperatorMessages(
        [...selected.blockers, ...selected.disabled_reasons].filter(
          (reason) => !(selected.stale && reason === "PO_DRAFT_STALE"),
        ),
        purchaseOrderFallback,
      )
    : [];

  return (
    <section
      className="procurement-orders-stage"
      aria-label="Danh sách đơn mua"
    >
      <header className="procurement-order-actions">
        <div>
          <strong>Đơn mua theo nhà cung cấp và ngày giao</strong>
          <span>{visibleOrders.length} đơn trong phạm vi hiện tại</span>
        </div>
        <button
          type="button"
          className={
            hasPurchaseOrders
              ? "secondary"
              : "primary procurement-primary-action"
          }
          disabled={busy || mutationLocked}
          onClick={onMaterialize}
        >
          Tạo đơn mua
        </button>
      </header>

      {loadMessage ? (
        <p className="procurement-load-message" role="alert">
          {loadMessage}
        </p>
      ) : data && data.purchase_orders.length === 0 ? (
        <p className="procurement-empty">Chưa có đơn mua trong phạm vi này.</p>
      ) : (
        <div className="procurement-order-layout">
          <div className="procurement-order-table-scroll">
            <table className="procurement-order-table" aria-label="Đơn mua">
              <thead>
                <tr>
                  <th>Nhà cung cấp</th>
                  <th>Ngày giao</th>
                  <th>Số dòng</th>
                  <th>Trường / điểm giao</th>
                  <th>Trạng thái</th>
                  <th>Số đơn</th>
                  <th>Cảnh báo</th>
                </tr>
              </thead>
              <tbody>
                {visibleOrders.map((order) => (
                  <tr
                    key={order.purchase_order_id}
                    className={
                      selectedId === order.purchase_order_id
                        ? "selected"
                        : undefined
                    }
                  >
                    <td>
                      <button
                        type="button"
                        className="procurement-row-select"
                        aria-label={`Mở đơn mua ${order.supplier.supplier_name}`}
                        onClick={() => setSelectedId(order.purchase_order_id)}
                      >
                        {order.supplier.supplier_name}
                      </button>
                    </td>
                    <td>{dateLabel(order.service_date)}</td>
                    <td>{order.lines.length} dòng</td>
                    <td>{locationNames(order).join(", ")}</td>
                    <td>
                      <span
                        className={`procurement-state ${
                          order.status === "RELEASED_TO_SUPPLIER"
                            ? "balanced"
                            : "unallocated"
                        }`}
                      >
                        {order.status === "RELEASED_TO_SUPPLIER"
                          ? "Đã phát hành"
                          : "Bản nháp"}
                      </span>
                    </td>
                    <td>{order.document_number ?? "—"}</td>
                    <td>
                      {order.stale
                        ? "Cần cập nhật"
                        : procurementOperatorMessages(
                            order.warnings,
                            "Có cảnh báo cần kiểm tra.",
                          ).join(", ") || "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {selected && (
            <aside
              className="procurement-order-detail"
              role="region"
              aria-label={`Chi tiết đơn mua ${selected.supplier.supplier_name}`}
            >
              <header>
                <div>
                  <span>Đơn mua đã chọn</span>
                  <h3>{selected.supplier.supplier_name}</h3>
                  <p>Ngày giao {dateLabel(selected.service_date)}</p>
                </div>
                {selected.document_number && (
                  <strong>{selected.document_number}</strong>
                )}
              </header>

              {selected.stale && (
                <p className="procurement-inline-danger">
                  Bản nháp không còn khớp nguồn phân bổ hiện tại. Phải tạo lại
                  trước khi phát hành.
                </p>
              )}
              {selectedMessages.map((message) => (
                <p className="procurement-inline-danger" key={message}>
                  {message}
                </p>
              ))}

              <table
                aria-label={`Dòng đơn mua ${selected.supplier.supplier_name}`}
              >
                <thead>
                  <tr>
                    <th>Nguyên liệu</th>
                    <th>Trường / điểm giao</th>
                    <th>Số lượng</th>
                    <th>Đơn vị</th>
                  </tr>
                </thead>
                <tbody>
                  {selected.lines.map((line) => (
                    <tr key={line.purchase_order_line_revision_id}>
                      <td>{line.ingredient.ingredient_name}</td>
                      <td>{line.delivery_location.location_name}</td>
                      <td>{quantityLabel(line.ordered_quantity)}</td>
                      <td>{line.unit.unit_code}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <section className="procurement-release-context">
                <strong>Bối cảnh phát hành</strong>
                <span>Phiên bản đơn {selected.version}</span>
                <span>
                  {selected.status === "RELEASED_TO_SUPPLIER"
                    ? "Đơn đã khóa để giữ nguyên chứng từ vận hành."
                    : "Máy chủ sẽ cấp số đơn chính thức khi phát hành thành công."}
                </span>
              </section>

              {selected.status === "DRAFT" && (
                <div className="procurement-order-detail-actions">
                  {selected.stale && (
                    <button
                      type="button"
                      className="primary procurement-primary-action"
                      disabled={busy || mutationLocked}
                      onClick={onMaterialize}
                    >
                      Tạo lại đơn cần cập nhật
                    </button>
                  )}
                  <button
                    type="button"
                    className={
                      selected.stale
                        ? "secondary"
                        : "primary procurement-primary-action"
                    }
                    disabled={
                      busy ||
                      mutationLocked ||
                      !selected.allowed_actions.release
                    }
                    onClick={() => onRelease(selected)}
                  >
                    Phát hành cho NCC
                  </button>
                </div>
              )}
              {selected.status === "RELEASED_TO_SUPPLIER" &&
                selected.export_ready &&
                selected.allowed_actions.export && (
                  <div
                    className="procurement-order-output-actions"
                    aria-label="Xuất đơn mua đã phát hành"
                  >
                    <button
                      type="button"
                      className="primary procurement-primary-action"
                      disabled={busy || mutationLocked}
                      onClick={() => onExportXlsx(selected)}
                    >
                      Xuất XLSX
                    </button>
                    <button
                      type="button"
                      className="secondary"
                      disabled={busy || mutationLocked}
                      onClick={() => onExportPdf(selected)}
                    >
                      Xuất PDF
                    </button>
                  </div>
                )}
            </aside>
          )}
        </div>
      )}
    </section>
  );
}
