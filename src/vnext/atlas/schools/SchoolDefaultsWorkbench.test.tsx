import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type {
  AtlasRpcResult,
  MasterDataBulkCommandRequest,
  SchoolMasterData,
  SchoolMasterDataApi,
} from "../bridges/schoolMasterData";
import { SchoolDefaultsWorkbench } from "./SchoolDefaultsWorkbench";

afterEach(cleanup);

const schools: SchoolMasterData[] = [
  {
    school_id: "school-2",
    school_code: "TH002",
    school_name: "Trường Trung học Beta",
    school_status: "ACTIVE",
    version: 7,
    display_order: 2,
    default_student_portions: 840,
    default_teacher_portions: 45,
    school_type_id: "secondary",
    school_type_name: "Trung học",
    customer_id: "customer-2",
    customer_code: "KH02",
    customer_name: "Cụm trường Beta",
    delivery_location_id: "location-2",
    delivery_location_name: "Kho thực phẩm",
    delivery_address: "02 Đường Bế Văn Đàn",
    delivery_instructions: null,
    contract_context: null,
  },
  {
    school_id: "school-1",
    school_code: "TH001",
    school_name: "Trường Tiểu học Ánh Dương",
    school_status: "INACTIVE",
    version: 3,
    display_order: 1,
    default_student_portions: 420,
    default_teacher_portions: 32,
    school_type_id: "primary",
    school_type_name: "Tiểu học",
    customer_id: "customer-1",
    customer_code: "KH01",
    customer_name: "Cụm trường Ánh Dương",
    delivery_location_id: "location-1",
    delivery_location_name: "Cổng giao chính",
    delivery_address: "01 Đường Nguyễn Trãi",
    delivery_instructions: "Trước 05:30",
    contract_context: "Hợp đồng 2026–2027",
  },
];

function success(rows = schools): AtlasRpcResult {
  return { kind: "success", response: { success: true, schools: rows } };
}

function apiWith({
  reads = [success()],
  write = { kind: "success", response: { success: true } },
}: {
  reads?: AtlasRpcResult[];
  write?: AtlasRpcResult;
} = {}) {
  const getSchools = vi.fn();
  for (const result of reads) getSchools.mockResolvedValueOnce(result);
  getSchools.mockResolvedValue(reads.at(-1) ?? success());
  const updateSchoolDefaultsBulk = vi
    .fn<(request: MasterDataBulkCommandRequest) => Promise<AtlasRpcResult>>()
    .mockResolvedValue(write as AtlasRpcResult);
  return {
    api: { getSchools, updateSchoolDefaultsBulk } satisfies SchoolMasterDataApi,
    getSchools,
    updateSchoolDefaultsBulk,
  };
}

async function renderReady(
  api: SchoolMasterDataApi,
  authSubject = "operator-1",
) {
  render(
    <AtlasVNextProvider>
      <SchoolDefaultsWorkbench authSubject={authSubject} api={api} />
    </AtlasVNextProvider>,
  );
  expect(
    await screen.findByText("Trường Tiểu học Ánh Dương"),
  ).toBeInTheDocument();
}

const student = (name = "Trường Tiểu học Ánh Dương") =>
  screen.getByLabelText(`Học sinh mặc định — ${name}`);
const teacher = (name = "Trường Trung học Beta") =>
  screen.getByLabelText(`Giáo viên mặc định — ${name}`);

