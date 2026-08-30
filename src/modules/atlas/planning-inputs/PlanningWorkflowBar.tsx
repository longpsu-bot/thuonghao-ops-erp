import { Button } from "@mantine/core";

export type PlanningWorkflowTone = "ok" | "warning" | "danger" | "neutral";

export type PlanningWorkflowItem<T extends string = string> = {
  id: T;
  step: 1 | 2 | 3 | 4;
  label: string;
  compactLabel?: string;
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
          <Button
            key={item.id}
            type="button"
            role="tab"
            variant="subtle"
            aria-label={item.label}
            aria-describedby={statusId}
            aria-selected={active}
            className={`planning-workflow-tab ${item.tone}${active ? " active" : ""}`}
            onClick={() => onChange(item.id)}
          >
            <span className="planning-workflow-step" aria-hidden="true">
              {item.step}
            </span>
            <span className="planning-workflow-copy">
              <strong>{item.compactLabel ?? item.label}</strong>
              <span id={statusId}>{item.status}</span>
            </span>
          </Button>
        );
      })}
    </div>
  );
}
