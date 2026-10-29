import { atlasVisuallyHidden } from "../AtlasTaskTabs";
import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  Table,
  Text,
} from "@chakra-ui/react";
import {
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
  type Ref,
} from "react";
import type { RecipeAdjustmentApi } from "../bridges/recipeAdjustment";
import {
  useAtlasWorkbenchStatus,
  type AtlasModuleExitProps,
} from "../AtlasModuleExit";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasWorkbar, AtlasWorkbarActions } from "../AtlasWorkbar";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { AtlasTaskContext } from "../AtlasTaskContext";
import { useAtlasWorkbenchActive } from "../AtlasVNextProvider";
import {
  focusFirstCompactFilter,
  preserveCompactFilterFocusOrder,
} from "../compactFilterFocus";
import { RecipeDirtyExitDialog } from "./RecipeDialogs";
import { ChangeOrderEditor, ChangeSelect } from "./ChangeOrderEditor";
import { ChangeOrderReview, ChangeOrderCancel } from "./ChangeOrderDialogs";
import { ChangeOrderDetail } from "./ChangeOrderDetail";
import {
  actionLabels,
  ledgerRows,
  periodLabel,
  rowFacts,
  scopeLabels,
  temporalLabels,
} from "./changeOrderModel";
import {
  useChangeOrderWorkbench,
  type RecipeJobHandle,
} from "./useChangeOrderWorkbench";

function resetOwnerReadingPosition(node: HTMLElement | null) {
  let owner = node?.parentElement ?? null;
  while (owner) {
    const overflow = window.getComputedStyle(owner).overflowY;
    if (
      /(auto|scroll)/.test(overflow) &&
      owner.scrollHeight > owner.clientHeight
    ) {
      owner.scrollTop = 0;
      owner.scrollLeft = 0;
      return;
    }
    owner = owner.parentElement;
  }
}

