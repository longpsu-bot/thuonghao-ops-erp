import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { ProcurementWorkbench } from "./ProcurementWorkbench";

afterEach(cleanup);

describe("Procurement workbench", () => {
  it("shows a decision-first summary and respects every command gate", () => {
    render(<ProcurementWorkbench />);
    expect(
      screen.getByText(
        "Can Procurement safely convert released demand into supplier commitments?",
        { exact: false },
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByLabelText("Procurement decision summary"),
    ).toHaveTextContent("purchase-handoff-2026-29-v1@1");

    const validateAllocation = screen.getByRole("button", {
      name: "Validate allocation",
    });
    const approveAllocation = screen.getByRole("button", {
      name: "Approve allocation",
    });
    const createDrafts = screen.getByRole("button", {
      name: "Create PO drafts",
    });
    const validatePurchaseOrder = screen.getByRole("button", {
      name: "Validate PO",
    });
    const releasePurchaseOrder = screen.getByRole("button", {
      name: "Release PO to supplier",
    });
    const confirmSupplier = screen.getByRole("button", {
      name: "Record supplier confirmation",
    });

    expect(validateAllocation).toBeDisabled();
    expect(approveAllocation).toBeDisabled();
    expect(createDrafts).toBeDisabled();
    expect(releasePurchaseOrder).toBeDisabled();
    expect(confirmSupplier).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Assign prototype suppliers" }),
    );
    expect(validateAllocation).toBeEnabled();
    fireEvent.click(validateAllocation);
    expect(approveAllocation).toBeEnabled();
    fireEvent.click(approveAllocation);
    expect(createDrafts).toBeEnabled();
    fireEvent.click(createDrafts);
    expect(validatePurchaseOrder).toBeEnabled();
    expect(releasePurchaseOrder).toBeDisabled();
    fireEvent.click(validatePurchaseOrder);
    expect(releasePurchaseOrder).toBeEnabled();
    fireEvent.click(releasePurchaseOrder);
    expect(confirmSupplier).toBeEnabled();
    fireEvent.click(confirmSupplier);
    expect(
      screen.getByText(/Warehouse receiving was not created/),
    ).toBeInTheDocument();
    expect(
      screen.getByLabelText("Procurement decision summary"),
    ).toHaveTextContent("Supplier commitment ready for Warehouse handoff");
  });

  it("keeps source, eligibility, PO, confirmation, and revision detail expandable", () => {
    render(<ProcurementWorkbench />);
    fireEvent.click(
      screen.getByRole("button", { name: "Assign prototype suppliers" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Show details" }));
    expect(screen.getAllByText("Atlas Fresh Supply").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Eligible").length).toBeGreaterThan(0);
    expect(
      screen.getByText("confirmed-need-2026-29-v1-line-1"),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        /does not receive goods or create Warehouse, QA, Finance/,
      ),
    ).toBeInTheDocument();
  });
});
