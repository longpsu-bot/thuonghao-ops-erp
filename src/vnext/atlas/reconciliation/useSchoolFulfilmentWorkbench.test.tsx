import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useSchoolFulfilmentWorkbench } from "./useSchoolFulfilmentWorkbench";
import {
  fulfilmentData,
  fulfilmentRow,
  fulfilmentSuccess,
  createSchoolFulfilmentReviewFixture,
} from "./schoolFulfilmentReviewFixtures";
import type { AtlasRpcResult } from "../bridges/schoolDispatch";
afterEach(cleanup);
function show(api = createSchoolFulfilmentReviewFixture(), end = "2026-09-24") {
  const read = vi.spyOn(api, "getWorkbench");
  const hook = renderHook(
    ({ subject }) =>
      useSchoolFulfilmentWorkbench({
        api,
        authSubject: subject,
        initialDateStart: "2026-09-24",
        initialDateEnd: end,
      }),
    { initialProps: { subject: "operator" as string | null } },
  );
  return { ...hook, read };
}
describe("reconciliation authority and presentation", () => {
  it("retains backend order within both exception and OK groups", async () => {
    const rows = [
      fulfilmentRow({ school_id: "ok-first", comparison_status: "OK" }),
      fulfilmentRow({
        school_id: "exception-first",
        comparison_status: "NO_PXK",
      }),
      fulfilmentRow({ school_id: "ok-second", comparison_status: "OK" }),
      fulfilmentRow({
        school_id: "exception-second",
        comparison_status: "NO_PO",
      }),
    ];
    const h = show({
      getWorkbench: vi
        .fn()
        .mockResolvedValue(fulfilmentSuccess(fulfilmentData(rows))),
    });
    await waitFor(() => expect(h.result.current.rows).toHaveLength(4));
    act(() => h.result.current.setFilter("all"));
    expect(h.result.current.visibleRows.map((r) => r.school_id)).toEqual([
      "exception-first",
      "exception-second",
      "ok-first",
      "ok-second",
    ]);
  });
  it("reads exact inclusive 31-day scope with null search and refreshes it", async () => {
    const h = show(undefined, "2026-10-24");
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    expect(h.read.mock.calls[0][0]).toMatchObject({
      requested_by_auth_subject: "operator",
      payload: {
        date_start: "2026-09-24",
        date_end: "2026-10-24",
        school_ids: [],
        search: null,
      },
    });
    act(() => h.result.current.refresh());
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    expect(h.read.mock.calls[1][0].payload).toEqual(
      h.read.mock.calls[0][0].payload,
    );
  });
  it.each([
    ["2026-09-23", "Đến ngày không được trước Từ ngày."],
    ["2026-10-25", "Khoảng đối chiếu tối đa 31 ngày."],
  ])("does not read invalid range %s", async (end, message) => {
    const h = show(undefined, end);
    await waitFor(() => expect(h.result.current.rangeError).toBe(message));
    expect(h.read).not.toHaveBeenCalled();
    expect(h.result.current.rows).toEqual([]);
  });
  it("invalidates rows and detail immediately on a date or School change; retains catalogue", async () => {
    const h = show();
    await waitFor(() =>
      expect(h.result.current.rows.length).toBeGreaterThan(0),
    );
    const catalogue = h.result.current.schools;
    act(() => h.result.current.select(h.result.current.rows[0]));
    act(() => h.result.current.applySchools(["school-a"]));
    expect(h.result.current.selected).toBeNull();
    expect(h.result.current.rows).toEqual([]);
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    expect(h.result.current.schools).toEqual(catalogue);
    expect(h.read.mock.calls.at(-1)?.[0].payload).toMatchObject({
      school_ids: ["school-a"],
    });
    act(() => h.result.current.applySchools(catalogue.map((s) => s.school_id)));
    await waitFor(() => expect(h.result.current.loading).toBe(false));
    expect(h.read.mock.calls.at(-1)?.[0].payload).toMatchObject({
      school_ids: [],
    });
    act(() => h.result.current.setDateEnd("2026-09-23"));
    expect(h.result.current.rows).toEqual([]);
    expect(h.result.current.selected).toBeNull();
    expect(h.read).toHaveBeenCalledTimes(3);
  });
  it("defaults to exceptions and stably places non-OK before OK without deriving status", async () => {
    const h = show();
    await waitFor(() =>
      expect(h.result.current.rows.length).toBeGreaterThan(0),
    );
    expect(h.result.current.filter).toBe("exceptions");
    expect(
      h.result.current.visibleRows.map((r) => r.comparison_status),
    ).toEqual(["MISMATCH", "NO_PO", "INGREDIENT_CHANGED", "NO_PXK"]);
    act(() => h.result.current.setFilter("all"));
    expect(
      h.result.current.visibleRows.map((r) => r.comparison_status),
    ).toEqual(["MISMATCH", "NO_PO", "INGREDIENT_CHANGED", "NO_PXK", "OK"]);
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it.each([
    "nguyen du",
    "bep chinh",
    "po-20260924-a",
    "pxk-20260924-a",
    "gao thom",
    "kg",
  ])("searches %s locally and closes hidden detail", async (search) => {
    const h = show();
    await waitFor(() =>
      expect(h.result.current.rows.length).toBeGreaterThan(0),
    );
    act(() => {
      h.result.current.setFilter("all");
      h.result.current.setSearch(search);
    });
    expect(
      h.result.current.visibleRows.some((r) => r.school_id === "school-a"),
    ).toBe(true);
    act(() => h.result.current.select(h.result.current.visibleRows[0]));
    act(() => h.result.current.setSearch("khong ton tai"));
    expect(h.result.current.selected).toBeNull();
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it.each([
    "contract",
    "range",
    "rowDate",
    "status",
    "details",
    "totals",
    "warnings",
    "nullRow",
    "quantity",
  ])("rejects malformed %s authority", async (fault) => {
    const data = fulfilmentData([fulfilmentRow()]);
    const malformed = data as unknown as Record<string, unknown>;
    const row = data.rows[0] as unknown as Record<string, unknown>;
    if (fault === "contract") malformed.contract_version = "wrong";
    if (fault === "range") malformed.date_end = "2026-09-25";
    if (fault === "rowDate") row.service_date = "2026-09-25";
    if (fault === "status") row.comparison_status = "NEW";
    if (fault === "details") row.details = null;
    if (fault === "totals") row.quantity_totals_by_unit = null;
    if (fault === "warnings") row.warnings = null;
    if (fault === "nullRow") malformed.rows = [null];
    if (fault === "quantity") data.rows[0].details[0].po_quantity = "NaN";
    const h = show({
      getWorkbench: vi.fn().mockResolvedValue(fulfilmentSuccess(data)),
    });
    await waitFor(() => expect(h.result.current.readError).toBeTruthy());
    expect(h.result.current.rows).toEqual([]);
  });
  it("rejects a row outside committed School scope", async () => {
    const api = {
      getWorkbench: vi
        .fn()
        .mockResolvedValue(
          fulfilmentSuccess(fulfilmentData([fulfilmentRow()])),
        ),
    };
    const h = show(api);
    await waitFor(() => expect(h.result.current.rows).toHaveLength(1));
    act(() => h.result.current.applySchools(["school-b"]));
    await waitFor(() => expect(h.result.current.readError).toBeTruthy());
    expect(h.result.current.rows).toEqual([]);
  });
  it.each(["refresh", "date", "school", "auth"])(
    "ignores slow old response after newer %s intent",
    async (intent) => {
      let resolveOld!: (r: AtlasRpcResult) => void;
      const fixture = createSchoolFulfilmentReviewFixture();
      const api = {
        getWorkbench: vi
          .fn()
          .mockImplementationOnce(
            () =>
              new Promise<AtlasRpcResult>((r) => {
                resolveOld = r;
              }),
          )
          .mockImplementation(fixture.getWorkbench),
      };
      const h = show(api);
      if (intent === "refresh") act(() => h.result.current.refresh());
      if (intent === "date")
        act(() => h.result.current.setDateEnd("2026-09-25"));
      if (intent === "school")
        act(() => h.result.current.applySchools(["school-a"]));
      if (intent === "auth") h.rerender({ subject: "new-operator" });
      await waitFor(() => expect(h.result.current.loading).toBe(false));
      await act(async () =>
        resolveOld(
          fulfilmentSuccess(
            fulfilmentData([fulfilmentRow({ school_name: "Trường cũ" })]),
          ),
        ),
      );
      expect(
        h.result.current.rows.some((r) => r.school_name === "Trường cũ"),
      ).toBe(false);
    },
  );
  it("clears data/catalogue on sign-out and performs no anonymous read", async () => {
    const h = show();
    await waitFor(() =>
      expect(h.result.current.rows.length).toBeGreaterThan(0),
    );
    h.rerender({ subject: null });
    expect(h.result.current.rows).toEqual([]);
    expect(h.result.current.schools).toEqual([]);
    expect(h.read).toHaveBeenCalledTimes(1);
  });
});
