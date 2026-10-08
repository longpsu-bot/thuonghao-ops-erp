import { Box, Button, Flex, Text } from "@chakra-ui/react";
import {
  createRef,
  memo,
  useCallback,
  useEffect,
  useId,
  useLayoutEffect,
  useReducer,
  useRef,
  useState,
  type RefObject,
} from "react";
import { flushSync } from "react-dom";
import { AtlasVNextShell } from "./AtlasVNextShell";
import type { AtlasVNextApis } from "./AtlasVNextApis";
import type {
  AtlasModuleExitHandle,
  AtlasWorkbenchStatus,
} from "./AtlasModuleExit";
import { vietnamServiceDate } from "./businessDate";
import type { ProcurementWorkbenchProps } from "./procurement/ProcurementWorkbench";
import type { SchoolPxkWorkbenchProps } from "./dispatch/useSchoolPxkWorkbench";
import type { ConfirmedNeedWorkbenchProps } from "./planning-confirmed/useConfirmedNeedWorkbench";
import type { PlanningSourcesProps } from "./planning/usePlanningSources";
import {
  atlasWorkbenches,
  type AtlasWorkbenchDefinition,
  type AtlasWorkbenchId,
  type AtlasProcurementContext,
  type RenderContext,
} from "./AtlasWorkbenchRegistry";
import { atlasWorkspaceReducer } from "./atlasWorkspace";
import { AtlasWorkbenchScope } from "./AtlasVNextProvider";
import { atlasVisuallyHidden } from "./AtlasTaskTabs";

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
    pxkGroupedXlsx?: SchoolPxkWorkbenchProps["onExportGroupedXlsx"];
    shoppingListXlsx?: ConfirmedNeedWorkbenchProps["onExportShoppingList"];
    shoppingListImport?: ConfirmedNeedWorkbenchProps["onImportShoppingList"];
    attendanceTemplateXlsx?: PlanningSourcesProps["onExportAttendanceTemplate"];
  };
};
export function AtlasVNextApp(props: AtlasVNextAppProps) {
  // An identity change owns a fresh application, including selection and recovery proof.
  return <ApplicationSession key={props.authSubject} {...props} />;
}
type WorkbenchEntry = {
  seed: string;
  exitRef: RefObject<AtlasModuleExitHandle | null>;
  panelRef: RefObject<HTMLDivElement | null>;
  report: (status: AtlasWorkbenchStatus) => void;
};

const WorkbenchContent = memo(function WorkbenchContent({
  definition,
  ...context
}: RenderContext & { definition: AtlasWorkbenchDefinition }) {
  return definition.render(context);
});

