import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";

afterEach(cleanup);

describe("AtlasApp", () => {
  it("shows exactly three active workflow stages", () => {
    render(<AtlasApp />);
    expect(
      screen.getByRole("heading", { name: "Active workflow stages" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "1. Requirement Planning" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "2. Purchase Planning" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "3. Warehouse Receiving" }),
    ).toBeInTheDocument();
    expect(screen.queryByText("Dispatch Planning")).not.toBeInTheDocument();
  });

  it("keeps destination with requirements and supplier coordination lightweight in purchase planning", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Requirement Planning" }),
    );
    expect(
      screen.getByText(/Destination is planned with the requirement/),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Purchase Planning" }));
    expect(
      screen.getByText(/No supplier confirmation required/),
    ).toBeInTheDocument();
  });

  it("shows an ordered-versus-received discrepancy", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Warehouse Receiving" }),
    );
    expect(screen.getByText("Discrepancy: short by 10 kg")).toBeInTheDocument();
  });
});
