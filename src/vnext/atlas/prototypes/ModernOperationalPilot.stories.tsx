/**
 * THROWAWAY / DESIGN REVIEW ONLY — ATLAS-UI-VNEXT-03A.
 * Four review directions using current workbenches and in-memory fixtures.
 * Storybook only. Never import this file into a production route.
 */
import type { Meta, StoryObj } from "@storybook/react-vite";
import { Box, Button, Flex, NativeSelect, Text } from "@chakra-ui/react";
import {
  ArrowLeft,
  ArrowRight,
  BowlFood,
  ClipboardText,
  Truck,
  Basket,
  List,
  X,
} from "@phosphor-icons/react";
import {
  createRef,
  useCallback,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  useState,
  type Ref,
  type ReactNode,
} from "react";
import type { AtlasModuleExitHandle } from "../AtlasModuleExit";
import { fireEvent, userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ConfirmedNeedWorkbench } from "../planning-confirmed/ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate as needDate,
} from "../planning-confirmed/confirmedNeedReviewFixtures";
import { ProcurementWorkbench } from "../procurement/ProcurementWorkbench";
import {
  createProcurementReviewFixture,
  reviewDate as purchaseDate,
  reviewSchools,
  reviewFamily,
} from "../procurement/procurementReviewFixtures";
import { DishRecipeWorkbench } from "../recipes/DishRecipeWorkbench";
import {
  createRecipeReviewFixture,
  recipeFixtureDate,
} from "../recipes/recipeReviewFixtures";
import { SchoolPxkWorkbench } from "../dispatch/SchoolPxkWorkbench";
import {
  createSchoolPxkReviewFixture,
  reviewDate as dispatchDate,
} from "../dispatch/schoolPxkReviewFixtures";
import "./modern-operational-pilot.css";

const variants = ["A", "B", "C", "D"] as const;
const surfaces = ["need", "procurement", "recipes", "dispatch"] as const;
const states = [
  "normal",
  "selected",
  "dirty",
  "blocked",
  "loading",
  "error",
  "empty",
  "ready",
] as const;
type Variant = (typeof variants)[number];
type Surface = (typeof surfaces)[number];
type State = (typeof states)[number];
const variantNames = {
  A: "Operational Saas UI",
  B: "Modern Operational",
  C: "Dense Modern ERP",
  D: "Persistent Workspace",
};
const surfaceNames = {
  need: "Lập nhu cầu",
  procurement: "Kế hoạch mua hàng",
  recipes: "Công thức",
  dispatch: "Phiếu xuất kho",
};
const icons = {
  need: ClipboardText,
  procurement: Basket,
  recipes: BowlFood,
  dispatch: Truck,
};
const stateNames = {
  normal: "Bình thường",
  selected: "Chi tiết",
  dirty: "Đang sửa",
  blocked: "Bị chặn",
  loading: "Đang tải",
  error: "Lỗi / thử lại",
  empty: "Trống",
  ready: "Sẵn sàng tiếp tục",
};
function queryValue<T extends string>(
  name: string,
  values: readonly T[],
  fallback: T,
): T {
  const value = new URLSearchParams(window.location.search).get(name);
  return values.find((item) => item === value) ?? fallback;
}
const pending = async (): Promise<never> => new Promise(() => {});

