import { AtlasOperationStatus } from "../AtlasOperationStatus";
import {
  Box,
  Button,
  Checkbox,
  Field,
  Flex,
  Grid,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState, useImperativeHandle } from "react";
import { AtlasWeekRangeInput } from "../AtlasWeekRangeInput";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import { AtlasTaskContext } from "../AtlasTaskContext";
import {
  useConfirmedNeedWorkbench,
  type ConfirmedNeedWorkbenchProps,
} from "./useConfirmedNeedWorkbench";
import { preflightMessage, weekDates } from "./confirmedNeedAuthority";
import { ConfirmedNeedTable } from "./ConfirmedNeedTable";
import { ConfirmedNeedDirtyExitDialog } from "./ConfirmedNeedDirtyExitDialog";
import { ConfirmedNeedCommandFeedback } from "./ConfirmedNeedCommandFeedback";
import { ConfirmedNeedSupportDetail } from "./ConfirmedNeedSupportDetail";
import {
  focusFirstCompactFilter,
  preserveCompactFilterFocusOrder,
} from "../compactFilterFocus";
const viDate = (date: string) => date.split("-").reverse().join("/");
export function ConfirmedNeedWorkbench(props: ConfirmedNeedWorkbenchProps) {
  const c = useConfirmedNeedWorkbench(props);
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  const [detailKey, setDetailKey] = useState<string | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [workbookBusy, setWorkbookBusy] = useState(false);
  const [workbookError, setWorkbookError] = useState<string | null>(null);
  const workbookInput = useRef<HTMLInputElement>(null);
  const compactFilters = useRef<HTMLDivElement>(null);
  const compactFilterTrigger = useRef<HTMLButtonElement>(null);
  const compactFilterOnward = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
  const days = weekDates(c.week);
  const contextKey = `${c.date}:${c.workbench?.need_generation_source.run_id}:${c.workbench?.batch_version}`;
  const detailOpen = detailKey === contextKey;
  const contextDisabled = c.busy || Boolean(c.lock);
  const dateSummary = viDate(c.date);
  const scopeSummary =
    c.readError && !c.workbench
      ? "Không xác định"
      : c.schoolIds.length
        ? `${c.schoolIds.length} trường`
        : "Tất cả trường";
  const filterSummary = {
    all: "Tất cả",
    needs_review: "Cần rà soát",
    carried_forward: "Giữ nguyên",
  }[c.filter];
  return (
    <Box
      as="section"
      aria-label="Xác nhận nhu cầu"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      overflow="hidden"
    >
      <Grid
        templateColumns="minmax(0, 1fr)"
        templateRows="auto minmax(0, 1fr)"
        minH="var(--atlas-confirmed-need-station-height, var(--atlas-layout-workbench-height, calc(100dvh - 100px)))"
      >
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh xác nhận nhu cầu"
          moduleLabel="Lập nhu cầu"
          jobLabel="Xác nhận nhu cầu"
          compactSummary={`${dateSummary} · ${scopeSummary}`}
          details={[
            { label: "Ngày phục vụ", value: dateSummary },
            { label: "Trường / điểm giao", value: scopeSummary },
          ]}
        />
        <Box minW="var(--atlas-layout-zero, 0)">
          <Grid
            role="group"
            aria-label="Phạm vi xác nhận nhu cầu"
            bg="bg.toolbar"
            p="sm"
            gap="sm"
            alignItems="start"
            borderBottomWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.subtle"
            templateColumns={{
              base: "minmax(0, 1fr) auto auto",
              lg: "repeat(2, minmax(0, 1fr))",
              xl: "minmax(150px, 1fr) minmax(140px, 0.9fr) minmax(160px, 1.1fr) minmax(145px, 1fr) minmax(130px, 0.8fr) auto",
            }}
          >
            <Box
              ref={compactFilters}
              id="confirmed-need-filters"
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
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 4, lg: 1 }}
                gridColumn={{ base: "1 / -1", lg: "auto" }}
              >
                <AtlasWeekRangeInput
                  label="Tuần phục vụ"
                  value={c.week}
                  disabled={contextDisabled}
                  onValueChange={(week) => c.transition({ week })}
                />
              </Box>
              <Field.Root
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 5, lg: 2 }}
                gridColumn={{ base: "1 / -1", lg: "auto" }}
              >
                <Field.Label>Ngày phục vụ</Field.Label>
                <NativeSelect.Root disabled={contextDisabled}>
                  <NativeSelect.Field
                    aria-label="Ngày phục vụ"
                    value={c.date}
                    onChange={(e) => c.transition({ date: e.target.value })}
                  >
                    {days.map((d) => (
                      <option key={d} value={d}>
                        {viDate(d)}
                      </option>
                    ))}
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
              </Field.Root>
              <Box
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 6, lg: 3 }}
                gridColumn={{ base: "1 / -1", lg: "auto" }}
              >
                <Text textStyle="label" mb="xs">
                  Trường / điểm giao
                </Text>
                <AtlasSchoolScope
                  schools={c.schools}
                  value={c.schoolIds}
                  disabled={contextDisabled || !c.workbench}
                  onApply={(schoolIds) => c.transition({ schoolIds })}
                />
              </Box>
              <Field.Root
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 7, lg: 5 }}
                gridColumn={{ base: "1 / -1", lg: "auto" }}
              >
                <Field.Label>Tình trạng</Field.Label>
                <NativeSelect.Root>
                  <NativeSelect.Field
                    aria-label="Tình trạng"
                    value={c.filter}
                    onChange={(e) => c.setFilter(e.target.value)}
                  >
                    <option value="all">Tất cả</option>
                    <option value="needs_review">Cần rà soát</option>
                    <option value="carried_forward">Giữ nguyên</option>
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
              </Field.Root>
            </Box>
            <Field.Root>
              <Field.Label display={{ base: "none", lg: "block" }}>
                Tìm kiếm
              </Field.Label>
              <Input
                aria-label="Tìm kiếm"
                placeholder="Nguyên liệu, nơi nhận…"
                value={c.search}
                onChange={(e) => c.setSearch(e.target.value)}
              />
            </Field.Root>
            <Button
              ref={compactFilterTrigger}
              display={{ base: "inline-flex", lg: "none" }}
              order="1"
              gridColumn="2"
              variant="secondary"
              minH="var(--atlas-layout-mobile-target, 44px)"
              aria-expanded={filtersOpen}
              aria-controls="confirmed-need-filters"
              onClick={() => setFiltersOpen((open) => !open)}
            >
              Bộ lọc
            </Button>
            <Text
              display={{ base: filtersOpen ? "none" : "block", lg: "none" }}
              order="3"
              gridColumn="1 / -1"
              textStyle="helper"
              color="fg.muted"
            >
              Tuần {viDate(c.week)} · Ngày {dateSummary} · {scopeSummary} · Tình
              trạng: {filterSummary}
            </Text>
            <Box
              ref={compactFilterOnward}
              order={{ base: 2, lg: 6 }}
              gridColumn={{ base: "3", lg: "auto" }}
              pt={{
                base: "var(--atlas-layout-zero, 0)",
                xl: "var(--atlas-layout-refresh-offset, 26px)",
              }}
            >
              <AtlasRefreshButton
                loading={c.busy}
                disabled={Boolean(c.lock)}
                onClick={() => c.transition({ refresh: true })}
              />
            </Box>
          </Grid>
          <AtlasOperationStatus operation={c.operation} />
          <ConfirmedNeedCommandFeedback
            lock={c.lock}
            notice={c.operation.status === "IDLE" ? c.notice : null}
            readError={c.readError}
            busy={c.busy}
            onRecover={() => void c.recover()}
          />
          {c.busy && !c.workbench && c.operation.status !== "RUNNING" ? (
            <Text
              p="md"
              role="status"
              tabIndex={-1}
              data-compact-filter-fallback
            >
              Đang tải nhu cầu…
            </Text>
          ) : !c.workbench ? (
            <Box p="md">
              <Text textStyle="label" mb="xs">
                Ngày phục vụ {viDate(c.date)}
              </Text>
              <Text>{preflightMessage(c.preflight)}</Text>
              {(c.canGenerate || c.operation.status === "RUNNING") && (
                <Button
                  mt="sm"
                  variant="businessPrimary"
                  loading={c.operation.status === "RUNNING"}
                  disabled={!c.canGenerate}
                  onClick={() => void c.generate()}
                >
                  {c.preflight?.downstream_currentness === "OUTDATED"
                    ? "Cập nhật nhu cầu"
                    : "Tạo nhu cầu"}
                </Button>
              )}
            </Box>
          ) : (
            <>
              <Flex
                role="group"
                aria-label="Tiện ích nhu cầu xác nhận"
                px="md"
                py="sm"
                gap="sm"
                justify="space-between"
                align="center"
                wrap="wrap"
              >
                <Text textStyle="helper" color="fg.muted">
                  {c.workbench.line_counts.total} dòng ·{" "}
                  {c.workbench.line_counts.needs_review} cần rà soát ·{" "}
                  {c.workbench.line_counts.confirmed} đã xác nhận ·{" "}
                  {c.workbench.line_counts.adjusted} đã điều chỉnh
                </Text>
                <Checkbox.Root
                  checked={c.differencesOnly}
                  onCheckedChange={(d) =>
                    c.setDifferencesOnly(d.checked === true)
                  }
                >
                  <Checkbox.HiddenInput />
                  <Checkbox.Control>
                    <Checkbox.Indicator />
                  </Checkbox.Control>
                  <Checkbox.Label>
                    Chỉ hiển thị thay đổi chưa lưu
                  </Checkbox.Label>
                </Checkbox.Root>
                <Button
                  variant="tertiary"
                  data-atlas-action-priority="tertiary"
                  aria-expanded={detailOpen}
                  onClick={() => setDetailKey(detailOpen ? null : contextKey)}
                >
                  {detailOpen
                    ? "Ẩn cách hình thành nhu cầu"
                    : "Xem cách hình thành nhu cầu"}
                </Button>
                {props.onExportShoppingList && props.onImportShoppingList && (
                  <Flex gap="sm" wrap="wrap">
                    <Button
                      variant="tertiary"
                      data-atlas-action-priority="tertiary"
                      disabled={workbookBusy || c.released}
                      onClick={() => {
                        setWorkbookError(null);
                        setWorkbookBusy(true);
                        void props.onExportShoppingList!(c.workbench!, c.drafts)
                          .catch(() =>
                            setWorkbookError(
                              "Không thể xuất Phiếu đi chợ. Hãy thử lại.",
                            ),
                          )
                          .finally(() => setWorkbookBusy(false));
                      }}
                    >
                      Xuất Phiếu đi chợ
                    </Button>
                    <Button
                      variant="tertiary"
                      data-atlas-action-priority="tertiary"
                      disabled={workbookBusy || c.released}
                      onClick={() => workbookInput.current?.click()}
                    >
                      Nhập Phiếu đi chợ
                    </Button>
                    <input
                      ref={workbookInput}
                      type="file"
                      accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                      aria-label="Nhập Phiếu đi chợ .xlsx"
                      style={{
                        position: "absolute",
                        width: 1,
                        height: 1,
                        padding: 0,
                        margin: -1,
                        overflow: "hidden",
                        clip: "rect(0, 0, 0, 0)",
                        whiteSpace: "nowrap",
                        border: 0,
                      }}
                      onChange={(event) => {
                        const file = event.target.files?.[0];
                        event.target.value = "";
                        if (!file) return;
                        setWorkbookError(null);
                        setWorkbookBusy(true);
                        void props.onImportShoppingList!(
                          file,
                          c.workbench!,
                          c.drafts,
                        )
                          .then(c.applyShoppingListImport)
                          .catch((error: unknown) =>
                            setWorkbookError(
                              error instanceof Error
                                ? error.message
                                : "Không thể nhập Phiếu đi chợ.",
                            ),
                          )
                          .finally(() => setWorkbookBusy(false));
                      }}
                    />
                  </Flex>
                )}
              </Flex>
              {workbookError && (
                <Text px="md" pb="xs" role="alert" color="status.danger">
                  {workbookError}
                </Text>
              )}
              {c.dirty && !c.released && (
                <Text px="md" pb="xs" textStyle="helper" color="status.warning">
                  Đang chỉnh sửa · chưa lưu
                </Text>
              )}
              {c.hiddenDirtyCount > 0 && (
                <Text px="md" pb="xs" textStyle="helper" color="status.warning">
                  Có {c.hiddenDirtyCount} thay đổi chưa lưu ngoài bộ lọc hiện
                  tại.
                </Text>
              )}
              {c.released && (
                <Text px="md" pb="sm" textStyle="helper" color="fg.muted">
                  Nhu cầu đã chuyển sang mua hàng · chỉ đọc.
                </Text>
              )}
              <ConfirmedNeedTable
                lines={c.visibleLines}
                drafts={c.drafts}
                errors={c.errors}
                editable={c.editable}
                compactEditing={c.dirty && !c.released}
                onEdit={c.edit}
              />
              <Flex
                role="group"
                aria-label="Thao tác xác nhận nhu cầu"
                data-atlas-persistent-actions="true"
                p="md"
                gap="sm"
                justify="flex-end"
                align="center"
                wrap="wrap"
                position="sticky"
                bottom="var(--atlas-layout-zero, 0)"
                zIndex="var(--atlas-layout-sticky-header-z, 3)"
                bg="bg.workbench"
                borderTopWidth="var(--atlas-layout-edge, 1px)"
                borderColor="border.subtle"
              >
                <Flex gap="sm" wrap="wrap">
                  {!c.released && c.dirty && (
                    <Button
                      variant="businessPrimary"
                      data-atlas-action-priority="primary"
                      disabled={!c.canSave}
                      onClick={() => void c.save()}
                    >
                      Lưu
                    </Button>
                  )}
                  <Button
                    variant={c.dirty ? "secondary" : "businessPrimary"}
                    data-atlas-action-priority={
                      c.dirty ? "secondary" : "primary"
                    }
                    disabled={!c.canContinue}
                    onClick={c.continueAllocation}
                  >
                    Tiếp tục phân bổ NCC
                  </Button>
                </Flex>
              </Flex>
              {c.dirty &&
                !c.workbench.allowed_actions.save_confirmed_needs &&
                c.workbench.disabled_reasons.save_confirmed_needs && (
                  <Text px="md" pb="sm" color="status.warning">
                    {c.workbench.disabled_reasons.save_confirmed_needs}
                  </Text>
                )}
              {detailOpen && props.authSubject && (
                <ConfirmedNeedSupportDetail
                  key={contextKey}
                  api={props.needGenerationApi}
                  authSubject={props.authSubject}
                  date={c.date}
                  runId={c.workbench.need_generation_source.run_id}
                  batchId={c.workbench.confirmed_need_batch_id}
                  lines={c.workbench.lines}
                />
              )}
            </>
          )}
          <ConfirmedNeedDirtyExitDialog
            open={Boolean(c.pendingTransition)}
            onCancel={c.cancelTransition}
            onDiscard={c.discardTransition}
          />
        </Box>
      </Grid>
    </Box>
  );
}
