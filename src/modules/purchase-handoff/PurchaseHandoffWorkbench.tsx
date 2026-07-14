import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  PurchaseHandoffWorkbench as shapeWorkbench,
  ReleasePurchaseHandoffToProcurement,
  ValidatePurchaseHandoff,
  type PurchaseHandoffBatch,
} from "./purchaseHandoffDomain";
import { preparedPurchaseHandoffFixture } from "./purchaseHandoffFixtures";

const labels: Record<string, string> = {
  RELEASED_FOR_PURCHASE_HANDOFF: "Đã chuyển Purchase Handoff",
  PREPARED: "Đã chuẩn bị",
  VALIDATED: "Đã kiểm tra",
  RELEASED_TO_PROCUREMENT: "Đã chuyển Procurement",
  REOPENED: "Đã mở lại",
  INVALIDATED: "Đã vô hiệu hóa",
};

export function PurchaseHandoffWorkbench() {
  const [batch, setBatch] = useState<PurchaseHandoffBatch>(
    preparedPurchaseHandoffFixture,
  );
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const workbench = shapeWorkbench(batch);

  const validate = () => {
    const result = ValidatePurchaseHandoff(
      batch,
      "planner-lan",
      "2026-07-14T01:40:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã kiểm tra bàn giao nhu cầu mua."
        : (result.message ?? "Không thể kiểm tra."),
    );
  };
  const release = () => {
    const result = ReleasePurchaseHandoffToProcurement(
      batch,
      "planner-lan",
      "2026-07-14T01:45:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã chuyển hàng đợi nhu cầu sang Procurement; chưa phân công nhà cung cấp hay tạo PO."
        : (result.message ?? "Không thể chuyển Procurement."),
    );
  };

  return (
    <Panel
      title="Bàn giao nhu cầu mua"
      description="Quyết định: Planning có thể chuyển nhu cầu đã duyệt sang Procurement chưa?"
      status={
        <Chip tone={workbench.blockingIssueCount ? "danger" : "ok"}>
          {labels[batch.status]}
        </Chip>
      }
    >
      <div
        className="purchase-handoff-summary"
        aria-label="Tóm tắt bàn giao nhu cầu mua"
      >
        <article>
          <span>Kỳ phục vụ</span>
          <strong>{workbench.servicePeriod}</strong>
        </article>
        <article>
          <span>Nguồn xác nhận</span>
          <strong>{labels[workbench.sourceConfirmedNeedStatus]}</strong>
        </article>
        <article>
          <span>Trạng thái bàn giao</span>
          <strong>{labels[workbench.handoffStatus]}</strong>
        </article>
        <article>
          <span>Lỗi chặn</span>
          <strong>{workbench.blockingIssueCount}</strong>
        </article>
        <article>
          <span>Cảnh báo</span>
          <strong>{workbench.warningCount}</strong>
        </article>
        <article>
          <span>Dòng nhu cầu</span>
          <strong>{workbench.lineCount}</strong>
        </article>
      </div>
      <div className="workbench-actions purchase-handoff-actions">
        <button onClick={validate} disabled={!workbench.canValidate}>
          Kiểm tra bàn giao
        </button>
        <button
          className="primary"
          onClick={release}
          disabled={!workbench.canReleaseToProcurement}
        >
          Chuyển Procurement
        </button>
        <button
          onClick={() => setDetailsOpen((open) => !open)}
          aria-expanded={detailsOpen}
        >
          {detailsOpen ? "Ẩn chi tiết" : "Xem chi tiết"}
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}
      {detailsOpen && (
        <div className="weekly-menu-details">
          <div className="trace-filter">
            <b>Ranh giới:</b>
            <span>
              Chỉ bàn giao nhu cầu đã duyệt. Không chọn nhà cung cấp, không chia
              nguồn cung và không tạo đơn mua hàng.
            </span>
          </div>
          <CompactTable
            headers={[
              "Ngày",
              "Trường",
              "Nguyên liệu",
              "Số lượng",
              "Đơn vị mua",
              "Dòng xác nhận",
              "Trace nguồn",
            ]}
          >
            {batch.lines.map((line) => (
              <tr key={line.purchaseHandoffLineId}>
                <td>{line.serviceDate}</td>
                <td>{line.schoolId}</td>
                <td>{line.ingredientId}</td>
                <td>{line.quantity}</td>
                <td>{line.purchaseUnit}</td>
                <td>{line.confirmedNeedLineId}</td>
                <td>{line.sourceTraceId}</td>
              </tr>
            ))}
          </CompactTable>
          <p className="weekly-menu-audit">
            Batch nguồn {batch.confirmedNeedReference.confirmedNeedBatchId} ·{" "}
            phiên bản {batch.confirmedNeedReference.batchVersion} ·{" "}
            {batch.releaseSnapshots.length} ảnh chụp đã phát hành ·{" "}
            {batch.changes.length} sự kiện.
          </p>
        </div>
      )}
    </Panel>
  );
}
