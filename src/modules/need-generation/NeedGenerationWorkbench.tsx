import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  GenerateTheoreticalNeedsFromInputs,
  NeedGenerationWorkbench as shapeWorkbench,
  ReleaseGeneratedNeedsForConfirmation,
  ValidateGeneratedNeeds,
  type NeedGenerationRun,
} from "./needGenerationDomain";
import {
  prototypeCalculationFixtures,
  readyPlanningInputFixture,
} from "./needGenerationFixtures";

const generatedFixture = GenerateTheoreticalNeedsFromInputs({
  needGenerationRunId: "need-run-2026-29-v1",
  inputSet: readyPlanningInputFixture,
  fixtures: prototypeCalculationFixtures,
  actorId: "planner-lan",
  at: "2026-07-14T01:00:00.000Z",
}).run!;

const labels: Record<string, string> = {
  READY: "Đầu vào sẵn sàng",
  NEED_GENERATION_REQUESTED: "Đã yêu cầu tạo nhu cầu",
  GENERATED: "Đã tạo",
  VALIDATED: "Đã kiểm tra",
  RELEASED_FOR_CONFIRMATION: "Đã chuyển xác nhận",
  INVALIDATED: "Đã vô hiệu hóa",
};

export function NeedGenerationWorkbench() {
  const [run, setRun] = useState<NeedGenerationRun>(generatedFixture);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const workbench = shapeWorkbench(run);

  const validate = () => {
    const result = ValidateGeneratedNeeds(
      run,
      "planner-lan",
      "2026-07-14T01:05:00.000Z",
    );
    if (result.run) setRun(result.run);
    setNotice(
      result.accepted
        ? "Đã kiểm tra nhu cầu lý thuyết."
        : (result.message ?? "Không thể kiểm tra."),
    );
  };
  const release = () => {
    const result = ReleaseGeneratedNeedsForConfirmation(
      run,
      "manager-minh",
      "2026-07-14T01:10:00.000Z",
    );
    if (result.run) setRun(result.run);
    setNotice(
      result.accepted
        ? "Đã chuyển nhu cầu lý thuyết sang bước xác nhận; chưa phải nhu cầu mua hàng."
        : (result.message ?? "Không thể chuyển xác nhận."),
    );
  };

  return (
    <Panel
      title="Tạo nhu cầu lý thuyết"
      description="Quyết định: bộ nhu cầu đã đủ điều kiện chuyển sang bước xác nhận chưa?"
      status={
        <Chip tone={workbench.blockingIssueCount ? "danger" : "ok"}>
          {labels[run.status]}
        </Chip>
      }
    >
      <div className="need-generation-summary" aria-label="Tóm tắt tạo nhu cầu">
        <article>
          <span>Kỳ phục vụ</span>
          <strong>{workbench.servicePeriod}</strong>
        </article>
        <article>
          <span>Đầu vào</span>
          <strong>{labels[workbench.readinessStatus]}</strong>
        </article>
        <article>
          <span>Trạng thái tạo</span>
          <strong>{labels[workbench.generationStatus]}</strong>
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
          <span>Dòng đã tạo</span>
          <strong>{workbench.generatedLineCount}</strong>
        </article>
      </div>
      <div className="workbench-actions need-generation-actions">
        <button onClick={validate} disabled={!workbench.canValidate}>
          Kiểm tra kết quả
        </button>
        <button
          className="primary"
          onClick={release}
          disabled={!workbench.canReleaseForConfirmation}
        >
          Chuyển sang xác nhận
        </button>
        <button
          onClick={() => setDetailsOpen((open) => !open)}
          aria-expanded={detailsOpen}
        >
          {detailsOpen ? "Ẩn giải thích" : "Xem giải thích"}
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}
      {detailsOpen && (
        <div className="weekly-menu-details">
          <div className="recipe-grid">
            <article>
              <b>Ảnh chụp đầu vào</b>
              <strong>{run.inputSnapshot.readinessSnapshotId}</strong>
              <small>
                Menu v{run.inputSnapshot.weeklyMenuVersion} · Sĩ số v
                {run.inputSnapshot.attendanceVersion}
              </small>
            </article>
            <article>
              <b>Quy tắc tính</b>
              <strong>{run.inputSnapshot.calculationRuleVersion}</strong>
              <small>
                Fixture xác định, không phải tích hợp backend sản xuất.
              </small>
            </article>
            <article>
              <b>Giới hạn sử dụng</b>
              <strong>Chỉ chuyển sang Confirmed Need</strong>
              <small>
                Procurement không được tiêu thụ trực tiếp các dòng này.
              </small>
            </article>
          </div>
          <CompactTable
            headers={[
              "Ngày",
              "Trường",
              "Món",
              "Nguyên liệu",
              "Số lượng",
              "Nguồn",
              "Cách tính",
            ]}
          >
            {run.lines.map((line) => (
              <tr key={line.theoreticalNeedLineId}>
                <td>{line.serviceDate}</td>
                <td>{line.schoolId}</td>
                <td>{line.dishId}</td>
                <td>{line.ingredientId}</td>
                <td>
                  {line.quantity} {line.unit}
                </td>
                <td>{line.sourceTraceId}</td>
                <td>
                  {line.calculationTrace.portions} ×{" "}
                  {line.calculationTrace.quantityPerPortion} (
                  {line.calculationTrace.ruleVersion})
                </td>
              </tr>
            ))}
          </CompactTable>
          <p className="weekly-menu-audit">
            {run.changes.length} sự kiện · tạo bởi {run.generatedBy} lúc{" "}
            {run.generatedAt} · phiên bản run {run.version}
          </p>
        </div>
      )}
    </Panel>
  );
}
