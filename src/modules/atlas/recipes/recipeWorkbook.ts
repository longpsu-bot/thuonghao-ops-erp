import readXlsxFile, {
  type CellValue,
  type Sheet,
} from "read-excel-file/browser";
import type {
  RecipeIngredientReference,
  RecipeReference,
  RecipeUnitReference,
} from "./recipeModel";

const RECIPE_HEADERS = ["Tên món", "Loại công thức", "Tên công thức"] as const;
const BOM_HEADERS = [
  "Tên món",
  "Loại công thức",
  "Tên nguyên liệu",
  "Định lượng/100 suất",
  "Đơn vị mua (tham khảo)",
] as const;

export type CanonicalRecipeImportRow = {
  legacy_line_id: string;
  dish_legacy_id: string;
  recipe_legacy_id: string;
  dish_code: string;
  dish_name: string;
  dish_category: string | null;
  operational_notes: string | null;
  requires_need_generation: boolean;
  school_type_id: string | null;
  basis_portions: number;
  ingredient_id: string;
  quantity_per_basis: number;
  unit_id: string;
  operational_note: string | null;
};

export type RecipeWorkbookReview = {
  fileName: string;
  canonicalJson: string;
  checksum: string;
  rows: CanonicalRecipeImportRow[];
  errors: string[];
  warnings: string[];
  sourceCounts: {
    dishes: number;
    recipes: number;
    recipeVersions: number;
    recipeLines: number;
  };
  lifecycleInterpretation: string;
};

type References = {
  schoolTypes: RecipeReference[];
  ingredients: RecipeIngredientReference[];
  units: RecipeUnitReference[];
};

type WorkbookCell = CellValue | null;

const text = (value: WorkbookCell | undefined) =>
  value === null || value === undefined ? "" : String(value).trim();
const normalized = (value: string) =>
  value.normalize("NFC").trim().toLocaleLowerCase("vi");
const slug = (value: string) =>
  normalized(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);

function indexHeaders(row: WorkbookCell[]) {
  return new Map(row.map((value, index) => [normalized(text(value)), index]));
}

function valueAt(
  row: WorkbookCell[],
  headers: Map<string, number>,
  name: string,
) {
  const index = headers.get(normalized(name));
  return index === undefined ? "" : text(row[index]);
}

function hasHeaders(sheet: Sheet, required: readonly string[]) {
  if (!sheet.data.length) return false;
  const headers = indexHeaders(sheet.data[0]);
  return required.every((header) => headers.has(normalized(header)));
}

function decimal(value: string): number | null {
  const compact = value.replace(/\s/g, "");
  const normalizedDecimal =
    compact.includes(",") && compact.includes(".")
      ? compact.replace(/\./g, "").replace(",", ".")
      : compact.replace(",", ".");
  const result = Number(normalizedDecimal);
  return Number.isFinite(result) && result > 0 ? result : null;
}

function findReference<T>(
  value: string,
  items: T[],
  code: (item: T) => string,
  name: (item: T) => string,
) {
  const key = normalized(value);
  return items.find(
    (item) => normalized(code(item)) === key || normalized(name(item)) === key,
  );
}

