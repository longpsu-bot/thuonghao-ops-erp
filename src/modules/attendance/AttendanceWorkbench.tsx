import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  ApproveAttendance,
  AttendanceApprovalSummary,
  AttendanceChangeHistory,
  AttendanceValidationIssues,
  AttendanceWorkbench as shapeWorkbench,
  ImportAttendance,
  MarkAttendanceUsedForNeedGeneration,
  ValidateAttendance,
} from "./attendanceDomain";

const references = { schoolIds: ["school-nguyen-du", "school-minh-an"] };
const sample = ImportAttendance(
  {
    attendanceBatchId: "attendance-2026-29",
    periodStart: "2026-07-13",
    periodEnd: "2026-07-19",
    sourceType: "FIXTURE",
    sourceName: "Attendance fixture",
    sourceSignature: "attendance-week-29-v1",
    actorId: "planner-lan",
    at: "2026-07-13T10:00:00.000Z",
    rows: [
      {
        serviceDate: "2026-07-14",
        schoolId: "school-nguyen-du",
        studentPortions: 320,
        teacherPortions: 24,
        sourceRowRef: "fixture:2",
      },
      {
        serviceDate: "2026-07-14",
        schoolId: "school-minh-an",
        studentPortions: 280,
        teacherPortions: 20,
        sourceRowRef: "fixture:3",
      },
    ],
  },
  references,
).batch;

const label = (value: string) =>
  ({
    DRAFT: "Nháp",
    VALIDATED: "Đã kiểm tra",
    APPROVED: "Đã duyệt",
    USED_FOR_NEED_GENERATION: "Đã bàn giao tạo nhu cầu",
    REOPENED: "Đã mở lại",
  })[value] ?? value;

export function AttendanceWorkbench() {
  const [batch, setBatch] = useState(sample);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const workbench = shapeWorkbench(batch);
  const issues = AttendanceValidationIssues(batch);
  const history = AttendanceChangeHistory(batch);
  const approval = AttendanceApprovalSummary(batch);
  const validate = () => {
    const result = ValidateAttendance(
      batch,
      references,
      "planner-lan",
      "2026-07-13T10:05:00.000Z",
    );
    setBatch(result.batch);
    setNotice(
      result.accepted
        ? result.isValid
          ? "Số suất không có lỗi chặn."
          : "Cần xử lý lỗi chặn trước khi duyệt."
        : (result.message ?? "Không thể kiểm tra."),
    );
  };
  const approve = () => {
    const result = ApproveAttendance(
      batch,
      "manager-minh",
      "2026-07-13T10:10:00.000Z",
    );
    setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã duyệt số suất."
        : (result.message ?? "Không thể duyệt."),
    );
  };
  const handoff = () => {
    const result = MarkAttendanceUsedForNeedGeneration(
      batch,
      "planner-lan",
      "2026-07-13T10:15:00.000Z",
    );
    setBatch(result.batch);
    setNotice(
      result.accepted
        ? "Đã bàn giao số suất cho bước tạo nhu cầu."
        : (result.message ?? "Không thể bàn giao."),
    );
  };
  return (
    <Panel
      title="Sĩ số / suất ăn"
      description="Prototype in-memory: quyết định trước, chi tiết và lịch sử mở rộng khi cần."
      status={
        <Chip tone={workbench.blockingIssueCount ? "danger" : "ok"}>
          {label(batch.status)}
        </Chip>
      }
    >
      <div className="weekly-menu-summary" aria-label="Tóm tắt số suất">
        <article>
          <span>Thời kỳ phục vụ</span>
          <strong>{workbench.period}</strong>
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
          <span>Trường-ngày đã đổi</span>
          <strong>{workbench.changedSchoolDayCount}</strong>
        </article>
      </div>
      <div className="workbench-actions">
        <button
          className="primary"
          onClick={validate}
          disabled={!workbench.canValidate}
        >
          Kiểm tra số suất
        </button>
        <button onClick={approve} disabled={!workbench.canApprove}>
          Duyệt số suất
        </button>
        <button onClick={handoff} disabled={!workbench.canUseForNeedGeneration}>
          Bàn giao tạo nhu cầu
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
          <CompactTable
            headers={[
              "Ngày",
              "Trường",
              "Suất học sinh",
              "Suất giáo viên",
              "Nguồn",
            ]}
          >
            {batch.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.serviceDate}</td>
                <td>
                  {line.schoolId === "school-nguyen-du"
                    ? "Trường Nguyễn Du"
                    : "Trường Minh An"}
                </td>
                <td>{line.studentPortions}</td>
                <td>{line.teacherPortions}</td>
                <td>{line.sourceRowRef}</td>
              </tr>
            ))}
          </CompactTable>
          {(issues.blocking.length > 0 || issues.warnings.length > 0) && (
            <p>
              Lỗi cần xử lý: {issues.blocking.length}; cảnh báo:{" "}
              {issues.warnings.length}.
            </p>
          )}
          <p className="weekly-menu-audit">
            Nhập {approval.importedRows} dòng · duyệt bởi{" "}
            {approval.approvedBy ?? "chưa duyệt"} · {history.length} sự kiện.
            Chi tiết audit chỉ là fixture, chưa ghi vào hệ thống.
          </p>
        </div>
      )}
    </Panel>
  );
}
