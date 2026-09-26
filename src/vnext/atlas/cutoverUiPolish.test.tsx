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
  fireEvent.click(await screen.findByRole("button", { name: "Mở điều hướng" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
  await waitFor(() =>
    expect(
      screen.queryByRole("dialog", { name: "Điều hướng Atlas" }),
    ).not.toBeInTheDocument(),
  );
}

describe("Atlas pre-cutover UI polish", () => {
  it("simplifies the connected header and uses a shopping cart for procurement", async () => {
    show();
    expect(screen.queryByText("Vận hành trường học")).not.toBeInTheDocument();
    expect(screen.getByText("Hôm nay: 07/09/2026")).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    const procurement = await screen.findByRole("button", {
      name: "Kế hoạch mua hàng",
    });
    expect(
      within(procurement).getByTestId("procurement-nav-icon"),
    ).toHaveAttribute("data-icon", "shopping-cart");
  });

  it("uses strong two-tier Planning tabs and a Monday-Sunday week range field", async () => {
    show();
    await nav("Lập nhu cầu");

    expect(
      screen.getByRole("tablist", { name: "Giai đoạn lập nhu cầu" }),
    ).toHaveAttribute("data-tab-tier", "primary");
    expect(
      screen.getByRole("tablist", { name: "Nguồn lập nhu cầu" }),
    ).toHaveAttribute("data-tab-tier", "secondary");
    const primary = screen.getByRole("tablist", {
      name: "Giai đoạn lập nhu cầu",
    });
    const secondary = screen.getByRole("tablist", {
      name: "Nguồn lập nhu cầu",
    });
    expect(primary.compareDocumentPosition(secondary)).toBe(
      Node.DOCUMENT_POSITION_FOLLOWING,
    );
    expect(
      within(secondary)
        .getAllByRole("tab")
        .map((tab) => tab.textContent),
    ).toEqual(["Thực đơn", "Sĩ số", "Bổ sung"]);
    expect(
      screen.getByRole("heading", { level: 1, name: "Thực đơn" }),
    ).toHaveAttribute("data-visually-hidden", "true");
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "07/09/2026 – 13/09/2026",
    );
  });

  it("normalizes an arbitrary selected week day to Monday and emits week_start only", async () => {
    const { apis } = show();
    const planningRead = vi.spyOn(apis.planning, "getWorkbench");
    await nav("Lập nhu cầu");

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
    await nav("Lập nhu cầu");
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));

    expect(
      await screen.findByRole("button", { name: "Xuất Phiếu đi chợ" }),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Nhập Phiếu đi chợ" }),
    ).toBeVisible();
    expect(
      screen.getByLabelText("Nhập Phiếu đi chợ .xlsx"),
    ).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "07/09/2026 – 13/09/2026",
    );
  });

  it("orders Procurement context, visible job title, then primary tabs", async () => {
    show();
    await nav("Kế hoạch mua hàng");
    const section = screen.getByRole("region", { name: "Kế hoạch mua hàng" });
    const context = within(section).getByText("Kế hoạch mua hàng");
    const heading = within(section).getByRole("heading", {
      level: 1,
      name: "Phân bổ nhà cung ứng",
    });
    const tabs = within(section).getByRole("tablist", {
      name: "Công việc mua hàng",
    });
    expect(context).toBeVisible();
    expect(heading).toBeVisible();
    expect(
      context.compareDocumentPosition(heading) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      heading.compareDocumentPosition(tabs) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(tabs).toHaveAttribute("data-tab-tier", "primary");
    expect(tabs).toHaveAttribute("data-tab-align", "start");
  });
});
