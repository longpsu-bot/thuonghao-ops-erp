/** Local review input only; production parsing remains recipeWorkbook. */
export async function recipeReviewWorkbook(invalid = false): Promise<File> {
  const { default: ExcelJS } = await import("exceljs");
  const workbook = new ExcelJS.Workbook();
  const recipes = workbook.addWorksheet("Công thức");
  recipes.addRow(["Tên món", "Loại công thức", "Tên công thức"]);
  recipes.addRow(["Canh bí đỏ thịt bằm", "Khối nhỏ", "Công thức mẫu"]);
  const bom = workbook.addWorksheet("Định lượng");
  bom.addRow([
    "Tên món",
    "Loại công thức",
    "Tên nguyên liệu",
    "Định lượng/100 suất",
    "Đơn vị mua (tham khảo)",
  ]);
  bom.addRow([
    "Canh bí đỏ thịt bằm",
    "Khối nhỏ",
    invalid ? "Nguyên liệu chưa có" : "Bí đỏ",
    "22,5",
    "Kilôgam",
  ]);
  return new File(
    [await workbook.xlsx.writeBuffer()],
    invalid ? "workbook-can-sua.xlsx" : "workbook-hop-le.xlsx",
    {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    },
  );
}
