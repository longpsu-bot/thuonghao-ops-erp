import { useCallback, useEffect, useRef, useState, type Ref } from "react";

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
  onCommitted?: () => void;
  freshnessRevision?: number;
};

export const staleAuthorityMessage =
  "Dữ liệu liên quan đã thay đổi. Hãy tải lại dữ liệu trước khi tiếp tục; thay đổi chưa lưu được giữ nguyên.";

/** A successful sibling command invalidates reads, never local business facts. */
export function useAtlasAuthorityFreshness(revision = 0) {
  const latest = useRef(revision);
  latest.current = revision;
  const [accepted, setAccepted] = useState(revision);
  const capture = useCallback(() => latest.current, []);
  const acknowledge = useCallback((readRevision: number) => {
    setAccepted(readRevision);
  }, []);
  return {
    stale: accepted !== revision,
    revision,
    accepted,
    capture,
    acknowledge,
  };
}

export function useAtlasAuthorityRefresh(
  freshness: { stale: boolean; revision: number },
  suspended: boolean,
  refresh: () => unknown,
) {
  const action = useRef(refresh);
  action.current = refresh;
  useEffect(() => {
    if (freshness.stale && !suspended) void action.current();
  }, [freshness.stale, freshness.revision, suspended]);
}

/** Report local presentation only; drafts and business facts stay with the owner. */
export function useAtlasWorkbenchStatus(
  report: AtlasModuleExitProps["onWorkspaceStatus"],
  { unsaved, blocked, attention }: AtlasWorkbenchStatus,
) {
  useEffect(() => {
    report?.({ unsaved, blocked, attention });
  }, [report, unsaved, blocked, attention]);
}
