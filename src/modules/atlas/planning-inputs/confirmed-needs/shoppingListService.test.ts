import { describe, it, expect, vi } from "vitest";
import ExcelJS from "exceljs";
import { shoppingFixture } from "./shoppingListTestFixtures";
import { reviewSuccess } from "../../../../vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";
import {
  createConfirmedNeedShoppingListXlsx,
  downloadConfirmedNeedShoppingList,
} from "./confirmedNeedShoppingList";
import {
  createConnectedShoppingListService,
  loadCompleteConfirmedNeedReview,
} from "./shoppingListService";
vi.mock("./confirmedNeedShoppingList", async (original) => ({
  ...(await original<typeof import("./confirmedNeedShoppingList")>()),
  downloadConfirmedNeedShoppingList: vi.fn(),
}));
function fixture() {
  const f = shoppingFixture();
  const getReview = vi
    .fn()
    .mockResolvedValue(reviewSuccess({ workbench: f.workbench }));
  const save = vi.fn(),
    preview = vi.fn(),
    confirm = vi.fn(),
    validate = vi.fn(),
    approve = vi.fn(),
    release = vi.fn();
  const api = { getReview, save, preview, confirm, validate, approve, release };
  const preflight = vi.fn().mockResolvedValue(
    reviewSuccess({
      preflight: {
        period_start: "2026-09-07",
        period_end: "2026-09-07",
        readiness_state: "READY",
        source_evidence: {},
        issues: [],
        downstream_currentness: "CURRENT",
        current_need: {
          confirmed_need_batch_id: f.workbench.confirmed_need_batch_id,
          confirmed_need_batch_version: f.workbench.batch_version,
          need_generation_run_id: f.workbench.need_generation_source.run_id,
          need_generation_release_snapshot_id:
            f.workbench.need_generation_source.release_snapshot_id,
        },
      },
    }),
  );
  return {
    ...f,
    api,
    preflight,
    service: createConnectedShoppingListService(api, { preflight }, "subject"),
  };
}
describe("connected XLSX authority", () => {
  it("freshly reads on restart and proposes quantity without invoking any command", async () => {
    const f = fixture(),
      book = new ExcelJS.Workbook();
    for (const line of f.workbench.lines) {
      line.controlled_unit.code = "kg";
      line.controlled_unit.name = "Kilogram";
    }
    f.api.getReview.mockResolvedValue(
      reviewSuccess({ workbench: f.workbench }),
    );
    const before = structuredClone({
      workbench: f.workbench,
      drafts: f.drafts,
    });
    await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
    book.worksheets[0]!.getCell("D5").value = 12.5;
    const buffer = new Uint8Array(await book.xlsx.writeBuffer());
    const file = { arrayBuffer: async () => buffer.buffer } as File;
    const imported = await f.service.import(file, f.workbench, f.drafts);
    expect(imported.changedLineIds).toEqual([
      f.workbench.lines[0]!.confirmed_need_line_id,
    ]);
    expect(imported.drafts[imported.changedLineIds[0]!]?.exact_quantity).toBe(
      "12,5",
    );
    expect({ workbench: f.workbench, drafts: f.drafts }).toEqual(before);
    expect(f.api.getReview).toHaveBeenCalled();
    for (const command of [
      f.api.save,
      f.api.preview,
      f.api.confirm,
      f.api.validate,
      f.api.approve,
      f.api.release,
    ])
      expect(command).not.toHaveBeenCalled();
  });
  it("follows pagination and rejects a version change between pages", async () => {
    const f = fixture();
    const first = structuredClone(f.workbench),
      last = structuredClone(f.workbench);
    first.lines = first.lines.slice(0, 3);
    first.pagination = { offset: 0, limit: 3, total_lines: 6, has_more: true };
    last.lines = last.lines.slice(3);
    last.pagination = { offset: 3, limit: 3, total_lines: 6, has_more: false };
    f.api.getReview
      .mockResolvedValueOnce(reviewSuccess({ workbench: first }))
      .mockResolvedValueOnce(reviewSuccess({ workbench: last }));
    expect(
      (
        await loadCompleteConfirmedNeedReview(
          f.api,
          "subject",
          f.workbench.confirmed_need_batch_id,
          "2026-09-07",
        )
      ).lines,
    ).toHaveLength(6);
    last.batch_version++;
    f.api.getReview
      .mockResolvedValueOnce(reviewSuccess({ workbench: first }))
      .mockResolvedValueOnce(reviewSuccess({ workbench: last }));
    await expect(
      loadCompleteConfirmedNeedReview(
        f.api,
        "subject",
        f.workbench.confirmed_need_batch_id,
        "2026-09-07",
      ),
    ).rejects.toThrow();
  });
  it("rejects workbook dates outside the selected scope with no local change", async () => {
    const f = fixture(),
      second = shoppingFixture("2026-09-08", 2),
      buffer = await createConfirmedNeedShoppingListXlsx([f, second]),
      before = structuredClone(f.drafts);
    await expect(
      f.service.import(
        { arrayBuffer: async () => buffer } as File,
        f.workbench,
        f.drafts,
      ),
    ).rejects.toMatchObject({
      code: "WORKBENCH_DATE_MISMATCH",
    });
    expect(f.drafts).toEqual(before);
  });
  it("blocks dirty and released workbenches before reads", async () => {
    const f = fixture();
    f.drafts[f.workbench.lines[0]!.confirmed_need_line_id]!.exact_quantity =
      "12,5";
    await expect(
      f.service.import({} as File, f.workbench, f.drafts),
    ).rejects.toMatchObject({ code: "DIRTY_WORKBENCH" });
    f.workbench.editing_allowed = false;
    await expect(
      f.service.import({} as File, f.workbench, {}),
    ).rejects.toThrow();
    expect(f.api.getReview).not.toHaveBeenCalled();
  });
});

