import { Text } from "@chakra-ui/react";
import { useRef, useState } from "react";
import {
  AtlasPageTransition,
  type AtlasPageTransitionHandle,
} from "./AtlasPageTransition";
import { AtlasVNextShell, type AtlasVNextModuleId } from "./AtlasVNextShell";
import type { AtlasVNextApis } from "./AtlasVNextApis";
import type { AtlasModuleExitHandle } from "./AtlasModuleExit";
import { vietnamServiceDate } from "./businessDate";
import { SchoolDefaultsWorkbench } from "./schools/SchoolDefaultsWorkbench";
import { IngredientSupplierWorkbench } from "./master-data/IngredientSupplierWorkbench";
import { RecipeCapability } from "./recipes/RecipeCapability";
import { PlanningCapability } from "./planning/PlanningCapability";
import {
  ProcurementWorkbench,
  type ProcurementWorkbenchProps,
} from "./procurement/ProcurementWorkbench";
import { SchoolPxkWorkbench } from "./dispatch/SchoolPxkWorkbench";
import type { SchoolPxkWorkbenchProps } from "./dispatch/useSchoolPxkWorkbench";
import { SchoolFulfilmentWorkbench } from "./reconciliation/SchoolFulfilmentWorkbench";

export type AtlasVNextAppProps = {
  authSubject: string;
  apis: AtlasVNextApis;
  userLabel?: string;
  environmentLabel?: string;
  now?: Date;
  onSignOut?: () => void;
  safeAuthError?: string | null;
  exporters?: {
    procurementXlsx?: ProcurementWorkbenchProps["onExportXlsx"];
    procurementPdf?: ProcurementWorkbenchProps["onExportPdf"];
    pxkXlsx?: SchoolPxkWorkbenchProps["onExportXlsx"];
    pxkPdf?: SchoolPxkWorkbenchProps["onExportPdf"];
  };
};
export function AtlasVNextApp(props: AtlasVNextAppProps) {
  // An identity change owns a fresh application, including selection and recovery proof.
  return <ApplicationSession key={props.authSubject} {...props} />;
}
function ApplicationSession({
  apis,
  authSubject,
  now,
  ...props
}: AtlasVNextAppProps) {
  const [module, setModule] = useState<AtlasVNextModuleId>("schools");
  const [serviceDate, setServiceDate] = useState(() =>
    vietnamServiceDate(now ?? new Date()),
  );
  const active = useRef<AtlasModuleExitHandle>(null);
  const transition = useRef<AtlasPageTransitionHandle>(null);
  const requestExit = (next: () => void) => {
    if (transition.current?.isActive()) return;
    if (module === "reconciliation") next();
    else active.current?.requestExit(next);
  };
  const navigate = (next: AtlasVNextModuleId, date?: string) => {
    if (module !== next)
      requestExit(() =>
        transition.current?.start(() => {
          if (date) setServiceDate(date);
          setModule(next);
        }),
      );
  };
  const context = { authSubject, exitRef: active };
  const dateContext = {
    initialServiceDate: serviceDate,
    onServiceDateChange: setServiceDate,
  };
  return (
    <AtlasVNextShell
      activeModule={module}
      onNavigate={navigate}
      mode="connected"
      now={now}
      userLabel={props.userLabel}
      environmentLabel={props.environmentLabel}
      onSignOut={
        props.onSignOut ? () => requestExit(props.onSignOut!) : undefined
      }
    >
      {props.safeAuthError && (
        <Text role="alert" color="status.danger">
          {props.safeAuthError}
        </Text>
      )}
      <AtlasPageTransition ref={transition}>
        {module === "schools" && (
          <SchoolDefaultsWorkbench {...context} api={apis.masterData} />
        )}
        {module === "ingredients-suppliers" && (
          <IngredientSupplierWorkbench {...context} api={apis.masterData} />
        )}
        {module === "recipes" && (
          <RecipeCapability
            {...context}
            initialDate={now ? vietnamServiceDate(now) : undefined}
            recipeApi={apis.recipe}
            adjustmentApi={apis.recipeAdjustment}
          />
        )}
        {module === "planning" && (
          <PlanningCapability
            {...context}
            apis={apis}
            serviceDate={serviceDate}
            onServiceDateChange={setServiceDate}
            onContinueAllocation={(date) => navigate("procurement", date)}
          />
        )}
        {module === "procurement" && (
          <ProcurementWorkbench
            {...context}
            {...dateContext}
            initialStage="allocation"
            purchaseReviewApi={apis.purchaseReview}
            procurementApi={apis.procurement}
            onExportXlsx={props.exporters?.procurementXlsx}
            onExportPdf={props.exporters?.procurementPdf}
          />
        )}
        {module === "pxk" && (
          <SchoolPxkWorkbench
            {...context}
            {...dateContext}
            api={apis.schoolDispatch}
            onExportXlsx={props.exporters?.pxkXlsx}
            onExportPdf={props.exporters?.pxkPdf}
          />
        )}
        {module === "reconciliation" && (
          <SchoolFulfilmentWorkbench
            authSubject={authSubject}
            api={apis.reconciliation}
            initialDateStart={serviceDate}
            initialDateEnd={serviceDate}
          />
        )}
      </AtlasPageTransition>
    </AtlasVNextShell>
  );
}
