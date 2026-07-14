import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { DispatchDeliveryWorkbench } from "./DispatchDeliveryWorkbench";

afterEach(cleanup);

describe("DispatchDeliveryWorkbench", () => {
  it("renders the morning decision, source ownership, execution, and attention views", () => {
    render(<DispatchDeliveryWorkbench />);
    expect(
      screen.getByText(/What is required, fulfilled, ready to load/),
    ).toBeInTheDocument();
    expect(
      screen.getByLabelText("Dispatch morning decision summary"),
    ).toHaveTextContent("7 Planning requirements");
    expect(screen.getAllByText("SCHOOL_CATERING").length).toBeGreaterThan(0);
    expect(screen.getAllByText("WHOLESALE").length).toBeGreaterThan(0);
    expect(screen.getByText("Warnings:")).toBeInTheDocument();
    expect(screen.getByText("Operator attention queue")).toBeInTheDocument();
    expect(screen.getAllByText("MISSING_FULFILMENT_EVIDENCE").length).toBe(1);
    expect(screen.getAllByText("UNRESOLVED_EXCEPTION").length).toBe(1);
    expect(screen.getAllByText("RETURN_EVIDENCE_REQUIRED").length).toBe(1);
    expect(screen.getAllByText("INACTIVE_DESTINATION").length).toBe(1);
    expect(
      screen.getAllByText("SUPPLIER_PO 25 kg + WAREHOUSE_STOCK 10 kg"),
    ).toHaveLength(1);
    expect(screen.getByText(/RETURN-HANDOVER-006/)).toBeInTheDocument();
  });

  it("renders the required ownership boundary note", () => {
    render(<DispatchDeliveryWorkbench />);
    expect(
      screen.getByText(/Dispatch confirms transport and destination outcome/),
    ).toHaveTextContent(
      "It does not rewrite Planning demand, Procurement fulfilment allocation, Warehouse stock movement, supplier receiving evidence, QA approval, Production execution, or Finance/Accounting settlement.",
    );
  });
});
