import { describe, it, expect, vi } from "vitest";
import ExcelJS from "exceljs";
import { shoppingFixture } from "./shoppingListTestFixtures";
import { reviewSuccess } from "../../../../vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";
import { createConfirmedNeedShoppingListXlsx } from "./confirmedNeedShoppingList";
import {
  createConnectedShoppingListService,
  loadCompleteConfirmedNeedReview,
} from "./shoppingListService";
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
    await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
    book.worksheets[0]!.getCell("D4").value = 12.5;
    const buffer = new Uint8Array(await book.xlsx.writeBuffer());
    const file = { arrayBuffer: async () => buffer.buffer } as File;
    const imported = await f.service.import(file, f.workbench, f.drafts);
    expect(imported.changedLineIds).toEqual([
      f.workbench.lines[0]!.confirmed_need_line_id,
    ]);
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
  it("rejects a valid multi-date file with a capability error and no local change", async () => {
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
      code: "MULTI_DATE_UI_DEFERRED_BY_EXACT_DAY_WORKBENCH",
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
