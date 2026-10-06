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
import { DishRecipeWorkbench } from "./recipes/DishRecipeWorkbench";
import { ChangeOrderWorkbench } from "./recipes/ChangeOrderWorkbench";
import { PlanningSourcesWorkbench } from "./planning/PlanningSourcesWorkbench";
import { ConfirmedNeedWorkbench } from "./planning-confirmed/ConfirmedNeedWorkbench";
import { ProcurementWorkbench } from "./procurement/ProcurementWorkbench";
import { SchoolPxkWorkbench } from "./dispatch/SchoolPxkWorkbench";
import { SchoolFulfilmentWorkbench } from "./reconciliation/SchoolFulfilmentWorkbench";

export type AtlasWorkbenchId =
  | "schools"
  | "ingredients"
  | "suppliers"
  | "recipes"
  | "change-orders"
  | "planning"
  | "confirmed-need"
  | "procurement"
  | "purchase-orders"
  | "pxk"
  | "reconciliation";
export type AtlasProcurementContext = {
  date: string;
  stage: "allocation" | "orders";
};
export type RenderContext = {
  app: AtlasVNextAppProps;
  seed: string;
  exitRef: RefObject<AtlasModuleExitHandle | null>;
  onWorkspaceStatus: (status: AtlasWorkbenchStatus) => void;
  onServiceDateChange: (date: string) => void;
  onContinueAllocation: (date: string) => void;
  onOpenOrders: (date: string) => void;
  onOpenChangeOrders: () => void;
  onProcurementContextChange: (context: AtlasProcurementContext) => void;
  onOrdersContextChange: (context: AtlasProcurementContext) => void;
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
    label: "Thực đơn",
    icon: ClipboardText,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <PlanningSourcesWorkbench
        {...dateOwner(c)}
        api={c.app.apis.planning}
        pantryApi={c.app.apis.pantry}
      />
    ),
  },
  {
    id: "confirmed-need",
    label: "Xác nhận nhu cầu",
    icon: ClipboardText,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <ConfirmedNeedWorkbench
        {...dateOwner(c)}
        preflightApi={c.app.apis.planningReadiness}
        needGenerationApi={c.app.apis.needGeneration}
        confirmedNeedApi={c.app.apis.confirmedNeed}
        onContinueAllocation={c.onContinueAllocation}
        onExportShoppingList={c.app.exporters?.shoppingListXlsx}
        onImportShoppingList={c.app.exporters?.shoppingListImport}
      />
    ),
  },
  {
    id: "procurement",
    label: "Phân bổ NCC",
    icon: ShoppingCart,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <ProcurementWorkbench
        {...dateOwner(c)}
        ownerStage="allocation"
        onOpenOrders={c.onOpenOrders}
        onContextChange={c.onProcurementContextChange}
        purchaseReviewApi={c.app.apis.purchaseReview}
        procurementApi={c.app.apis.procurement}
        onExportXlsx={c.app.exporters?.procurementXlsx}
        onExportPdf={c.app.exporters?.procurementPdf}
      />
    ),
  },
  {
    id: "purchase-orders",
    label: "Đơn mua",
    icon: ShoppingCart,
    group: "CÔNG VIỆC HẰNG NGÀY",
    render: (c) => (
      <ProcurementWorkbench
        {...dateOwner(c)}
        ownerStage="orders"
        onContextChange={c.onOrdersContextChange}
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
    id: "ingredients",
    label: "Nguyên liệu",
    icon: Package,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <IngredientSupplierWorkbench
        {...owner(c)}
        ownerJob="ingredients"
        api={c.app.apis.masterData}
      />
    ),
  },
  {
    id: "suppliers",
    label: "Nhà cung ứng",
    icon: Truck,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <IngredientSupplierWorkbench
        {...owner(c)}
        ownerJob="suppliers"
        api={c.app.apis.masterData}
      />
    ),
  },
  {
    id: "recipes",
    label: "Công thức",
    icon: CookingPot,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <DishRecipeWorkbench
        {...owner(c)}
        initialDate={c.seed}
        api={c.app.apis.recipe}
        onOpenChangeOrders={c.onOpenChangeOrders}
      />
    ),
  },
  {
    id: "change-orders",
    label: "Lệnh điều chỉnh",
    icon: ClipboardText,
    group: "DỮ LIỆU & CẤU HÌNH",
    render: (c) => (
      <ChangeOrderWorkbench
        {...owner(c)}
        standalone
        initialDate={c.seed}
        api={c.app.apis.recipeAdjustment}
      />
    ),
  },
];
