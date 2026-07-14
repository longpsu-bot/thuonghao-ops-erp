import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  SetSchoolDisplayOrder,
  SetSchoolStatus,
  SchoolAdminWorkbench as createReadModel,
  type SchoolAdminState,
} from "./schoolAdminDomain";
import { schoolAdminFixture } from "./schoolAdminFixtures";

export function SchoolAdminWorkbench() {
  const [state, setState] = useState<SchoolAdminState>(schoolAdminFixture);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const model = createReadModel(state);
  const displayOrder = () => {
    const school = state.schools[0];
    const result = SetSchoolDisplayOrder(state, {
      schoolId: school.schoolId,
      displayOrder: school.displayOrder + 1,
      actorId: "admin-lan",
      at: "2026-07-14T05:00:00.000Z",
      reason: "Prototype review",
    });
    if (result.accepted) setState(result.state);
    setNotice(
      result.accepted
        ? "Display-order change recorded with audit evidence."
        : (result.message ?? "Unable to update display order."),
    );
  };
  const activate = () => {
    const school = state.schools.find((item) => item.status === "INACTIVE");
    if (!school) return;
    const result = SetSchoolStatus(state, {
      schoolId: school.schoolId,
      status: "ACTIVE",
      actorId: "admin-lan",
      at: "2026-07-14T05:00:00.000Z",
      reason: "Prototype review",
    });
    if (result.accepted) setState(result.state);
    setNotice(
      result.accepted
        ? "School reactivated with explicit status evidence."
        : (result.message ?? "Unable to change school status."),
    );
  };
  const lookup = {
    group: (id?: string) =>
      state.schoolGroups.find((item) => item.schoolGroupId === id)
        ?.schoolGroupName ?? "Missing",
    type: (id?: string) =>
      state.schoolTypes.find((item) => item.schoolTypeId === id)
        ?.schoolTypeName ?? "Missing",
    calendar: (id?: string) =>
      state.serviceCalendars.find((item) => item.serviceCalendarId === id)
        ?.calendarName ?? "Missing",
    location: (id?: string) =>
      state.deliveryLocations.find((item) => item.deliveryLocationId === id)
        ?.locationName ?? "Missing",
  };
  return (
    <Panel
      title="School Admin Workbench"
      description="Decision: Is this school/customer master data valid for Planning and downstream operational reference?"
      status={
        <Chip tone={model.blockingIssueCount ? "danger" : "ok"}>
          {model.blockingIssueCount
            ? `${model.blockingIssueCount} blocking issue(s)`
            : "Ready for review"}
        </Chip>
      }
    >
      <div
        className="confirmed-need-summary"
        aria-label="School administration summary"
      >
        <article>
          <span>Active schools</span>
          <strong>{model.activeSchoolCount}</strong>
        </article>
        <article>
          <span>Inactive schools</span>
          <strong>{model.inactiveSchoolCount}</strong>
        </article>
        <article>
          <span>Blocking issues</span>
          <strong>{model.blockingIssueCount}</strong>
        </article>
        <article>
          <span>Warnings</span>
          <strong>{model.warningCount}</strong>
        </article>
      </div>
      <div className="workbench-actions confirmed-need-actions">
        <button onClick={displayOrder}>Set school display order</button>
        <button
          onClick={activate}
          disabled={
            !state.schools.some((school) => school.status === "INACTIVE")
          }
        >
          Set school status
        </button>
        <button
          className="primary"
          onClick={() => setDetailsOpen((open) => !open)}
          aria-expanded={detailsOpen}
        >
          {detailsOpen ? "Hide school details" : "Review school details"}
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}
      <p className="supporting-copy">{model.boundaryNote}</p>
      {detailsOpen && (
        <div className="weekly-menu-details">
          <CompactTable
            headers={[
              "School",
              "Status",
              "Customer group",
              "School type",
              "Service rule",
              "Delivery location",
              "Display order",
              "Issues",
            ]}
          >
            {model.schools.map((school) => (
              <tr key={school.schoolId}>
                <td>
                  {school.schoolName}
                  <small>{school.operationalProfile.operationalNotes}</small>
                </td>
                <td>
                  <Chip tone={school.status === "ACTIVE" ? "ok" : "warning"}>
                    {school.status}
                  </Chip>
                </td>
                <td>{lookup.group(school.schoolGroupId)}</td>
                <td>{lookup.type(school.operationalProfile.schoolTypeId)}</td>
                <td>
                  {lookup.calendar(school.operationalProfile.serviceCalendarId)}
                </td>
                <td>
                  {lookup.location(
                    school.operationalProfile.defaultDeliveryLocationId,
                  )}
                </td>
                <td>{school.displayOrder}</td>
                <td>
                  {school.issues.length === 0
                    ? "None"
                    : school.issues.map((issue) => (
                        <small key={issue.issueCode}>{issue.message}</small>
                      ))}
                </td>
              </tr>
            ))}
          </CompactTable>
          <p className="weekly-menu-audit">
            Change history:{" "}
            {model.schools
              .flatMap((school) => school.masterDataChanges)
              .map((change) => change.changeType)
              .join(" · ")}
          </p>
        </div>
      )}
    </Panel>
  );
}
