import readXlsxFile from "read-excel-file/browser";
import { describe, expect, it, vi } from "vitest";
import type {
  PlanningDish,
  PlanningDishType,
  PlanningSchool,
} from "./planningInputsModel";
import {
  browserChecksum,
  parseAttendancePaste,
  parseAttendanceWorkbook,
  parseMenuMatrix,
  parseMenuWorkbook,
} from "./planningInputsWorkbook";

vi.mock("read-excel-file/browser", () => ({ default: vi.fn() }));

const schools: PlanningSchool[] = [
  {
    school_id: "school-1",
    school_code: "TH001",
    school_name: "Trường Nguyễn Du",
    school_status: "ACTIVE",
    display_order: 1,
    school_type_id: null,
    default_student_portions: 100,
    default_teacher_portions: 10,
  },
];
const dishTypes: PlanningDishType[] = [
  {
    dish_type_id: "type-soup",
    dish_type_code: "soup",
    dish_type_name: "Món canh",
    source_header_aliases: ["Món Canh", "Canh"],
    display_order: 1,
    dish_type_status: "ACTIVE",
    version: 1,
  },
  {
    dish_type_id: "type-beverage",
    dish_type_code: "beverage",
    dish_type_name: "Nước",
    source_header_aliases: ["Đồ uống"],
    display_order: 6,
    dish_type_status: "ACTIVE",
    version: 1,
  },
];
const dishes: PlanningDish[] = [
  {
    dish_id: "dish-1",
    dish_code: "CANH-BI",
    dish_name: "Canh bí",
    dish_type_id: "type-soup",
    dish_type_code: "soup",
    dish_type_name: "Món canh",
    dish_status: "ACTIVE",
    display_order: 1,
    requires_need_generation: true,
  },
  {
    dish_id: "dish-2",
    dish_code: "NUOC-CAM",
    dish_name: "Nước cam",
    dish_type_id: "type-beverage",
    dish_type_code: "beverage",
    dish_type_name: "Nước",
    dish_status: "ACTIVE",
    display_order: 2,
    requires_need_generation: false,
  },
];

describe("Planning workbook canonicalization", () => {
  it("preserves explicit zero attendance and unresolved schools for backend blockers", () => {
    const rows = parseAttendancePaste(
      [
        "TH001\t03/08/2026\t0\t0",
        "Trường không tồn tại\t2026-08-04\t12\t2",
      ].join("\n"),
      schools,
    );
    expect(rows[0]).toMatchObject({
      school_id: "school-1",
      service_date: "2026-08-03",
      student_portions: 0,
      teacher_portions: 0,
    });
    expect(rows[1].school_id).toMatch(/^unresolved:school:/);
  });

  it("produces an order-independent browser SHA-256 review checksum", async () => {
    const fields = ["school_id", "service_date", "student_portions"];
    const left = [
      {
        school_id: "school-2",
        service_date: "2026-08-04",
        student_portions: 20,
      },
      {
        school_id: "school-1",
        service_date: "2026-08-03",
        student_portions: 10,
      },
    ];
    await expect(browserChecksum(left, fields)).resolves.toBe(
      await browserChecksum([...left].reverse(), fields),
    );
  });

  it("finds row-three Menu headers and maps Vietnamese labels to stable slot codes", async () => {
    vi.mocked(readXlsxFile).mockResolvedValueOnce([
      {
        sheet: "Hướng dẫn",
        data: [["Không phải dữ liệu thực đơn"]],
      },
      {
        sheet: "Tuần 03-08-2026",
        data: [
          ["Thực đơn tuần"],
          [],
          [
            "Ngày",
            "Thứ",
            "Tên trường",
            "Món Canh",
            "Món Mặn",
            "Món Xào",
            "Tráng miệng",
            "Buổi xế",
          ],
          ["03/08/2026", "Thứ hai", "TH001", "Canh bí", "", "", "", ""],
        ],
      },
    ]);
    const review = await parseMenuWorkbook(
      new File(["fixture"], "menu.xlsx"),
      dishTypes,
      schools,
      dishes,
    );
    expect(review.errors).toEqual([]);
    expect(review.fileName).toBe("menu.xlsx / Tuần 03-08-2026");
    expect(review.rows).toEqual([
      expect.objectContaining({
        school_id: "school-1",
        service_date: "2026-08-03",
        menu_slot_code: "soup",
        dish_id: "dish-1",
        source_row_reference: "menu.xlsx:Tuần 03-08-2026:row:4:soup",
      }),
    ]);
  });

  it("uses the same database-driven parser for Google matrices, aliases, and added types", async () => {
    const review = await parseMenuMatrix(
      [
        [],
        ["Tên trường", "Ngày", "Canh", "Đồ uống", "Thứ"],
        ["TH001", "03/08/2026", "CANH-BI", "NUOC-CAM", "Thứ hai"],
      ],
      {
        sourceName: "Nguồn Google thử",
        sheetName: "Tuần 03-08-2026",
        firstRowNumber: 3,
      },
      dishTypes,
      schools,
      dishes,
    );
    expect(review.errors).toEqual([]);
    expect(review.rows).toEqual([
      expect.objectContaining({
        menu_slot_code: "soup",
        dish_id: "dish-1",
      }),
      expect.objectContaining({
        menu_slot_code: "beverage",
        dish_id: "dish-2",
      }),
    ]);
    expect(review.headerRowNumber).toBe(4);
  });

  it("accepts documented Attendance header aliases without inferring blanks as zero", async () => {
    vi.mocked(readXlsxFile).mockResolvedValueOnce([
      {
        sheet: "Sĩ số",
        data: [
          ["Tên trường", "Ngày", "Sĩ số học sinh", "Sĩ số giáo viên"],
          ["TH001", "2026-08-03", "", "0"],
        ],
      },
    ]);
    const review = await parseAttendanceWorkbook(
      new File(["fixture"], "attendance.xlsx"),
      schools,
    );
    expect(review.errors).toEqual([]);
    expect(Number.isNaN(review.rows[0].student_portions)).toBe(true);
    expect(review.rows[0].teacher_portions).toBe(0);
  });
});

