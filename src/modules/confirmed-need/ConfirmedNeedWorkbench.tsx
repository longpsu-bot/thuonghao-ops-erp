import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  AdjustConfirmedNeedLine,
  ApproveConfirmedNeeds,
  ConfirmedNeedWorkbench as shapeWorkbench,
  ReleaseConfirmedNeedsForPurchaseHandoff,
  ValidateConfirmedNeeds,
  type ConfirmedNeedBatch,
} from "./confirmedNeedDomain";
import { draftConfirmedNeedFixture } from "./confirmedNeedFixtures";

const labels: Record<string, string> = {
  RELEASED_FOR_CONFIRMATION: "Đã chuyển sang xác nhận",
  DRAFT_REVIEW: "Đang rà soát",
  VALIDATED: "Đã kiểm tra",
  APPROVED: "Đã duyệt",
  RELEASED_FOR_PURCHASE_HANDOFF: "Đã chuyển bước bàn giao mua hàng",
  REOPENED: "Đã mở lại",
};

export function ConfirmedNeedWorkbench() {
  const [batch, setBatch] = useState<ConfirmedNeedBatch>(
    draftConfirmedNeedFixture,
  );
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const workbench = shapeWorkbench(batch);

  const validate = () => {
    const result = ValidateConfirmedNeeds(
      batch,
      "planner-lan",
      "2026-07-14T01:20:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã kiểm tra nhu cầu xác nhận."
        : (result.message ?? "Không thể kiểm tra."),
    );
  };
  const approve = () => {
    const result = ApproveConfirmedNeeds(
      batch,
      "manager-minh",
      "2026-07-14T01:25:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã duyệt nhu cầu xác nhận."
        : (result.message ?? "Không thể duyệt."),
    );
  };
  const release = () => {
    const result = ReleaseConfirmedNeedsForPurchaseHandoff(
      batch,
      "planner-lan",
      "2026-07-14T01:30:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã chuyển nhu cầu đã duyệt sang bước Purchase Handoff; không tạo đơn mua hàng."
        : (result.message ?? "Không thể chuyển bàn giao."),
    );
  };
  const adjustFirstLine = () => {
    const line = batch.lines[0];
    const result = AdjustConfirmedNeedLine(batch, {
      confirmedNeedLineId: line.confirmedNeedLineId,
      actorId: "planner-lan",
      at: "2026-07-14T01:18:00.000Z",
      reasonCode: "PORTION_CORRECTION",
      reasonNote: "Fixture: bếp xác nhận giảm suất ăn",
      beforeQuantity: line.confirmedQuantity,
      afterQuantity: line.confirmedQuantity - 2,
      unit: line.unit,
    });
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã ghi điều chỉnh có lý do và dấu vết trước/sau."
        : (result.message ?? "Không thể điều chỉnh."),
    );
  };

  return (
    <Panel
      title="Xác nhận nhu cầu"
      description="Quyết định: Planning có thể duyệt và chuyển nhu cầu này sang bước Purchase Handoff chưa?"
      status={
        <Chip tone={workbench.blockingIssueCount ? "danger" : "ok"}>
          {labels[batch.status]}
        </Chip>
      }
    >
      <div
        className="confirmed-need-summary"
        aria-label="Tóm tắt xác nhận nhu cầu"
      >
        <article>
          <span>Kỳ phục vụ</span>
          <strong>{workbench.servicePeriod}</strong>
        </article>
        <article>
          <span>Nguồn tạo nhu cầu</span>
          <strong>{labels[workbench.sourceGenerationStatus]}</strong>
        </article>
        <article>
          <span>Trạng thái xác nhận</span>
          <strong>{labels[workbench.confirmedNeedStatus]}</strong>
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
          <span>Dòng đã đổi</span>
          <strong>{workbench.changedLineCount}</strong>
        </article>
      </div>
      <div className="workbench-actions confirmed-need-actions">
        <button onClick={validate} disabled={!workbench.canValidate}>
          Kiểm tra nhu cầu
        </button>
        <button onClick={approve} disabled={!workbench.canApprove}>
          Duyệt nhu cầu
        </button>
        <button
          className="primary"
          onClick={release}
          disabled={!workbench.canReleaseForPurchaseHandoff}
        >
          Chuyển Purchase Handoff
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
              Đây là nhu cầu Planning đã xác nhận, không phải đơn mua hàng và
              không thực hiện Procurement.
            </span>
            <button
              className="inline-action"
              onClick={adjustFirstLine}
              disabled={
                batch.status !== "DRAFT_REVIEW" && batch.status !== "REOPENED"
              }
            >
              Điều chỉnh dòng mẫu
            </button>
          </div>
          <CompactTable
            headers={[
              "Ngày",
              "Trường",
              "Nguyên liệu",
              "Lý thuyết",
              "Xác nhận",
              "Dòng nguồn",
              "Điều chỉnh",
            ]}
          >
            {batch.lines.map((line) => (
              <tr key={line.confirmedNeedLineId}>
                <td>{line.serviceDate}</td>
                <td>{line.schoolId}</td>
                <td>{line.ingredientId}</td>
                <td>
                  {line.theoreticalQuantity} {line.unit}
                </td>
                <td>
                  {line.confirmedQuantity} {line.unit}
                </td>
                <td>{line.sourceReference.theoreticalNeedLineId}</td>
                <td>
                  {line.adjustments.length === 0
                    ? "Không"
                    : line.adjustments.map((adjustment) => (
                        <small key={adjustment.confirmedNeedAdjustmentId}>
                          {adjustment.beforeQuantity} →{" "}
                          {adjustment.afterQuantity} {adjustment.unit} ·{" "}
                          {adjustment.reasonCode ?? "Ghi chú"} ·{" "}
                          {adjustment.adjustedBy}
                        </small>
                      ))}
                </td>
              </tr>
            ))}
          </CompactTable>
          <p className="weekly-menu-audit">
            Nguồn {batch.needGenerationRunId} · phiên bản batch {batch.version}{" "}
            · {batch.approvedSnapshots.length} ảnh chụp đã duyệt ·{" "}
            {batch.changes.length} sự kiện.
          </p>
        </div>
      )}
    </Panel>
  );
}