function FixtureWorkbench({
  surface,
  state,
  exitRef,
  initialDate,
  onDateChange,
  onContinueAllocation,
  onRead,
}: {
  surface: Surface;
  state: State;
  exitRef?: Ref<AtlasModuleExitHandle>;
  initialDate?: string;
  onDateChange?: (date: string) => void;
  onContinueAllocation?: (date: string) => void;
  onRead?: () => void;
}) {
  const [notice, setNotice] = useState("");
  const fixtures = useMemo(() => {
    const need = createConfirmedNeedReviewFixture(
      state === "loading"
        ? "loading"
        : state === "error"
          ? "read_failure"
          : state === "empty"
            ? "no_demand"
            : state === "blocked"
              ? "blocked"
              : "normal",
    );
    const procurement = createProcurementReviewFixture(
      state === "error"
        ? "read_failure"
        : state === "empty"
          ? "empty"
          : state === "blocked"
            ? "blocked"
            : state === "ready"
              ? "ready"
              : "manual_split",
    );
    if (!["error", "empty", "loading"].includes(state)) {
      const names = [
        "Thịt heo nạc",
        "Cà rốt",
        "Bắp cải",
        "Trứng gà",
        "Cải thìa",
        "Bí đỏ",
        "Khoai tây",
        "Đậu hũ",
        "Thịt gà",
        "Cá phi lê",
        "Dầu ăn",
        "Rau muống",
      ];
      procurement.allocation.rows.push(
        ...names.map((name, index) => {
          const row = reviewFamily(
            state === "ready"
              ? "ready"
              : index % 4 === 0
                ? "normal"
                : "manual_split",
          );
          const school = reviewSchools[index % reviewSchools.length]!;
          return {
            ...row,
            ingredient_id: `pilot-ingredient-${index}`,
            ingredient_name: name,
            school_id: school.school_id,
            school_name: school.school_name,
            schools: [school],
            family: {
              ...row.family,
              ingredient_id: `pilot-ingredient-${index}`,
              source_fingerprint: `pilot-source-${index}`,
            },
          };
        }),
      );
    }
    const recipes = createRecipeReviewFixture(
      state === "error"
        ? "READ_FAILURE"
        : state === "empty"
          ? "EMPTY_CATALOG"
          : state === "blocked"
            ? "DISH_ACTIVE_LOCKED"
            : "DISH_ACTIVE_EDITABLE",
    );
    const dispatch = createSchoolPxkReviewFixture(
      state === "error"
        ? "READ_FAILURE"
        : state === "empty"
          ? "EMPTY"
          : state === "blocked"
            ? "BLOCKED"
            : "MULTIPLE_SCHOOLS",
    );
    if (state === "loading") {
      procurement.purchaseReviewApi.getConfirmedAllocations = pending;
      recipes.api.getWorkbench = pending;
      dispatch.getWorkbench = pending;
    }
    if (initialDate && surface === "procurement") {
      procurement.allocation.date_start = initialDate;
      procurement.allocation.date_end = initialDate;
      procurement.orders.date_start = initialDate;
      procurement.orders.date_end = initialDate;
      for (const row of procurement.allocation.rows) {
        row.service_date = initialDate;
        row.family.service_date = initialDate;
      }
      for (const order of procurement.orders.purchase_orders) {
        order.service_date = initialDate;
        for (const line of order.lines) line.service_date = initialDate;
      }
      if (procurement.allocation.preparation)
        procurement.allocation.preparation.service_date = initialDate;
    }
    // Review-only read evidence; fixture identities stay stable on visibility changes.
    function counted<T extends object>(api: T): T {
      if (!onRead) return api;
      return new Proxy(api, {
        get(target, key, receiver) {
          const value = Reflect.get(target, key, receiver);
          if (typeof value !== "function") return value;
          return (...args: unknown[]) => {
            if (String(key).startsWith("get") || key === "preflight") onRead();
            return Reflect.apply(value, target, args);
          };
        },
      });
    }
    need.preflightApi = counted(need.preflightApi);
    need.confirmedNeedApi = counted(need.confirmedNeedApi);
    need.needGenerationApi = counted(need.needGenerationApi);
    procurement.purchaseReviewApi = counted(procurement.purchaseReviewApi);
    procurement.procurementApi = counted(procurement.procurementApi);
    recipes.api = counted(recipes.api);
    return { need, procurement, recipes, dispatch: counted(dispatch) };
  }, [state, surface, initialDate, onRead]);
  const simulatedExport = () =>
    setNotice("Xem thử: đã chọn xuất. Không tạo tệp hoặc chứng từ thật.");
  return (
    <>
      {surface === "need" && (
        <ConfirmedNeedWorkbench
          {...fixtures.need}
          authSubject="fixture-operator"
          initialServiceDate={initialDate ?? needDate}
          exitRef={exitRef}
          onServiceDateChange={onDateChange}
          onExportShoppingList={async () => {
            simulatedExport();
          }}
          onImportShoppingList={async (_file, _workbench, drafts) => {
            setNotice(
              "Xem thử: đã chọn tệp. Pilot không phân tích workbook; bản nháp được giữ nguyên.",
            );
            return { drafts, changedLineIds: [] };
          }}
          onContinueAllocation={
            onContinueAllocation ??
            (() =>
              setNotice("Xem thử: tiếp tục phân bổ NCC từ nhu cầu đã lưu."))
          }
        />
      )}
      {surface === "procurement" && (
        <ProcurementWorkbench
          authSubject="fixture-operator"
          purchaseReviewApi={fixtures.procurement.purchaseReviewApi}
          procurementApi={fixtures.procurement.procurementApi}
          initialServiceDate={initialDate ?? purchaseDate}
          exitRef={exitRef}
          onServiceDateChange={onDateChange}
          schools={reviewSchools}
          onExportXlsx={simulatedExport}
          onExportPdf={simulatedExport}
        />
      )}
      {surface === "recipes" && (
        <DishRecipeWorkbench
          authSubject="fixture-operator"
          api={fixtures.recipes.api}
          initialDate={initialDate ?? recipeFixtureDate}
          exitRef={exitRef}
          onOpenChangeOrders={() =>
            setNotice("Xem thử: mở Lệnh điều chỉnh. Không gọi lệnh thật.")
          }
        />
      )}
      {surface === "dispatch" && (
        <SchoolPxkWorkbench
          authSubject="fixture-operator"
          api={fixtures.dispatch}
          initialServiceDate={initialDate ?? dispatchDate}
          exitRef={exitRef}
          onServiceDateChange={onDateChange}
          onExportXlsx={simulatedExport}
          onExportPdf={simulatedExport}
          onExportGroupedXlsx={simulatedExport}
        />
      )}
      {notice && (
        <Text role="status" p="sm" color="fg.primary">
          {notice}
        </Text>
      )}
    </>
  );
}