describe("typed duplicate Dish names", () => {
  it("resolves the same Dish name within the source column Dish Type", async () => {
    const typedDishTypes: PlanningDishType[] = [
      {
        dish_type_id: "type-savory",
        dish_type_code: "savory",
        dish_type_name: "Món mặn",
        source_header_aliases: ["Món Mặn"],
        display_order: 2,
        dish_type_status: "ACTIVE",
        version: 1,
      },
      {
        dish_type_id: "type-snack",
        dish_type_code: "afternoon_snack",
        dish_type_name: "Món xế",
        source_header_aliases: ["Buổi xế"],
        display_order: 5,
        dish_type_status: "ACTIVE",
        version: 1,
      },
    ];
    const typedDishes: PlanningDish[] = [
      {
        dish_id: "dish-snack",
        dish_code: "v1-dish-1436",
        dish_name: "Cà ri gà + bánh mì",
        dish_type_id: "type-snack",
        dish_type_code: "afternoon_snack",
        dish_type_name: "Món xế",
        dish_status: "ACTIVE",
        display_order: 1,
        requires_need_generation: true,
      },
      {
        dish_id: "dish-savory",
        dish_code: "v1-dish-1984",
        dish_name: "Cà ri gà + bánh mì",
        dish_type_id: "type-savory",
        dish_type_code: "savory",
        dish_type_name: "Món mặn",
        dish_status: "ACTIVE",
        display_order: 2,
        requires_need_generation: true,
      },
    ];
    const review = await parseMenuMatrix(
      [
        ["Tên trường", "Ngày", "Món Mặn", "Buổi xế"],
        ["TH001", "2026-08-03", "Cà ri gà + bánh mì", "Cà ri gà + bánh mì"],
      ],
      { sourceName: "Google", sheetName: "Tuần" },
      typedDishTypes,
      schools,
      typedDishes,
    );
    expect(review.rows).toEqual([
      expect.objectContaining({
        menu_slot_code: "savory",
        dish_id: "dish-savory",
      }),
      expect.objectContaining({
        menu_slot_code: "afternoon_snack",
        dish_id: "dish-snack",
      }),
    ]);
  });
});

