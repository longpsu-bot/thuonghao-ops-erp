import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { MantineProvider } from "@mantine/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type {
  MasterDataApi,
  MasterDataBulkCommandRequest,
} from "../atlas/master-data/masterDataApi";
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
import { atlasTheme } from "../../theme";
import { SchoolAdminWorkbench } from "./SchoolAdminWorkbench";

afterEach(cleanup);

const authSubject = "10000000-0000-0000-0000-000000000101";
const authState = {
  status: "authenticated",
  authSubject,
  user: { id: authSubject },
  session: {
    access_token: "test",
    refresh_token: "test",
    expires_in: 3600,
    token_type: "bearer",
    user: { id: authSubject },
  },
} as unknown as AtlasAuthState;

const schools = [
  {
    school_id: "school-1",
    school_code: "atlas-primary",
    school_name: "Trường Tiểu học Atlas",
    school_status: "ACTIVE",
    version: 3,
    display_order: 1,
    default_student_portions: 420,
    default_teacher_portions: 32,
    school_type_id: "primary",
    school_type_name: "Tiểu học",
    customer_id: "customer-1",
    customer_code: "group-1",
    customer_name: "Cụm trường Atlas",
    delivery_location_id: "location-1",
    delivery_location_name: "Cổng giao chính",
    delivery_address: "01 Đường Atlas",
    delivery_instructions: "Trước 05:30",
    contract_context: "Hợp đồng 2026–2027",
  },
  {
    school_id: "school-2",
    school_code: "atlas-secondary",
    school_name: "Trường Trung học Beta",
    school_status: "ACTIVE",
    version: 7,
    display_order: 2,
    default_student_portions: 840,
    default_teacher_portions: 45,
    school_type_id: "secondary",
    school_type_name: "Trung học",
    customer_id: "customer-2",
    customer_code: "group-2",
    customer_name: "Cụm trường Beta",
    delivery_location_id: "location-2",
    delivery_location_name: "Kho thực phẩm",
    delivery_address: "02 Đường Beta",
    delivery_instructions: null,
    contract_context: null,
  },
  {
    school_id: "school-3",
    school_code: "atlas-primary-2",
    school_name: "Trường Tiểu học Gamma",
    school_status: "INACTIVE",
    version: 2,
    display_order: 3,
    default_student_portions: 300,
    default_teacher_portions: 20,
    school_type_id: "primary",
    school_type_name: "Tiểu học",
    customer_id: "customer-3",
    customer_code: "group-3",
    customer_name: "Cụm trường Gamma",
    delivery_location_id: "location-3",
    delivery_location_name: "Cổng phụ",
    delivery_address: "03 Đường Gamma",
    delivery_instructions: null,
    contract_context: null,
  },
];

function success(extra: Record<string, unknown>): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...extra },
  } as AtlasRpcResult;
}

function createApi(writeResult?: AtlasRpcResult, readAfterWrite = schools) {
  const getSchools = vi
    .fn()
    .mockResolvedValueOnce(success({ schools }))
    .mockResolvedValue(success({ schools: readAfterWrite }));
  const updateSchoolDefaultsBulk = vi
    .fn<(request: MasterDataBulkCommandRequest) => Promise<AtlasRpcResult>>()
    .mockResolvedValue(
      writeResult ??
        success({
          safe_operator_message: "Saved.",
          updated_schools: [],
        }),
    );
  return {
    api: {
      getSchools,
      updateSchoolDefaultsBulk,
    } as unknown as MasterDataApi,
    getSchools,
    updateSchoolDefaultsBulk,
  };
}

async function renderReady(api: MasterDataApi) {
  render(
    <MantineProvider theme={atlasTheme} forceColorScheme="light">
      <SchoolAdminWorkbench authState={authState} api={api} />
    </MantineProvider>,
  );
  expect(await screen.findByText("Trường Tiểu học Atlas")).toBeInTheDocument();
}

function studentInput(name = "Trường Tiểu học Atlas") {
  return screen.getByLabelText(`Học sinh mặc định — ${name}`);
}

function teacherInput(name = "Trường Trung học Beta") {
  return screen.getByLabelText(`Giáo viên mặc định — ${name}`);
}

async function openReview() {
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  return screen.findByRole("dialog", { name: "Xem thay đổi" });
}