type WorkspaceId = Surface | `capacity-${number}`;
type FixtureOptions = Omit<Parameters<typeof FixtureWorkbench>[0], "surface">;
type WorkbenchDefinition = {
  id: WorkspaceId;
  label: string;
  icon: typeof ClipboardText;
  render: (options: FixtureOptions) => ReactNode;
};
// Static UI descriptors, not domain modules or serialized workbench state.
const workbenchDefinitions: WorkbenchDefinition[] = [
  ...surfaces.map((surface) => ({
    id: surface,
    label: surfaceNames[surface],
    icon: icons[surface],
    render: (options: FixtureOptions) => (
      <FixtureWorkbench {...options} surface={surface} />
    ),
  })),
  ...[
    "Trường học",
    "Nguyên liệu",
    "Nhà cung ứng",
    "Nhập kho",
    "Đối chiếu PO / PXK",
    "Kiểm tra chất lượng",
    "Kế hoạch bếp",
    "Suất ăn & nguồn",
  ].map((label, index) => ({
    id: `capacity-${index + 1}` as WorkspaceId,
    label,
    icon: List,
    render: () => (
      <section className="workspace-capacity">
        <h1>{label}</h1>
        <p>
          Chỉ minh họa dung lượng thanh bàn làm việc. Không có chức năng hoặc
          kết nối.
        </p>
      </section>
    ),
  })),
];
const definitionFor = (id: WorkspaceId) =>
  workbenchDefinitions.find((d) => d.id === id)!;
type WorkspaceState = { open: WorkspaceId[]; active: WorkspaceId | null };
type WorkspaceAction = { type: "open" | "activate" | "close"; id: WorkspaceId };
function workspaceReducer(
  current: WorkspaceState,
  action: WorkspaceAction,
): WorkspaceState {
  if (action.type === "open")
    return {
      open: current.open.includes(action.id)
        ? current.open
        : [...current.open, action.id],
      active: action.id,
    };
  if (action.type === "activate")
    return current.open.includes(action.id)
      ? { ...current, active: action.id }
      : current;
  const index = current.open.indexOf(action.id);
  const open = current.open.filter((id) => id !== action.id);
  return {
    open,
    active:
      current.active === action.id
        ? (open[Math.max(0, index - 1)] ?? null)
        : current.active,
  };
}
type TabStatus = { dirty: boolean; modal: boolean; attention: boolean };
const tabStatusText = (status?: TabStatus) =>
  status?.dirty
    ? " · thay đổi chưa lưu"
    : status?.attention
      ? " · biểu mẫu món đang mở, kiểm tra thay đổi"
      : "";
