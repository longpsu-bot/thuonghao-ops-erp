import { describe, expect, it, vi } from "vitest";
import type { JsonValue } from "../../connection/atlasRpc";
import {
  applyConfirmedNeedWorkbookReview,
  assembleConfirmedNeedPages,
  buildConfirmedNeedWorkbookSheets,
  confirmedNeedHiddenColumns,
  confirmedNeedMetaKeys,
  confirmedNeedVisibleColumns,
  confirmedNeedWorkbookColumns,
  confirmedNeedWorkbookVisibilityFeature,
  CONFIRMED_NEED_META_SHEET,
  CONFIRMED_NEED_OPERATOR_SHEET,
  CONFIRMED_NEED_WORKBOOK_CONTRACT,
  createConfirmedNeedWorkbookBlob,
  parseExactWorkbookNumber,
  readConfirmedNeedWorkbook,
  reviewConfirmedNeedWorkbook,
  type ConfirmedNeedReadWorkbook,
} from "./confirmedNeedWorkbook";
import {
  initialConfirmedNeedDraft,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import { createReviewConfirmedNeedApi } from "./reviewConfirmedNeedApi";

async function authority() {
  const api = createReviewConfirmedNeedApi("ready");
  const result = await api.getReview(
    "review-only-atlas-operator",
    crypto.randomUUID(),
    "c4500000-0000-0000-0000-000000000001",
    {
      service_date: null,
      school_id: null,
      delivery_location_id: null,
      ingredient_id: null,
      decision_state: null,
    },
    0,
    250,
  );
  if (result.kind !== "success") throw new Error("Fixture read failed");
  return structuredClone(
    result.response.workbench as unknown as ConfirmedNeedWorkbenchData,
  );
}

function draftsFor(workbench: ConfirmedNeedWorkbenchData) {
  return Object.fromEntries(
    workbench.lines.map((line) => [
      line.confirmed_need_line_id,
      initialConfirmedNeedDraft(line),
    ]),
  );
}

async function workbookFixture(
  mutateDraft?: (
    drafts: Record<string, ConfirmedNeedDraftLine>,
    workbench: ConfirmedNeedWorkbenchData,
  ) => void,
) {
  const workbench = await authority();
  const drafts = draftsFor(workbench);
  mutateDraft?.(drafts, workbench);
  const blob = await createConfirmedNeedWorkbookBlob(
    workbench,
    drafts,
    "2026-08-10T01:02:03.000Z",
  );
  return {
    workbench,
    drafts,
    workbook: await readConfirmedNeedWorkbook(blob),
  };
}

function sheets(workbook: ConfirmedNeedReadWorkbook) {
  return {
    operator: workbook.find(
      (sheet) => sheet.sheet === CONFIRMED_NEED_OPERATOR_SHEET,
    )!,
    meta: workbook.find((sheet) => sheet.sheet === CONFIRMED_NEED_META_SHEET)!,
  };
}

function cloneWorkbook(workbook: ConfirmedNeedReadWorkbook) {
  return structuredClone(workbook);
}

describe("Confirmed Need XLSX contract", () => {
  it("writes the exact visible columns, hidden identity columns and metadata", async () => {
    const { workbook } = await workbookFixture();
    const { operator, meta } = sheets(workbook);
    expect(operator.data[0]?.slice(0, 11)).toEqual(confirmedNeedVisibleColumns);
    expect(operator.data[0]?.slice(11)).toEqual(confirmedNeedHiddenColumns);
    expect(operator.data[0]).toEqual(confirmedNeedWorkbookColumns);
    expect(meta.data).toEqual([
      ["workbook_contract_version", CONFIRMED_NEED_WORKBOOK_CONTRACT],
      ["confirmed_need_batch_id", "c4500000-0000-0000-0000-000000000001"],
      ["batch_version", "1"],
      ["exported_at", "2026-08-10T01:02:03.000Z"],
    ]);
    expect(meta.data.map((row) => row[0])).toEqual(confirmedNeedMetaKeys);
    expect(
      operator.data.slice(1).every((row) => row.slice(11).length === 3),
    ).toBe(true);
  });

  it("serializes canonical quantities as text without Number conversion", async () => {
    const workbench = await authority();
    workbench.lines[0]!.theoretical_quantity = "99999999999999.123456";
    const drafts = draftsFor(workbench);
    drafts[workbench.lines[0]!.confirmed_need_line_id]!.exact_quantity =
      "99999999999999.123456";
    const { operatorData } = buildConfirmedNeedWorkbookSheets(
      workbench,
      drafts,
      "2026-08-10T00:00:00Z",
    );
    expect(operatorData[1]?.[5]).toMatchObject({
      value: "99999999999999.123456",
      type: String,
      format: "@",
    });
    expect(operatorData[1]?.[7]).toMatchObject({
      value: "99999999999999.123456",
      type: String,
      format: "@",
    });
  });

  it("captures XLSX numeric source text before JavaScript Number conversion", () => {
    expect(parseExactWorkbookNumber("99999999999999.123456")).toBe(
      "99999999999999.123456",
    );
    expect(typeof parseExactWorkbookNumber("0")).toBe("string");
  });

  it("assembles every page, preserves a stable order and rejects drift, duplicates and gaps", async () => {
    const full = await authority();
    const first = structuredClone(full);
    const second = structuredClone(full);
    first.lines = [full.lines[1]!];
    first.pagination = { offset: 0, limit: 1, total_lines: 2, has_more: true };
    second.lines = [full.lines[0]!];
    second.pagination = {
      offset: 1,
      limit: 1,
      total_lines: 2,
      has_more: false,
    };
    const assembled = assembleConfirmedNeedPages([first, second]);
    expect(assembled.lines.map((line) => line.service_date)).toEqual([
      "2026-08-03",
      "2026-08-04",
    ]);
    expect(assembled.lines).toHaveLength(2);

    const versionDrift = structuredClone(second);
    versionDrift.batch_version += 1;
    expect(() => assembleConfirmedNeedPages([first, versionDrift])).toThrow(
      /thay đổi/,
    );

    const duplicate = structuredClone(second);
    duplicate.lines = [first.lines[0]!];
    expect(() => assembleConfirmedNeedPages([first, duplicate])).toThrow(
      /trùng/,
    );

    const gap = structuredClone(second);
    gap.pagination.offset = 2;
    expect(() => assembleConfirmedNeedPages([first, gap])).toThrow(
      /không liên tục/,
    );
  });

  it("accepts explicit zero and the exact 14 integer / 6 fractional boundary", async () => {
    const zero = await workbookFixture((drafts, workbench) => {
      const id = workbench.lines[0]!.confirmed_need_line_id;
      drafts[id] = {
        selected: true,
        exact_quantity: "0",
        reason_code: "PLANNING_STEP_ADJUSTMENT",
        reason_note: "",
      };
      const maxId = workbench.lines[1]!.confirmed_need_line_id;
      drafts[maxId] = {
        selected: true,
        exact_quantity: "99999999999999.123456",
        reason_code: "PLANNING_STEP_ADJUSTMENT",
        reason_note: "",
      };
    });
    const review = reviewConfirmedNeedWorkbook(
      zero.workbook,
      zero.workbench,
      draftsFor(zero.workbench),
    );
    expect(review.canApply).toBe(true);
    expect(review.changedRows).toBe(2);
    expect(
      review.candidate?.[zero.workbench.lines[0]!.confirmed_need_line_id],
    ).toMatchObject({ exact_quantity: "0" });
  });

  it.each([
    ["", "blank"],
    ["-1", "negative"],
    ["100000000000000", "15 integer digits"],
    ["1.1234567", "7 fractional digits"],
    ["1e3", "exponent"],
    ["1,000.25", "ambiguous separators"],
  ])("rejects invalid quantity %s (%s)", async (value) => {
    const fixture = await workbookFixture();
    const workbook = cloneWorkbook(fixture.workbook);
    sheets(workbook).operator.data[1]![7] = value;
    const review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    expect(review.canApply).toBe(false);
    expect(review.errors.some((error) => error.field === "SL xác nhận")).toBe(
      true,
    );
  });

  it("enforces every-and-only rows: missing, duplicate and unknown are whole-workbook errors", async () => {
    const fixture = await workbookFixture();
    const missing = cloneWorkbook(fixture.workbook);
    sheets(missing).operator.data.splice(1, 1);
    const missingReview = reviewConfirmedNeedWorkbook(
      missing,
      fixture.workbench,
      fixture.drafts,
    );
    expect(missingReview.canApply).toBe(false);
    expect(
      missingReview.errors.some((error) => error.field === "Thiếu dòng"),
    ).toBe(true);
    expect(
      missingReview.errors.some((error) => error.message.includes("0")),
    ).toBe(true);

    const duplicate = cloneWorkbook(fixture.workbook);
    sheets(duplicate).operator.data.push([
      ...sheets(duplicate).operator.data[1]!,
    ]);
    expect(
      reviewConfirmedNeedWorkbook(
        duplicate,
        fixture.workbench,
        fixture.drafts,
      ).errors.some((error) => error.message.includes("bị trùng")),
    ).toBe(true);

    const unknown = cloneWorkbook(fixture.workbook);
    sheets(unknown).operator.data[1]![11] =
      "c4520000-0000-0000-0000-000000000099";
    expect(
      reviewConfirmedNeedWorkbook(
        unknown,
        fixture.workbench,
        fixture.drafts,
      ).errors.some((error) => error.message.includes("không thuộc")),
    ).toBe(true);
  });

  it("rejects stale batch version, revision and decision identity", async () => {
    const fixture = await workbookFixture();
    const staleBatch = cloneWorkbook(fixture.workbook);
    sheets(staleBatch).meta.data[2]![1] = "2";
    expect(
      reviewConfirmedNeedWorkbook(staleBatch, fixture.workbench, fixture.drafts)
        .errors[0]?.message,
    ).toContain("phiên bản dữ liệu cũ");

    const staleRevision = cloneWorkbook(fixture.workbook);
    sheets(staleRevision).operator.data[1]![12] = "stale-revision";
    expect(
      reviewConfirmedNeedWorkbook(
        staleRevision,
        fixture.workbench,
        fixture.drafts,
      ).errors.some((error) => error.field === "Phiên bản dòng"),
    ).toBe(true);

    const staleDecision = cloneWorkbook(fixture.workbook);
    sheets(staleDecision).operator.data[1]![13] = "stale-decision";
    expect(
      reviewConfirmedNeedWorkbook(
        staleDecision,
        fixture.workbench,
        fixture.drafts,
      ).errors.some((error) => error.field === "Quyết định hiện hành"),
    ).toBe(true);
  });

  it.each([0, 1, 2, 3, 4, 5, 6])(
    "rejects tampering with read-only reference column %i",
    async (column) => {
      const fixture = await workbookFixture();
      const workbook = cloneWorkbook(fixture.workbook);
      sheets(workbook).operator.data[1]![column] = "Đã sửa";
      const review = reviewConfirmedNeedWorkbook(
        workbook,
        fixture.workbench,
        fixture.drafts,
      );
      expect(review.canApply).toBe(false);
      expect(review.errors.some((error) => error.rowNumber === 2)).toBe(true);
    },
  );

  it("ignores workbook difference as authority and recalculates it locally", async () => {
    const fixture = await workbookFixture();
    const workbook = cloneWorkbook(fixture.workbook);
    sheets(workbook).operator.data[1]![8] = "999999";
    const review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    expect(review.canApply).toBe(true);
  });

  it("maps Vietnamese reasons, applies blank defaults and preserves note rules", async () => {
    const fixture = await workbookFixture();
    const workbook = cloneWorkbook(fixture.workbook);
    const operator = sheets(workbook).operator;
    operator.data[1]![9] = "";
    operator.data[2]![7] = "5.25";
    operator.data[2]![9] = "";
    let review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    expect(review.canApply).toBe(true);
    expect(
      review.candidate?.[fixture.workbench.lines[0]!.confirmed_need_line_id],
    ).toMatchObject({ reason_code: "PROPOSAL_ACCEPTED" });
    expect(
      review.candidate?.[fixture.workbench.lines[1]!.confirmed_need_line_id],
    ).toMatchObject({ reason_code: "PLANNING_STEP_ADJUSTMENT" });

    operator.data[2]![9] = "Lý do khác";
    operator.data[2]![10] = "";
    review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    expect(review.canApply).toBe(false);
    expect(
      review.errors.some((error) => error.message.includes("cần ghi chú")),
    ).toBe(true);

    operator.data[2]![9] = "Chấp nhận đề xuất";
    operator.data[2]![10] = "Ghi chú";
    review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    expect(
      review.errors.some((error) => error.message.includes("mâu thuẫn")),
    ).toBe(true);
  });

  it("reports review counts and applies valid changes only to the shared local draft", async () => {
    const fixture = await workbookFixture();
    const workbook = cloneWorkbook(fixture.workbook);
    const operator = sheets(workbook).operator;
    operator.data[2]![7] = "5.25";
    operator.data[2]![9] = "Điều chỉnh theo bước lượng";
    const review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    expect(review).toMatchObject({
      totalRows: 2,
      changedRows: 1,
      unchangedRows: 1,
      errorRows: 0,
      canApply: true,
    });
    expect(review.changedLines[0]).toMatchObject({
      differenceFromProposal: "+0.25",
    });
    const next = applyConfirmedNeedWorkbookReview(review, fixture.drafts);
    expect(
      next[fixture.workbench.lines[1]!.confirmed_need_line_id],
    ).toMatchObject({
      selected: true,
      exact_quantity: "5.25",
      reason_code: "PLANNING_STEP_ADJUSTMENT",
    });
  });

  it("never partially applies an invalid workbook and performs no API write", async () => {
    const fixture = await workbookFixture();
    const workbook = cloneWorkbook(fixture.workbook);
    sheets(workbook).operator.data[1]![7] = "10.5";
    sheets(workbook).operator.data[1]![9] = "Điều chỉnh theo bước lượng";
    sheets(workbook).operator.data[2]![7] = "invalid";
    const review = reviewConfirmedNeedWorkbook(
      workbook,
      fixture.workbench,
      fixture.drafts,
    );
    const before = structuredClone(fixture.drafts);
    expect(applyConfirmedNeedWorkbookReview(review, fixture.drafts)).toBe(
      fixture.drafts,
    );
    expect(fixture.drafts).toEqual(before);
    expect(review.candidate).toBeNull();
  });

  it("sets the narrow hidden-sheet and hidden-column XML attributes", () => {
    const workbookTransform =
      confirmedNeedWorkbookVisibilityFeature.files?.transform?.[
        "xl/workbook.xml"
      ]?.transformElementAttributes!;
    expect(
      workbookTransform("sheet", { name: "_ATLAS_META" }, 1, [], {}),
    ).toMatchObject({ state: "hidden" });

    const sheetTransform =
      confirmedNeedWorkbookVisibilityFeature.files?.transform?.[
        "xl/worksheets/sheet{id}.xml"
      ]?.transformElementAttributes!;
    const options = { columns: confirmedNeedWorkbookColumns.map(() => ({})) };
    expect(
      sheetTransform("col", { min: 12 }, 11, options, {
        sheetIndex: 0,
        sheetId: "1",
      }),
    ).toMatchObject({ hidden: 1 });
    expect(
      sheetTransform("col", { min: 11 }, 10, options, {
        sheetIndex: 0,
        sheetId: "1",
      }),
    ).not.toHaveProperty("hidden");
  });

  it("keeps workbook helpers independent of backend and RPC invocation", async () => {
    const workbench = await authority();
    const drafts = draftsFor(workbench);
    const invoke = vi.fn();
    buildConfirmedNeedWorkbookSheets(workbench, drafts, "2026-08-10T00:00:00Z");
    const blob = await createConfirmedNeedWorkbookBlob(workbench, drafts);
    reviewConfirmedNeedWorkbook(
      await readConfirmedNeedWorkbook(blob),
      workbench,
      drafts,
    );
    expect(invoke).not.toHaveBeenCalled();
  });
});