it("imports two dates atomically after refreshing every daily authority", async () => {
  const f = fixture(),
    second = shoppingFixture("2026-09-08", 2);
  const batches = [f.workbench, second.workbench];
  f.api.getReview.mockImplementation(async (_s, _c, id) =>
    reviewSuccess({
      workbench: batches.find((b) => b.confirmed_need_batch_id === id),
    }),
  );
  let staleDate: string | null = null;
  f.preflight.mockImplementation(async (_s, _c, date) => {
    const b = batches.find((b) => b.service_period.period_start === date)!;
    return reviewSuccess({
      preflight: {
        period_start: date,
        period_end: date,
        readiness_state: "READY",
        source_evidence: {},
        issues: [],
        downstream_currentness: "CURRENT",
        current_need: {
          confirmed_need_batch_id: b.confirmed_need_batch_id,
          confirmed_need_batch_version:
            b.batch_version + (date === staleDate ? 1 : 0),
          need_generation_run_id: b.need_generation_source.run_id,
        },
      },
    });
  });
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f, second]));
  book.worksheets[0]!.getCell("D5").value = 12.5;
  book.worksheets[1]!.getCell("D5").value = 12.5;
  const bytes = await book.xlsx.writeBuffer();
  const drafts = { ...f.drafts, ...second.drafts };
  const before = structuredClone(drafts);
  const context = {
    range: { start: "2026-09-07", end: "2026-09-08" },
    workbenches: batches,
    drafts,
  };
  const imported = await f.service.import(
    { arrayBuffer: async () => bytes } as File,
    f.workbench,
    drafts,
    context,
  );
  expect(imported.changedLineIds).toHaveLength(2);
  expect(drafts).toEqual(before);
  expect(f.api.save).not.toHaveBeenCalled();
  staleDate = "2026-09-08";
  f.api.getReview.mockClear();
  await expect(
    f.service.import(
      { arrayBuffer: async () => bytes } as File,
      f.workbench,
      drafts,
      context,
    ),
  ).rejects.toMatchObject({ code: "STALE_AUTHORITY" });
  expect(f.api.getReview).toHaveBeenCalledTimes(2);
  expect(drafts).toEqual(before);
});

