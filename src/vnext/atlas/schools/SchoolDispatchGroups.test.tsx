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

async function membership(kind: "cooking" | "dispatch") {
  const title = kind === "cooking" ? "Nấu tại" : "Nhóm phiếu xuất kho";
  fireEvent.click(
    await screen.findByRole("tab", {
      name: kind === "cooking" ? "Nơi nấu" : title,
    }),
  );
  const group = await screen.findByRole("combobox", {
    name: kind === "cooking" ? "Nơi nấu" : title,
  });
  await waitFor(() =>
    expect(group).toHaveTextContent(
      kind === "cooking" ? "Bếp X" : "Dispatch X",
    ),
  );
  const id = kind === "cooking" ? "group-x" : "dispatch-x";
  if ((group as HTMLSelectElement).value !== id)
    fireEvent.change(group, { target: { value: id } });
  fireEvent.change(screen.getByLabelText(`Danh sách trường — ${title}`), {
    target: { value: "ALL" },
  });
  const select = await screen.findByLabelText(
    `${title} — ${school.school_name}`,
  );
  expect(select).toBeVisible();
  return select;
}

it("saves cooking and Dispatch independently and uses each authoritative School version", async () => {
  const { api, report } = setup();
  const cooking = await membership("cooking");
  fireEvent.change(cooking, { target: { value: "group-x" } });
  const dispatch = await membership("dispatch");
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
  await membership("cooking");
  fireEvent.click(screen.getByLabelText(`Lưu Nấu tại — ${school.school_name}`));
  await waitFor(() => expect(api.getSchools).toHaveBeenCalledTimes(2));
  const retainedDispatch = await membership("dispatch");
  await waitFor(() => expect(retainedDispatch).not.toBeDisabled());
  expect(api.setSchoolDispatchGroup).not.toHaveBeenCalled();
  expect(retainedDispatch).toHaveValue("dispatch-x");
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
    screen.getByLabelText(`Lưu Nhóm phiếu xuất kho — ${school.school_name}`),
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
  expect(await membership("cooking")).toHaveValue("group-x");
  expect(api.setSchoolCookingGroup).toHaveBeenCalledOnce();
  expect(api.updateSchoolDefaultsBulk).not.toHaveBeenCalled();
});
it("preserves uncertain Dispatch assignments and cooking drafts until readback", async () => {
  const { api } = setup({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  });
  const dispatch = await membership("dispatch");
  fireEvent.change(dispatch, { target: { value: "dispatch-x" } });
  const cooking = await membership("cooking");
  fireEvent.change(cooking, { target: { value: "group-x" } });
  const pendingDispatch = await membership("dispatch");
  fireEvent.click(
    screen.getByLabelText(`Lưu Nhóm phiếu xuất kho — ${school.school_name}`),
  );
  await screen.findByText(
    "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
  );
  expect(pendingDispatch).toBeDisabled();
  expect(await membership("cooking")).toBeDisabled();
  await membership("dispatch");
  fireEvent.click(
    screen.getByText("Tải lại để xác nhận", { selector: "button" }),
  );
  const currentDispatch = screen.getByLabelText(
    `Nhóm phiếu xuất kho — ${school.school_name}`,
  );
  await waitFor(() => expect(currentDispatch).not.toBeDisabled());
  expect(currentDispatch).toHaveValue("dispatch-x");
  expect(await membership("cooking")).toHaveValue("group-x");
  expect(api.setSchoolDispatchGroup).toHaveBeenCalledOnce();
  expect(api.setSchoolCookingGroup).not.toHaveBeenCalled();
});
it("replays the exact uncertain Dispatch creation command and never adopts a same-name group", async () => {
  const { api, report } = setup({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
  });
  fireEvent.click(
    await screen.findByRole("tab", { name: "Nhóm phiếu xuất kho" }),
  );
  const name = await screen.findByLabelText("Tên nhóm phiếu xuất kho");
  await waitFor(() => expect(name).toBeEnabled());
  fireEvent.change(name, {
    target: { value: "Dispatch X" },
  });
  fireEvent.click(
    screen.getByText("Lưu nhóm phiếu xuất kho", { selector: "button" }),
  );
  await screen.findByText(
    "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
  );
  const request = api.upsertDispatchGroup.mock.calls[0]![0];
  fireEvent.click(
    screen.getByText("Xác nhận lần lưu nhóm phiếu xuất kho", {
      selector: "button",
    }),
  );
  await waitFor(() => expect(api.upsertDispatchGroup).toHaveBeenCalledTimes(2));
  expect(api.upsertDispatchGroup.mock.calls[1]![0]).toBe(request);
  expect(screen.getByLabelText("Tên nhóm phiếu xuất kho")).toBeDisabled();
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true, blocked: true }),
  );
  expect(api.upsertCookingGroup).not.toHaveBeenCalled();
});
it("uses the existing dirty exit guard for Dispatch maintenance and membership drafts", async () => {
  const { exitRef, report } = setup();
  const dispatch = await membership("dispatch");
  fireEvent.change(dispatch, { target: { value: "dispatch-x" } });
  fireEvent.click(screen.getByRole("tab", { name: "Nhóm phiếu xuất kho" }));
  fireEvent.change(screen.getByLabelText("Tên nhóm phiếu xuất kho"), {
    target: { value: "Unsaved" },
  });
  const next = vi.fn();
  act(() => exitRef.current!.requestExit(next));
  expect(next).not.toHaveBeenCalled();
  fireEvent.click(
    await screen.findByText("Bỏ thay đổi", { selector: "button" }),
  );
  expect(next).toHaveBeenCalledOnce();
  expect(screen.getByLabelText("Tên nhóm phiếu xuất kho")).toHaveValue("");
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: false }),
  );
  expect(await membership("dispatch")).toHaveValue("");
});
