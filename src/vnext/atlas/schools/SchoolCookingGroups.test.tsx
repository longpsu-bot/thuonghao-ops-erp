import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { createRef } from "react";
import type { AtlasModuleExitHandle } from "../AtlasModuleExit";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type {
  AtlasRpcResult,
  SchoolMasterData,
} from "../bridges/schoolMasterData";
import { SchoolDefaultsWorkbench } from "./SchoolDefaultsWorkbench";
import { schoolDefaultsFixtureSchools } from "./schoolDefaultsReviewFixtures";

afterEach(cleanup);
const school = {
  ...schoolDefaultsFixtureSchools[0]!,
  cooking_group_id: null,
  cooking_group_name: null,
};
const groups = [
  {
    cooking_group_id: "group-x",
    cooking_group_name: "Bếp X",
    active: true,
    version: 3,
  },
  {
    cooking_group_id: "group-y",
    cooking_group_name: "Bếp Y",
    active: false,
    version: 2,
  },
];
const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};
function setup(
  write: AtlasRpcResult = success,
  rows: SchoolMasterData[] = [school],
) {
  const api = {
    getSchools: vi.fn().mockResolvedValue({
      kind: "success",
      response: { success: true, schools: rows },
    }),
    getCookingGroups: vi.fn().mockResolvedValue({
      kind: "success",
      response: { success: true, cooking_groups: groups },
    }),
    updateSchoolDefaultsBulk: vi.fn().mockResolvedValue(success),
    setSchoolCookingGroup: vi.fn().mockResolvedValue(write),
    upsertCookingGroup: vi.fn().mockResolvedValue(write),
  };
  const report = vi.fn();
  const exitRef = createRef<AtlasModuleExitHandle>();
  render(
    <AtlasVNextProvider>
      <SchoolDefaultsWorkbench
        api={api}
        authSubject="operator"
        onWorkspaceStatus={report}
        exitRef={exitRef}
      />
    </AtlasVNextProvider>,
  );
  return { api, report, exitRef };
}
async function selectGroup() {
  const select = await screen.findByLabelText(
    `Nấu tại — ${school.school_name}`,
  );
  fireEvent.change(select, { target: { value: "group-x" } });
  return select;
}
it("offers only active groups and saves one explicit assignment with the School version", async () => {
  const { api, report } = setup();
  const select = await selectGroup();
  expect(select).not.toHaveTextContent("Bếp Y");
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true }),
  );
  api.getSchools.mockResolvedValue({
    kind: "success",
    response: {
      success: true,
      schools: [
        {
          ...school,
          version: school.version + 1,
          cooking_group_id: "group-x",
          cooking_group_name: "Bếp X",
        },
      ],
    },
  });
  fireEvent.click(
    screen.getByRole("button", { name: `Lưu Nấu tại — ${school.school_name}` }),
  );
  await waitFor(() => expect(api.setSchoolCookingGroup).toHaveBeenCalledOnce());
  expect(api.setSchoolCookingGroup).toHaveBeenCalledWith(
    expect.objectContaining({
      expected_version: school.version,
      reason_code: "SCHOOL_COOKING_GROUP_SET",
      payload: { school_id: school.school_id, cooking_group_id: "group-x" },
    }),
  );
  expect(api.updateSchoolDefaultsBulk).not.toHaveBeenCalled();
  await waitFor(() =>
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    ),
  );
});
it("locks an uncertain assignment until authoritative readback, preserving its draft", async () => {
  const { api } = setup({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  });
  const select = await selectGroup();
  fireEvent.click(
    screen.getByRole("button", { name: `Lưu Nấu tại — ${school.school_name}` }),
  );
  expect(
    await screen.findByText(
      "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
    ),
  ).toBeInTheDocument();
  expect(select).toBeDisabled();
  fireEvent.click(screen.getByRole("button", { name: "Tải lại để xác nhận" }));
  await waitFor(() => expect(select).not.toBeDisabled());
  expect(select).toHaveValue("group-x");
  expect(api.setSchoolCookingGroup).toHaveBeenCalledOnce();
});
it("creates a group and permits explicit deactivation through the same editor", async () => {
  const { api, report } = setup();
  api.upsertCookingGroup.mockResolvedValue({
    kind: "success",
    response: {
      success: true,
      affected_aggregate_ids: { cooking_group_id: "group-created" },
    },
  });
  fireEvent.click(
    await screen.findByRole("button", { name: "Quản lý nhóm nấu" }),
  );
  fireEvent.change(screen.getByLabelText("Tên nhóm nấu"), {
    target: { value: "Bếp mới" },
  });
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true }),
  );
  api.getCookingGroups.mockResolvedValue({
    kind: "success",
    response: {
      success: true,
      cooking_groups: [
        ...groups,
        {
          cooking_group_id: "group-created",
          cooking_group_name: "Bếp mới",
          active: true,
          version: 1,
        },
      ],
    },
  });
  fireEvent.click(screen.getByRole("button", { name: "Lưu nhóm nấu" }));
  await waitFor(() =>
    expect(api.upsertCookingGroup).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 1,
        reason_code: "COOKING_GROUP_SAVED",
        payload: {
          cooking_group_id: null,
          cooking_group_name: "Bếp mới",
          active: true,
        },
      }),
    ),
  );
  await waitFor(() =>
    expect(screen.getByLabelText("Nhóm nấu")).not.toBeDisabled(),
  );
  fireEvent.change(screen.getByLabelText("Nhóm nấu"), {
    target: { value: "group-x" },
  });
  fireEvent.change(screen.getByLabelText("Trạng thái nhóm nấu"), {
    target: { value: "INACTIVE" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Lưu nhóm nấu" }));
  await waitFor(() =>
    expect(api.upsertCookingGroup).toHaveBeenLastCalledWith(
      expect.objectContaining({
        expected_version: 3,
        payload: {
          cooking_group_id: "group-x",
          cooking_group_name: "Bếp X",
          active: false,
        },
      }),
    ),
  );
});

it("never confirms uncertain creation using an existing same-name group and replays only the exact command", async () => {
  const unknown: AtlasRpcResult = {
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  };
  const { api, report } = setup(unknown);
  fireEvent.click(
    await screen.findByRole("button", { name: "Quản lý nhóm nấu" }),
  );
  fireEvent.change(screen.getByLabelText("Tên nhóm nấu"), {
    target: { value: "Bếp X" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Lưu nhóm nấu" }));
  await screen.findByText(
    "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
  );
  const request = api.upsertCookingGroup.mock.calls[0]![0];
  fireEvent.click(
    screen.getByRole("button", { name: "Xác nhận lần lưu nhóm nấu" }),
  );
  await waitFor(() => expect(api.upsertCookingGroup).toHaveBeenCalledTimes(2));
  expect(api.upsertCookingGroup.mock.calls[1]![0]).toBe(request);
  expect(screen.getByLabelText("Tên nhóm nấu")).toHaveValue("Bếp X");
  expect(screen.getByLabelText("Tên nhóm nấu")).toBeDisabled();
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true, blocked: true }),
  );
  api.upsertCookingGroup.mockResolvedValue({
    kind: "success",
    response: {
      success: true,
      affected_aggregate_ids: { cooking_group_id: "group-created" },
    },
  });
  fireEvent.click(
    screen.getByRole("button", { name: "Xác nhận lần lưu nhóm nấu" }),
  );
  await screen.findByText(
    "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
  );
  expect(screen.getByLabelText("Tên nhóm nấu")).toHaveValue("Bếp X");
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true, blocked: true }),
  );
  api.getCookingGroups.mockResolvedValue({
    kind: "success",
    response: {
      success: true,
      cooking_groups: [
        ...groups,
        { ...groups[0]!, cooking_group_id: "group-created" },
      ],
    },
  });
  fireEvent.click(screen.getByRole("button", { name: "Tải lại để xác nhận" }));
  await waitFor(() =>
    expect(screen.getByLabelText("Tên nhóm nấu")).toHaveValue(""),
  );
  expect(api.upsertCookingGroup).toHaveBeenCalledTimes(3);
  expect(api.upsertCookingGroup.mock.calls[2]![0]).toBe(request);
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: false, blocked: false }),
  );
});
it("retains assignment edits when the backend denies authority", async () => {
  const { api } = setup({
    kind: "backend_error",
    error: {
      success: false,
      error_code: "CAPABILITY_DENIED",
      safe_message: "denied",
    },
  });
  const select = await selectGroup();
  fireEvent.click(
    screen.getByRole("button", { name: `Lưu Nấu tại — ${school.school_name}` }),
  );
  expect(
    await screen.findByText("Bạn không có quyền thực hiện thao tác này."),
  ).toBeInTheDocument();
  expect(select).toHaveValue("group-x");
  expect(api.getSchools).toHaveBeenCalledOnce();
});