function WorkspacePanel({
  definition,
  active,
  state,
  initialDate,
  exitRef,
  onStatus,
  onContinueAllocation,
}: {
  definition: WorkbenchDefinition;
  active: boolean;
  state: State;
  initialDate?: string;
  exitRef: Ref<AtlasModuleExitHandle>;
  onStatus: (id: WorkspaceId, status: TabStatus) => void;
  onContinueAllocation: (date: string) => void;
}) {
  const root = useRef<HTMLDivElement>(null);
  const evidence = useRef({ mounts: 0, reads: 0 });
  const [date, setDate] = useState(
    initialDate ??
      (
        {
          need: needDate,
          procurement: purchaseDate,
          recipes: recipeFixtureDate,
          dispatch: dispatchDate,
        } as Partial<Record<WorkspaceId, string>>
      )[definition.id],
  );
  const read = useCallback(() => {
    evidence.current.reads++;
    if (root.current)
      root.current.dataset.readCount = String(evidence.current.reads);
  }, []);
  const report = useCallback(() => {
    const node = root.current;
    if (!node) return;
    // ponytail: presentation bridge to existing rendered dirty evidence, not an exit decision.
    // Recipe metadata has no dirty signal: show truthful form-open attention instead.
    // Production needs a narrow exact status callback, not this localized DOM bridge.
    const note = node.querySelector<HTMLTextAreaElement>(
      '[aria-label="Ghi chú trên phiếu"]',
    );
    onStatus(definition.id, {
      dirty:
        (node.textContent ?? "").includes("Đang chỉnh sửa · chưa lưu") ||
        Boolean(note?.value.trim()),
      attention:
        definition.id === "recipes" &&
        Array.from(node.querySelectorAll("h2")).some((heading) =>
          ["Tạo món mới", "Sửa thông tin món"].includes(
            heading.textContent ?? "",
          ),
        ),
      modal: Boolean(
        node.querySelector(
          '[role="dialog"][aria-modal="true"]:not([data-state="closed"])',
        ),
      ),
    });
  }, [definition.id, onStatus]);
  useEffect(() => {
    evidence.current.mounts++;
    root.current!.dataset.mountCount = String(evidence.current.mounts);
    root.current!.dataset.readCount = String(evidence.current.reads);
    const observer = new MutationObserver(report);
    observer.observe(root.current!, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["data-state", "aria-modal"],
    });
    report();
    return () => observer.disconnect();
  }, [report]);
  return (
    <div
      ref={root}
      id={`workspace-panel-${definition.id}`}
      data-testid={`workspace-panel-${definition.id}`}
      data-service-date={date}
      role="tabpanel"
      aria-labelledby={`workspace-tab-${definition.id}`}
      tabIndex={0}
      hidden={!active}
      inert={!active}
      className="workspace-panel"
      onChangeCapture={() => queueMicrotask(report)}
    >
      <AtlasVNextProvider>
        {definition.render({
          state,
          exitRef,
          initialDate,
          onDateChange: setDate,
          onRead: read,
          onContinueAllocation,
        })}
      </AtlasVNextProvider>
    </div>
  );
}

