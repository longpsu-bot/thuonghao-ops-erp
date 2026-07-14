import { BuildMvpMorningChaosReadModel } from "./mvpMorningChaos";
import { mvpMorningChaosScenario } from "./mvpMorningChaosFixtures";
import { Chip, CompactTable, Panel } from "./WorkbenchComponents";

const model = BuildMvpMorningChaosReadModel(mvpMorningChaosScenario);

const ownerLabels = {
  PLANNING: "Planning",
  PROCUREMENT: "Procurement",
  SUPPLIER_RECEIVING: "Supplier receiving",
  WAREHOUSE: "Warehouse",
  DISPATCH: "Dispatch",
  DESTINATION_FOLLOW_UP: "Destination follow-up",
} as const;

const time = (value: string) => value.slice(11, 16);
const quantity = (value: number, unit: string) => `${value} ${unit}`;

export function MvpMorningChaosPage() {
  const delivered = model.requirements.filter(
    (row) => row.deliveredQuantity > 0,
  ).length;
  const evidenceReady = model.requirements.filter(
    (row) => row.evidenceReady,
  ).length;
  const openAttention = Object.values(model.attentionByOwner)
    .flat()
    .filter((item) => item.status === "OPEN").length;

  return (
    <div aria-label="MVP operations simulation review">
      <p className="prototype-notice">
        Fixture-backed review surface only. It creates no commands, changes no
        ownership, and writes no operational data.
      </p>

      <section className="exception-grid" aria-label="Operating-day summary">
        <article>
          <span>Operating window</span>
          <strong>02:00–08:00</strong>
          <small>15 July 2026</small>
        </article>
        <article>
          <span>Requirement lines</span>
          <strong>{model.requirements.length}</strong>
          <small>{evidenceReady} evidence-ready</small>
        </article>
        <article>
          <span>Trips</span>
          <strong>{model.trips.length}</strong>
          <small>
            {model.trips.filter((trip) => trip.lateByMinutes > 0).length} late
          </small>
        </article>
        <article>
          <span>Delivery outcomes</span>
          <strong>{delivered}</strong>
          <small>lines with delivered quantity</small>
        </article>
        <article>
          <span>Open attention</span>
          <strong>{openAttention}</strong>
          <small>owner-grouped fixture events</small>
        </article>
        <article>
          <span>Unresolved at 08:00</span>
          <strong>{model.blockedAtEndOfWindow.length}</strong>
          <small>lines requiring follow-up</small>
        </article>
      </section>

      <Panel
        title="02:00–08:00 timeline"
        description="Ordered observations from planning release through the end-of-window review."
      >
        <CompactTable headers={["Time", "Owner", "Observation", "Attention"]}>
          {model.timeline.map((event) => (
            <tr key={event.eventId}>
              <td>
                <strong>{time(event.at)}</strong>
              </td>
              <td>{ownerLabels[event.owner]}</td>
              <td>{event.summary}</td>
              <td>
                {event.attentionStatus ? (
                  <Chip
                    tone={event.attentionStatus === "OPEN" ? "warning" : "ok"}
                  >
                    {event.attentionStatus}
                  </Chip>
                ) : (
                  "—"
                )}
              </td>
            </tr>
          ))}
        </CompactTable>
      </Panel>

      <Panel
        title="Trip statuses"
        description="Each trip is independently prepared, departed, and reviewed."
      >
        <CompactTable
          headers={["Trip / vehicle", "Plan", "Actual", "Status", "Blocked"]}
        >
          {model.trips.map((trip) => (
            <tr key={trip.dispatchTripId}>
              <td>
                <strong>{trip.dispatchTripId}</strong>
                <br />
                <small>{trip.vehicleReference}</small>
              </td>
              <td>{time(trip.plannedDepartureAt)}</td>
              <td>
                {trip.departedAt ? time(trip.departedAt) : "Not departed"}
              </td>
              <td>
                <Chip
                  tone={
                    trip.status === "CLOSED"
                      ? "ok"
                      : trip.status === "LOADED"
                        ? "danger"
                        : "warning"
                  }
                >
                  {trip.status}
                  {trip.lateByMinutes
                    ? ` · ${trip.lateByMinutes} min late`
                    : ""}
                </Chip>
              </td>
              <td>
                {[...new Set(trip.blockedRequirementReferences)].join(", ") ||
                  "None"}
              </td>
            </tr>
          ))}
        </CompactTable>
      </Panel>

      <Panel
        title="Requirements, source trace, fulfilment and delivery outcomes"
        description="Every line keeps its released source references beside physical evidence and destination outcome."
      >
        <CompactTable
          headers={[
            "Requirement line",
            "Immutable source trace",
            "Required",
            "Fulfilment evidence",
            "Trip",
            "Delivery outcome",
          ]}
        >
          {model.requirements.map((row) => (
            <tr key={row.requirementLineReference}>
              <td>
                <strong>{row.requirementLineReference}</strong>
                <br />
                <small>
                  {row.destinationReference} · {row.itemReference}
                </small>
                <br />
                {row.revisionStatus !== "UNCHANGED" && (
                  <Chip tone="warning">{row.revisionStatus}</Chip>
                )}
              </td>
              <td>
                <small>
                  Demand: {row.demandSourceReference}
                  <br />
                  Release: {row.planningReleaseReference}
                  <br />
                  Need: {row.confirmedNeedLineReference}
                  <br />
                  Handoff: {row.purchaseHandoffLineReference}
                </small>
              </td>
              <td>{quantity(row.requiredQuantity, row.unit)}</td>
              <td>
                {row.fulfilment.map((portion) => (
                  <small key={portion.allocationLineReference}>
                    {portion.sourceType}:{" "}
                    {quantity(portion.evidencedQuantity, row.unit)} /{" "}
                    {quantity(portion.allocatedQuantity, row.unit)}
                    <br />
                    {portion.evidenceReferences.join(", ") || "No evidence"}
                    <br />
                  </small>
                ))}
                <Chip tone={row.evidenceReady ? "ok" : "danger"}>
                  {row.evidenceReady
                    ? "READY"
                    : `${quantity(row.uncoveredQuantity, row.unit)} UNCOVERED`}
                </Chip>
              </td>
              <td>
                {row.tripReference}
                <br />
                <small>{row.tripStatus}</small>
              </td>
              <td>
                <strong>{row.destinationOutcome}</strong>
                <br />
                <small>
                  Delivered {quantity(row.deliveredQuantity, row.unit)} ·
                  Returned {quantity(row.returnedQuantity, row.unit)} ·
                  Exception {quantity(row.exceptionQuantity, row.unit)}
                </small>
              </td>
            </tr>
          ))}
        </CompactTable>
      </Panel>

      <Panel
        title="Owner-grouped attention queue"
        description="Review grouping only; the source module remains accountable for each next action."
      >
        <div
          className="exception-grid"
          aria-label="Owner-grouped attention queue"
        >
          {Object.entries(model.attentionByOwner).map(([owner, items]) => (
            <article key={owner}>
              <span>{ownerLabels[owner as keyof typeof ownerLabels]}</span>
              <strong>
                {items.filter((item) => item.status === "OPEN").length} open
              </strong>
              {items.map((item) => (
                <small key={item.eventId}>
                  {time(item.at)} · {item.status} · {item.message}
                </small>
              ))}
            </article>
          ))}
        </div>
      </Panel>

      <Panel
        title="Unresolved state at 08:00"
        description="The simulation ends with these facts visible; it does not resolve them on behalf of an owner."
        status={<Chip tone="danger">REVIEW REQUIRED</Chip>}
      >
        <CompactTable
          headers={["Requirement line", "Unresolved fact", "Next owner"]}
        >
          {model.blockedAtEndOfWindow.map((row) => (
            <tr key={row.requirementLineReference}>
              <td>
                <strong>{row.requirementLineReference}</strong>
                <br />
                <small>{row.tripReference}</small>
              </td>
              <td>{row.unresolved.join(" · ")}</td>
              <td>
                {row.nextActionOwner
                  ? ownerLabels[row.nextActionOwner]
                  : "Existing source module"}
              </td>
            </tr>
          ))}
        </CompactTable>
      </Panel>
    </div>
  );
}
