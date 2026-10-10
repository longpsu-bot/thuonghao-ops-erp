import {
  Box,
  Button,
  Flex,
  Field,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState, useImperativeHandle, useId } from "react";
import { useAtlasWorkbenchStatus } from "../AtlasModuleExit";
import { AtlasDateRangeInput } from "../AtlasDateRangeInput";
import { AtlasWorkbar, AtlasWorkbarActions } from "../AtlasWorkbar";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import {
  useSchoolPxkWorkbench,
  type SchoolPxkWorkbenchProps,
} from "./useSchoolPxkWorkbench";
import { SchoolPxkTable, pxkLabels } from "./SchoolPxkTable";
import { SchoolPxkDetail } from "./SchoolPxkDetail";
import { SchoolPxkDirtyExitDialog } from "./SchoolPxkDirtyExitDialog";
import { SchoolPxkCommandFeedback } from "./SchoolPxkCommandFeedback";
import type { SchoolDispatchDocument } from "../bridges/schoolDispatch";
import {
  focusFirstCompactFilter,
  preserveCompactFilterFocusOrder,
} from "../compactFilterFocus";
export function SchoolPxkWorkbench(props: SchoolPxkWorkbenchProps) {
  const rangeErrorId = useId();
  const c = useSchoolPxkWorkbench(props);
  useAtlasWorkbenchStatus(props.onWorkspaceStatus, {
    unsaved: Boolean(c.note.trim()),
    blocked: c.busy || Boolean(c.lock),
    attention: c.lock
      ? "Cần xác nhận dữ liệu hiện tại"
      : c.busy
        ? "Đang phát hành"
        : undefined,
  });
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  const trigger = useRef<HTMLButtonElement | null>(null);
  const detail = useRef<HTMLDivElement>(null);
  const lastKey = useRef<string | null>(null);
  const pendingTrigger = useRef<HTMLButtonElement | null>(null);
  const dialogTrigger = useRef<HTMLElement | null>(null);
  const dialogDestination = useRef<"row" | "detail" | "date" | null>(null);
  const dateControl = useRef<HTMLDivElement>(null);
  const [dateReset, setDateReset] = useState(0);
  const [exportError, setExportError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [exportMode, setExportMode] = useState<"date" | "entity">("date");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const compactFilters = useRef<HTMLDivElement>(null);
  const compactFilterTrigger = useRef<HTMLButtonElement>(null);
  const compactFilterOnward = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
  const releasedDocuments = Array.from(
    new Map(
      c.rows
        .filter((row) => row.allowed_actions.export)
        .flatMap((row) => [row.current_release, ...row.history])
        .filter(
          (document): document is SchoolDispatchDocument =>
            document !== null &&
            document.export_ready &&
            ["RELEASED", "SUPERSEDED"].includes(document.status),
        )
        .map((document) => [document.school_dispatch_release_id, document]),
    ).values(),
  );
  const transition: typeof c.transition = (next) => {
    dialogTrigger.current =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
    dialogDestination.current = null;
    c.transition(next);
  };
  useEffect(() => {
    if (c.selectedKey !== lastKey.current) {
      if (c.selectedKey) {
        trigger.current = pendingTrigger.current;
        detail.current?.focus();
      } else trigger.current?.focus();
      lastKey.current = c.selectedKey;
    }
  }, [c.selectedKey]);
  const disabled = c.busy || Boolean(c.lock);
  const exportLoaded = async (zip: boolean) => {
    if (!c.canExportLoaded || exporting || !releasedDocuments.length) return;
    setExporting(true);
    setExportError(null);
    try {
      if (zip) await props.onExportZip?.(releasedDocuments, exportMode);
      else await props.onExportGroupedXlsx?.(releasedDocuments);
    } catch {
      setExportError("Không thể xuất nhóm Phiếu xuất kho.");
    } finally {
      setExporting(false);
    }
  };
  const dateSummary =
    c.date.split("-").reverse().join("/") +
    (c.dateEnd !== c.date
      ? ` — ${c.dateEnd.split("-").reverse().join("/")}`
      : "");
  const scopeSummary =
    c.schoolIds.length === 0
      ? "Tất cả trường"
      : c.schoolIds.length === 1
        ? (c.schools.find((school) => school.school_id === c.schoolIds[0])
            ?.school_name ?? "1 trường")
        : `${c.schoolIds.length} trường`;
  const stateSummary =
    Object.entries(pxkLabels).find(([value]) => value === c.filter)?.[1] ??
    "Tất cả";
  return (
    <Box
      as="section"
      aria-label="Phiếu xuất kho"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      minH="var(--atlas-layout-zero, 0)"
      h="full"
      display="flex"
      flexDirection="column"
    >
      <Heading
        as="h1"
        textStyle="workbenchTitle"
        px="md"
        py="sm"
        flexShrink="0"
      >
        Phiếu xuất kho
      </Heading>
      <AtlasWorkbar
        display="grid"
        bg="bg.toolbar"
        px={{ base: "sm", md: "md" }}
        py="sm"
        gap="sm"
        alignItems="end"
        flexShrink="0"
        role="group"
        aria-label="Phạm vi phiếu xuất kho"
        gridTemplateColumns={{
          base: "minmax(0, 1fr) auto auto",
          md: "repeat(2, minmax(0, 1fr))",
          xl: "minmax(310px, 1.6fr) minmax(180px, 1.4fr) minmax(160px, 1.3fr) minmax(140px, 1fr) auto",
        }}
      >
        <Box
          ref={compactFilters}
          id="pxk-filters"
          display="contents"
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
          <Box
            ref={dateControl}
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 4, md: 1 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
            <AtlasDateRangeInput
              key={dateReset}
              label="Khoảng ngày"
              value={c.range}
              error={c.rangeError}
              errorMessageId={rangeErrorId}
              disabled={disabled}
              onValueChange={(range) => transition({ range })}
            />
          </Box>
          <Box
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 5, md: 2 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
            <Text textStyle="label" mb="xs">
              Trường / điểm giao
            </Text>
            <AtlasSchoolScope
              schools={c.schools}
              value={c.schoolIds}
              disabled={disabled || Boolean(c.rangeError) || !c.schools.length}
              onApply={(schoolIds) => transition({ schoolIds })}
            />
          </Box>
          <Field.Root
            order={{ base: 0, md: 3 }}
            gridColumn={{ base: "1", md: "auto" }}
          >
            <Field.Label display={{ base: "none", md: "block" }}>
              Tìm kiếm
            </Field.Label>
            <Input
              aria-label="Tìm kiếm"
              placeholder="Trường, phiếu, nguyên liệu…"
              value={c.search}
              onChange={(e) => c.setSearch(e.target.value)}
            />
          </Field.Root>
          <Field.Root
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 6, md: 4 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
            <Field.Label>Tình trạng</Field.Label>
            <NativeSelect.Root>
              <NativeSelect.Field
                aria-label="Tình trạng"
                value={c.filter}
                onChange={(e) => c.setFilter(e.target.value)}
              >
                <option value="all">Tất cả</option>
                {(
                  [
                    "READY",
                    "REPLACEMENT_REQUIRED",
                    "BLOCKED",
                    "CURRENT",
                  ] as const
                ).map((key) => (
                  <option key={key} value={key}>
                    {pxkLabels[key]}
                  </option>
                ))}
              </NativeSelect.Field>
              <NativeSelect.Indicator />
            </NativeSelect.Root>
          </Field.Root>
        </Box>
        <Button
          ref={compactFilterTrigger}
          display={{ base: "inline-flex", md: "none" }}
          order="1"
          gridColumn="2"
          variant="secondary"
          minH="var(--atlas-layout-mobile-target, 44px)"
          aria-expanded={filtersOpen}
          aria-controls="pxk-filters"
          onClick={() => setFiltersOpen((open) => !open)}
        >
          Bộ lọc
        </Button>
        <Text
          display={{ base: filtersOpen ? "none" : "block", md: "none" }}
          order="3"
          gridColumn="1 / -1"
          textStyle="helper"
          color="fg.muted"
        >
          Ngày {dateSummary} · {scopeSummary} · Tình trạng: {stateSummary}
        </Text>
        <AtlasWorkbarActions
          ref={compactFilterOnward}
          order={{ base: 2, md: 5 }}
          gridColumn={{ base: "3", md: "auto" }}
        >
          <AtlasRefreshButton
            loading={c.loading}
            disabled={disabled || Boolean(c.rangeError)}
            onClick={() => transition({ refresh: true })}
          />
        </AtlasWorkbarActions>
      </AtlasWorkbar>
      {c.rangeError && (
        <Text
          id={rangeErrorId}
          role="alert"
          textStyle="helper"
          color="status.danger"
          px="md"
          py="xs"
        >
          {c.rangeError}
        </Text>
      )}
      <SchoolPxkCommandFeedback
        lock={c.lock}
        notice={c.notice}
        readError={c.readError}
        loading={c.loading}
        onRecover={() => {
          if (c.lock) void c.recover();
          else transition({ refresh: true });
        }}
      />
      <Flex
        px="md"
        py="sm"
        gap="sm"
        align="center"
        justify="space-between"
        wrap="wrap"
        flexShrink="0"
      >
        <Text textStyle="helper" color="fg.muted">
          {(["READY", "REPLACEMENT_REQUIRED", "BLOCKED", "CURRENT"] as const)
            .map(
              (s) =>
                `${pxkLabels[s]} ${c.rows.filter((r) => r.state === s).length}`,
            )
            .join(" · ")}
        </Text>
        {(props.onExportGroupedXlsx || props.onExportZip) && (
          <AtlasWorkbar
            aria-label="Xuất phiếu trong phạm vi đã tải"
            justifyContent="flex-end"
          >
            {props.onExportZip && (
              <Field.Root
                w={{
                  base: "full",
                  md: "var(--atlas-export-mode-width, 230px)",
                }}
              >
                <Field.Label>Nhóm file xuất kho</Field.Label>
                <NativeSelect.Root disabled={!c.canExportLoaded || exporting}>
                  <NativeSelect.Field
                    value={exportMode}
                    onChange={(event) =>
                      setExportMode(event.target.value as "date" | "entity")
                    }
                  >
                    <option value="date">Theo ngày</option>
                    <option value="entity">Theo trường / điểm giao</option>
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
              </Field.Root>
            )}
            <AtlasWorkbarActions>
              {props.onExportGroupedXlsx && (
                <Button
                  variant="secondary"
                  disabled={
                    !c.canExportLoaded || exporting || !releasedDocuments.length
                  }
                  onClick={() => void exportLoaded(false)}
                >
                  Xuất Excel · phạm vi đã tải
                </Button>
              )}
              {props.onExportZip && (
                <Button
                  variant="secondary"
                  loading={exporting}
                  disabled={!c.canExportLoaded || !releasedDocuments.length}
                  onClick={() => void exportLoaded(true)}
                >
                  Xuất ZIP · phạm vi đã tải
                </Button>
              )}
            </AtlasWorkbarActions>
          </AtlasWorkbar>
        )}
      </Flex>
      {exportError && (
        <Text px="md" pb="sm" role="alert" color="status.danger">
          {exportError}
        </Text>
      )}
      {c.loading && (
        <Text role="status" px="md" pb="sm">
          Đang tải phiếu xuất kho…
        </Text>
      )}
      {!c.loading && !c.readError && !c.rows.length && (
        <Text p="md">Không có phiếu xuất kho trong phạm vi đã chọn.</Text>
      )}
      <Grid
        flex="1"
        minH="var(--atlas-layout-zero, 0)"
        templateRows={{
          base: c.selected
            ? "fit-content(35%) minmax(0, 1fr)"
            : "minmax(0, 1fr)",
          lg: "minmax(0, 1fr)",
        }}
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: c.selected
            ? "minmax(0, 62fr) minmax(320px, 38fr)"
            : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
        data-pxk-master-detail
      >
        <Box
          minW="var(--atlas-layout-zero, 0)"
          minH="var(--atlas-layout-zero, 0)"
          h="full"
        >
          <SchoolPxkTable
            rows={c.visibleRows}
            selectedKey={c.selectedKey}
            disabled={disabled || c.loading}
            onSelect={(row, button) => {
              pendingTrigger.current = button;
              transition({ selectedKey: c.key(row) });
            }}
          />
          {c.rows.length > 0 && !c.visibleRows.length && (
            <Text p="md">Không có phiếu khớp bộ lọc.</Text>
          )}
        </Box>
        {c.selected && (
          <SchoolPxkDetail
            row={c.selected}
            note={c.note}
            onNote={c.setNote}
            canRelease={c.canRelease}
            actionAllowed={c.actionAllowed}
            busy={c.busy}
            locked={Boolean(c.lock)}
            onRelease={() => void c.release()}
            onClose={() => transition({ selectedKey: null })}
            detailRef={detail}
            onExportXlsx={props.onExportXlsx}
            onExportPdf={props.onExportPdf}
          />
        )}
      </Grid>
      <SchoolPxkDirtyExitDialog
        open={Boolean(c.pendingTransition)}
        onCancel={() => {
          dialogDestination.current =
            c.pendingTransition?.date || c.pendingTransition?.range
              ? "date"
              : null;
          // DateInput retains an edited segment internally when its controlled
          // ISO value is unchanged. Remount only a cancelled date edit.
          if (c.pendingTransition?.date || c.pendingTransition?.range)
            setDateReset((value) => value + 1);
          c.cancelTransition();
        }}
        onDiscard={() => {
          dialogDestination.current =
            c.pendingTransition && "selectedKey" in c.pendingTransition
              ? c.pendingTransition.selectedKey === null
                ? "row"
                : "detail"
              : null;
          c.discardTransition();
        }}
        finalFocusEl={() =>
          dialogDestination.current === "row"
            ? trigger.current
            : dialogDestination.current === "detail"
              ? detail.current
              : dialogDestination.current === "date"
                ? (Array.from(
                    dateControl.current?.querySelectorAll<HTMLElement>(
                      '[role="spinbutton"]',
                    ) ?? [],
                  ).find(
                    (element) =>
                      element.dataset.type ===
                        dialogTrigger.current?.dataset.type &&
                      element
                        .closest('[data-part="segment-group"]')
                        ?.id.split(":")
                        .at(-1) ===
                        dialogTrigger.current
                          ?.closest('[data-part="segment-group"]')
                          ?.id.split(":")
                          .at(-1),
                  ) ??
                  dateControl.current?.querySelector<HTMLElement>(
                    '[role="spinbutton"]',
                  ) ??
                  null)
                : dialogTrigger.current
        }
      />
    </Box>
  );
}
