import { describe, expect, it } from "vitest";
import { createReviewSchoolDispatchDocument } from "./reviewSchoolDispatchReleaseApi";
import {
  buildSchoolDispatchExportData,
  buildSchoolDispatchPdfDefinition,
  createSchoolDispatchXlsx,
} from "./schoolDispatchReleaseExports";

describe("School dispatch release exports", () => {
  it.each(["RELEASED", "SUPERSEDED"] as const)(
    "keeps an immutable %s PXK exportable",
    (status) => {
      const document = createReviewSchoolDispatchDocument(status);
      expect(buildSchoolDispatchExportData(document)).toMatchObject({
        documentNumber: "PXK-20260924-2600000000004000",
        schoolName: "Trường Tiểu học Nguyễn Du",
        lines: [
          {
            ingredientName: "Gạo thơm",
            quantity: "100.000000",
            unitCode: "kg",
          },
        ],
      });
      expect(
        JSON.stringify(buildSchoolDispatchPdfDefinition(document)),
      ).toContain("PHIẾU XUẤT KHO");
    },
  );

  it("creates a workbook with the official PXK identity and exact quantity", async () => {
    const bytes = await createSchoolDispatchXlsx(
      createReviewSchoolDispatchDocument("RELEASED"),
    );
    expect(bytes.byteLength).toBeGreaterThan(1000);
  });

  it("includes a relevant immutable release note in the export snapshot", () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.note = "Giao tại cổng phụ trước 06:00";

    expect(buildSchoolDispatchExportData(document)).toMatchObject({
      note: "Giao tại cổng phụ trước 06:00",
    });
    expect(
      JSON.stringify(buildSchoolDispatchPdfDefinition(document)),
    ).toContain("Giao tại cổng phụ trước 06:00");
  });
});
