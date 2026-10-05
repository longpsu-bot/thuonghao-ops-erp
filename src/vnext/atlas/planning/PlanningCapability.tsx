import { Box, Tabs } from "@chakra-ui/react";
import { useCallback, useImperativeHandle, useRef, useState } from "react";
import type {
  AtlasModuleExitHandle,
  AtlasModuleExitProps,
} from "../AtlasModuleExit";
import type { AtlasVNextApis } from "../AtlasVNextApis";
import { PlanningSourcesWorkbench } from "./PlanningSourcesWorkbench";
import { ConfirmedNeedWorkbench } from "../planning-confirmed/ConfirmedNeedWorkbench";
import type { ConfirmedNeedWorkbenchProps } from "../planning-confirmed/useConfirmedNeedWorkbench";
import { atlasPrimaryTabList, atlasPrimaryTabTrigger } from "../AtlasTaskTabs";
export function PlanningCapability(
  props: AtlasModuleExitProps & {
    authSubject: string;
    apis: AtlasVNextApis;
    serviceDate: string;
    onServiceDateChange: (date: string) => void;
    onContinueAllocation: (date: string) => void;
    onExportShoppingList?: ConfirmedNeedWorkbenchProps["onExportShoppingList"];
    onImportShoppingList?: ConfirmedNeedWorkbenchProps["onImportShoppingList"];
  },
) {
  const [phase, setPhase] = useState("sources");
  const [serviceDate, setServiceDate] = useState(props.serviceDate);
  const onServiceDateChange = useCallback(
    (date: string) => {
      setServiceDate(date);
      props.onServiceDateChange(date);
    },
    [props.onServiceDateChange],
  );
  const active = useRef<AtlasModuleExitHandle>(null);
  const content = useRef<HTMLDivElement>(null);
  useImperativeHandle(props.exitRef, () => ({
    requestExit: (next) => active.current?.requestExit(next),
  }));
  return (
    <Box>
      <Tabs.Root
        value={phase}
        activationMode="manual"
        variant="line"
        gap="var(--atlas-layout-zero, 0)"
        onValueChange={({ value }) => {
          if ((value === "sources" || value === "confirmed") && value !== phase)
            active.current?.requestExit(() => setPhase(value));
        }}
      >
        <Tabs.List
          aria-label="Giai đoạn lập nhu cầu"
          mb="var(--atlas-layout-zero, 0)"
          {...atlasPrimaryTabList}
        >
          <Tabs.Trigger value="sources" {...atlasPrimaryTabTrigger}>
            Nguồn lập nhu cầu
          </Tabs.Trigger>
          <Tabs.Trigger value="confirmed" {...atlasPrimaryTabTrigger}>
            Xác nhận nhu cầu
          </Tabs.Trigger>
        </Tabs.List>
        <Box ref={content}>
          <Tabs.Content value="sources" p="var(--atlas-layout-zero, 0)">
            {phase === "sources" && (
              <PlanningSourcesWorkbench
                exitRef={active}
                onWorkspaceStatus={props.onWorkspaceStatus}
                api={props.apis.planning}
                pantryApi={props.apis.pantry}
                authSubject={props.authSubject}
                initialServiceDate={serviceDate}
                onServiceDateChange={onServiceDateChange}
              />
            )}
          </Tabs.Content>
          <Tabs.Content value="confirmed" p="var(--atlas-layout-zero, 0)">
            {phase === "confirmed" && (
              <ConfirmedNeedWorkbench
                exitRef={active}
                onWorkspaceStatus={props.onWorkspaceStatus}
                authSubject={props.authSubject}
                initialServiceDate={serviceDate}
                onServiceDateChange={onServiceDateChange}
                preflightApi={props.apis.planningReadiness}
                needGenerationApi={props.apis.needGeneration}
                confirmedNeedApi={props.apis.confirmedNeed}
                onContinueAllocation={props.onContinueAllocation}
                onExportShoppingList={props.onExportShoppingList}
                onImportShoppingList={props.onImportShoppingList}
              />
            )}
          </Tabs.Content>
        </Box>
      </Tabs.Root>
    </Box>
  );
}
