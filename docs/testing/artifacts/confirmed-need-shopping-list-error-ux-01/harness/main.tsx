// Local fixture only: real production components and XLSX, no hosted connection.
import ExcelJS from "exceljs";
import { createRoot } from "react-dom/client";
import { AtlasVNextProvider } from "../../../../../src/vnext/atlas/AtlasVNextProvider";
import { AtlasVNextShell } from "../../../../../src/vnext/atlas/AtlasVNextShell";
import { ConfirmedNeedWorkbench } from "../../../../../src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
} from "../../../../../src/vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";
import {
  createConfirmedNeedShoppingListXlsx,
  downloadConfirmedNeedShoppingList,
  importConfirmedNeedShoppingList,
} from "../../../../../src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedShoppingList";
import { initialConfirmedNeedDraft } from "../../../../../src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel";

const fixture = createConfirmedNeedReviewFixture("normal");
const evidence = { saveCalls: 0 };
const save = fixture.confirmedNeedApi.save.bind(fixture.confirmedNeedApi);
fixture.confirmedNeedApi.save = (...args) => {
  evidence.saveCalls++;
  return save(...args);
};
Object.assign(window, {
  shoppingListEvidence: evidence,
  shoppingListFixtureBytes: async (state: "stale" | "edited") => {
    const drafts = Object.fromEntries(
      fixture.batch.lines.map((line) => [
        line.confirmed_need_line_id,
        initialConfirmedNeedDraft(line),
      ]),
    );
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createConfirmedNeedShoppingListXlsx(fixture.batch, drafts),
    );
    if (state === "stale")
      workbook.worksheets[0]!.getCell("F4").value = "stale-fixture";
    else {
      workbook.worksheets[0]!.getCell("D4").value = 12.5;
      workbook.worksheets[0]!.getCell("E4").value =
        "Điều chỉnh từ Phiếu đi chợ";
    }
    return Array.from(new Uint8Array(await workbook.xlsx.writeBuffer()));
  },
});
createRoot(document.getElementById("root")!).render(
  <AtlasVNextProvider>
    <AtlasVNextShell activeModule="planning">
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="fixture-operator"
        initialServiceDate={reviewDate}
        onContinueAllocation={() => {}}
        onExportShoppingList={downloadConfirmedNeedShoppingList}
        onImportShoppingList={importConfirmedNeedShoppingList}
      />
    </AtlasVNextShell>
  </AtlasVNextProvider>,
);
