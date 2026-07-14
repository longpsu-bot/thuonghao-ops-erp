import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import { DispatchDeliveryWorkbench as buildReadModel } from "./dispatchDeliveryDomain";
import { dispatchDeliveryInputFixture } from "./dispatchDeliveryFixtures";

export function DispatchDeliveryWorkbench() {
  const model = buildReadModel(dispatchDeliveryInputFixture);
  return (
    <>
      <Panel
        title="Dispatch and Delivery decision"
        description="Are Planning-released and Procurement-fulfilled requirements assigned, loaded, delivered, or unresolved? Which stops require operator attention before the trip can close?"
        status={
          <Chip tone={model.blockers.length ? "danger" : "warning"}>
            {model.blockers.length
              ? `${model.blockers.length} blockers`
              : "Ready for assignment"}
          </Chip>
        }
      >
        <div aria-label="Dispatch decision summary" className="trace-filter">
          <b>Decision now:</b> {model.rows.length} released requirements have
          matching fulfilment allocations and physical evidence. Assign a trip,
          confirm each source-backed load, then resolve every destination
          outcome.
        </div>
        <CompactTable
          headers={[
            "Source of need",
            "Requirement / allocation",
            "Evidence",
            "Plan / trip",
            "Stop / destination",
            "Loaded / delivered / returned / exception",
            "Driver / vehicle",
            "Delivery evidence",
          ]}
        >
          {model.rows.map((row) => (
            <tr key={row.requirementReference}>
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
                <small>{row.allocationReference}</small>
              </td>
              <td>
                <Chip tone={row.evidenceStatus === "READY" ? "ok" : "danger"}>
                  {row.evidenceStatus}
                </Chip>
              </td>
              <td>
                {row.planStatus}
                <br />
                <small>{row.tripStatus}</small>
              </td>
              <td>
                {row.stopSequence}. {row.destination}
              </td>
              <td>
                {row.loaded} / {row.delivered} / {row.returned} /{" "}
                {row.exception} {row.unit}
              </td>
              <td>{row.driverVehicleReference}</td>
              <td>{row.deliveryEvidence}</td>
            </tr>
          ))}
        </CompactTable>
      </Panel>
      <Panel
        title="Operator attention"
        description="Stops and evidence that must be resolved before trip closure."
        status={
          <Chip tone={model.attentionStops.length ? "warning" : "ok"}>
            {model.attentionStops.length} stops
          </Chip>
        }
      >
        {model.attentionStops.length ? (
          <ul>
            {model.attentionStops.map((stop) => (
              <li key={stop}>{stop}</li>
            ))}
          </ul>
        ) : (
          <p>No unresolved stops.</p>
        )}
        <p>
          <b>Blockers:</b>{" "}
          {model.blockers.length
            ? model.blockers.join(" ")
            : "None in the prepared fixture."}
        </p>
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
