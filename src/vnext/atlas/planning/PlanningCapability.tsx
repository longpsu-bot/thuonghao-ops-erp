import { Box, Tabs } from "@chakra-ui/react";
import { useImperativeHandle, useRef, useState } from "react";
import type {
  AtlasModuleExitHandle,
  AtlasModuleExitProps,
} from "../AtlasModuleExit";
import type { AtlasVNextApis } from "../AtlasVNextApis";
import { PlanningSourcesWorkbench } from "./PlanningSourcesWorkbench";
import { ConfirmedNeedWorkbench } from "../planning-confirmed/ConfirmedNeedWorkbench";
export function PlanningCapability(
  props: AtlasModuleExitProps & {
    authSubject: string;
    apis: AtlasVNextApis;
    serviceDate: string;
    onServiceDateChange: (date: string) => void;
    onContinueAllocation: (date: string) => void;
  },
) {
  const [phase, setPhase] = useState("sources");
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
        onValueChange={({ value }) => {
          if ((value === "sources" || value === "confirmed") && value !== phase)
            active.current?.requestExit(() => setPhase(value));
        }}
      >
        <Tabs.List aria-label="Công việc lập nhu cầu">
          <Tabs.Trigger value="sources">Nguồn lập nhu cầu</Tabs.Trigger>
          <Tabs.Trigger value="confirmed">Xác nhận nhu cầu</Tabs.Trigger>
        </Tabs.List>
        <Box ref={content}>
          <Tabs.Content value="sources" p="var(--atlas-layout-zero, 0)">
            {phase === "sources" && (
              <PlanningSourcesWorkbench
                exitRef={active}
                api={props.apis.planning}
                pantryApi={props.apis.pantry}
                authSubject={props.authSubject}
                initialServiceDate={props.serviceDate}
                onServiceDateChange={props.onServiceDateChange}
              />
            )}
          </Tabs.Content>
          <Tabs.Content value="confirmed" p="var(--atlas-layout-zero, 0)">
            {phase === "confirmed" && (
              <ConfirmedNeedWorkbench
                exitRef={active}
                authSubject={props.authSubject}
                initialServiceDate={props.serviceDate}
                onServiceDateChange={props.onServiceDateChange}
                preflightApi={props.apis.planningReadiness}
                needGenerationApi={props.apis.needGeneration}
                confirmedNeedApi={props.apis.confirmedNeed}
                onContinueAllocation={props.onContinueAllocation}
              />
            )}
          </Tabs.Content>
        </Box>
      </Tabs.Root>
    </Box>
  );
}
