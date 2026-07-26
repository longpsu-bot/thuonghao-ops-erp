import { cleanup, render, screen, within } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { MvpMorningChaosPage } from "./MvpMorningChaosPage";

afterEach(cleanup);

describe("MVP morning operations simulation page", () => {
  it("shows the complete fixture-backed 02:00–08:00 review surface", () => {
    render(<MvpMorningChaosPage />);

    expect(screen.getByLabelText("Operating-day summary")).toHaveTextContent(
      "02:00–08:00",
    );
    expect(
      screen.getByRole("heading", { name: "02:00–08:00 timeline" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Trip statuses" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", {
        name: "Requirements, source trace, fulfilment and delivery outcomes",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Owner-grouped attention queue" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Unresolved state at 08:00" }),
    ).toBeInTheDocument();

    const unresolved = screen
      .getByRole("heading", { name: "Unresolved state at 08:00" })
      .closest("section")!;
    expect(within(unresolved).getByText("DR-S10-L2")).toBeInTheDocument();
    expect(
      within(unresolved).getByText(
        /3 kg remains without physical fulfilment evidence/,
      ),
    ).toBeInTheDocument();
    expect(within(unresolved).getByText("Procurement")).toBeInTheDocument();

    expect(
      screen.getByText(/Fixture-backed review surface only/),
    ).toBeInTheDocument();
    expect(
      within(
        screen.getByLabelText("MVP operations simulation review"),
      ).queryByRole("button"),
    ).not.toBeInTheDocument();
  });
});
