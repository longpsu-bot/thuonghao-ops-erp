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
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextApp } from "./AtlasVNextApp";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import {
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";

afterEach(cleanup);

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
  return render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={createAtlasApplicationFixture()}
        authSubject="operator"
        userLabel="operator@example.test"
        now={applicationReviewNow}
        exporters={exporters}
        onSignOut={vi.fn()}
      />
    </AtlasVNextProvider>,
  );
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
    const procurement = screen.getByRole("button", {
      name: "Kế hoạch mua hàng",
    });
    expect(within(procurement).getByTestId("procurement-nav-icon")).toHaveAttribute(
      "data-icon",
      "shopping-cart",
    );
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
    expect(
      screen.getByRole("heading", { level: 1, name: "Thực đơn" }),
    ).toHaveAttribute("data-visually-hidden", "true");
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "07/09/2026 – 13/09/2026",
    );
  });

  it("uses Phiếu đi chợ wording without changing the Confirmed Need workflow", async () => {
    show();
    await nav("Lập nhu cầu");
    fireEvent.click(
      screen.getByRole("tab", { name: "Xác nhận nhu cầu" }),
    );

    expect(
      await screen.findByRole("button", { name: "Xuất Phiếu đi chợ" }),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Nhập Phiếu đi chợ" }),
    ).toBeVisible();
    expect(screen.getByLabelText("Nhập Phiếu đi chợ .xlsx")).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "07/09/2026 – 13/09/2026",
    );
  });

  it("puts Procurement tabs first and removes the duplicated visible title block", async () => {
    show();
    await nav("Kế hoạch mua hàng");
    const section = screen.getByRole("region", { name: "Kế hoạch mua hàng" });
    const tabs = within(section).getByRole("tablist", {
      name: "Công việc mua hàng",
    });
    expect(tabs).toHaveAttribute("data-tab-tier", "primary");
    expect(tabs).toHaveAttribute("data-tab-align", "start");
    expect(within(section).queryByText("Kế hoạch mua hàng")).not.toBeInTheDocument();
    expect(
      within(section).getByRole("heading", {
        level: 1,
        name: "Phân bổ nhà cung ứng",
      }),
    ).toHaveAttribute("data-visually-hidden", "true");
  });
});