function ApplicationSession(props: AtlasVNextAppProps) {
  const prefix = useId();
  const [workspace, dispatch] = useReducer(atlasWorkspaceReducer, {
    openIds: ["schools"],
    activeId: "schools",
  });
  const currentWorkspace = useRef(workspace);
  useLayoutEffect(() => {
    currentWorkspace.current = workspace;
  }, [workspace]);
  const mountDate = useRef(vietnamServiceDate(props.now ?? new Date()));
  const procurementContext = useRef<AtlasProcurementContext | null>(null);
  const ordersContext = useRef<AtlasProcurementContext | null>(null);
  const [statuses, setStatuses] = useState<
    Partial<Record<AtlasWorkbenchId, AtlasWorkbenchStatus>>
  >({});
  const [notice, setNotice] = useState<string | null>(null);
  const [signOutBlocked, setSignOutBlocked] = useState(false);
  const entries = useRef<Map<AtlasWorkbenchId, WorkbenchEntry> | null>(null);
  const createEntry = useCallback(
    (id: AtlasWorkbenchId, seed: string): WorkbenchEntry => ({
      seed,
      exitRef: createRef(),
      panelRef: createRef(),
      report: (status) =>
        setStatuses((previous) => {
          const old = previous[id];
          if (
            old?.unsaved === status.unsaved &&
            old?.blocked === status.blocked &&
            old?.attention === status.attention
          )
            return previous;
          return { ...previous, [id]: status };
        }),
    }),
    [],
  );
  if (!entries.current)
    entries.current = new Map([
      ["schools", createEntry("schools", mountDate.current)],
    ]);
  const reportDate = useCallback((date: string) => {
    mountDate.current = date;
  }, []);
  const reportProcurement = useCallback((context: AtlasProcurementContext) => {
    procurementContext.current = context;
  }, []);
  const reportOrders = useCallback((context: AtlasProcurementContext) => {
    ordersContext.current = context;
  }, []);
  const ownersNeedingResolution = workspace.openIds.filter((id) => {
    const status = statuses[id];
    return (
      id !== "reconciliation" && (!status || status.unsaved || status.blocked)
    );
  });
  const protectedSession = ownersNeedingResolution.length > 0;
  useEffect(() => {
    if (!protectedSession) return;
    const warn = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [protectedSession]);

  const canDeactivate = useCallback((target: AtlasWorkbenchId | null) => {
    const activeId = currentWorkspace.current.activeId;
    if (target === activeId) return true;
    // Modal presence is focus/portal safety, never a source of dirty metadata.
    const panel = activeId
      ? entries.current?.get(activeId)?.panelRef.current
      : null;
    if (
      panel?.querySelector(
        '[data-scope="dialog"][data-state="open"][role="dialog"], [data-scope="dialog"][data-state="open"][role="alertdialog"]',
      )
    ) {
      setNotice(
        "Hoàn tất hoặc đóng hộp thoại hiện tại trước khi chuyển bàn làm việc.",
      );
      return false;
    }
    return true;
  }, []);
  const open = useCallback(
    (id: AtlasWorkbenchId, seed?: string) => {
      if (!canDeactivate(id)) return false;
      if (!entries.current!.has(id))
        entries.current!.set(id, createEntry(id, seed ?? mountDate.current));
      setNotice(null);
      dispatch({ type: "OPEN", id });
      return true;
    },
    [canDeactivate, createEntry],
  );
  const continueAllocation = useCallback(
    (date: string) => {
      const retained = entries.current!.has("procurement");
      if (!open("procurement", date)) return;
      const context = procurementContext.current;
      if (retained && context && context.date !== date) {
        setNotice(
          `Nhu cầu ngày ${date} yêu cầu Phân bổ NCC. Phân bổ NCC đang mở giữ ngày ${context.date} và các thay đổi tại chỗ. Đổi ngày tại bàn làm việc này khi đã sẵn sàng.`,
        );
      }
    },
    [open],
  );
  const openOrders = useCallback(
    (date: string) => {
      const retained = entries.current!.has("purchase-orders");
      if (!open("purchase-orders", date)) return;
      if (retained) {
        const retainedDate = ordersContext.current?.date ?? date;
        setNotice(
          `Chuyển sang Đơn mua từ Phân bổ NCC ngày ${date}. Đơn mua đang mở giữ ngày ${retainedDate} và ngữ cảnh tại chỗ. Tải lại dữ liệu tại Đơn mua để xem kết quả mới; đổi ngày khi đã sẵn sàng nếu cần.`,
        );
      }
    },
    [open],
  );
  const openChangeOrders = useCallback(() => {
    open("change-orders");
  }, [open]);
  const restoreNavigationFocus = () => {
    requestAnimationFrame(() => {
      const id = currentWorkspace.current.activeId;
      const desktopTab = id
        ? document.getElementById(`${prefix}-tab-${id}`)
        : null;
      const target = desktopTab
        ? desktopTab
        : (document.getElementById(`${prefix}-open-trigger`) ??
          document.getElementById(`${prefix}-launcher`));
      target?.focus();
    });
  };
  const close = (id: AtlasWorkbenchId) => {
    if (!canDeactivate(id)) return;
    const entry = entries.current!.get(id);
    if (!entry) return;
    flushSync(() => dispatch({ type: "ACTIVATE", id }));
    const approved = () => {
      flushSync(() => {
        dispatch({ type: "CLOSE_APPROVED", id });
        setStatuses((previous) => {
          const copy = { ...previous };
          delete copy[id];
          return copy;
        });
      });
      entries.current!.delete(id);
      if (id === "procurement") procurementContext.current = null;
      if (id === "purchase-orders") ordersContext.current = null;
      restoreNavigationFocus();
    };
    if (id === "reconciliation") approved();
    else entry.exitRef.current?.requestExit(approved);
  };
  const signOut = () => {
    if (ownersNeedingResolution.length) {
      setSignOutBlocked(true);
      return;
    }
    setSignOutBlocked(false);
    props.onSignOut?.();
  };
  return (
    <AtlasVNextShell
      prefix={prefix}
      activeModule={workspace.activeId}
      openIds={workspace.openIds}
      statuses={statuses}
      onNavigate={open}
      onClose={close}
      mode="connected"
      now={props.now}
      userLabel={props.userLabel}
      environmentLabel={props.environmentLabel}
      onSignOut={props.onSignOut ? signOut : undefined}
    >
      {props.safeAuthError && (
        <Text role="alert" color="status.danger">
          {props.safeAuthError}
        </Text>
      )}
      {notice && (
        <Flex role="status" bg="bg.info" p="sm" gap="sm" align="center">
          <Text flex="1">{notice}</Text>
          <Button
            variant="utility"
            onClick={() => setNotice(null)}
            aria-label="Đóng thông báo"
          >
            Đóng
          </Button>
        </Flex>
      )}
      {signOutBlocked && ownersNeedingResolution.length > 0 && (
        <Box role="alert" bg="bg.warning" p="sm" mb="sm">
          <Text fontWeight="semibold">
            Chưa thể đăng xuất. Giải quyết từng bàn làm việc dưới đây; thay đổi
            vẫn được giữ nguyên.
          </Text>
          <Flex gap="sm" wrap="wrap" mt="xs">
            {ownersNeedingResolution.map((id) => (
              <Button key={id} variant="secondary" onClick={() => open(id)}>
                {atlasWorkbenches.find((w) => w.id === id)!.label}
                {statuses[id]?.unsaved ? " — Chưa lưu" : " — Cần giải quyết"}
              </Button>
            ))}
          </Flex>
        </Box>
      )}
      {workspace.openIds.map((id) => {
        const definition = atlasWorkbenches.find((w) => w.id === id)!;
        const entry = entries.current!.get(id)!;
        const active = workspace.activeId === id;
        return (
          <Box
            key={id}
            ref={entry.panelRef}
            id={`${prefix}-panel-${id}`}
            role="tabpanel"
            aria-labelledby={`${prefix}-label-${id}`}
            aria-label={definition.label}
            hidden={!active}
            inert={!active}
            tabIndex={0}
            flex="1"
            minH="var(--atlas-layout-zero, 0)"
            overflow="auto"
            bg="bg.workbench"
            minW="var(--atlas-layout-zero, 0)"
          >
            <Box
              as="span"
              id={`${prefix}-label-${id}`}
              {...atlasVisuallyHidden}
            >
              {definition.label}
            </Box>
            <AtlasWorkbenchScope active={active}>
              <WorkbenchContent
                definition={definition}
                app={props}
                seed={entry.seed}
                exitRef={entry.exitRef}
                onWorkspaceStatus={entry.report}
                onServiceDateChange={reportDate}
                onContinueAllocation={continueAllocation}
                onOpenOrders={openOrders}
                onOpenChangeOrders={openChangeOrders}
                onProcurementContextChange={reportProcurement}
                onOrdersContextChange={reportOrders}
              />
            </AtlasWorkbenchScope>
          </Box>
        );
      })}
      {!workspace.openIds.length && (
        <Box p="lg">
          <Text>Mở Bàn làm việc để bắt đầu công việc.</Text>
        </Box>
      )}
    </AtlasVNextShell>
  );
}
