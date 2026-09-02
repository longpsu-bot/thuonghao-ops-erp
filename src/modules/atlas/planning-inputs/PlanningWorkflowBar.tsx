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
            className={`planning-workflow-tab ${item.tone}${active ? " active" : ""}`}
            onClick={() => onChange(item.id)}
          >
            <span className="planning-workflow-copy">
              <strong>{item.label}</strong>
              <span id={statusId}>{item.status}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}
