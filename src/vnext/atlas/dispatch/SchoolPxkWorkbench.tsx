import {
  Box,
  Field,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
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
export function SchoolPxkWorkbench(props: SchoolPxkWorkbenchProps) {
  const c = useSchoolPxkWorkbench(props);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const detail = useRef<HTMLDivElement>(null);
  const lastKey = useRef<string | null>(null);
  const pendingTrigger = useRef<HTMLButtonElement | null>(null);
  const dialogTrigger = useRef<HTMLElement | null>(null);
  const dialogDestination = useRef<"row" | "detail" | "date" | null>(null);
  const dateControl = useRef<HTMLDivElement>(null);
  const [dateReset, setDateReset] = useState(0);
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
  return (
    <Box
      as="section"
      aria-label="Phiếu xuất kho"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Heading as="h1" textStyle="workbenchTitle" p="md">
        Phiếu xuất kho
      </Heading>
      <Grid
        bg="bg.toolbar"
        p="md"
        gap="sm"
        alignItems="start"
        templateColumns={{
          base: "minmax(0, 1fr)",
          md: "repeat(2, minmax(0, 1fr))",
          xl: "minmax(150px, 0.9fr) minmax(180px, 1.4fr) minmax(160px, 1.3fr) minmax(140px, 1fr) auto",
        }}
      >
        <Box ref={dateControl}>
          <AtlasDateInput
            key={dateReset}
            label="Ngày phục vụ"
            value={c.date}
            disabled={disabled}
            onValueChange={(date) => transition({ date })}
          />
        </Box>
        <Box>
          <Text textStyle="label" mb="xs">
            Trường / điểm giao
          </Text>
          <AtlasSchoolScope
            schools={c.schools}
            value={c.schoolIds}
            disabled={disabled || !c.schools.length}
            onApply={(schoolIds) => transition({ schoolIds })}
          />
        </Box>
        <Field.Root>
          <Field.Label>Tìm kiếm</Field.Label>
          <Input
            aria-label="Tìm kiếm"
            placeholder="Trường, phiếu, nguyên liệu…"
            value={c.search}
            onChange={(e) => c.setSearch(e.target.value)}
          />
        </Field.Root>
        <Field.Root>
          <Field.Label>Tình trạng</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label="Tình trạng"
              value={c.filter}
              onChange={(e) => c.setFilter(e.target.value)}
            >
              <option value="all">Tất cả</option>
              {(
                ["READY", "REPLACEMENT_REQUIRED", "BLOCKED", "CURRENT"] as const
              ).map((key) => (
                <option key={key} value={key}>
                  {pxkLabels[key]}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Box
          pt={{
            base: "var(--atlas-layout-zero, 0)",
            xl: "var(--atlas-layout-refresh-offset, 26px)",
          }}
        >
          <AtlasRefreshButton
            loading={c.loading}
            disabled={disabled}
            onClick={() => transition({ refresh: true })}
          />
        </Box>
      </Grid>
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
      <Text px="md" py="sm" textStyle="helper" color="fg.muted">
        {(["READY", "REPLACEMENT_REQUIRED", "BLOCKED", "CURRENT"] as const)
          .map(
            (s) =>
              `${pxkLabels[s]} ${c.rows.filter((r) => r.state === s).length}`,
          )
          .join(" · ")}
      </Text>
      {c.loading && (
        <Text role="status" px="md" pb="sm">
          Đang tải phiếu xuất kho…
        </Text>
      )}
      {!c.loading && !c.readError && !c.rows.length && (
        <Text p="md">Không có phiếu xuất kho trong phạm vi đã chọn.</Text>
      )}
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: c.selected
            ? "minmax(0, 62fr) minmax(320px, 38fr)"
            : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
        data-pxk-master-detail
      >
        <Box minW="var(--atlas-layout-zero, 0)">
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
          dialogDestination.current = c.pendingTransition?.date ? "date" : null;
          // DateInput retains an edited segment internally when its controlled
          // ISO value is unchanged. Remount only a cancelled date edit.
          if (c.pendingTransition?.date) setDateReset((value) => value + 1);
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
                      dialogTrigger.current?.dataset.type,
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
