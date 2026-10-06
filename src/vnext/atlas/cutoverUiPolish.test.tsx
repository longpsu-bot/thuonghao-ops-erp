import "@testing-library/jest-dom/vitest";
import type { ComponentProps } from "react";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextApp } from "./AtlasVNextApp";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import {
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";

beforeEach(() => {
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches: true,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  );
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const exporters: NonNullable<
  ComponentProps<typeof AtlasVNextApp>["exporters"]
> = {
  procurementXlsx: vi.fn(),
  procurementPdf: vi.fn(),
  pxkXlsx: vi.fn(),
  pxkPdf: vi.fn(),
  pxkGroupedXlsx: vi.fn(),
  shoppingListXlsx: vi.fn(async () => {}),
  shoppingListImport: vi.fn(async (_file, _workbench, drafts) => ({
    drafts,
    changedLineIds: [],
  })),
};

function show() {
  const apis = createAtlasApplicationFixture();
  const view = render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        userLabel="operator@example.test"
        now={applicationReviewNow}
        exporters={exporters}
        onSignOut={vi.fn()}
      />
    </AtlasVNextProvider>,
  );
  return { ...view, apis };
}

async function nav(label: string) {
  fireEvent.click(await screen.findByRole("button", { name: "Bàn làm việc" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
  await waitFor(() =>
    expect(
      screen.queryByRole("dialog", { name: "Bàn làm việc" }),
    ).not.toBeInTheDocument(),
  );
}

describe("Atlas pre-cutover UI polish", () => {
  it("simplifies the connected header and uses a shopping cart for procurement", async () => {
    show();
    expect(screen.queryByText("Vận hành trường học")).not.toBeInTheDocument();
    expect(screen.getByText("Hôm nay: 07/09/2026")).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
    const procurement = await screen.findByRole("button", {
      name: "Phân bổ NCC",
    });
    expect(
      within(procurement).getByTestId("procurement-nav-icon"),
    ).toHaveAttribute("data-icon", "shopping-cart");
  });

  it("retains Planning secondary jobs and a Monday-Sunday week range field", async () => {
    show();
    await nav("Thực đơn");

    expect(
      screen.queryByRole("tablist", { name: "Giai đoạn lập nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("tablist", { name: "Công việc thực đơn" }),
    ).toHaveAttribute("data-tab-tier", "secondary");
    const secondary = screen.getByRole("tablist", {
      name: "Công việc thực đơn",
    });
    expect(
      within(secondary)
        .getAllByRole("tab")
        .map((tab) => tab.textContent),
    ).toEqual(["Thực đơn", "Sĩ số", "Bổ sung"]);
    const heading = screen.getByRole("heading", {
      level: 1,
      name: "Thực đơn",
    });
    expect(heading).toBeVisible();
    expect(screen.getAllByRole("heading", { level: 1 })).toEqual([heading]);
    fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "07/09/2026 – 13/09/2026",
    );
  });

  it("normalizes an arbitrary selected week day to Monday and emits week_start only", async () => {
    const { apis } = show();
    const planningRead = vi.spyOn(apis.planning, "getWorkbench");
    await nav("Thực đơn");

    fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
    fireEvent.click(
      screen.getByRole("button", { name: "Mở lịch — Tuần phục vụ" }),
    );
    const grid = await screen.findByRole("grid");
    const wednesday = grid.querySelector<HTMLElement>(
      '[data-part="table-cell-trigger"][data-value="2026-09-16"]',
    );
    expect(wednesday).not.toBeNull();
    fireEvent.click(wednesday!);

    await waitFor(() =>
      expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
        "14/09/2026 – 20/09/2026",
      ),
    );
    await waitFor(() =>
      expect(planningRead.mock.lastCall?.[2]).toBe("2026-09-14"),
    );
    expect(planningRead.mock.lastCall).toHaveLength(3);
  });

  it("uses Phiếu đi chợ wording without changing the Confirmed Need workflow", async () => {
    show();
    await nav("Thực đơn");
    await nav("Xác nhận nhu cầu");

    expect(
      await screen.findByRole("button", { name: "Xuất Phiếu đi chợ" }),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Nhập Phiếu đi chợ" }),
    ).toBeVisible();
    expect(
      screen.getByLabelText("Nhập Phiếu đi chợ .xlsx"),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "07/09/2026 – 13/09/2026",
    );
  });

  it("gives Allocation one heading without duplicate primary navigation", async () => {
    show();
    await nav("Phân bổ NCC");
    const section = screen.getByRole("region", { name: "Phân bổ NCC" });
    const tabs = within(section).queryByRole("tablist", {
      name: "Công việc mua hàng",
    });
    expect(tabs).not.toBeInTheDocument();
    const heading = within(section).getByRole("heading", {
      level: 1,
      name: "Phân bổ NCC",
    });
    expect(heading).toBeVisible();
    expect(heading).toHaveAccessibleDescription("Phân bổ NCC");
    expect(within(section).getAllByRole("heading", { level: 1 })).toEqual([
      heading,
    ]);
  });
});