export function ChangeOrderWorkbench(
  props: AtlasModuleExitProps & {
    authSubject: string | null;
    api: RecipeAdjustmentApi;
    initialDate?: string;
    standalone?: boolean;
    exitRef?: Ref<RecipeJobHandle>;
  },
) {
  const c = useChangeOrderWorkbench(props);
  const active = useAtlasWorkbenchActive();
  useAtlasWorkbenchStatus(props.onWorkspaceStatus, {
    unsaved: c.dirty || (Boolean(c.cancelTarget) && c.cancelDirty),
    blocked: Boolean(
      c.loading ||
      c.busy ||
      c.lock ||
      c.preview ||
      c.previewLoading ||
      c.cancelTarget ||
      c.discardOpen,
    ),
    attention: c.lock ? c.message : undefined,
  });
  const [query, setQuery] = useState(""),
    [temporal, setTemporal] = useState("current"),
    [scope, setScope] = useState(""),
    [filtersOpen, setFiltersOpen] = useState(false);
  const detail = useRef<HTMLDivElement>(null),
    detailBody = useRef<HTMLDivElement>(null),
    origin = useRef<HTMLButtonElement | null>(null),
    compactFilters = useRef<HTMLDivElement>(null),
    compactFilterTrigger = useRef<HTMLButtonElement>(null),
    compactFilterOnward = useRef<HTMLDivElement>(null),
    wasOpen = useRef(false),
    activeSelection = useRef<string | null>(null);
  const open = Boolean(c.draft || c.selected),
    selectedKey = c.draft?.adjustmentId ?? c.selected?.adjustment_id;
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  useEffect(() => {
    if (!active) return;
    if (open) {
      if (selectedKey !== activeSelection.current) {
        activeSelection.current = selectedKey ?? null;
        if (detail.current) detail.current.scrollTop = 0;
        if (detailBody.current) detailBody.current.scrollTop = 0;
        detail.current?.focus({ preventScroll: true });
        resetOwnerReadingPosition(detail.current);
      }
    } else if (wasOpen.current) {
      origin.current?.focus();
      activeSelection.current = null;
    }
    wasOpen.current = open;
  }, [active, open, selectedKey]);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
  const rows = ledgerRows(c.data, query, temporal, scope);
  const temporalFilterLabels: Record<string, string> = {
    current: "Cần chú ý / hiện hành",
    all: "Tất cả",
    active: "Đang hiệu lực",
    SCHEDULED: "Sắp hiệu lực",
    EXPIRED: "Đã kết thúc",
    CANCELLED: "Đã hủy",
  };
  const temporalFilterLabel =
    temporalFilterLabels[temporal] ?? "Không xác định";
  const scopeFilterLabel = scope
    ? (Object.entries(scopeLabels).find(([value]) => value === scope)?.[1] ??
      "Không xác định")
    : "Tất cả";
  return (
    <Box aria-label="Lệnh điều chỉnh" minW="var(--atlas-layout-zero, 0)">
      {props.standalone && (
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh lệnh điều chỉnh"
          moduleLabel="Công thức"
          jobLabel="Lệnh điều chỉnh"
          compactSummary={`${rows.length} lệnh · ${temporalFilterLabel}`}
        />
      )}
      <AtlasWorkbar
        display={{ base: open ? "none" : "grid", lg: "grid" }}
        bg="bg.toolbar"
        px={{ base: "sm", md: "md" }}
        py="sm"
        gap="sm"
        alignItems="end"
        templateColumns={{
          base: "minmax(0, 1fr) auto",
          md: "minmax(180px, 1fr) minmax(340px, 400px) auto",
        }}
        aria-label="Bộ lọc lệnh điều chỉnh"
      >
        <Field.Root
          minW="var(--atlas-layout-zero, 0)"
          gridRow={{ base: "1", md: "auto" }}
        >
          <Field.Label display={{ base: "none", md: "block" }}>
            Tìm lệnh
          </Field.Label>
          <Input
            aria-label="Tìm lệnh"
            value={query}
            placeholder="Món, trường, nguyên liệu, lý do…"
            onChange={(e) => setQuery(e.target.value)}
          />
        </Field.Root>
        <Grid
          ref={compactFilters}
          id="change-order-filters"
          display={{ base: filtersOpen ? "grid" : "none", md: "grid" }}
          gridColumn={{ base: "1 / -1", md: "auto" }}
          gridRow={{ base: "3", md: "auto" }}
          templateColumns="repeat(2, minmax(0, 1fr))"
          gap="sm"
          minW="var(--atlas-layout-zero, 0)"
          onKeyDown={(event) => {
            if (filtersOpen)
              preserveCompactFilterFocusOrder(
                event,
                compactFilters.current,
                compactFilterTrigger.current,
                compactFilterOnward.current,
              );
          }}
        >
          <Box minW="var(--atlas-layout-zero, 0)">
            <ChangeSelect
              label="Tình trạng"
              value={temporal}
              onChange={setTemporal}
            >
              <option value="current">Cần chú ý / hiện hành</option>
              <option value="all">Tất cả</option>
              <option value="active">Đang hiệu lực</option>
              <option value="SCHEDULED">Sắp hiệu lực</option>
              <option value="EXPIRED">Đã kết thúc</option>
              <option value="CANCELLED">Đã hủy</option>
            </ChangeSelect>
          </Box>
          <Box minW="var(--atlas-layout-zero, 0)">
            <ChangeSelect label="Phạm vi" value={scope} onChange={setScope}>
              <option value="">Tất cả</option>
              {Object.entries(scopeLabels).map(([v, label]) => (
                <option key={v} value={v}>
                  {label}
                </option>
              ))}
            </ChangeSelect>
          </Box>
        </Grid>
        <Button
          ref={compactFilterTrigger}
          display={{ base: "inline-flex", md: "none" }}
          gridColumn="2"
          gridRow="1"
          variant="secondary"
          minH="var(--atlas-layout-mobile-target, 44px)"
          aria-expanded={filtersOpen}
          aria-controls="change-order-filters"
          onClick={() => setFiltersOpen((value) => !value)}
        >
          Bộ lọc
        </Button>
        <Text
          display={{ base: filtersOpen ? "none" : "block", md: "none" }}
          gridColumn="1 / -1"
          gridRow="2"
          textStyle="helper"
          color="fg.muted"
        >
          Tình trạng: {temporalFilterLabel} · Phạm vi: {scopeFilterLabel}
        </Text>
        <AtlasWorkbarActions
          ref={compactFilterOnward}
          gridColumn={{ base: "1 / -1", md: "auto" }}
          gridRow={{ base: filtersOpen ? "4" : "3", md: "auto" }}
          justifyContent={{ base: "flex-start", md: "flex-end" }}
          flexWrap="wrap"
        >
          <AtlasRefreshButton
            loading={c.loading}
            disabled={c.refreshDisabled}
            onClick={c.refresh}
          />
          <Button
            variant={open ? "secondary" : "businessPrimary"}
            disabled={
              !c.canAct || Boolean(c.preview) || Boolean(c.cancelTarget)
            }
            onClick={(e) => {
              origin.current = e.currentTarget;
              c.openCreate();
            }}
          >
            Tạo lệnh điều chỉnh
          </Button>
        </AtlasWorkbarActions>
      </AtlasWorkbar>
      {c.message && (
        <Box px="md" py="sm" role={c.lock || !c.ready ? "alert" : "status"}>
          <Text color={c.lock ? "status.warning" : "fg.default"}>
            {c.message}
          </Text>
          {(c.lock || !c.ready) && (
            <Button
              mt="xs"
              loading={c.loading}
              disabled={c.busy}
              onClick={() => void c.recover()}
            >
              {c.lock === "unknown" || c.lock === "readback"
                ? "Tải lại để xác nhận"
                : "Tải lại dữ liệu hiện tại"}
            </Button>
          )}
        </Box>
      )}
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: open ? "320px minmax(0, 1fr)" : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
      >
        <Box
          display={{ base: open ? "none" : "block", lg: "block" }}
          minW="var(--atlas-layout-zero, 0)"
        >
          <AtlasTableViewport
            label="Bảng lệnh điều chỉnh"
            maxH="var(--atlas-adjustment-ledger-height, calc(100dvh - 300px))"
          >
            <Table.Root
              size="sm"
              aria-label="Lệnh điều chỉnh"
              tableLayout="fixed"
              minW={
                open
                  ? "var(--atlas-layout-zero, 0)"
                  : {
                      base: "var(--atlas-layout-zero, 0)",
                      md: "var(--atlas-adjustment-table-width, 740px)",
                    }
              }
              css={{
                "& th, & td": {
                  whiteSpace: "normal",
                  overflowWrap: "anywhere",
                  paddingBlock: "var(--atlas-spacing-xs)",
                  verticalAlign: "middle",
                },
                ...(open
                  ? {
                      "& colgroup": { display: "none" },
                      "& tbody": { display: "block" },
                      "& tr": {
                        display: "grid",
                        gridTemplateColumns: "minmax(0, 1fr) auto",
                        padding: "var(--atlas-spacing-xs)",
                        borderBottom:
                          "1px solid var(--atlas-colors-border-subtle)",
                      },
                      "& td": { display: "block", border: "none" },
                      "& td:first-of-type": { fontWeight: "semibold" },
                      "& td:nth-of-type(n + 2):nth-of-type(-n + 5)": {
                        gridColumn: "1 / -1",
                      },
                      "& td:last-of-type": {
                        gridColumn: "2",
                        gridRow: "1",
                      },
                    }
                  : {}),
                "@media(max-width:47.99rem)": {
                  "& colgroup": { display: "none" },
                  "& tbody": { display: "block" },
                  "& tr": {
                    display: "grid",
                    gridTemplateColumns: "minmax(0, 1fr) auto",
                    padding: "var(--atlas-spacing-xs)",
                    borderBottom: "1px solid var(--atlas-colors-border-subtle)",
                  },
                  "& td": { display: "block", border: "none" },
                  "& td:first-of-type": { fontWeight: "semibold" },
                  "& td:nth-of-type(n + 2):nth-of-type(-n + 5)": {
                    gridColumn: "1 / -1",
                  },
                  "& td:last-of-type": {
                    gridColumn: "2",
                    gridRow: "1",
                  },
                },
              }}
            >
              <Table.Header
                css={
                  open
                    ? atlasVisuallyHidden
                    : { "@media(max-width:47.99rem)": atlasVisuallyHidden }
                }
              >
                <Table.Row>
                  {[
                    "Lệnh",
                    "Phạm vi",
                    "Đối tượng",
                    "Hiệu lực",
                    "Trạng thái",
                    "Thao tác",
                  ].map((label) => (
                    <Table.ColumnHeader
                      key={label}
                      left={
                        label === "Lệnh"
                          ? "var(--atlas-layout-zero, 0)"
                          : undefined
                      }
                      position={
                        label === "Thao tác" || label === "Lệnh"
                          ? { base: "static", md: "sticky" }
                          : undefined
                      }
                      right={
                        label === "Thao tác"
                          ? "var(--atlas-layout-zero, 0)"
                          : undefined
                      }
                      bg="bg.toolbar"
                      w={
                        label === "Thao tác"
                          ? "var(--atlas-layout-row-action, 58px)"
                          : undefined
                      }
                    >
                      {label}
                    </Table.ColumnHeader>
                  ))}
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {rows.map((row) => (
                  <Table.Row
                    key={row.adjustment_id}
                    aria-selected={
                      c.selected?.adjustment_id === row.adjustment_id
                    }
                    bg={
                      c.selected?.adjustment_id === row.adjustment_id
                        ? "bg.selected"
                        : undefined
                    }
                  >
                    <Table.Cell
                      data-sticky-column=""
                      position={{ base: "relative", md: "sticky" }}
                      left="var(--atlas-layout-zero, 0)"
                      bg="bg.workbench"
                      zIndex="var(--atlas-layout-sticky-cell, 1)"
                    >
                      {c.selected?.adjustment_id === row.adjustment_id && (
                        <Box data-selection-indicator />
                      )}
                      {actionLabels[row.action_kind]}
                    </Table.Cell>
                    <Table.Cell>{scopeLabels[row.scope_kind]}</Table.Cell>
                    <Table.Cell>{rowFacts(row, c.data).join(" · ")}</Table.Cell>
                    <Table.Cell>
                      {periodLabel(
                        row.display_revision.effective_from,
                        row.display_revision.effective_to,
                      )}
                    </Table.Cell>
                    <Table.Cell>
                      {temporalLabels[row.temporal_state]}
                    </Table.Cell>
                    <Table.Cell
                      data-sticky-column=""
                      position={{ base: "static", md: "sticky" }}
                      right="var(--atlas-layout-zero, 0)"
                      bg="bg.workbench"
                      zIndex="var(--atlas-layout-sticky-cell, 1)"
                    >
                      <Button
                        variant="tertiary"
                        size="sm"
                        disabled={
                          !c.canAct ||
                          Boolean(c.preview) ||
                          Boolean(c.cancelTarget)
                        }
                        aria-label={`Xem lệnh ${actionLabels[row.action_kind]} ${rowFacts(row, c.data)[0] ?? ""}`}
                        onClick={(e) => {
                          origin.current = e.currentTarget;
                          c.select(row);
                        }}
                      >
                        Xem
                      </Button>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table.Body>
            </Table.Root>
            {c.ready && !rows.length && (
              <Text p="md" textStyle="helper" color="fg.muted">
                {c.data.operator_rows.length
                  ? "Không có lệnh phù hợp bộ lọc."
                  : "Chưa có lệnh điều chỉnh."}
              </Text>
            )}
          </AtlasTableViewport>
        </Box>
        {open && (
          <Box
            ref={detail}
            tabIndex={-1}
            aria-label="Chi tiết lệnh"
            display="flex"
            flexDirection="column"
            maxH={{
              base: "var(--atlas-layout-detail-height, calc(100dvh - 120px))",
              lg: "var(--atlas-layout-detail-height, calc(100dvh - 280px))",
            }}
            overflow="hidden"
            borderLeftWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.subtle"
            minW="var(--atlas-layout-zero, 0)"
          >
            <Flex
              justify="space-between"
              align="center"
              gap="sm"
              p={{ base: "sm", md: "md" }}
              borderBottomWidth="var(--atlas-layout-edge, 1px)"
              borderColor="border.subtle"
              flexShrink="0"
            >
              <Heading as="h2" textStyle="section">
                {c.draft
                  ? c.editing
                    ? "Sửa lệnh"
                    : "Tạo lệnh điều chỉnh"
                  : "Chi tiết lệnh"}
              </Heading>
              <Button
                variant="tertiary"
                size="sm"
                aria-label="Đóng lệnh"
                disabled={c.busy || Boolean(c.lock)}
                onClick={c.close}
              >
                Đóng
              </Button>
            </Flex>
            <Box
              ref={detailBody}
              p={{ base: "sm", md: "md" }}
              overflowY="auto"
              minH="var(--atlas-layout-zero, 0)"
              minW="var(--atlas-layout-zero, 0)"
            >
              {c.draft ? (
                <ChangeOrderEditor c={c} />
              ) : (
                <ChangeOrderDetail key={c.selected!.adjustment_id} c={c} />
              )}
            </Box>
          </Box>
        )}
      </Grid>
      <RecipeDirtyExitDialog c={c} />
      <ChangeOrderReview c={c} />
      {c.cancelTarget && (
        <ChangeOrderCancel key={c.cancelTarget.adjustment_id} c={c} />
      )}
    </Box>
  );
}
