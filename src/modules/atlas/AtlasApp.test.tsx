import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";

afterEach(cleanup);

describe("AtlasApp", () => {
  it("navigates to a page with visible ownership and handoff", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Demand Overview" }));
    expect(
      screen.getByRole("heading", { name: "Demand Overview" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Vai trò chịu trách nhiệm")).toBeInTheDocument();
    expect(screen.getByText("Bàn giao tiếp theo")).toBeInTheDocument();
  });

  it("keeps requirement review separate from supplier allocation", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Requirement Review" }));
    expect(
      screen.getByText("Planning · Requirement Review"),
    ).toBeInTheDocument();
    expect(screen.queryByText("Theo nhà cung cấp")).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Supplier Allocation" }),
    );
    expect(
      screen.getByRole("heading", { name: "Supplier Allocation" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Purchasing")).toBeInTheDocument();
  });

  it("shows stable catering and wholesale journey identities", () => {
    render(<AtlasApp />);
    expect(screen.getByText("Catering · Nguyễn Du")).toBeInTheDocument();
    expect(screen.getByText("Wholesale · Bếp ăn Minh An")).toBeInTheDocument();
    expect(screen.getByText("CAT-0713-ND")).toBeInTheDocument();
    expect(screen.getByText("WS-2026-0714")).toBeInTheDocument();
  });
});