describe("canonical Dish identity independent of Menu slot", () => {
  const slots: PlanningDishType[] = [
    {
      ...dishTypes[0],
      dish_type_id: "savory",
      dish_type_code: "savory",
      dish_type_name: "Món mặn",
      source_header_aliases: [],
    },
    {
      ...dishTypes[0],
      dish_type_id: "snack",
      dish_type_code: "afternoon_snack",
      dish_type_name: "Buổi xế",
      source_header_aliases: [],
    },
    {
      ...dishTypes[0],
      dish_type_id: "dessert",
      dish_type_code: "dessert",
      dish_type_name: "Tráng miệng",
      source_header_aliases: [],
    },
  ];
  const curry: PlanningDish = {
    ...dishes[0],
    dish_id: "curry",
    dish_code: "CURRY",
    dish_name: "Cà ri gà + bánh mì",
    dish_type_id: "savory",
    dish_type_code: "savory",
  };
  const parse = (catalog: PlanningDish[], values: string[]) =>
    parseMenuMatrix(
      [
        ["Tên trường", "Ngày", "Món mặn", "Buổi xế", "Tráng miệng"],
        ["TH001", "2026-08-03", ...values],
      ],
      { sourceName: "Google", sheetName: "Tuần", firstRowNumber: 3 },
      slots,
      schools,
      catalog,
    );
  it.each(["savory", null])(
    "uses one unique Dish across both slots with legacy type %s",
    async (legacy) => {
      const review = await parse(
        [{ ...curry, dish_type_id: legacy, dish_type_code: legacy }],
        [curry.dish_name, curry.dish_name],
      );
      expect(
        review.rows.map((row) => [row.menu_slot_code, row.dish_id]),
      ).toEqual([
        ["savory", "curry"],
        ["afternoon_snack", "curry"],
      ]);
      expect(review.diagnostics).toEqual([]);
      expect(review.compatibilityResolutions).toEqual([]);
    },
  );
  it("gives global code identity precedence over a same-name slot candidate", async () => {
    const review = await parse(
      [
        curry,
        {
          ...curry,
          dish_id: "other",
          dish_code: "OTHER",
          dish_name: "CURRY",
          dish_type_id: "snack",
          dish_type_code: "afternoon_snack",
        },
      ],
      ["", " curry "],
    );
    expect(review.rows[0].dish_id).toBe("curry");
  });
  it.each(["Cà ri gà + bánh mì", "Sâm bổ lượng"])(
    "records deterministic legacy duplicate compatibility for %s",
    async (name) => {
      const catalog = [
        { ...curry, dish_name: name },
        {
          ...curry,
          dish_id: "snack-dish",
          dish_code: "SNACK",
          dish_name: name,
          dish_type_id: "snack",
          dish_type_code: "afternoon_snack",
        },
      ];
      for (const ordered of [catalog, [...catalog].reverse()]) {
        const review = await parse(ordered, [name, name]);
        expect(review.rows.map((row) => row.dish_id)).toEqual([
          "curry",
          "snack-dish",
        ]);
        expect(review.diagnostics).toEqual([]);
        expect(review.compatibilityResolutions).toHaveLength(2);
      }
    },
  );
  it("uses dessert/snack compatibility for duplicated Sâm bổ lượng", async () => {
    const name = "Sâm bổ lượng";
    const review = await parse(
      [
        {
          ...curry,
          dish_name: name,
          dish_id: "dessert-dish",
          dish_type_id: "dessert",
          dish_type_code: "dessert",
        },
        {
          ...curry,
          dish_name: name,
          dish_id: "snack-dish",
          dish_code: "SNACK",
          dish_type_id: "snack",
          dish_type_code: "afternoon_snack",
        },
      ],
      ["", name, name],
    );
    expect(review.rows.map((row) => row.dish_id)).toEqual([
      "snack-dish",
      "dessert-dish",
    ]);
    expect(review.compatibilityResolutions).toHaveLength(2);
    expect(review.diagnostics).toEqual([]);
  });
  it("resolves unique Sâm bổ lượng in dessert and snack", async () => {
    const review = await parse(
      [
        {
          ...curry,
          dish_name: "Sâm bổ lượng",
          dish_type_id: "dessert",
          dish_type_code: "dessert",
        },
      ],
      ["", "Sâm bổ lượng", "Sâm bổ lượng"],
    );
    expect(review.rows.map((row) => row.dish_id)).toEqual(["curry", "curry"]);
    expect(review.diagnostics).toEqual([]);
  });
  it.each([0, 2])(
    "blocks duplicate names with %s legacy slot candidates",
    async (matches) => {
      const catalog = [
        curry,
        { ...curry, dish_id: "duplicate", dish_code: "DUP" },
      ].map((d) => ({
        ...d,
        dish_type_id: matches ? "snack" : "savory",
        dish_type_code: matches ? "afternoon_snack" : "savory",
      }));
      const review = await parse(catalog, ["", curry.dish_name]);
      expect(review.diagnostics).toEqual([
        expect.objectContaining({
          code: "AMBIGUOUS_DISH",
          source_row_number: 4,
          source_value: curry.dish_name,
          menu_slot_code: "afternoon_snack",
          menu_slot_name: "Buổi xế",
        }),
      ]);
    },
  );
  it("diagnoses unknown and inactive-only names without choosing an inactive Dish", async () => {
    const review = await parse(
      [{ ...curry, dish_status: "INACTIVE" }],
      ["Cá kho tiêu", curry.dish_name],
    );
    expect(review.diagnostics.map((issue) => issue.code)).toEqual([
      "UNKNOWN_DISH",
      "UNKNOWN_DISH",
    ]);
  });
});
