import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type {
  MasterDataApi,
  MasterDataBulkCommandRequest,
} from "../atlas/master-data/masterDataApi";
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
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
  render(<SchoolAdminWorkbench authState={authState} api={api} />);
  expect(await screen.findByText("Trường Tiểu học Atlas")).toBeInTheDocument();
}

describe("bulk School default portions", () => {
  it("presents directly editable cells without a row detail action and keeps search and School Type filtering", async () => {
    const connected = createApi();
    await renderReady(connected.api);

    expect(
      screen.getByLabelText("Học sinh mặc định — Trường Tiểu học Atlas"),
    ).toHaveValue(420);
    expect(
      screen.getByLabelText("Giáo viên mặc định — Trường Trung học Beta"),
    ).toHaveValue(45);
    expect(
      screen.queryByRole("button", { name: "Xem và sửa" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();

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

  it("retains a multi-School changeset across filters and sends one atomic v2 command with only dirty rows", async () => {
    const readAfterWrite = [
      { ...schools[0]!, version: 4, default_student_portions: 430 },
      { ...schools[1]!, version: 8, default_teacher_portions: 46 },
      schools[2]!,
    ];
    const connected = createApi(undefined, readAfterWrite);
    await renderReady(connected.api);

    fireEvent.change(
      screen.getByLabelText("Học sinh mặc định — Trường Tiểu học Atlas"),
      { target: { value: "430" } },
    );
    fireEvent.change(
      screen.getByLabelText("Giáo viên mặc định — Trường Trung học Beta"),
      { target: { value: "46" } },
    );
    expect(screen.getByText("2 trường đã thay đổi")).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Loại trường"), {
      target: { value: "Trung học" },
    });
    expect(screen.queryByText("Trường Tiểu học Atlas")).not.toBeInTheDocument();
    expect(screen.getByText("2 trường đã thay đổi")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
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
    expect(request).not.toHaveProperty("expected_version");
    expect(connected.getSchools).toHaveBeenCalledTimes(2);
    expect(await screen.findByText("Chưa có thay đổi")).toBeInTheDocument();
    expect(
      screen.getByText("Đã cập nhật 2 trường và tải lại dữ liệu chính thức."),
    ).toBeInTheDocument();
  });

  it("visibly blocks Save for blank, negative, or non-integer values", async () => {
    const connected = createApi();
    await renderReady(connected.api);
    const input = screen.getByLabelText(
      "Học sinh mặc định — Trường Tiểu học Atlas",
    );
    const save = screen.getByRole("button", { name: "Lưu" });

    fireEvent.change(input, { target: { value: "" } });
    expect(input).toHaveAttribute("aria-invalid", "true");
    expect(save).toBeDisabled();

    fireEvent.change(input, { target: { value: "-1" } });
    expect(input).toHaveAttribute("aria-invalid", "true");
    expect(save).toBeDisabled();

    fireEvent.change(input, { target: { value: "1.5" } });
    expect(input).toHaveAttribute("aria-invalid", "true");
    expect(save).toBeDisabled();
    expect(connected.updateSchoolDefaultsBulk).not.toHaveBeenCalled();
  });

  it("discards every local change back to the authoritative values", async () => {
    const connected = createApi();
    await renderReady(connected.api);
    const student = screen.getByLabelText(
      "Học sinh mặc định — Trường Tiểu học Atlas",
    );
    const teacher = screen.getByLabelText(
      "Giáo viên mặc định — Trường Trung học Beta",
    );

    fireEvent.change(student, { target: { value: "430" } });
    fireEvent.change(teacher, { target: { value: "46" } });
    fireEvent.click(screen.getByRole("button", { name: "Hủy thay đổi" }));

    expect(student).toHaveValue(420);
    expect(teacher).toHaveValue(45);
    expect(screen.getByText("Chưa có thay đổi")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
  });

  it("keeps local edits after a known atomic stale rejection and offers reload/review", async () => {
    const connected = createApi({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_VERSION",
        safe_message: "Stale.",
      },
    });
    await renderReady(connected.api);
    const input = screen.getByLabelText(
      "Học sinh mặc định — Trường Tiểu học Atlas",
    );

    fireEvent.change(input, { target: { value: "430" } });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(
        "Một hoặc nhiều trường đã được người khác cập nhật. Không có trường nào được lưu; hãy tải lại và kiểm tra thay đổi.",
      ),
    ).toBeInTheDocument();
    expect(input).toHaveValue(430);
    expect(screen.getByText("1 trường đã thay đổi")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tải lại" })).toBeEnabled();
  });

  it("locks further mutation after an unknown outcome until an authoritative refresh", async () => {
    const connected = createApi({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "Network failed.",
      },
    });
    await renderReady(connected.api);
    const input = screen.getByLabelText(
      "Học sinh mặc định — Trường Tiểu học Atlas",
    );

    fireEvent.change(input, { target: { value: "430" } });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(
        "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa. Hãy tải lại dữ liệu chính thức trước khi lưu tiếp.",
      ),
    ).toBeInTheDocument();
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
    expect(input).toBeDisabled();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Tải lại dữ liệu chính thức" }),
    );
    await waitFor(() => expect(connected.getSchools).toHaveBeenCalledTimes(2));
    expect(input).toBeEnabled();
    expect(input).toHaveValue(430);
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();
    expect(connected.updateSchoolDefaultsBulk).toHaveBeenCalledOnce();
  });

  it("clears authorized data on session loss", async () => {
    const connected = createApi();
    const rendered = render(
      <SchoolAdminWorkbench authState={authState} api={connected.api} />,
    );
    expect(
      await screen.findByText("Trường Tiểu học Atlas"),
    ).toBeInTheDocument();
    rendered.rerender(
      <SchoolAdminWorkbench
        authState={{ status: "unauthenticated" }}
        api={connected.api}
      />,
    );
    expect(
      screen.getByText(/Đăng nhập để xem và cập nhật/),
    ).toBeInTheDocument();
    expect(screen.queryByText("Trường Tiểu học Atlas")).not.toBeInTheDocument();
  });
});