it("removes a current group through an explicit nullable assignment command", async () => {
  const { api } = setup(success, [
    { ...school, cooking_group_id: "group-x", cooking_group_name: "Bếp X" },
  ]);
  const select = await screen.findByLabelText(
    `Nấu tại — ${school.school_name}`,
  );
  expect(select).toHaveValue("group-x");
  fireEvent.change(select, { target: { value: "" } });
  fireEvent.click(
    screen.getByRole("button", { name: `Lưu Nấu tại — ${school.school_name}` }),
  );
  await waitFor(() =>
    expect(api.setSchoolCookingGroup).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: school.version,
        payload: { school_id: school.school_id, cooking_group_id: null },
      }),
    ),
  );
});

it("locks a successful command if group authority cannot be read back", async () => {
  const { api } = setup();
  const select = await selectGroup();
  api.getCookingGroups.mockResolvedValue({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  });
  fireEvent.click(
    screen.getByRole("button", { name: `Lưu Nấu tại — ${school.school_name}` }),
  );
  expect(
    await screen.findByText(
      "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
    ),
  ).toBeInTheDocument();
  expect(select).toBeDisabled();
  expect(api.setSchoolCookingGroup).toHaveBeenCalledOnce();
});

it("keeps group drafts and School assignment drafts behind the existing dirty exit guard", async () => {
  const { exitRef, report } = setup();
  await selectGroup();
  fireEvent.click(screen.getByRole("button", { name: "Quản lý nhóm nấu" }));
  fireEvent.change(screen.getByLabelText("Tên nhóm nấu"), {
    target: { value: "Chưa lưu" },
  });
  const next = vi.fn();
  act(() => exitRef.current!.requestExit(next));
  expect(next).not.toHaveBeenCalled();
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  expect(next).toHaveBeenCalledOnce();
  expect(screen.getByLabelText("Tên nhóm nấu")).toHaveValue("");
  await waitFor(() =>
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    ),
  );
});

it("preserves a rejected deactivation and explains the current membership blocker", async () => {
  const { api } = setup({
    kind: "backend_error",
    error: {
      success: false,
      error_code: "COOKING_GROUP_HAS_MEMBERS",
      safe_message: "blocked",
    },
  });
  await selectGroup();
  fireEvent.click(screen.getByRole("button", { name: "Quản lý nhóm nấu" }));
  fireEvent.change(screen.getByLabelText("Nhóm nấu"), {
    target: { value: "group-x" },
  });
  fireEvent.change(screen.getByLabelText("Trạng thái nhóm nấu"), {
    target: { value: "INACTIVE" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Lưu nhóm nấu" }));
  expect(
    await screen.findByText(
      "Nhóm nấu vẫn còn trường được gán. Hãy bỏ hoặc đổi nhóm của các trường trước khi ngừng hoạt động.",
    ),
  ).toBeInTheDocument();
  expect(screen.getByLabelText("Trạng thái nhóm nấu")).toHaveValue("INACTIVE");
  expect(api.getCookingGroups).toHaveBeenCalledOnce();
});