function rangeFixture() {
  const batches = [shoppingFixture(), shoppingFixture("2026-09-08", 2)];
  const events: string[] = [];
  const preflight = vi.fn(async (_s: string, _c: string, date: string) => {
    events.push(`preflight:${date}`);
    const b = batches.find(
      (b) => b.workbench.service_period.period_start === date,
    )?.workbench;
    return reviewSuccess({
      preflight: {
        period_start: date,
        period_end: date,
        readiness_state: b ? "READY" : "BLOCKED",
        source_evidence: {},
        downstream_currentness: b ? "CURRENT" : "NOT_GENERATED",
        issues: b
          ? []
          : [
              {
                severity: "BLOCKING",
                issue_code: "NO_NEED_SOURCE_FOR_SERVICE_DATE",
              },
            ],
        current_need: b
          ? {
              confirmed_need_batch_id: b.confirmed_need_batch_id,
              confirmed_need_batch_version: b.batch_version,
              need_generation_run_id: b.need_generation_source.run_id,
            }
          : null,
      },
    });
  });
  const getShoppingListExport = vi.fn(
    async (
      request: Parameters<
        NonNullable<
          Parameters<
            typeof createConnectedShoppingListService
          >[0]["getShoppingListExport"]
        >
      >[0],
    ) => {
      const b = batches.find(
        (b) =>
          b.workbench.confirmed_need_batch_id ===
          (request.payload as { confirmed_need_batch_id: string })
            .confirmed_need_batch_id,
      )!;
      events.push(`export:${b.workbench.service_period.period_start}`);
      return reviewSuccess({
        workbench: b.workbench,
        shopping_list_supplier_advice: b.supplierAdvice,
      });
    },
  );
  const api = { getReview: vi.fn(), getShoppingListExport };
  const context = {
    range: { start: "2026-09-07", end: "2026-09-08" },
    workbenches: batches.map((b) => b.workbench),
    drafts: Object.assign({}, ...batches.map((b) => b.drafts)),
    onSkippedDates: vi.fn(),
  };
  return {
    batches,
    context,
    events,
    preflight,
    api,
    service: createConnectedShoppingListService(api, { preflight }, "subject"),
  };
}
it("exports complete daily authorities into one workbook and explicitly reports proven no-demand dates", async () => {
  const f = rangeFixture();
  f.context.range.end = "2026-09-09";
  await f.service.export(f.batches[0]!.workbench, f.context);
  expect(
    vi.mocked(downloadConfirmedNeedShoppingList).mock.lastCall![0],
  ).toHaveLength(2);
  expect(f.context.onSkippedDates).toHaveBeenCalledWith(["2026-09-09"]);
  for (const date of ["2026-09-07", "2026-09-08"]) {
    const position = f.events.indexOf(`export:${date}`);
    expect(f.events[position - 1]).toBe(`preflight:${date}`);
    expect(f.events[position + 1]).toBe(`preflight:${date}`);
  }
});
it("blocks the entire export on dirty, released, read-failed or changed authority", async () => {
  const f = rangeFixture();
  const download = vi.mocked(downloadConfirmedNeedShoppingList);
  download.mockClear();
  const key = f.batches[1]!.workbench.lines[0]!.confirmed_need_line_id;
  f.context.drafts[key]!.exact_quantity = "99";
  await expect(
    f.service.export(f.batches[0]!.workbench, f.context),
  ).rejects.toMatchObject({ code: "DIRTY_WORKBENCH" });
  f.context.drafts[key] = structuredClone(
    shoppingFixture("2026-09-08", 2).drafts[key]!,
  );
  f.batches[1]!.workbench.editing_allowed = false;
  await expect(
    f.service.export(f.batches[0]!.workbench, f.context),
  ).rejects.toThrow();
  f.batches[1]!.workbench.editing_allowed = true;
  f.api.getShoppingListExport.mockRejectedValueOnce(new Error("read failed"));
  await expect(
    f.service.export(f.batches[0]!.workbench, f.context),
  ).rejects.toThrow("read failed");
  Object.assign(f.context, { isCurrent: () => false });
  await expect(
    f.service.export(f.batches[0]!.workbench, f.context),
  ).rejects.toMatchObject({ code: "STALE_AUTHORITY" });
  expect(download).not.toHaveBeenCalled();
});
