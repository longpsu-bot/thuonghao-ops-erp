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
import type { AtlasOperatorDateRange } from "./atlasOperatorDateRange";

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
    procurementZip?: ProcurementWorkbenchProps["onExportZip"];
    pxkXlsx?: SchoolPxkWorkbenchProps["onExportXlsx"];
    pxkPdf?: SchoolPxkWorkbenchProps["onExportPdf"];
    pxkGroupedXlsx?: SchoolPxkWorkbenchProps["onExportGroupedXlsx"];
    pxkZip?: SchoolPxkWorkbenchProps["onExportZip"];
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
  seedRange?: AtlasOperatorDateRange;
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
    (
      id: AtlasWorkbenchId,
      seed: string,
      seedRange?: AtlasOperatorDateRange,
    ): WorkbenchEntry => ({
      seed,
      seedRange,
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
    (id: AtlasWorkbenchId, seed?: string, range?: AtlasOperatorDateRange) => {
      if (!canDeactivate(id)) return false;
      if (!entries.current!.has(id))
        entries.current!.set(
          id,
          createEntry(id, seed ?? mountDate.current, range),
        );
      setNotice(null);
      dispatch({ type: "OPEN", id });
      return true;
    },
    [canDeactivate, createEntry],
  );
  const continueAllocation = useCallback(
    (range: AtlasOperatorDateRange) => {
      const retained = entries.current!.has("procurement");
      if (!open("procurement", range.start, range)) return;
      const context = procurementContext.current;
      if (
        retained &&
        context &&
        (context.range.start !== range.start || context.range.end !== range.end)
      ) {
        setNotice(
          `Cần phân bổ NCC cho nhu cầu từ ${range.start} đến ${range.end}. Bàn Phân bổ NCC vẫn giữ khoảng ngày ${context.range.start} → ${context.range.end} và các thay đổi đang chỉnh sửa. Khi sẵn sàng, hãy chọn lại khoảng ngày cần phân bổ.`,
        );
      }
    },
    [open],
  );
  const openOrders = useCallback(
    (scope: string | AtlasOperatorDateRange) => {
      const range =
        typeof scope === "string" ? { start: scope, end: scope } : scope;
      const retained = entries.current!.has("purchase-orders");
      if (!open("purchase-orders", range.start, range)) return;
      if (retained) {
        const retainedRange = ordersContext.current?.range ?? range;
        setNotice(
          `Đã mở bàn Đơn mua từ Phân bổ NCC ${range.start} → ${range.end}. Bàn Đơn mua vẫn giữ khoảng ngày ${retainedRange.start} → ${retainedRange.end} và các lựa chọn đang dùng. Hãy tải lại dữ liệu để xem kết quả mới; chọn lại khoảng ngày nếu cần.`,
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
            Chưa thể đăng xuất. Kiểm tra các thay đổi chưa lưu hoặc thao tác
            chưa xác định kết quả ở từng bàn dưới đây. Các thay đổi vẫn được giữ
            nguyên.
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
                seedRange={entry.seedRange}
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
