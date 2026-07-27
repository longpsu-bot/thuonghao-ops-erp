import { beforeEach, describe, expect, it, vi } from "vitest";
import readXlsxFile from "read-excel-file/browser";
import { reviewRecipeWorkbook } from "./recipeWorkbook";

vi.mock("read-excel-file/browser", () => ({
  default: vi.fn(),
}));

const references = {
  schoolTypes: [
    {
      school_type_id: "school-type-primary",
      school_type_code: "TIEU_HOC",
      school_type_name: "Tiểu học",
      school_type_status: "ACTIVE" as const,
    },
  ],
  ingredients: [
    {
      ingredient_id: "ingredient-pork",
      ingredient_code: "THIT_HEO",
      ingredient_name: "Thịt heo",
      ingredient_status: "ACTIVE" as const,
    },
  ],
  units: [
    {
      unit_id: "unit-kg",
      unit_code: "KG",
      unit_name: "Kilôgam",
      unit_status: "ACTIVE" as const,
    },
  ],
};

const workbook = (
  ingredientName = "Thịt heo",
  quantity: string | number = "22,5",
) => [
  {
    sheet: "Công thức",
    data: [
      ["Tên món", "Loại công thức", "Tên công thức", "Ghi chú"],
      ["Canh bí đỏ", "Tiểu học", "Canh bí đỏ tiểu học", "Nấu trong ngày"],
    ],
  },
  {
    sheet: "Định lượng",
    data: [
      [
        "Tên món",
        "Loại công thức",
        "Tên nguyên liệu",
        "Định lượng/100 suất",
        "Đơn vị mua (tham khảo)",
        "Ghi chú",
      ],
      ["Canh bí đỏ", "Tiểu học", ingredientName, quantity, "KG", "Sơ chế sạch"],
    ],
  },
];

describe("OPS v1 recipe workbook review", () => {
  beforeEach(() => {
    vi.mocked(readXlsxFile).mockResolvedValue(workbook());
  });

  it("creates deterministic draft-only import rows with decimal-comma support", async () => {
    const review = await reviewRecipeWorkbook(
      new File(["fixture"], "ops-v1.xlsx"),
      references,
    );

    expect(review.errors).toEqual([]);
    expect(review.rows).toHaveLength(1);
    expect(review.rows[0]).toMatchObject({
      dish_code: "canh-bi-do",
      dish_name: "Canh bí đỏ",
      school_type_id: "school-type-primary",
      ingredient_id: "ingredient-pork",
      quantity_per_basis: 22.5,
      unit_id: "unit-kg",
      basis_portions: 100,
      operational_note: "Sơ chế sạch",
    });
    expect(JSON.parse(review.canonicalJson)).toEqual({ rows: review.rows });
    expect(review.checksum).toMatch(/^[a-f0-9]{64}$/);
    expect(review.sourceCounts).toEqual({
      dishes: 1,
      recipes: 1,
      recipeVersions: 1,
      recipeLines: 1,
    });
    expect(review.lifecycleInterpretation).toContain("NHÁP");
  });

  it("rejects unknown references and never proposes creating them", async () => {
    vi.mocked(readXlsxFile).mockResolvedValue(workbook("Nguyên liệu lạ", 10));

    const review = await reviewRecipeWorkbook(
      new File(["fixture"], "ops-v1.xlsx"),
      references,
    );

    expect(review.rows).toEqual([]);
    expect(review.errors).toEqual([expect.stringContaining("Nguyên liệu lạ")]);
  });

  it("rejects non-xlsx inputs while preserving row-level review evidence", async () => {
    const review = await reviewRecipeWorkbook(
      new File(["fixture"], "ops-v1.xls"),
      references,
    );

    expect(review.errors[0]).toBe("Chỉ chấp nhận tệp .xlsx.");
    expect(review.rows).toHaveLength(1);
  });
});
