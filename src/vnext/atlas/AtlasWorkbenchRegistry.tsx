import type { ReactNode, RefObject } from "react";
import {
  Buildings,
  ClipboardText,
  CookingPot,
  Package,
  Scales,
  ShoppingCart,
  Truck,
  type Icon,
} from "@phosphor-icons/react";
import type { AtlasVNextAppProps } from "./AtlasVNextApp";
import type {
  AtlasModuleExitHandle,
  AtlasWorkbenchStatus,
} from "./AtlasModuleExit";
import { SchoolDefaultsWorkbench } from "./schools/SchoolDefaultsWorkbench";
import { IngredientSupplierWorkbench } from "./master-data/IngredientSupplierWorkbench";
import { RecipeCapability } from "./recipes/RecipeCapability";
import { PlanningCapability } from "./planning/PlanningCapability";
import { ProcurementWorkbench } from "./procurement/ProcurementWorkbench";
import { SchoolPxkWorkbench } from "./dispatch/SchoolPxkWorkbench";
import { SchoolFulfilmentWorkbench } from "./reconciliation/SchoolFulfilmentWorkbench";

export type AtlasWorkbenchId =
  | "schools"
  | "ingredients-suppliers"
  | "recipes"
  | "planning"
  | "procurement"
  | "pxk"
  | "reconciliation";
export type AtlasProcurementContext = {
  date: string;
  stage: "allocation" | "orders";
};
type RenderContext = {
  app: AtlasVNextAppProps;
  seed: string;
  exitRef: RefObject<AtlasModuleExitHandle | null>;
  onWorkspaceStatus: (status: AtlasWorkbenchStatus) => void;
  onServiceDateChange: (date: string) => void;
  onContinueAllocation: (date: string) => void;
  onProcurementContextChange: (context: AtlasProcurementContext) => void;
};
export type AtlasWorkbenchDefinition = {
  id: AtlasWorkbenchId;
  label: string;
  icon: Icon;
  group: "CÔNG VIỆC HẰNG NGÀY" | "DỮ LIỆU & CẤU HÌNH";
  render: (context: RenderContext) => ReactNode;
};
function owner(c: RenderContext) {
  return {
    authSubject: c.app.authSubject,
    exitRef: c.exitRef,
    onWorkspaceStatus: c.onWorkspaceStatus,
  };
}
function dateOwner(c: RenderContext) {
  return {
    ...owner(c),
    initialServiceDate: c.seed,
    onServiceDateChange: c.onServiceDateChange,
  };
}

export const atlasWorkbenches: readonly AtlasWorkbenchDefinition[] = [
  {
    id: "planning",
    label: "Lập nhu cầu",
    icon: ClipboardText,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <PlanningCapability
        {...owner(c)}
        apis={c.app.apis}
        serviceDate={c.seed}
        onServiceDateChange={c.onServiceDateChange}
        onContinueAllocation={c.onContinueAllocation}
        onExportShoppingList={c.app.exporters?.shoppingListXlsx}
        onImportShoppingList={c.app.exporters?.shoppingListImport}
      />
    ),
  },
  {
    id: "procurement",
    label: "Kế hoạch mua hàng",
    icon: ShoppingCart,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <ProcurementWorkbench
        {...dateOwner(c)}
        initialStage="allocation"
        onContextChange={c.onProcurementContextChange}
        purchaseReviewApi={c.app.apis.purchaseReview}
        procurementApi={c.app.apis.procurement}
        onExportXlsx={c.app.exporters?.procurementXlsx}
        onExportPdf={c.app.exporters?.procurementPdf}
      />
    ),
  },
  {
    id: "pxk",
    label: "Phiếu xuất kho",
    icon: Truck,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <SchoolPxkWorkbench
        {...dateOwner(c)}
        api={c.app.apis.schoolDispatch}
        onExportXlsx={c.app.exporters?.pxkXlsx}
        onExportPdf={c.app.exporters?.pxkPdf}
        onExportGroupedXlsx={c.app.exporters?.pxkGroupedXlsx}
      />
    ),
  },
  {
    id: "reconciliation",
    label: "Đối chiếu PO / Phiếu xuất kho",
    icon: Scales,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <SchoolFulfilmentWorkbench
        authSubject={c.app.authSubject}
        api={c.app.apis.reconciliation}
        initialDateStart={c.seed}
        initialDateEnd={c.seed}
      />
    ),
  },
  {
    id: "schools",
    label: "Trường học",
    icon: Buildings,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <SchoolDefaultsWorkbench {...owner(c)} api={c.app.apis.masterData} />
    ),
  },
  {
    id: "ingredients-suppliers",
    label: "Nguyên liệu và Nhà cung ứng",
    icon: Package,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <IngredientSupplierWorkbench {...owner(c)} api={c.app.apis.masterData} />
    ),
  },
  {
    id: "recipes",
    label: "Công thức",
    icon: CookingPot,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <RecipeCapability
        {...owner(c)}
        initialDate={c.seed}
        recipeApi={c.app.apis.recipe}
        adjustmentApi={c.app.apis.recipeAdjustment}
      />
    ),
  },
];
