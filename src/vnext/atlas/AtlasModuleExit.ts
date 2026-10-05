import { useEffect, type Ref } from "react";

export interface AtlasModuleExitHandle {
  requestExit(next: () => void): void;
}

export type AtlasWorkbenchStatus = {
  unsaved: boolean;
  blocked: boolean;
  attention?: string;
};

export type AtlasModuleExitProps = {
  exitRef?: Ref<AtlasModuleExitHandle>;
  onWorkspaceStatus?: (status: AtlasWorkbenchStatus) => void;
};

/** Report local presentation only; drafts and business facts stay with the owner. */
export function useAtlasWorkbenchStatus(
  report: AtlasModuleExitProps["onWorkspaceStatus"],
  { unsaved, blocked, attention }: AtlasWorkbenchStatus,
) {
  useEffect(() => {
    report?.({ unsaved, blocked, attention });
  }, [report, unsaved, blocked, attention]);
}