describe("Chakra School default portions workbench", () => {
  it("reads once, orders operationally, searches accents and filters School Type locally", async () => {
    const connected = apiWith();
    await renderReady(connected.api);

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Sĩ số mặc định",
    );
    const table = screen.getByRole("table", {
      name: "Sĩ số mặc định theo trường",
    });
    const rows = within(table).getAllByRole("row").slice(1);
    expect(rows[0]).toHaveTextContent("Trường Tiểu học Ánh Dương");
    expect(rows[0]).toHaveTextContent("Ngừng hoạt động");
    expect(screen.queryByText("school-1")).not.toBeInTheDocument();
    expect(screen.queryByText("customer-1")).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "be van dan" },
    });
    expect(screen.getByText("Trường Trung học Beta")).toBeInTheDocument();
    expect(
      screen.queryByText("Trường Tiểu học Ánh Dương"),
    ).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "" },
    });
    fireEvent.change(screen.getByLabelText("Loại trường"), {
      target: { value: "Tiểu học" },
    });
    expect(screen.getByText("Trường Tiểu học Ánh Dương")).toBeInTheDocument();
    expect(screen.queryByText("Trường Trung học Beta")).not.toBeInTheDocument();
    expect(connected.getSchools).toHaveBeenCalledOnce();
  });

  it("accepts explicit zero but rejects every invalid contract form without coercion", async () => {
    const connected = apiWith();
    await renderReady(connected.api);
    const input = student();
    const review = screen.getByRole("button", { name: "Xem thay đổi" });

    fireEvent.change(input, { target: { value: "0" } });
    expect(input).toHaveAttribute("aria-invalid", "false");
    expect(review).toBeEnabled();

    for (const value of [
      "",
      "-1",
      "1.5",
      "1e3",
      "abc",
      "2147483648",
      "9007199254740992",
    ]) {
      fireEvent.change(input, { target: { value } });
      expect(input).toHaveAttribute("aria-invalid", "true");
      expect(review).toBeDisabled();
      expect(
        screen.getByText("1 trường có dữ liệu chưa hợp lệ"),
      ).toBeInTheDocument();
    }
    expect(connected.updateSchoolDefaultsBulk).not.toHaveBeenCalled();

    fireEvent.change(input, { target: { value: "420" } });
    expect(screen.getByText(/0 thay đổi chưa lưu/)).toBeInTheDocument();
  });

  it("keeps hidden dirty Schools and includes all of them in attached Review", async () => {
    const connected = apiWith();
    await renderReady(connected.api);
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.change(teacher(), { target: { value: "46" } });
    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "beta" },
    });
    expect(screen.getByText(/1 thay đổi ngoài bộ lọc/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("complementary", {
      name: "Thay đổi sĩ số mặc định",
    });
    expect(
      within(review).getByText("Trường Tiểu học Ánh Dương"),
    ).toBeInTheDocument();
    expect(
      within(review).getByText("Trường Trung học Beta"),
    ).toBeInTheDocument();
    expect(within(review).getByText("Học sinh: 420 → 421")).toBeInTheDocument();
    expect(within(review).getByText("Giáo viên: 45 → 46")).toBeInTheDocument();
    const comparisonTable = within(review).getByRole("table", {
      name: "So sánh thay đổi sĩ số mặc định",
    });
    expect(comparisonTable).toHaveStyle({ tableLayout: "fixed" });
    expect(
      screen.getByLabelText("Học sinh mặc định — Trường Trung học Beta"),
    ).toBeDisabled();
    expect(teacher()).toBeDisabled();
    expect(
      screen.queryByText(/expected_version|version|school-1/),
    ).not.toBeInTheDocument();

    fireEvent.click(within(review).getByRole("button", { name: "Đóng" }));
    expect(await screen.findByDisplayValue("46")).toBeEnabled();
  });

  it("sends one exact bulk command from the frozen Review and clears only proven drafts after readback", async () => {
    const readback = [
      { ...schools[0], version: 8, default_teacher_portions: 46 },
      { ...schools[1], version: 4, default_student_portions: 421 },
    ];
    const connected = apiWith({ reads: [success(), success(readback)] });
    await renderReady(connected.api);
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.change(teacher(), { target: { value: "46" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("complementary", {
      name: "Thay đổi sĩ số mặc định",
    });
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu thay đổi" }),
    );

    await waitFor(() =>
      expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce(),
    );
    expect(connected.updateSchoolDefaultsBulk.mock.calls[0]?.[0]).toMatchObject(
      {
        contract_version: "RMVP-01.v2",
        requested_by_auth_subject: "operator-1",
        payload: {
          changes: [
            {
              school_id: "school-1",
              expected_version: 3,
              default_student_portions: 421,
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
      },
    );
    await waitFor(() => expect(connected.getSchools).toHaveBeenCalledTimes(2));
    expect(
      await screen.findByText("Đã cập nhật 2 trường."),
    ).toBeInTheDocument();
    expect(screen.getByText(/0 thay đổi chưa lưu/)).toBeInTheDocument();
  });

  it("keeps editing locked until successful Save readback establishes current authority", async () => {
    let resolveReadback!: (value: AtlasRpcResult) => void;
    const getSchools = vi
      .fn()
      .mockResolvedValueOnce(success())
      .mockImplementationOnce(
        () =>
          new Promise<AtlasRpcResult>((resolve) => {
            resolveReadback = resolve;
          }),
      );
    const api = {
      getSchools,
      updateSchoolDefaultsBulk: vi.fn().mockResolvedValue({
        kind: "success",
        response: { success: true },
      }),
    } as unknown as SchoolMasterDataApi;
    await renderReady(api);
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(
      within(
        await screen.findByRole("complementary", {
          name: "Thay đổi sĩ số mặc định",
        }),
      ).getByRole("button", { name: "Lưu thay đổi" }),
    );
    await waitFor(() => expect(getSchools).toHaveBeenCalledTimes(2));
    expect(student()).toBeDisabled();

    resolveReadback(
      success([
        { ...schools[0] },
        { ...schools[1], default_student_portions: 421 },
      ]),
    );
    await waitFor(() => expect(student()).toBeEnabled());
  });

  it("refreshes authority without discarding valid or invalid drafts and reviews the refreshed version", async () => {
    const refreshed = [
      schools[0],
      { ...schools[1], version: 9, default_teacher_portions: 33 },
    ];
    const connected = apiWith({ reads: [success(), success(refreshed)] });
    await renderReady(connected.api);
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.change(teacher("Trường Tiểu học Ánh Dương"), {
      target: { value: "" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));

    expect(
      await screen.findByText(
        "Đã tải lại dữ liệu chính thức. Kiểm tra các thay đổi chưa lưu trước khi lưu.",
      ),
    ).toBeInTheDocument();
    expect(student()).toHaveValue("421");
    expect(teacher("Trường Tiểu học Ánh Dương")).toHaveValue("");
    fireEvent.change(teacher("Trường Tiểu học Ánh Dương"), {
      target: { value: "34" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("complementary", {
      name: "Thay đổi sĩ số mặc định",
    });
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu thay đổi" }),
    );
    await waitFor(() =>
      expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce(),
    );
    expect(
      connected.updateSchoolDefaultsBulk.mock.calls[0]?.[0].payload.changes[0],
    ).toMatchObject({ expected_version: 9, default_teacher_portions: 34 });
  });

  it("drops drafts that match refreshed authority and removes orphan School drafts", async () => {
    const connected = apiWith({
      reads: [
        success(),
        success([{ ...schools[1], version: 4, default_student_portions: 421 }]),
      ],
    });
    await renderReady(connected.api);
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.change(teacher(), { target: { value: "46" } });
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() => expect(connected.getSchools).toHaveBeenCalledTimes(2));
    expect(screen.getByText(/0 thay đổi chưa lưu/)).toBeInTheDocument();
    expect(screen.queryByText("Trường Trung học Beta")).not.toBeInTheDocument();
  });

  it("ignores a delayed read from the previous authentication subject and clears its drafts", async () => {
    let resolveOld!: (value: AtlasRpcResult) => void;
    const oldRead = new Promise<AtlasRpcResult>((resolve) => {
      resolveOld = resolve;
    });
    const newSchool = {
      ...schools[0],
      school_id: "school-new",
      school_name: "Trường của phiên mới",
    };
    const getSchools = vi
      .fn()
      .mockImplementationOnce(() => oldRead)
      .mockResolvedValue(success([newSchool]));
    const api = {
      getSchools,
      updateSchoolDefaultsBulk: vi.fn(),
    } as unknown as SchoolMasterDataApi;
    const rendered = render(
      <AtlasVNextProvider>
        <SchoolDefaultsWorkbench authSubject="operator-old" api={api} />
      </AtlasVNextProvider>,
    );
    rendered.rerender(
      <AtlasVNextProvider>
        <SchoolDefaultsWorkbench authSubject="operator-new" api={api} />
      </AtlasVNextProvider>,
    );
    expect(await screen.findByText("Trường của phiên mới")).toBeInTheDocument();
    resolveOld(success(schools));
    await Promise.resolve();
    expect(
      screen.queryByText("Trường Tiểu học Ánh Dương"),
    ).not.toBeInTheDocument();
  });

  it("ignores a delayed Save outcome from the previous authentication subject", async () => {
    let resolveOldWrite!: (value: AtlasRpcResult) => void;
    const oldWrite = new Promise<AtlasRpcResult>((resolve) => {
      resolveOldWrite = resolve;
    });
    const newSchool = {
      ...schools[0],
      school_id: "school-new",
      school_name: "Trường của phiên mới",
    };
    const api = {
      getSchools: vi
        .fn()
        .mockResolvedValueOnce(success())
        .mockResolvedValueOnce(success([newSchool])),
      updateSchoolDefaultsBulk: vi.fn().mockReturnValue(oldWrite),
    } as unknown as SchoolMasterDataApi;
    const rendered = render(
      <AtlasVNextProvider>
        <SchoolDefaultsWorkbench authSubject="operator-old" api={api} />
      </AtlasVNextProvider>,
    );
    expect(
      await screen.findByText("Trường Tiểu học Ánh Dương"),
    ).toBeInTheDocument();
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(
      within(
        await screen.findByRole("complementary", {
          name: "Thay đổi sĩ số mặc định",
        }),
      ).getByRole("button", { name: "Lưu thay đổi" }),
    );

    rendered.rerender(
      <AtlasVNextProvider>
        <SchoolDefaultsWorkbench authSubject="operator-new" api={api} />
      </AtlasVNextProvider>,
    );
    expect(await screen.findByText("Trường của phiên mới")).toBeInTheDocument();
    resolveOldWrite({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Offline." },
    });
    await Promise.resolve();
    expect(
      screen.queryByText(
        "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
      ),
    ).not.toBeInTheDocument();
    expect(
      screen.getByLabelText("Học sinh mặc định — Trường của phiên mới"),
    ).toBeEnabled();
  });

  it("recovers an ordinary read failure without using uncertain-write copy", async () => {
    const connected = apiWith({
      reads: [
        {
          kind: "transport_error",
          diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Offline." },
        },
        success(),
      ],
    });
    render(
      <AtlasVNextProvider>
        <SchoolDefaultsWorkbench authSubject="operator-1" api={connected.api} />
      </AtlasVNextProvider>,
    );
    const retry = await screen.findByRole("button", {
      name: "Thử tải lại dữ liệu",
    });
    expect(screen.queryByText("Tải lại để xác nhận")).not.toBeInTheDocument();
    fireEvent.click(retry);
    expect(
      await screen.findByText("Trường Tiểu học Ánh Dương"),
    ).toBeInTheDocument();
  });

  it.each([
    [
      "stale",
      {
        kind: "backend_error",
        error: {
          success: false,
          error_code: "STALE_VERSION",
          safe_message: "Stale.",
        },
      } as AtlasRpcResult,
      "Một hoặc nhiều trường đã được cập nhật. Không có trường nào được lưu; hãy tải lại và kiểm tra thay đổi.",
      "Tải lại dữ liệu hiện tại",
    ],
    [
      "unknown",
      {
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Offline." },
      } as AtlasRpcResult,
      "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
      "Tải lại để xác nhận",
    ],
  ])(
    "locks a %s result until an authoritative read and never resends",
    async (_kind, write, message, recoveryLabel) => {
      const connected = apiWith({ reads: [success(), success()], write });
      await renderReady(connected.api);
      fireEvent.change(student(), { target: { value: "421" } });
      fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
      const review = await screen.findByRole("complementary", {
        name: "Thay đổi sĩ số mặc định",
      });
      fireEvent.click(
        within(review).getByRole("button", { name: "Lưu thay đổi" }),
      );
      expect(await screen.findByText(message)).toBeInTheDocument();
      expect(
        screen.getByRole("button", { name: "Xem thay đổi" }),
      ).toBeDisabled();
      expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();

      fireEvent.click(screen.getByRole("button", { name: recoveryLabel }));
      await waitFor(() =>
        expect(connected.getSchools).toHaveBeenCalledTimes(2),
      );
      expect(
        await screen.findByText(
          "Đã tải lại dữ liệu chính thức. Kiểm tra các thay đổi chưa lưu trước khi lưu.",
        ),
      ).toBeInTheDocument();
      expect(screen.queryByText(message)).not.toBeInTheDocument();
      expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
      expect(student()).toHaveValue("421");
      expect(
        screen.getByRole("button", { name: "Xem thay đổi" }),
      ).toBeEnabled();
    },
  );

  it("locks after success when authoritative readback fails", async () => {
    const connected = apiWith({
      reads: [
        success(),
        {
          kind: "transport_error",
          diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Offline." },
        },
        success(),
      ],
    });
    await renderReady(connected.api);
    fireEvent.change(student(), { target: { value: "421" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(
      within(
        await screen.findByRole("complementary", {
          name: "Thay đổi sĩ số mặc định",
        }),
      ).getByRole("button", { name: "Lưu thay đổi" }),
    );
    expect(
      await screen.findByText(
        "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Tải lại để xác nhận" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
  });

  it("preserves drafts after a definite permission failure and serializes zero only when explicitly typed", async () => {
    const denied: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "CAPABILITY_DENIED",
        safe_message: "Denied.",
      },
    };
    const connected = apiWith({ write: denied });
    await renderReady(connected.api);
    fireEvent.change(student(), { target: { value: "0" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(
      within(
        await screen.findByRole("complementary", {
          name: "Thay đổi sĩ số mặc định",
        }),
      ).getByRole("button", { name: "Lưu thay đổi" }),
    );
    expect(
      await screen.findByText("Bạn không có quyền thực hiện thao tác này."),
    ).toBeInTheDocument();
    expect(student()).toHaveValue("0");
    expect(
      connected.updateSchoolDefaultsBulk.mock.calls[0]?.[0].payload.changes[0]
        ?.default_student_portions,
    ).toBe(0);
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
  });
});
