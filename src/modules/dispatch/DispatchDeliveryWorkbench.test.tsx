import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { DispatchDeliveryWorkbench } from "./DispatchDeliveryWorkbench";

afterEach(cleanup);

describe("DispatchDeliveryWorkbench", () => {
  it("renders decision-first status, sources, blockers, warnings, and evidence", () => {
    render(<DispatchDeliveryWorkbench />);
    expect(
      screen.getByText(
        /Are Planning-released and Procurement-fulfilled requirements assigned/,
      ),
    ).toBeInTheDocument();
    expect(screen.getAllByText("SCHOOL_CATERING").length).toBeGreaterThan(0);
    expect(screen.getAllByText("WHOLESALE").length).toBeGreaterThan(0);
    expect(screen.getByText("Blockers:")).toBeInTheDocument();
    expect(screen.getByText("Warnings:")).toBeInTheDocument();
    expect(screen.getAllByText("READY")).toHaveLength(5);
    expect(
      screen.getByText(/operator attention before the trip can close/),
    ).toBeInTheDocument();
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
