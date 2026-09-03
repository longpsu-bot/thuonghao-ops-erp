export type PlanningWorkflowTone = "ok" | "warning" | "danger" | "neutral";

export type PlanningWorkflowItem<T extends string = string> = {
  id: T;
  label: string;
  status: string;
  tone: PlanningWorkflowTone;
};

type PlanningWorkflowBarProps<T extends string> = {
  items: PlanningWorkflowItem<T>[];
  activeId: T;
  onChange: (id: T) => void;
};

export function PlanningWorkflowBar<T extends string>({
  items,
  activeId,
  onChange,
}: PlanningWorkflowBarProps<T>) {
  return (
    <div
      className="planning-workflow-bar"
      role="tablist"
      aria-label="Quy trình Lập nhu cầu"
    >
      {items.map((item) => {
        const statusId = `planning-workflow-${item.id}-status`;
        const active = item.id === activeId;
        return (
          <button
            key={item.id}
            type="button"
            role="tab"
            aria-label={item.label}
            aria-describedby={statusId}
            aria-selected={active}
            title={`${item.label} · ${item.status}`}
            className={`planning-workflow-tab ${item.tone}${active ? " active" : ""}`}
            onClick={() => onChange(item.id)}
          >
            <span className="planning-workflow-copy">
              <strong>{item.label}</strong>
              <span
                id={statusId}
                className={
                  item.tone === "ok" || item.tone === "neutral"
                    ? "planning-workflow-status-quiet"
                    : undefined
                }
              >
                {item.status}
              </span>
            </span>
            {(item.tone === "ok" || item.tone === "neutral") && (
              <span className="planning-workflow-marker" aria-hidden="true">
                {item.tone === "ok" ? "✓" : "—"}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
