import type { ReactNode } from "react";
import {
  PlanningWorkflowBar,
  type PlanningWorkflowItem,
} from "./PlanningWorkflowBar";
import { PlanningRailActionHost } from "./PlanningRailActionPortal";

type PlanningOperatingRailProps<T extends string> = {
  weekControl: ReactNode;
  serviceDateControl: ReactNode;
  schoolControl: ReactNode;
  workflowItems: PlanningWorkflowItem<T>[];
  activeId: T;
  onStepChange: (id: T) => void;
  secondaryActions?: ReactNode;
  actions?: ReactNode;
};

export function PlanningOperatingRail<T extends string>({
  weekControl,
  serviceDateControl,
  schoolControl,
  workflowItems,
  activeId,
  onStepChange,
  secondaryActions,
  actions,
}: PlanningOperatingRailProps<T>) {
  return (
    <section
      className="planning-operating-rail"
      role="region"
      aria-label="Thanh điều hành Lập nhu cầu"
    >
      <div
        className="planning-operating-context"
        role="group"
        aria-label="Phạm vi vận hành"
      >
        {weekControl}
        {serviceDateControl}
        {schoolControl}
      </div>
      <div
        className="planning-operating-workflow-row"
        role="group"
        aria-label="Công việc lập nhu cầu"
      >
        <div className="planning-operating-workflow">
          <PlanningWorkflowBar
            items={workflowItems}
            activeId={activeId}
            onChange={onStepChange}
          />
        </div>
        <div className="planning-operating-action-zone">
          {secondaryActions}
          <PlanningRailActionHost>{actions}</PlanningRailActionHost>
        </div>
      </div>
    </section>
  );
}
