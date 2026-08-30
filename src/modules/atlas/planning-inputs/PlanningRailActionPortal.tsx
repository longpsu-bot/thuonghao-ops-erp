import {
  createContext,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";

type PlanningRailActionContextValue = {
  host: HTMLDivElement | null;
  setHost: (node: HTMLDivElement | null) => void;
};

const PlanningRailActionContext =
  createContext<PlanningRailActionContextValue | null>(null);

export function PlanningRailActionProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [host, setHost] = useState<HTMLDivElement | null>(null);
  const value = useMemo(() => ({ host, setHost }), [host]);
  return (
    <PlanningRailActionContext.Provider value={value}>
      {children}
    </PlanningRailActionContext.Provider>
  );
}

export function PlanningRailActionHost({ children }: { children?: ReactNode }) {
  const value = useContext(PlanningRailActionContext);
  if (!value)
    throw new Error(
      "PlanningRailActionHost requires PlanningRailActionProvider.",
    );
  return (
    <div
      ref={value.setHost}
      className="planning-operating-actions"
      aria-label="Hành động bước hiện tại"
    >
      {children}
    </div>
  );
}

export function PlanningRailActionPortal({
  children,
}: {
  children: ReactNode;
}) {
  const value = useContext(PlanningRailActionContext);
  if (!value)
    throw new Error(
      "PlanningRailActionPortal requires PlanningRailActionProvider.",
    );
  return value.host ? createPortal(children, value.host) : null;
}