describe("bulk School default portions", () => {
  it("keeps inline search/filter editing and exposes Review, never direct Save, in the Edit state", async () => {
    const connected = createApi();
    await renderReady(connected.api);

    expect(studentInput()).toHaveValue(420);
    expect(teacherInput()).toHaveValue(45);
    expect(
      screen.queryByRole("button", { name: "Xem và sửa" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "beta" },
    });
    expect(screen.getByText("Trường Trung học Beta")).toBeInTheDocument();
    expect(screen.queryByText("Trường Tiểu học Atlas")).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "" },
    });
    fireEvent.change(screen.getByLabelText("Loại trường"), {
      target: { value: "Tiểu học" },
    });
    expect(screen.getByText("Trường Tiểu học Atlas")).toBeInTheDocument();
    expect(screen.getByText("Trường Tiểu học Gamma")).toBeInTheDocument();
    expect(screen.queryByText("Trường Trung học Beta")).not.toBeInTheDocument();
  });

  it("opens a local Review containing every dirty School, including a filtered-out row, with exact Before and After values", async () => {
    const connected = createApi();
    await renderReady(connected.api);
    fireEvent.change(studentInput(), { target: { value: "430" } });
    fireEvent.change(teacherInput(), { target: { value: "46" } });
    fireEvent.change(screen.getByLabelText("Loại trường"), {
      target: { value: "Trung học" },
    });

    const dialog = await openReview();
    expect(connected.updateSchoolDefaultsBulk).not.toHaveBeenCalled();
    expect(
      within(dialog).getByText("Trường Tiểu học Atlas"),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByText("Trường Trung học Beta"),
    ).toBeInTheDocument();
    expect(
      within(dialog).queryByText("Trường Tiểu học Gamma"),
    ).not.toBeInTheDocument();

    const atlasRow = within(dialog)
      .getByText("Trường Tiểu học Atlas")
      .closest("tr")!;
    expect(within(atlasRow).getByText("420")).toBeInTheDocument();
    expect(within(atlasRow).getByText("430")).toHaveClass("changed");
    expect(within(atlasRow).getAllByText("32")[1]).toHaveClass("unchanged");

    const betaRow = within(dialog)
      .getByText("Trường Trung học Beta")
      .closest("tr")!;
    expect(within(betaRow).getByText("45")).toBeInTheDocument();
    expect(within(betaRow).getByText("46")).toHaveClass("changed");
  });

  it("preserves edits on return and requires a fresh Review after a material edit", async () => {
    const connected = createApi();
    await renderReady(connected.api);
    fireEvent.change(studentInput(), { target: { value: "430" } });
    let dialog = await openReview();
    fireEvent.click(within(dialog).getByRole("button", { name: "Quay lại" }));

    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument(),
    );
    expect(studentInput()).toHaveValue(430);
    expect(connected.updateSchoolDefaultsBulk).not.toHaveBeenCalled();

    fireEvent.change(studentInput(), { target: { value: "431" } });
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    dialog = await openReview();
    expect(within(dialog).getByText("431")).toHaveClass("changed");
    expect(within(dialog).queryByText("430")).not.toBeInTheDocument();
  });

  it("saves the stable reviewed snapshot exactly once with only dirty Schools and reviewed versions", async () => {
    const readAfterWrite = [
      { ...schools[0]!, version: 4, default_student_portions: 430 },
      { ...schools[1]!, version: 8, default_teacher_portions: 46 },
      schools[2]!,
    ];
    const connected = createApi(undefined, readAfterWrite);
    await renderReady(connected.api);
    fireEvent.change(studentInput(), { target: { value: "430" } });
    fireEvent.change(teacherInput(), { target: { value: "46" } });

    const dialog = await openReview();
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce(),
    );
    const request = connected.updateSchoolDefaultsBulk.mock.calls[0]![0];
    expect(request).toMatchObject({
      contract_version: "RMVP-01.v2",
      requested_by_auth_subject: authSubject,
      reason_code: "SCHOOL_PORTION_DEFAULTS_BULK_UPDATE",
      payload: {
        changes: [
          {
            school_id: "school-1",
            expected_version: 3,
            default_student_portions: 430,
            default_teacher_portions: 32,
          },
          {
            school_id: "school-2",
            expected_version: 7,
            default_student_portions: 840,
            default_teacher_portions: 46,
          },
        ],
      },
    });
    expect(request.payload.changes).toHaveLength(2);
    expect(request).not.toHaveProperty("expected_version");
    expect(connected.getSchools).toHaveBeenCalledTimes(2);
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument(),
    );
    expect(await screen.findByText("Chưa có thay đổi")).toBeInTheDocument();
  });

  it("disables Review for blank, negative, fractional, and out-of-range values", async () => {
    const connected = createApi();
    await renderReady(connected.api);
    const input = studentInput();
    const review = screen.getByRole("button", { name: "Xem thay đổi" });

    for (const value of ["", "-1", "1.5", "2147483648"]) {
      fireEvent.change(input, { target: { value } });
      expect(input).toHaveAttribute("aria-invalid", "true");
      expect(review).toBeDisabled();
    }
    expect(connected.updateSchoolDefaultsBulk).not.toHaveBeenCalled();
  });

  it("discards all drafts and any prior Review snapshot", async () => {
    const connected = createApi();
    await renderReady(connected.api);
    fireEvent.change(studentInput(), { target: { value: "430" } });
    const dialog = await openReview();
    fireEvent.click(within(dialog).getByRole("button", { name: "Quay lại" }));
    fireEvent.click(screen.getByRole("button", { name: "Hủy thay đổi" }));

    expect(studentInput()).toHaveValue(420);
    expect(screen.getByText("Chưa có thay đổi")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument(),
    );
  });

  it("preserves edits and invalidates Review after a known atomic stale rejection", async () => {
    const connected = createApi({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_VERSION",
        safe_message: "Stale.",
      },
    });
    await renderReady(connected.api);
    fireEvent.change(studentInput(), { target: { value: "430" } });
    const dialog = await openReview();
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(
        "Một hoặc nhiều trường đã được người khác cập nhật. Không có trường nào được lưu; hãy tải lại và kiểm tra thay đổi.",
      ),
    ).toBeInTheDocument();
    expect(studentInput()).toHaveValue(430);
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument(),
    );
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeEnabled();
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
  });

  it("invalidates Review and locks mutation after an unknown outcome until authoritative refresh", async () => {
    const connected = createApi({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "Network failed.",
      },
    });
    await renderReady(connected.api);
    fireEvent.change(studentInput(), { target: { value: "430" } });
    const dialog = await openReview();
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(
        "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa. Hãy tải lại dữ liệu chính thức trước khi lưu tiếp.",
      ),
    ).toBeInTheDocument();
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
    expect(studentInput()).toBeDisabled();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument(),
    );

    fireEvent.click(
      screen.getByRole("button", { name: "Tải lại dữ liệu chính thức" }),
    );
    await waitFor(() => expect(connected.getSchools).toHaveBeenCalledTimes(2));
    expect(studentInput()).toBeEnabled();
    expect(studentInput()).toHaveValue(430);
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
  });

  it.each([1280, 650])(
    "keeps the Review modal bounded without horizontal overflow at %ipx",
    async (viewportWidth) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: viewportWidth,
      });
      const connected = createApi();
      await renderReady(connected.api);
      fireEvent.change(studentInput(), { target: { value: "430" } });
      const dialog = await openReview();
      const root = dialog.closest<HTMLElement>("[data-centered]");
      const body = dialog.querySelector<HTMLElement>(".mantine-Modal-body");

      expect(root?.style.getPropertyValue("--modal-size")).toBe(
        "calc(56.25rem * var(--mantine-scale))",
      );
      expect(dialog).toHaveStyle({ maxHeight: "86dvh", overflowX: "hidden" });
      expect(body).toHaveStyle({
        maxHeight: "calc(86dvh - 64px)",
        overflowX: "hidden",
      });
      expect(document.documentElement.scrollWidth).toBeLessThanOrEqual(
        viewportWidth,
      );
    },
  );

  it("clears authorized data on session loss", async () => {
    const connected = createApi();
    const rendered = render(
      <MantineProvider theme={atlasTheme} forceColorScheme="light">
        <SchoolAdminWorkbench authState={authState} api={connected.api} />
      </MantineProvider>,
    );
    expect(
      await screen.findByText("Trường Tiểu học Atlas"),
    ).toBeInTheDocument();
    rendered.rerender(
      <MantineProvider theme={atlasTheme} forceColorScheme="light">
        <SchoolAdminWorkbench
          authState={{ status: "unauthenticated" }}
          api={connected.api}
        />
      </MantineProvider>,
    );
    expect(
      screen.getByText(/Đăng nhập để xem và cập nhật/),
    ).toBeInTheDocument();
    expect(screen.queryByText("Trường Tiểu học Atlas")).not.toBeInTheDocument();
  });
});