function PersistentWorkspace({
  surface,
  state,
}: {
  surface: Surface;
  state: State;
}) {
  const [workspace, dispatch] = useReducer(workspaceReducer, undefined, () => ({
    open:
      queryValue("workspace", ["single", "four", "stress"], "single") ===
      "stress"
        ? workbenchDefinitions.map((d) => d.id)
        : queryValue("workspace", ["single", "four", "stress"], "single") ===
            "four"
          ? [...surfaces]
          : [surface],
    active: surface,
  }));
  const [statuses, setStatuses] = useState<
    Partial<Record<WorkspaceId, TabStatus>>
  >({});
  const [launcherOpen, setLauncherOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const launcher = useRef<HTMLButtonElement>(null);
  const launchMenu = useRef<HTMLElement>(null);
  const strip = useRef<HTMLDivElement>(null);
  const focusAfterClose = useRef<WorkspaceId | "launcher" | null>(null);
  const guards = useMemo(
    () =>
      Object.fromEntries(
        workbenchDefinitions.map((d) => [
          d.id,
          createRef<AtlasModuleExitHandle>(),
        ]),
      ),
    [],
  );
  const seeds = useRef<Partial<Record<WorkspaceId, string>>>({});
  const status = useCallback(
    (id: WorkspaceId, next: TabStatus) =>
      setStatuses((current) =>
        current[id]?.dirty === next.dirty &&
        current[id]?.modal === next.modal &&
        current[id]?.attention === next.attention
          ? current
          : { ...current, [id]: next },
      ),
    [],
  );
  const tabElement = (id: WorkspaceId) =>
    document.getElementById(`workspace-tab-${id}`);
  function focusWorkbench(id: WorkspaceId) {
    const tab = tabElement(id);
    const mobile = document.querySelector<HTMLSelectElement>(
      ".workspace-mobile-switcher select",
    );
    (tab?.getClientRects().length
      ? tab
      : mobile?.getClientRects().length
        ? mobile
        : launcher.current
    )?.focus({ preventScroll: true });
  }
  const modalOpen = () =>
    workspace.active &&
    document.querySelector(
      `#workspace-panel-${workspace.active} [role="dialog"][aria-modal="true"]:not([data-state="closed"])`,
    );
  function activate(id: WorkspaceId, open = false) {
    if (modalOpen()) {
      setNotice("Hãy hoàn tất hoặc đóng hộp thoại hiện tại trước khi đổi bàn.");
      return;
    }
    focusWorkbench(id);
    dispatch({ type: open ? "open" : "activate", id });
    setLauncherOpen(false);
  }
  useEffect(() => {
    if (!workspace.active) {
      launcher.current?.focus();
      return;
    }
    const tab = tabElement(workspace.active);
    if (!tab || !strip.current) return;
    const r = tab.parentElement!.getBoundingClientRect(),
      s = strip.current.getBoundingClientRect();
    const inset = Number.parseFloat(
      getComputedStyle(strip.current).paddingRight,
    );
    if (r.right > s.right - inset)
      strip.current.scrollLeft += r.right - s.right + inset;
    if (r.left < s.left + inset)
      strip.current.scrollLeft += r.left - s.left - inset;
  }, [workspace.active, workspace.open]);
  useEffect(() => {
    if (launcherOpen)
      launchMenu.current?.querySelector<HTMLButtonElement>("button")?.focus();
    const dismiss = (event: PointerEvent) => {
      if (!launcher.current?.parentElement?.contains(event.target as Node))
        setLauncherOpen(false);
    };
    if (launcherOpen) document.addEventListener("pointerdown", dismiss);
    return () => document.removeEventListener("pointerdown", dismiss);
  }, [launcherOpen]);
  useEffect(() => {
    const target = focusAfterClose.current;
    if (!target) return;
    focusAfterClose.current = null;
    // Run after commit and Zag's deferred return-focus cleanup for the removed dialog.
    const timer = window.setTimeout(() => {
      if (target === "launcher") launcher.current?.focus();
      else focusWorkbench(target);
    }, 0);
    return () => window.clearTimeout(timer);
  }, [workspace.open, workspace.active]);
  function close(id: WorkspaceId) {
    if (modalOpen()) return;
    activate(id);
    // Guard must be visible before it may open its own existing dialog.
    requestAnimationFrame(() => {
      const approved = () => {
        const index = workspace.open.indexOf(id);
        const remaining = workspace.open.filter((item) => item !== id);
        focusAfterClose.current =
          remaining[Math.max(0, index - 1)] ?? "launcher";
        dispatch({ type: "close", id });
        delete seeds.current[id];
      };
      if (guards[id]?.current) guards[id].current!.requestExit(approved);
      else if (id.startsWith("capacity-")) approved();
    });
  }
  const continueIntoProcurement = useCallback(
    (date: string) => {
      const existing = workspace.open.includes("procurement");
      if (!existing) seeds.current.procurement = date;
      activate("procurement", true);
      const currentDate = document.getElementById("workspace-panel-procurement")
        ?.dataset.serviceDate;
      setNotice(
        existing
          ? `Nhu cầu ngày ${date.split("-").reverse().join("/")}. Tab mua đang giữ ngày ${currentDate?.split("-").reverse().join("/") ?? "đã chọn"}, giai đoạn và bản nháp. Không tự đổi ngữ cảnh; dùng Đóng chi tiết, ngày và Phân bổ NCC trong tab hiện tại.`
          : `Đã mở Kế hoạch mua hàng từ nhu cầu ngày ${date.split("-").reverse().join("/")}. Chỉ dữ liệu minh họa.`,
      );
    },
    [workspace.open, workspace.active],
  );
  const activeDefinition = workspace.active
    ? definitionFor(workspace.active)
    : null;
  const modal = workspace.active ? statuses[workspace.active]?.modal : false;
  return (
    <div className="workspace-shell">
      <header
        className="workspace-header"
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget))
            setLauncherOpen(false);
        }}
        onKeyDown={(event) => {
          if (launcherOpen && event.key === "Escape") {
            setLauncherOpen(false);
            launcher.current?.focus();
          }
        }}
      >
        <strong className="workspace-brand">Atlas</strong>
        <Button
          ref={launcher}
          size="sm"
          variant="utility"
          aria-expanded={launcherOpen}
          aria-controls="workspace-launcher"
          aria-label="Mở bàn làm việc"
          title={`${workspace.open.length} bàn đang mở${workspace.open.length > 4 ? " · cuộn ngang thanh bàn" : ""}`}
          disabled={modal}
          onClick={() => setLauncherOpen(!launcherOpen)}
        >
          <List size={18} />
          Mở bàn làm việc
          <span className="workspace-open-count" aria-hidden="true">
            {workspace.open.length}
            {workspace.open.length > 4 ? " ↔" : ""}
          </span>
        </Button>
        <span className="workspace-identity">Thượng Hảo · Vận hành</span>
        {launcherOpen && (
          <nav
            ref={launchMenu}
            id="workspace-launcher"
            className="workspace-launcher"
            aria-label="Mở bàn làm việc Atlas"
          >
            {workbenchDefinitions.map((definition) => (
              <button
                type="button"
                key={definition.id}
                aria-label={definition.label}
                aria-describedby={`workspace-launch-status-${definition.id}`}
                onClick={() => activate(definition.id, true)}
              >
                <definition.icon size={18} aria-hidden="true" />
                <span>{definition.label}</span>
                <small id={`workspace-launch-status-${definition.id}`}>
                  {definition.id.startsWith("capacity-") ? "Minh họa · " : ""}
                  {workspace.open.includes(definition.id) ? "Đang mở" : ""}
                </small>
              </button>
            ))}
          </nav>
        )}
      </header>
      <div className="workspace-mobile-switcher">
        <NativeSelect.Root disabled={modal || !workspace.open.length}>
          <NativeSelect.Field
            aria-label="Bàn đang mở"
            value={workspace.active ?? ""}
            onChange={(event) => {
              const id = workspace.open.find(
                (item) => item === event.target.value,
              );
              if (id) activate(id);
            }}
          >
            {!workspace.open.length && <option value="">Chưa mở bàn</option>}
            {workspace.open.map((id) => (
              <option key={id} value={id}>
                {definitionFor(id).label}
                {tabStatusText(statuses[id])}
              </option>
            ))}
          </NativeSelect.Field>
          <NativeSelect.Indicator />
        </NativeSelect.Root>
        {workspace.active && (
          <Button
            size="sm"
            variant="tertiary"
            aria-label={`Đóng bàn ${activeDefinition!.label}`}
            disabled={modal}
            onClick={() => close(workspace.active!)}
          >
            <X size={18} />
          </Button>
        )}
      </div>
      <div
        ref={strip}
        role="tablist"
        aria-label="Bàn làm việc đang mở"
        className="workspace-tabs"
      >
        {workspace.open.map((id, index) => {
          const d = definitionFor(id),
            selected = id === workspace.active;
          return (
            <div className="workspace-tab" key={id} data-active={selected}>
              <button
                type="button"
                id={`workspace-tab-${id}`}
                role="tab"
                aria-selected={selected}
                aria-controls={`workspace-panel-${id}`}
                aria-label={`${d.label}${tabStatusText(statuses[id])}`}
                tabIndex={selected ? 0 : -1}
                disabled={modal}
                onClick={() => activate(id)}
                onKeyDown={(event) => {
                  const next =
                    event.key === "ArrowRight"
                      ? workspace.open[(index + 1) % workspace.open.length]
                      : event.key === "ArrowLeft"
                        ? workspace.open[
                            (index - 1 + workspace.open.length) %
                              workspace.open.length
                          ]
                        : event.key === "Home"
                          ? workspace.open[0]
                          : event.key === "End"
                            ? workspace.open.at(-1)
                            : null;
                  if (next) {
                    event.preventDefault();
                    activate(next);
                  }
                  if (event.key === "Delete") {
                    event.preventDefault();
                    close(id);
                  }
                }}
              >
                <d.icon size={16} aria-hidden="true" />
                <span>{d.label}</span>
                {(statuses[id]?.dirty || statuses[id]?.attention) && (
                  <span className="workspace-dirty-dot" aria-hidden="true" />
                )}
              </button>
              <button
                type="button"
                className="workspace-tab-close"
                tabIndex={selected ? 0 : -1}
                disabled={modal}
                aria-label={`Đóng bàn ${d.label}`}
                onClick={() => close(id)}
              >
                <X size={14} aria-hidden="true" />
              </button>
            </div>
          );
        })}
      </div>
      {notice && (
        <div className="workspace-notice" role="status">
          {notice}
          <button
            type="button"
            aria-label="Đóng thông báo tiếp tục"
            onClick={() => setNotice("")}
          >
            <X size={16} />
          </button>
        </div>
      )}
      <main className="workspace-panels">
        {workspace.open.map((id) => (
          <WorkspacePanel
            key={id}
            definition={definitionFor(id)}
            active={workspace.active === id}
            state={state}
            initialDate={seeds.current[id]}
            exitRef={guards[id]}
            onStatus={status}
            onContinueAllocation={continueIntoProcurement}
          />
        ))}
        {!workspace.open.length && (
          <div className="workspace-empty">
            <h1>Chọn bàn làm việc</h1>
            <p>Mở một công việc từ danh mục để bắt đầu.</p>
          </div>
        )}
      </main>
    </div>
  );
}

