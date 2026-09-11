import { describe, expect, it } from "vitest";
import { checkSources } from "./check-atlas-vnext-ui-boundary.mjs";

describe("Atlas vNext presentation boundary", () => {
  it("permits only reviewed School PXK API/model bridge modules", () => {
    for (const module of [
      "schoolDispatchReleaseApi",
      "schoolDispatchReleaseModel",
    ]) {
      const source = `export * from "@/modules/atlas/dispatch/${module}";`;
      expect(
        checkSources({ "src/vnext/atlas/bridges/schoolDispatch.ts": source }),
      ).toEqual([]);
      expect(
        checkSources({ "src/vnext/atlas/dispatch/View.tsx": source }),
      ).toHaveLength(1);
    }
    for (const module of [
      "SchoolDispatchReleaseWorkbench",
      "schoolDispatchReleaseExports",
      "schoolFulfilmentReconciliationApi",
      "schoolFulfilmentReconciliationModel",
      "SchoolFulfilmentReconciliationWorkbench",
    ]) {
      expect(
        checkSources({
          "src/vnext/atlas/bridges/schoolDispatch.ts": `export * from "@/modules/atlas/dispatch/${module}";`,
        }),
      ).toHaveLength(1);
    }
  });
  it("permits only the six downstream Planning business modules through a bridge", () => {
    for (const module of [
      "readiness/planningInputReadinessApi",
      "readiness/planningInputReadinessModel",
      "need-generation/needGenerationApi",
      "need-generation/needGenerationModel",
      "confirmed-needs/confirmedNeedApi",
      "confirmed-needs/confirmedNeedModel",
    ]) {
      const source = `export * from "@/modules/atlas/planning-inputs/${module}";`;
      expect(
        checkSources({ "src/vnext/atlas/bridges/confirmedNeed.ts": source }),
      ).toEqual([]);
      expect(
        checkSources({ "src/vnext/atlas/planning-confirmed/View.tsx": source }),
      ).toHaveLength(1);
    }
    for (const module of [
      "need-generation/NeedGenerationWorkbench",
      "confirmed-needs/ConfirmedNeedReviewWorkbench",
    ]) {
      expect(
        checkSources({
          "src/vnext/atlas/bridges/confirmedNeed.ts": `export * from "@/modules/atlas/planning-inputs/${module}";`,
        }),
      ).toHaveLength(1);
    }
  });
  it("permits reviewed Planning business dependencies only inside bridges", () => {
    for (const module of [
      "planningInputsApi",
      "planningInputsModel",
      "planningInputsWorkbook",
      "planningCorrectionApi",
      "planningSchoolScope",
      "pantry/pantryApi",
      "pantry/pantryModel",
    ]) {
      const source = `export * from "@/modules/atlas/planning-inputs/${module}";`;
      expect(
        checkSources({ "src/vnext/atlas/bridges/planning.ts": source }),
      ).toEqual([]);
      expect(
        checkSources({ "src/vnext/atlas/planning/View.tsx": source }),
      ).toHaveLength(1);
    }
  });
  it.each([
    "PlanningInputsWorkbench",
    "PlanningOperatingRail",
    "PlanningRailActionPortal",
    "PlanningCorrectionImpactPanel",
    "PlanningSchoolScopeControl",
    "pantry/PantryWorkbench",
  ])("rejects Planning presentation %s through a bridge", (module) => {
    expect(
      checkSources({
        "src/vnext/atlas/bridges/planning.ts": `export * from "@/modules/atlas/planning-inputs/${module}";`,
      }),
    ).toHaveLength(1);
  });
  it("approves the five reviewed Procurement business modules only through bridges", () => {
    const modules = [
      "procurement/purchaseReviewApi",
      "procurement/schoolCateringProcurementApi",
      "procurement/schoolCateringProcurementModel",
      "procurement/procurementOperatorCopy",
      "connection/atlasRpc",
    ];
    for (const module of modules) {
      expect(
        checkSources({
          "src/vnext/atlas/bridges/procurement.ts": `export * from "@/modules/atlas/${module}";`,
        }),
      ).toEqual([]);
      expect(
        checkSources({
          "src/vnext/atlas/procurement/View.tsx": `import type { Data } from "@/modules/atlas/${module}";`,
        }),
      ).toHaveLength(1);
    }
  });
  it.each([
    "AllocationFamilyTable",
    "SupplierSplitPanel",
    "PurchaseOrderStage",
    "ProcurementCommandResult",
    "purchaseOrderExports",
  ])("does not approve %s through the Procurement bridge", (module) => {
    expect(
      checkSources({
        "src/vnext/atlas/bridges/procurement.ts": `export * from "@/modules/atlas/procurement/${module}";`,
      }),
    ).toHaveLength(1);
  });
  it("permits Chakra-only vNext and an explicitly approved API through a bridge", () => {
    expect(
      checkSources(
        {
          "src/vnext/atlas/View.tsx":
            'import { Box } from "@chakra-ui/react"; import { api } from "./bridges/procurement";',
          "src/vnext/atlas/bridges/procurement.ts":
            'export { api } from "../../../modules/atlas/procurement/procurementApi";',
        },
        ["src/modules/atlas/procurement/procurementApi"],
      ),
    ).toEqual([]);
  });
  it("rejects direct legacy API reuse outside the bridge", () => {
    expect(
      checkSources(
        {
          "src/vnext/atlas/View.tsx":
            'import { api } from "../../modules/atlas/procurement/procurementApi";',
        },
        ["src/modules/atlas/procurement/procurementApi"],
      ),
    ).toHaveLength(1);
  });
  it.each(["src/vnext/atlas/View.tsx", "src/vnext/atlas/bridges/unsafe.ts"])(
    "rejects indirect legacy presentation from %s",
    (file) => {
      expect(
        checkSources({
          [file]:
            'import { Workbench } from "@/modules/atlas/procurement/SchoolCateringProcurementWorkbench";',
          "src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx":
            'import { Button } from "@mantine/core";',
        }),
      ).toHaveLength(1);
    },
  );
  it("does not permit unapproved business bridges or legacy CSS", () => {
    expect(
      checkSources({
        "src/vnext/atlas/bridges/unapproved.ts":
          'export { api } from "@/modules/atlas/api";',
      }),
    ).toHaveLength(1);
    expect(
      checkSources({
        "src/vnext/atlas/View.tsx": 'import "@/modules/atlas/workbench.css";',
      }),
    ).toHaveLength(1);
  });
  it.each([
    "@mantine/core",
    "@mantine/dates",
    "@mantine/hooks",
    "@mantine/core/styles.css",
  ])("rejects %s under vNext", (name) => {
    expect(
      checkSources({ "src/vnext/atlas/View.tsx": `import "${name}";` }),
    ).toHaveLength(1);
  });
  it.each([
    "../../theme",
    "../../theme.ts",
    "../../styles.css",
    "@/theme",
    "@/styles.css",
    "/src/theme.ts",
    "src/styles.css?inline",
  ])("rejects legacy presentation import %s", (name) => {
    expect(
      checkSources({
        "src/vnext/atlas/View.tsx": `import theme from "${name}";`,
      }),
    ).toHaveLength(1);
  });
  it.each([
    'import { Button } from "@chakra-ui/react"',
    'export { Button } from "@chakra-ui/react"',
    'const ui = import("@chakra-ui/react")',
    'const ui = require("@chakra-ui/react")',
  ])("rejects Chakra in legacy source: %s", (source) => {
    expect(
      checkSources({ "src/modules/atlas/Legacy.tsx": source }),
    ).toHaveLength(1);
  });
  it("ignores comments and permits legacy Mantine", () => {
    expect(
      checkSources({
        "src/modules/atlas/Legacy.tsx":
          '/* import "@chakra-ui/react" */\nimport "@mantine/core";',
        "src/vnext/atlas/View.tsx":
          '// import "@mantine/hooks"\nimport "@chakra-ui/react";',
      }),
    ).toEqual([]);
  });
  it("reports deterministically by path", () => {
    const sources = {
      "src/z.ts": 'import "@chakra-ui/react"',
      "src/a.ts": 'import "@chakra-ui/react"',
    };
    expect(checkSources(sources)[0]).toContain("src/a.ts");
  });
});
