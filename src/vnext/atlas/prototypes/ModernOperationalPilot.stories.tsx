/**
 * THROWAWAY / DESIGN REVIEW ONLY — ATLAS-UI-VNEXT-03A.
 * Three compositions of the same current workbenches and in-memory fixtures.
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
} from "@phosphor-icons/react";
import { useEffect, useMemo, useRef, useState } from "react";
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

const variants = ["A", "B", "C"] as const;
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
}: {
  surface: Surface;
  state: State;
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
    return { need, procurement, recipes, dispatch };
  }, [state]);
  const simulatedExport = () =>
    setNotice("Xem thử: đã chọn xuất. Không tạo tệp hoặc chứng từ thật.");
  return (
    <>
      {surface === "need" && (
        <ConfirmedNeedWorkbench
          {...fixtures.need}
          authSubject="fixture-operator"
          initialServiceDate={needDate}
          onExportShoppingList={async () => {
            simulatedExport();
          }}
          onImportShoppingList={async (_file, _workbench, drafts) => {
            setNotice(
              "Xem thử: đã chọn tệp. Pilot không phân tích workbook; bản nháp được giữ nguyên.",
            );
            return { drafts, changedLineIds: [] };
          }}
          onContinueAllocation={() =>
            setNotice("Xem thử: tiếp tục phân bổ NCC từ nhu cầu đã lưu.")
          }
        />
      )}
      {surface === "procurement" && (
        <ProcurementWorkbench
          authSubject="fixture-operator"
          purchaseReviewApi={fixtures.procurement.purchaseReviewApi}
          procurementApi={fixtures.procurement.procurementApi}
          initialServiceDate={purchaseDate}
          schools={reviewSchools}
          onExportXlsx={simulatedExport}
          onExportPdf={simulatedExport}
        />
      )}
      {surface === "recipes" && (
        <DishRecipeWorkbench
          authSubject="fixture-operator"
          api={fixtures.recipes.api}
          initialDate={recipeFixtureDate}
          onOpenChangeOrders={() =>
            setNotice("Xem thử: mở Lệnh điều chỉnh. Không gọi lệnh thật.")
          }
        />
      )}
      {surface === "dispatch" && (
        <SchoolPxkWorkbench
          authSubject="fixture-operator"
          api={fixtures.dispatch}
          initialServiceDate={dispatchDate}
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
            aria-label="So sánh ba phương án"
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
        </Flex>
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