export function ModernOperationalPilot({
  initialSurface = "need",
}: {
  initialSurface?: Surface;
}) {
  const surface = queryValue("surface", surfaces, initialSurface);
  const state = queryValue("state", states, "normal");
  const [variant, setVariant] = useState(() =>
    queryValue("variant", variants, "B"),
  );
  const [menuOpen, setMenuOpen] = useState(false);
  const nav = useRef<HTMLElement>(null);
  useEffect(() => {
    if (menuOpen)
      nav.current?.querySelector<HTMLButtonElement>("button")?.focus();
  }, [menuOpen]);
  function changeVariant(value: Variant) {
    const url = new URL(window.location.href);
    url.searchParams.set("variant", value);
    window.history.replaceState(null, "", url);
    setVariant(value);
  }
  function resetFixture(name: string, value: string) {
    const url = new URL(window.location.href);
    url.searchParams.set(name, value);
    url.searchParams.set("variant", variant);
    window.location.assign(url);
  }
  function cycle(direction: number) {
    changeVariant(
      variants[
        (variants.indexOf(variant) + direction + variants.length) %
          variants.length
      ]!,
    );
  }
  return (
    <AtlasVNextProvider>
      <Box
        className="atlas-modern-prototype"
        data-variant={variant}
        data-surface={surface}
        data-state={state}
      >
        <Flex
          className="pilot-review-bar"
          align="center"
          gap="sm"
          wrap="wrap"
          role="region"
          aria-label="Điều khiển prototype"
        >
          <Text textStyle="helper">
            <strong>PROTOTYPE</strong> · Dữ liệu minh họa, chỉ lưu trong phiên
          </Text>
          <NativeSelect.Root
            size="sm"
            width="var(--pilot-state-select-width, auto)"
          >
            <NativeSelect.Field
              aria-label="Trạng thái minh họa (đặt lại dữ liệu)"
              value={state}
              onChange={(e) => resetFixture("state", e.target.value)}
            >
              {states.map((item) => (
                <option key={item} value={item}>
                  {stateNames[item]}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
          <Flex
            className="pilot-switcher"
            role="group"
            aria-label="So sánh bốn phương án"
            onKeyDown={(event) => {
              if (
                event.target !== event.currentTarget &&
                (event.target as HTMLElement).tagName !== "BUTTON"
              )
                return;
              if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
                event.preventDefault();
                cycle(event.key === "ArrowLeft" ? -1 : 1);
              }
            }}
          >
            <Button
              aria-label="Phương án trước"
              variant="utility"
              size="sm"
              onClick={() => cycle(-1)}
            >
              <ArrowLeft size={16} />
            </Button>
            {variants.map((item) => (
              <Button
                key={item}
                title={variantNames[item]}
                variant={variant === item ? "businessPrimary" : "utility"}
                size="sm"
                aria-pressed={variant === item}
                onClick={() => changeVariant(item)}
              >
                {item}
                <span className="pilot-variant-name">
                  {" "}
                  · {variantNames[item]}
                </span>
              </Button>
            ))}
            <Button
              aria-label="Phương án tiếp theo"
              variant="utility"
              size="sm"
              onClick={() => cycle(1)}
            >
              <ArrowRight size={16} />
            </Button>
          </Flex>
          {variant === "D" && (
            <Button
              className="workspace-stress-trigger"
              size="sm"
              variant="utility"
              title="Đặt lại dữ liệu minh họa với 12 bàn mở"
              onClick={() => resetFixture("workspace", "stress")}
            >
              Minh họa 12 bàn
            </Button>
          )}
        </Flex>
        {variant === "D" ? (
          <PersistentWorkspace surface={surface} state={state} />
        ) : (
          <div className="pilot-shell">
            <aside className="pilot-sidebar" data-open={menuOpen}>
              <div className="pilot-brand">
                <span className="pilot-mark" aria-hidden="true">
                  A
                </span>
                <span>
                  <strong>Atlas</strong>
                  <small>Thượng Hảo · OPS ERP</small>
                </span>
              </div>
              <nav
                ref={nav}
                id="pilot-navigation"
                aria-label="Các bề mặt pilot (đặt lại dữ liệu)"
              >
                {surfaces.map((item) => {
                  const Icon = icons[item];
                  return (
                    <button
                      key={item}
                      type="button"
                      aria-current={surface === item ? "page" : undefined}
                      onClick={() => resetFixture("surface", item)}
                    >
                      <Icon
                        size={20}
                        weight={surface === item ? "bold" : "regular"}
                        aria-hidden="true"
                      />
                      <span>{surfaceNames[item]}</span>
                    </button>
                  );
                })}
              </nav>
              <div className="pilot-sidebar-footer">
                Thiết kế thử nghiệm<small>03A · Không kết nối hệ thống</small>
              </div>
            </aside>
            <div className="pilot-stage">
              <header className="pilot-app-header">
                <div className="pilot-app-context">
                  <Button
                    className="pilot-menu-trigger"
                    variant="tertiary"
                    size="sm"
                    aria-controls="pilot-navigation"
                    aria-expanded={menuOpen}
                    onClick={() => setMenuOpen(!menuOpen)}
                  >
                    Danh mục
                  </Button>
                  <span>{surfaceNames[surface]}</span>
                </div>
                <span className="pilot-environment">
                  Local review · Nhân viên vận hành
                </span>
              </header>
              <main id="pilot-workbench" className="pilot-workspace">
                <FixtureWorkbench surface={surface} state={state} />
              </main>
            </div>
          </div>
        )}
      </Box>
    </AtlasVNextProvider>
  );
}

const meta = {
  title: "Atlas Prototypes/Modern Operational 03A",
  component: ModernOperationalPilot,
  parameters: { layout: "fullscreen" },
  beforeEach: () => {
    // Storybook 10.5's focus getter throws when Ark reads it on the prototype.
    // ponytail: iframe-wide shim drops Storybook's getter guard; remove after its fix.
    const focus = Object.getOwnPropertyDescriptor(
      HTMLElement.prototype,
      "focus",
    );
    if (focus?.get)
      Object.defineProperty(HTMLElement.prototype, "focus", {
        configurable: true,
        writable: true,
        value: focus.get.call(document.body),
      });
  },
} satisfies Meta<typeof ModernOperationalPilot>;
export default meta;
type Story = StoryObj<typeof meta>;
async function prepare({ canvasElement }: { canvasElement: HTMLElement }) {
  const surface = queryValue("surface", surfaces, "need");
  const state = queryValue("state", states, "normal");
  const c = within(canvasElement);
  if (
    !["selected", "dirty"].includes(state) &&
    !(state === "blocked" && ["recipes", "dispatch"].includes(surface))
  )
    return;
  if (surface === "need") {
    if (state === "selected")
      await userEvent.click(
        await c.findByRole("button", { name: "Xem cách hình thành nhu cầu" }),
      );
    if (state === "dirty") {
      fireEvent.change(
        await c.findByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
        { target: { value: "12,5" } },
      );
      fireEvent.change(c.getByRole("combobox", { name: "Lý do Gạo thơm" }), {
        target: { value: "OTHER" },
      });
      fireEvent.change(c.getByRole("textbox", { name: "Ghi chú Gạo thơm" }), {
        target: { value: "Bếp yêu cầu" },
      });
    }
  }
  if (surface === "procurement") {
    await userEvent.click(
      (
        await c.findAllByRole("button", {
          name: /^(Phân bổ NCC|Xem phân bổ)(?: |$)/,
        })
      )[0]!,
    );
    if (state === "dirty")
      fireEvent.change(
        (await c.findAllByRole("textbox", { name: /Ghi chú cho/ }))[0]!,
        {
          target: { value: "Giao trước 05:30" },
        },
      );
  }
  if (surface === "recipes") {
    await userEvent.click(
      await c.findByRole("button", {
        name: /^(Sửa|Xem) công thức Canh bí đỏ thịt bằm$/,
      }),
    );
    if (state === "dirty")
      fireEvent.change(await c.findByLabelText("Định lượng Bí đỏ"), {
        target: { value: "30" },
      });
  }
  if (surface === "dispatch") {
    await userEvent.click(
      (
        await c.findAllByRole("button", {
          name: state === "blocked" ? "Xem lỗi" : "Phát hành",
        })
      )[0]!,
    );
    if (state === "dirty")
      fireEvent.change(
        await c.findByRole("textbox", { name: "Ghi chú trên phiếu" }),
        { target: { value: "Giao tại cổng phụ trước 06:00" } },
      );
  }
}
export const Pilot: Story = {
  play: async (context) => {
    await prepare(context);
    context.canvasElement
      .querySelector(".atlas-modern-prototype")
      ?.setAttribute("data-prepared", "true");
  },
};
