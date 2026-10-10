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
  dispatch_group_id: null,
  dispatch_group_name: null,
};
const groups = [
  {
    cooking_group_id: "group-x",
    cooking_group_name: "Bếp X",
    active: true,
    location_kind: "SCHOOL",
    host_school_id: school.school_id,
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
    getDispatchGroups: vi.fn().mockResolvedValue({
      kind: "success",
      response: {
        success: true,
        dispatch_groups: [
          {
            dispatch_group_id: "dispatch-x",
            dispatch_group_name: "Dispatch X",
            active: true,
            version: 4,
          },
        ],
      },
    }),
    upsertDispatchGroup: vi.fn().mockResolvedValue(write),
    setSchoolDispatchGroup: vi.fn().mockResolvedValue(write),
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

it("saves cooking and Dispatch independently and uses each authoritative School version", async () => {
  const { api, report } = setup();
  const cooking = await screen.findByLabelText(
    `Nấu tại — ${school.school_name}`,
  );
  const dispatch = screen.getByLabelText(
    `Nhóm Dispatch — ${school.school_name}`,
  );
  fireEvent.change(cooking, { target: { value: "group-x" } });
  fireEvent.change(dispatch, { target: { value: "dispatch-x" } });
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
  fireEvent.click(screen.getByLabelText(`Lưu Nấu tại — ${school.school_name}`));
  await waitFor(() => expect(api.getSchools).toHaveBeenCalledTimes(2));
  await waitFor(() => expect(dispatch).not.toBeDisabled());
  expect(api.setSchoolDispatchGroup).not.toHaveBeenCalled();
  expect(dispatch).toHaveValue("dispatch-x");
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
          version: school.version + 2,
          cooking_group_id: "group-x",
          cooking_group_name: "Bếp X",
          dispatch_group_id: "dispatch-x",
          dispatch_group_name: "Dispatch X",
        },
      ],
    },
  });
  fireEvent.click(
    screen.getByLabelText(`Lưu Nhóm Dispatch — ${school.school_name}`),
  );
  await waitFor(() =>
    expect(api.setSchoolDispatchGroup).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: school.version + 1,
        reason_code: "SCHOOL_DISPATCH_GROUP_SET",
        payload: {
          school_id: school.school_id,
          dispatch_group_id: "dispatch-x",
        },
      }),
    ),
  );
  await waitFor(() =>
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    ),
  );
  expect(cooking).toHaveValue("group-x");
  expect(api.setSchoolCookingGroup).toHaveBeenCalledOnce();
  expect(api.updateSchoolDefaultsBulk).not.toHaveBeenCalled();
});
it("preserves uncertain Dispatch assignments and cooking drafts until readback", async () => {
  const { api } = setup({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  });
  const dispatch = await screen.findByLabelText(
    `Nhóm Dispatch — ${school.school_name}`,
  );
  const cooking = screen.getByLabelText(`Nấu tại — ${school.school_name}`);
  fireEvent.change(dispatch, { target: { value: "dispatch-x" } });
  fireEvent.change(cooking, { target: { value: "group-x" } });
  fireEvent.click(
    screen.getByLabelText(`Lưu Nhóm Dispatch — ${school.school_name}`),
  );
  await screen.findByText(
    "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
  );
  expect(dispatch).toBeDisabled();
  expect(cooking).toBeDisabled();
  fireEvent.click(
    screen.getByText("Tải lại để xác nhận", { selector: "button" }),
  );
  await waitFor(() => expect(dispatch).not.toBeDisabled());
  expect(dispatch).toHaveValue("dispatch-x");
  expect(cooking).toHaveValue("group-x");
  expect(api.setSchoolDispatchGroup).toHaveBeenCalledOnce();
  expect(api.setSchoolCookingGroup).not.toHaveBeenCalled();
});
it("replays the exact uncertain Dispatch creation command and never adopts a same-name group", async () => {
  const { api, report } = setup({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  });
  fireEvent.click(
    await screen.findByText("Quản lý nhóm Dispatch", { selector: "button" }),
  );
  fireEvent.change(screen.getByLabelText("Tên nhóm Dispatch"), {
    target: { value: "Dispatch X" },
  });
  fireEvent.click(
    screen.getByText("Lưu nhóm Dispatch", { selector: "button" }),
  );
  await screen.findByText(
    "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
  );
  const request = api.upsertDispatchGroup.mock.calls[0]![0];
  fireEvent.click(
    screen.getByText("Xác nhận lần lưu nhóm Dispatch", { selector: "button" }),
  );
  await waitFor(() => expect(api.upsertDispatchGroup).toHaveBeenCalledTimes(2));
  expect(api.upsertDispatchGroup.mock.calls[1]![0]).toBe(request);
  expect(screen.getByLabelText("Tên nhóm Dispatch")).toBeDisabled();
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true, blocked: true }),
  );
  expect(api.upsertCookingGroup).not.toHaveBeenCalled();
});
it("uses the existing dirty exit guard for Dispatch maintenance and membership drafts", async () => {
  const { exitRef, report } = setup();
  const dispatch = await screen.findByLabelText(
    `Nhóm Dispatch — ${school.school_name}`,
  );
  fireEvent.change(dispatch, { target: { value: "dispatch-x" } });
  fireEvent.click(
    screen.getByText("Quản lý nhóm Dispatch", { selector: "button" }),
  );
  fireEvent.change(screen.getByLabelText("Tên nhóm Dispatch"), {
    target: { value: "Unsaved" },
  });
  const next = vi.fn();
  act(() => exitRef.current!.requestExit(next));
  expect(next).not.toHaveBeenCalled();
  fireEvent.click(
    await screen.findByText("Bỏ thay đổi", { selector: "button" }),
  );
  expect(next).toHaveBeenCalledOnce();
  expect(dispatch).toHaveValue("");
  expect(screen.getByLabelText("Tên nhóm Dispatch")).toHaveValue("");
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: false }),
  );
});
