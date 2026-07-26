import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import type { Session } from "@supabase/supabase-js";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { MasterDataApi } from "../atlas/master-data/masterDataApi";
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

const school = {
  school_id: "school-1",
  school_code: "atlas-primary",
  school_name: "Trường Tiểu học Atlas",
  school_status: "ACTIVE",
  version: 1,
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
};

function success(extra: Record<string, unknown>) {
  return {
    kind: "success",
    response: { success: true, ...extra },
  } as const;
}

function api() {
  return {
    getSchools: vi
      .fn()
      .mockResolvedValueOnce(success({ schools: [school] }))
      .mockResolvedValue(
        success({
          schools: [
            {
              ...school,
              version: 2,
              default_student_portions: 430,
              default_teacher_portions: 35,
            },
          ],
        }),
      ),
    updateSchoolDefaults: vi.fn().mockResolvedValue(
      success({
        safe_operator_message: "School portion defaults saved.",
      }),
    ),
  } as unknown as MasterDataApi;
}

describe("connected School master data", () => {
  it("loads, searches, validates, commands, and reads authoritative values back", async () => {
    const connectedApi = api();
    render(<SchoolAdminWorkbench authState={authState} api={connectedApi} />);

    expect(
      screen.getByText("Đang tải dữ liệu trường học…"),
    ).toBeInTheDocument();
    expect(
      await screen.findByText("Trường Tiểu học Atlas"),
    ).toBeInTheDocument();
    expect(screen.getByText("Hợp đồng 2026–2027")).toBeInTheDocument();
    expect(screen.getByText("01 Đường Atlas")).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "không có" },
    });
    expect(
      screen.getByText("Không có trường phù hợp bộ lọc."),
    ).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "atlas" },
    });

    fireEvent.click(screen.getByRole("button", { name: "Sửa số suất" }));
    fireEvent.change(screen.getByLabelText("Suất học sinh mặc định"), {
      target: { value: "-1" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu và đọc lại" }));
    expect(
      screen.getByText("Số suất mặc định phải là số nguyên không âm."),
    ).toBeInTheDocument();
    expect(connectedApi.updateSchoolDefaults).not.toHaveBeenCalled();

    fireEvent.change(screen.getByLabelText("Suất học sinh mặc định"), {
      target: { value: "430" },
    });
    fireEvent.change(screen.getByLabelText("Suất giáo viên mặc định"), {
      target: { value: "35" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu và đọc lại" }));

    await waitFor(() =>
      expect(connectedApi.updateSchoolDefaults).toHaveBeenCalledOnce(),
    );
    expect(connectedApi.updateSchoolDefaults).toHaveBeenCalledWith(
      expect.objectContaining({
        contract_version: "RMVP-01.v1",
        expected_version: 1,
        requested_by_auth_subject: authSubject,
        payload: {
          school_id: "school-1",
          default_student_portions: 430,
          default_teacher_portions: 35,
        },
      }),
    );
    await waitFor(() =>
      expect(connectedApi.getSchools).toHaveBeenCalledTimes(2),
    );
    expect(await screen.findByText("430 / 35")).toBeInTheDocument();
  });

  it("clears authorized data on session loss", async () => {
    const connectedApi = api();
    const rendered = render(
      <SchoolAdminWorkbench authState={authState} api={connectedApi} />,
    );
    expect(
      await screen.findByText("Trường Tiểu học Atlas"),
    ).toBeInTheDocument();
    rendered.rerender(
      <SchoolAdminWorkbench
        authState={{ status: "unauthenticated" }}
        api={connectedApi}
      />,
    );
    expect(
      screen.getByText(/Đăng nhập để xem và cập nhật/),
    ).toBeInTheDocument();
    expect(screen.queryByText("Trường Tiểu học Atlas")).not.toBeInTheDocument();
  });
});
