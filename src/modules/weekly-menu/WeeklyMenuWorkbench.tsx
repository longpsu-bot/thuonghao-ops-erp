import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  ApproveWeeklyMenu,
  ImportWeeklyMenu,
  RequestPlanningNeedGeneration,
  ValidateWeeklyMenu,
  WeeklyMenuApprovalSummary,
  WeeklyMenuChangeHistory,
  WeeklyMenuValidationIssues,
  WeeklyMenuWorkbench as shapeWorkbench,
} from "./weeklyMenuDomain";

const references = {
  schoolIds: ["school-nguyen-du", "school-minh-an"],
  dishIds: ["dish-pumpkin-soup", "dish-rice"],
};
const sample = ImportWeeklyMenu(
  {
    weeklyMenuId: "weekly-menu-2026-29",
    weekStart: "2026-07-13",
    weekEnd: "2026-07-19",
    sourceType: "FIXTURE",
    sourceName: "Weekly menu fixture",
    sourceSignature: "week-29-v1",
    actorId: "planner-lan",
    at: "2026-07-13T10:00:00.000Z",
    rows: [
      {
        serviceDate: "2026-07-14",
        schoolId: "school-nguyen-du",
        menuSlot: "soup",
        dishId: "dish-pumpkin-soup",
        sourceRowRef: "fixture:2",
      },
      {
        serviceDate: "2026-07-14",
        schoolId: "school-minh-an",
        menuSlot: "main",
        dishId: "dish-rice",
        sourceRowRef: "fixture:3",
      },
    ],
  },
  references,
).menu;

const label = (value: string) =>
  ({
    DRAFT: "Nháp",
    VALIDATED: "Đã kiểm tra",
    APPROVED: "Đã duyệt",
    NEED_GENERATION_REQUESTED: "Đã yêu cầu tạo nhu cầu",
    REOPENED: "Đã mở lại",
  })[value] ?? value;

export function WeeklyMenuWorkbench() {
  const [menu, setMenu] = useState(sample);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const workbench = shapeWorkbench(menu);
  const issues = WeeklyMenuValidationIssues(menu);
  const history = WeeklyMenuChangeHistory(menu);
  const approval = WeeklyMenuApprovalSummary(menu);
  const validate = () => {
    const result = ValidateWeeklyMenu(
      menu,
      references,
      "planner-lan",
      "2026-07-13T10:05:00.000Z",
    );
    setMenu(result.menu);
    setNotice(
      result.isValid
        ? "Thực đơn không có lỗi chặn."
        : "Cần xử lý lỗi chặn trước khi duyệt.",
    );
  };
  const approve = () => {
    const result = ApproveWeeklyMenu(
      menu,
      "manager-minh",
      "2026-07-13T10:10:00.000Z",
    );
    setMenu(result.menu);
    setNotice(
      result.accepted
        ? "Đã duyệt phiên bản thực đơn."
        : (result.message ?? "Không thể duyệt."),
    );
  };
  const request = () => {
    const result = RequestPlanningNeedGeneration(
      menu,
      "planner-lan",
      "2026-07-13T10:15:00.000Z",
    );
    setMenu(result.menu);
    setNotice(
      result.accepted
        ? "Đã yêu cầu tạo nhu cầu từ phiên bản đã duyệt."
        : (result.message ?? "Không thể yêu cầu."),
    );
  };
  return (
    <Panel
      title="Thực đơn tuần"
      description="Prototype in-memory: quyết định trước, chi tiết và lịch sử mở rộng khi cần."
      status={
        <Chip tone={workbench.blockingIssueCount ? "danger" : "ok"}>
          {label(menu.status)}
        </Chip>
      }
    >
      <div className="weekly-menu-summary" aria-label="Tóm tắt thực đơn tuần">
        <article>
          <span>Tuần</span>
          <strong>{workbench.week}</strong>
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
        <button className="primary" onClick={validate}>
          Kiểm tra thực đơn
        </button>
        <button onClick={approve} disabled={!workbench.canApprove}>
          Duyệt thực đơn
        </button>
        <button
          onClick={request}
          disabled={!workbench.canRequestNeedGeneration}
        >
          Yêu cầu tạo nhu cầu
        </button>
        <button
          onClick={() => setDetailsOpen((open) => !open)}
          aria-expanded={detailsOpen}
        >
          {" "}
          {detailsOpen ? "Ẩn chi tiết" : "Xem chi tiết"}
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}
      {detailsOpen && (
        <div className="weekly-menu-details">
          <CompactTable
            headers={["Ngày", "Trường", "Buổi / nhóm món", "Món", "Nguồn"]}
          >
            {menu.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.serviceDate}</td>
                <td>
                  {line.schoolId === "school-nguyen-du"
                    ? "Trường Nguyễn Du"
                    : "Trường Minh An"}
                </td>
                <td>{line.menuSlot}</td>
                <td>
                  {line.dishId === "dish-pumpkin-soup" ? "Canh bí đỏ" : "Cơm"}
                </td>
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
