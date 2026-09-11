import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useSchoolPxkWorkbench } from "./useSchoolPxkWorkbench";
import {
  createSchoolPxkReviewFixture,
  pxkData,
  pxkFailure,
  pxkRow,
  pxkSuccess,
  pxkUnknown,
  reviewDate,
  type SchoolPxkScenario,
} from "./schoolPxkReviewFixtures";
import type { AtlasRpcResult } from "../bridges/schoolDispatch";
afterEach(cleanup);
function deferred() {
  let resolve!: (r: AtlasRpcResult) => void;
  const promise = new Promise<AtlasRpcResult>((r) => {
    resolve = r;
  });
  return { resolve, promise };
}
async function mount(scenario: SchoolPxkScenario = "READY") {
  const api = createSchoolPxkReviewFixture(scenario);
  const originalRead = api.getWorkbench;
  const read = vi.spyOn(api, "getWorkbench");
  const write = vi.spyOn(api, "releaseDocument");
  const h = renderHook(
    ({ authSubject }) =>
      useSchoolPxkWorkbench({
        api,
        authSubject,
        initialServiceDate: reviewDate,
      }),
    { initialProps: { authSubject: "operator" } },
  );
  await waitFor(() => expect(h.result.current.loading).toBe(false));
  if (h.result.current.rows[0])
    act(() =>
      h.result.current.transition({
        selectedKey: h.result.current.key(h.result.current.rows[0]!),
      }),
    );
  return { ...h, api, read, write, originalRead };
}
describe("School PXK authoritative daily scope", () => {
  it("reselecting the same date keeps its proven authority", async () => {
    const h = await mount();
    act(() => h.result.current.transition({ date: reviewDate }));
    await act(async () => h.result.current.release());
    expect(h.write).toHaveBeenCalledTimes(1);
  });
  it("a slower same-scope refresh cannot replace a newer successful refresh", async () => {
    const h = await mount();
    const old = deferred();
    h.read.mockReturnValueOnce(old.promise);
    act(() => h.result.current.transition({ refresh: true }));
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([pxkRow("CURRENT")])));
    act(() => h.result.current.transition({ refresh: true }));
    await waitFor(() =>
      expect(h.result.current.rows[0]!.state).toBe("CURRENT"),
    );
    await act(async () => old.resolve(pxkSuccess(pxkData())));
    expect(h.result.current.rows[0]!.state).toBe("CURRENT");
  });
  it("reads one date and all Schools; local accent search and state filtering do not read", async () => {
    const h = await mount("MULTIPLE_SCHOOLS");
    expect(h.read).toHaveBeenCalledTimes(1);
    expect(h.read.mock.calls[0]![0]).toMatchObject({
      requested_by_auth_subject: "operator",
      payload: {
        date_start: reviewDate,
        date_end: reviewDate,
        school_ids: [],
        search: null,
      },
    });
    act(() => {
      h.result.current.setSearch("ca rot");
      h.result.current.setFilter("READY");
    });
    expect(h.result.current.visibleRows.length).toBeGreaterThan(0);
    expect(h.result.current.visibleRows.every((r) => r.state === "READY")).toBe(
      true,
    );
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it.each([{ date: "2026-09-25" }, { schoolIds: ["school-2"] }])(
    "invalidates immediately for %j and failed scope cannot release old rows",
    async (transition) => {
      const h = await mount();
      const pending = deferred();
      h.read.mockReturnValueOnce(pending.promise);
      act(() => h.result.current.transition(transition));
      expect(h.result.current.canRelease).toBe(false);
      await act(async () => h.result.current.release());
      expect(h.write).not.toHaveBeenCalled();
      await act(async () => pending.resolve(pxkFailure()));
      expect(h.result.current.canRelease).toBe(false);
      expect(h.result.current.readError).toBeTruthy();
    },
  );
  it("retains the catalogue after subset Apply and normalizes explicit all", async () => {
    const h = await mount("MULTIPLE_SCHOOLS");
    const schools = h.result.current.schools;
    act(() => h.result.current.transition({ schoolIds: ["school-2"] }));
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    expect(h.result.current.schools).toEqual(schools);
    act(() =>
      h.result.current.transition({
        schoolIds: schools.map((s) => s.school_id),
      }),
    );
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(3));
    expect(h.read.mock.calls[2]![0].payload).toMatchObject({ school_ids: [] });
  });
  it("ignores slower old scope and refresh responses", async () => {
    const h = await mount();
    const old = deferred();
    h.read.mockReturnValueOnce(old.promise);
    act(() => h.result.current.transition({ refresh: true }));
    act(() => h.result.current.transition({ date: "2026-09-25" }));
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    await act(async () => old.resolve(pxkSuccess(pxkData())));
    expect(h.result.current.date).toBe("2026-09-25");
    expect(h.result.current.rows[0]!.service_date).toBe("2026-09-25");
  });
  it("refreshes exact applied scope with null search", async () => {
    const h = await mount();
    act(() => h.result.current.transition({ schoolIds: ["school-1"] }));
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    act(() => {
      h.result.current.setSearch("gao");
      h.result.current.transition({ refresh: true });
    });
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(3));
    expect(h.read.mock.calls[2]![0].payload).toEqual({
      date_start: reviewDate,
      date_end: reviewDate,
      school_ids: [],
      search: null,
    });
  });
  it("invalidates authority on auth change and ignores its delayed response", async () => {
    const h = await mount();
    const pending = deferred();
    h.read.mockReturnValueOnce(pending.promise);
    h.rerender({ authSubject: "other" });
    expect(h.result.current.canRelease).toBe(false);
    h.rerender({ authSubject: "third" });
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    await act(async () => pending.resolve(pxkFailure()));
    expect(h.result.current.readError).toBeNull();
  });
});
describe("School PXK release and replacement", () => {
  it("clears the note when UNKNOWN recovery proves the exact command committed", async () => {
    const h = await mount();
    const api = createSchoolPxkReviewFixture();
    h.write.mockImplementation(async (req) => {
      await api.releaseDocument(req);
      return pxkUnknown();
    });
    act(() => h.result.current.setNote("Ghi chú phát hành"));
    await act(async () => h.result.current.release());
    h.read.mockImplementation(api.getWorkbench);
    await act(async () => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.selected!.state).toBe("CURRENT");
    expect(h.result.current.note).toBe("");
  });
  it("prevents duplicate synchronous commands and rejects notes over 500 characters", async () => {
    const h = await mount();
    act(() => h.result.current.setNote("x".repeat(501)));
    await act(async () => h.result.current.release());
    expect(h.write).not.toHaveBeenCalled();
    act(() => h.result.current.setNote("x".repeat(500)));
    await act(async () => {
      await Promise.all([
        h.result.current.release(),
        h.result.current.release(),
      ]);
    });
    expect(h.write).toHaveBeenCalledTimes(1);
  });
  it("treats thrown transport exceptions as UNKNOWN without retry", async () => {
    const h = await mount();
    h.write.mockRejectedValueOnce(new Error("private transport text"));
    await act(async () => h.result.current.release());
    expect(h.result.current.lock).toBe("unknown");
    expect(h.result.current.notice).not.toContain("private transport");
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it("keeps success uncertainty locked until the exact fingerprint is proven", async () => {
    const h = await mount();
    const wrong = pxkRow("CURRENT");
    wrong.current_release!.source_fingerprint = "unrelated";
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([wrong])));
    act(() => h.result.current.setNote("Ghi chú"));
    await act(async () => h.result.current.release());
    expect(h.result.current.lock).toBe("unknown");
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([wrong])));
    await act(async () => h.result.current.recover());
    expect(h.result.current.lock).toBe("unknown");
    expect(h.result.current.note).toBe("Ghi chú");
    await act(async () => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.note).toBe("");
    expect(h.write).toHaveBeenCalledTimes(1);
  });
  it.each(["READY", "REPLACEMENT_REQUIRED"] as const)(
    "uses exact builder facts for %s and adopts only readback",
    async (scenario) => {
      const h = await mount(scenario);
      const row = h.result.current.selected!;
      const old = structuredClone(row.current_release);
      const pending = deferred();
      act(() => h.result.current.setNote("  Giao cổng phụ  "));
      h.read.mockReturnValueOnce(pending.promise);
      let command!: Promise<void>;
      act(() => {
        command = h.result.current.release();
      });
      await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
      expect(h.result.current.note).toBe("  Giao cổng phụ  ");
      expect(h.result.current.canRelease).toBe(false);
      await act(async () => h.result.current.release());
      expect(h.write).toHaveBeenCalledTimes(1);
      const req = h.write.mock.calls[0]![0];
      expect(req).toMatchObject({
        contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
        expected_version: row.expected_version,
        requested_by_auth_subject: "operator",
        reason_code: "SCHOOL_DISPATCH_DOCUMENT_RELEASED",
        reason_note: "Giao cổng phụ",
        payload: {
          service_date: row.service_date,
          school_id: row.school_id,
          delivery_location_id: row.delivery_location_id,
          expected_source_fingerprint: row.preview.source_fingerprint,
          predecessor_release_id: old?.school_dispatch_release_id ?? null,
        },
      });
      expect(req.idempotency_key).toBe(
        `school-dispatch-release:${req.command_id}`,
      );
      expect(req.correlation_id).toBe(h.read.mock.calls[0]![0].correlation_id);
      expect(Number.isNaN(Date.parse(req.requested_at))).toBe(false);
      const actual = await h.originalRead(h.read.mock.calls[1]![0]);
      await act(async () => {
        pending.resolve(actual);
        await command;
      });
      expect(h.result.current.selected!.state).toBe("CURRENT");
      expect(h.result.current.note).toBe("");
      expect(h.result.current.notice).toContain("Đã xác nhận");
      expect(row.current_release).toEqual(old);
      if (old)
        expect(h.result.current.selected!.history).toContainEqual({
          ...old,
          status: "SUPERSEDED",
        });
    },
  );
  it.each(["READY", "REPLACEMENT_REQUIRED"] as const)(
    "requires matching backend action for %s",
    async (state) => {
      const api = createSchoolPxkReviewFixture();
      const row = pxkRow(state);
      row.allowed_actions = { release: false, replace: false, export: false };
      vi.spyOn(api, "getWorkbench").mockResolvedValue(
        pxkSuccess(pxkData([row])),
      );
      const write = vi.spyOn(api, "releaseDocument");
      const h = renderHook(() =>
        useSchoolPxkWorkbench({
          api,
          authSubject: "operator",
          initialServiceDate: reviewDate,
        }),
      );
      await waitFor(() => expect(h.result.current.loading).toBe(false));
      act(() =>
        h.result.current.transition({ selectedKey: h.result.current.key(row) }),
      );
      await act(async () => h.result.current.release());
      expect(write).not.toHaveBeenCalled();
    },
  );
  it.each(["STALE", "SOURCE_CHANGED", "PXK_NOT_READY"] as const)(
    "%s locks until explicit current-data reload without retry",
    async (scenario) => {
      const h = await mount(scenario);
      await act(async () => h.result.current.release());
      expect(h.result.current.lock).toBe("stale");
      expect(h.result.current.canRelease).toBe(false);
      expect(h.read).toHaveBeenCalledTimes(1);
      await act(async () => h.result.current.recover());
      expect(h.result.current.lock).toBeNull();
      expect(h.write).toHaveBeenCalledTimes(1);
    },
  );
  it("UNKNOWN recovery retains lock on failure then derives the actual state", async () => {
    const h = await mount("UNKNOWN_RELEASE");
    await act(async () => h.result.current.release());
    expect(h.result.current.lock).toBe("unknown");
    h.read.mockResolvedValueOnce(pxkFailure());
    await act(async () => h.result.current.recover());
    expect(h.result.current.lock).toBe("unknown");
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([pxkRow("BLOCKED")])));
    await act(async () => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.selected!.state).toBe("BLOCKED");
    expect(h.result.current.canRelease).toBe(false);
    expect(h.write).toHaveBeenCalledTimes(1);
  });
  it.each(["SUCCESS_THEN_READBACK_FAILURE", "READY"] as const)(
    "success with failed/unproven readback remains uncertain (%s)",
    async (scenario) => {
      const h = await mount(scenario);
      if (scenario === "READY")
        h.read.mockResolvedValueOnce(pxkSuccess(pxkData()));
      act(() => h.result.current.setNote("Giữ ghi chú"));
      await act(async () => h.result.current.release());
      expect(h.result.current.lock).toBe("unknown");
      expect(h.result.current.note).toBe("Giữ ghi chú");
      expect(h.result.current.notice).not.toContain("Đã xác nhận");
      await act(async () => h.result.current.release());
      expect(h.write).toHaveBeenCalledTimes(1);
    },
  );
  it("rejects replacement readback without exact predecessor/history", async () => {
    const h = await mount("REPLACEMENT_REQUIRED");
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([pxkRow("CURRENT")])));
    await act(async () => h.result.current.release());
    expect(h.result.current.lock).toBe("unknown");
  });
  it("permission failure shows safe message and requires read", async () => {
    const h = await mount();
    h.write.mockResolvedValueOnce(pxkFailure());
    await act(async () => h.result.current.release());
    expect(h.result.current.lock).toBe("stale");
    expect(h.result.current.notice).not.toContain("CAPABILITY_DENIED");
  });
});
describe("School PXK note transitions", () => {
  it.each([
    { selectedKey: "another" },
    { date: "2026-09-25" },
    { schoolIds: ["school-2"] },
    { refresh: true },
    { selectedKey: null },
  ])("protects %j with cancel and discard", async (transition) => {
    const h = await mount("MULTIPLE_SCHOOLS");
    const before = {
      date: h.result.current.date,
      key: h.result.current.selectedKey,
      ids: h.result.current.schoolIds,
    };
    act(() => {
      h.result.current.setNote("Chưa phát hành");
    });
    act(() => h.result.current.transition(transition));
    expect(h.result.current.pendingTransition).toEqual(transition);
    expect(h.read).toHaveBeenCalledTimes(1);
    act(() => h.result.current.cancelTransition());
    expect(h.result.current.note).toBe("Chưa phát hành");
    expect({
      date: h.result.current.date,
      key: h.result.current.selectedKey,
      ids: h.result.current.schoolIds,
    }).toEqual(before);
    act(() => h.result.current.transition(transition));
    act(() => h.result.current.discardTransition());
    expect(h.result.current.note).toBe("");
    expect(h.result.current.pendingTransition).toBeNull();
    if ("date" in transition)
      expect(h.result.current.date).toBe(transition.date);
    if ("selectedKey" in transition)
      expect(h.result.current.selectedKey).toBe(transition.selectedKey);
  });
  it("search/state filters retain note and selected detail", async () => {
    const h = await mount();
    const selected = h.result.current.selectedKey;
    act(() => h.result.current.setNote("Giữ nguyên"));
    act(() => {
      h.result.current.setSearch("không khớp");
      h.result.current.setFilter("CURRENT");
    });
    expect(h.result.current.note).toBe("Giữ nguyên");
    expect(h.result.current.selectedKey).toBe(selected);
    expect(h.result.current.visibleRows).toEqual([]);
  });
});
