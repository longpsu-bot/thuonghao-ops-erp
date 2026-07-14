import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import { DispatchDeliveryWorkbench as buildReadModel } from "./dispatchDeliveryDomain";
import { dispatchOperatorReviewFixture } from "./dispatchDeliveryFixtures";

export function DispatchDeliveryWorkbench() {
  const model = buildReadModel(dispatchOperatorReviewFixture);
  return (
    <>
      <Panel
        title="2AM–8AM Dispatch control"
        description="What is required, fulfilled, ready to load, assigned, delivered, returned, exceptional, or blocking trip closure?"
        status={
          <Chip tone={model.counts.unresolved ? "danger" : "ok"}>
            {model.counts.unresolved} unresolved requirements
          </Chip>
        }
      >
        <div
          aria-label="Dispatch morning decision summary"
          className="trace-filter"
        >
          <b>Morning wave:</b> {model.counts.total} Planning requirements ·{" "}
          {model.counts.readyToLoad} ready to load · {model.counts.assigned}{" "}
          assigned · {model.counts.delivered} delivered ·{" "}
          {model.counts.unresolved} need attention.
        </div>
        <CompactTable
          headers={[
            "Source of need",
            "Planning requirement",
            "Procurement allocation",
            "Physical evidence",
            "Ready to load",
          ]}
        >
          {model.rows.map((row) => (
            <tr key={`need-${row.requirementReference}`}>
              <td>
                <Chip
                  tone={
                    row.sourceOfNeed === "SCHOOL_CATERING" ? "ok" : "neutral"
                  }
                >
                  {row.sourceOfNeed}
                </Chip>
              </td>
              <td>
                {row.requirementReference}
                <br />
                <small>
                  {row.requirementStatus} · {row.planningReleaseReference}
                </small>
              </td>
              <td>
                {row.allocationReference}
                <br />
                <small>{row.fulfilmentSourceSplit}</small>
              </td>
              <td>
                <Chip tone={row.evidenceStatus === "READY" ? "ok" : "danger"}>
                  {row.evidenceStatus}
                </Chip>
                <br />
                <small>
                  {row.fulfilled} / {row.allocated} {row.unit} fulfilled
                </small>
              </td>
              <td>
                <Chip tone={row.readyToLoad ? "ok" : "danger"}>
                  {row.readyToLoad ? "READY" : "BLOCKED"}
                </Chip>
              </td>
            </tr>
          ))}
        </CompactTable>
      </Panel>
      <Panel
        title="Trip, load, and destination outcome"
        description="Assignment and quantity reconciliation for each Planning requirement."
        status={
          <Chip tone={model.counts.assigned ? "warning" : "danger"}>
            {model.counts.assigned} assigned
          </Chip>
        }
      >
        <CompactTable
          headers={[
            "Plan / trip",
            "Driver / vehicle",
            "Stop / destination",
            "Delivery location",
            "Required / loaded / delivered / returned / exception",
            "Delivery evidence",
            "Closure readiness",
          ]}
        >
          {model.rows.map((row) => (
            <tr key={`outcome-${row.requirementReference}`}>
              <td>
                {row.planReference} · {row.planStatus}
                <br />
                <small>
                  {row.tripReference} · {row.tripStatus}
                </small>
              </td>
              <td>
                {row.driverReference}
                <br />
                <small>{row.vehicleReference}</small>
              </td>
              <td>
                {row.stopSequence ?? "—"}. {row.destination}
                <br />
                <small>{row.stopStatus}</small>
              </td>
              <td>{row.deliveryLocation}</td>
              <td>
                {row.required} / {row.loaded} / {row.delivered} / {row.returned}{" "}
                / {row.exception} {row.unit}
              </td>
              <td>{row.deliveryEvidence}</td>
              <td>
                <Chip
                  tone={
                    row.closureReadiness === "CLOSED" ||
                    row.closureReadiness === "READY_TO_CLOSE"
                      ? "ok"
                      : "danger"
                  }
                >
                  {row.closureReadiness}
                </Chip>
              </td>
            </tr>
          ))}
        </CompactTable>
      </Panel>
      <Panel
        title="Operator attention queue"
        description="Resolve these items before the affected trip can close."
        status={
          <Chip tone={model.attentionQueue.length ? "danger" : "ok"}>
            {model.attentionQueue.length} attention items
          </Chip>
        }
      >
        <CompactTable headers={["Blocker", "Requirement / stop", "Action"]}>
          {model.attentionQueue.map((item, index) => (
            <tr
              key={`${item.requirementReference}-${item.attentionCode}-${index}`}
            >
              <td>{item.attentionCode}</td>
              <td>
                {item.requirementReference}
                <br />
                <small>{item.stopReference ?? "No stop assigned"}</small>
              </td>
              <td>{item.message}</td>
            </tr>
          ))}
        </CompactTable>
        <p>
          <b>Warnings:</b> {model.warnings.join(" ")}
        </p>
      </Panel>
      <p className="prototype-notice">
        Dispatch confirms transport and destination outcome. It does not rewrite
        Planning demand, Procurement fulfilment allocation, Warehouse stock
        movement, supplier receiving evidence, QA approval, Production
        execution, or Finance/Accounting settlement.
      </p>
    </>
  );
}