function resolveSchoolType(value: string, schoolTypes: RecipeReference[]) {
  const key = normalized(value);
  if (
    !key ||
    ["chung", "công thức chung", "general", "toàn trường"].includes(key)
  )
    return { id: null, error: null };
  const schoolType = findReference(
    value,
    schoolTypes.filter((item) => item.school_type_status === "ACTIVE"),
    (item) => item.school_type_code,
    (item) => item.school_type_name,
  );
  return schoolType
    ? { id: schoolType.school_type_id, error: null }
    : {
        id: null,
        error: `Không tìm thấy loại trường đang hoạt động “${value}”.`,
      };
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function reviewRecipeWorkbook(
  file: File,
  references: References,
): Promise<RecipeWorkbookReview> {
  const errors: string[] = [];
  const warnings: string[] = [];
  if (!file.name.toLocaleLowerCase().endsWith(".xlsx")) {
    errors.push("Chỉ chấp nhận tệp .xlsx.");
  }
  const sheets = await readXlsxFile(file);
  const recipeSheet = sheets.find((sheet) => hasHeaders(sheet, RECIPE_HEADERS));
  const bomSheet = sheets.find((sheet) => hasHeaders(sheet, BOM_HEADERS));
  if (!recipeSheet)
    errors.push(`Thiếu trang có các cột: ${RECIPE_HEADERS.join(", ")}.`);
  if (!bomSheet)
    errors.push(`Thiếu trang có các cột: ${BOM_HEADERS.join(", ")}.`);

  const recipeMetadata = new Map<
    string,
    { recipeName: string; note: string | null }
  >();
  if (recipeSheet) {
    const headers = indexHeaders(recipeSheet.data[0]);
    recipeSheet.data.slice(1).forEach((row, index) => {
      const dishName = valueAt(row, headers, "Tên món");
      const scopeName = valueAt(row, headers, "Loại công thức");
      const recipeName = valueAt(row, headers, "Tên công thức");
      if (!dishName && !scopeName && !recipeName) return;
      if (!dishName || !recipeName) {
        errors.push(
          `Trang ${recipeSheet.sheet}, dòng ${index + 2}: thiếu Tên món hoặc Tên công thức.`,
        );
        return;
      }
      const key = `${normalized(dishName)}|${normalized(scopeName)}`;
      if (recipeMetadata.has(key)) {
        errors.push(
          `Trang ${recipeSheet.sheet}, dòng ${index + 2}: trùng phạm vi công thức của món “${dishName}”.`,
        );
        return;
      }
      recipeMetadata.set(key, {
        recipeName,
        note:
          valueAt(row, headers, "Ghi chú") ||
          valueAt(row, headers, "Ghi chú công thức") ||
          null,
      });
    });
  }

  const rows: CanonicalRecipeImportRow[] = [];
  if (bomSheet) {
    const headers = indexHeaders(bomSheet.data[0]);
    bomSheet.data.slice(1).forEach((row, index) => {
      const excelRow = index + 2;
      const dishName = valueAt(row, headers, "Tên món");
      const scopeName = valueAt(row, headers, "Loại công thức");
      const ingredientName = valueAt(row, headers, "Tên nguyên liệu");
      const quantityText = valueAt(row, headers, "Định lượng/100 suất");
      const unitName = valueAt(row, headers, "Đơn vị mua (tham khảo)");
      if (
        !dishName &&
        !scopeName &&
        !ingredientName &&
        !quantityText &&
        !unitName
      )
        return;
      const prefix = `Trang ${bomSheet.sheet}, dòng ${excelRow}`;
      if (!dishName || !ingredientName || !quantityText || !unitName) {
        errors.push(`${prefix}: thiếu một trường BOM bắt buộc.`);
        return;
      }
      const key = `${normalized(dishName)}|${normalized(scopeName)}`;
      const metadata = recipeMetadata.get(key);
      if (!metadata) {
        errors.push(
          `${prefix}: không có dòng công thức tương ứng cho món và loại công thức này.`,
        );
        return;
      }
      const schoolType = resolveSchoolType(scopeName, references.schoolTypes);
      if (schoolType.error) errors.push(`${prefix}: ${schoolType.error}`);
      const ingredient = findReference(
        ingredientName,
        references.ingredients.filter(
          (item) => item.ingredient_status === "ACTIVE",
        ),
        (item) => item.ingredient_code,
        (item) => item.ingredient_name,
      );
      if (!ingredient)
        errors.push(
          `${prefix}: nguyên liệu “${ingredientName}” không tồn tại hoặc không hoạt động.`,
        );
      const unit = findReference(
        unitName,
        references.units.filter((item) => item.unit_status === "ACTIVE"),
        (item) => item.unit_code,
        (item) => item.unit_name,
      );
      if (!unit)
        errors.push(
          `${prefix}: đơn vị “${unitName}” không tồn tại hoặc không hoạt động.`,
        );
      const quantity = decimal(quantityText);
      if (!quantity) errors.push(`${prefix}: định lượng phải là số dương.`);
      if (!ingredient || !unit || !quantity || schoolType.error) return;

      const dishKey = slug(dishName);
      const scopeKey = schoolType.id ?? "general";
      const ingredientKey = slug(ingredient.ingredient_code);
      rows.push({
        legacy_line_id: `ops-v1:${dishKey}:${scopeKey}:${ingredientKey}`,
        dish_legacy_id: `ops-v1:dish:${dishKey}`,
        recipe_legacy_id: `ops-v1:recipe:${dishKey}:${scopeKey}`,
        dish_code: dishKey,
        dish_name: dishName,
        dish_category: null,
        operational_notes: metadata.note,
        requires_need_generation: true,
        school_type_id: schoolType.id,
        basis_portions: 100,
        ingredient_id: ingredient.ingredient_id,
        quantity_per_basis: quantity,
        unit_id: unit.unit_id,
        operational_note: valueAt(row, headers, "Ghi chú") || null,
      });
    });
  }

  const lineIds = new Set<string>();
  for (const row of rows) {
    if (lineIds.has(row.legacy_line_id))
      errors.push(
        `BOM có nhiều dòng cho cùng nguyên liệu trong phạm vi ${row.recipe_legacy_id}.`,
      );
    lineIds.add(row.legacy_line_id);
  }
  if (!rows.length && !errors.length)
    warnings.push("Workbook không có dòng BOM để nhập.");

  rows.sort((left, right) =>
    left.legacy_line_id.localeCompare(right.legacy_line_id),
  );
  const canonicalJson = JSON.stringify({ rows });
  const checksum = await sha256(canonicalJson);
  const dishIds = new Set(rows.map((row) => row.dish_legacy_id));
  const recipeIds = new Set(rows.map((row) => row.recipe_legacy_id));
  return {
    fileName: file.name,
    canonicalJson,
    checksum,
    rows,
    errors,
    warnings,
    sourceCounts: {
      dishes: dishIds.size,
      recipes: recipeIds.size,
      recipeVersions: recipeIds.size,
      recipeLines: rows.length,
    },
    lifecycleInterpretation:
      "Dữ liệu OPS v1 được diễn giải thành phiên bản công thức NHÁP trong Atlas; không tự xác thực hoặc phát hành.",
  };
}
