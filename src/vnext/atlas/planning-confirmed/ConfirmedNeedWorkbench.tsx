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
import { useAtlasWorkbenchStatus } from "../AtlasModuleExit";
import { AtlasDateRangeInput } from "../AtlasDateRangeInput";
import {
  AtlasWorkbar,
  AtlasWorkbarActions,
  AtlasWorkbarField,
} from "../AtlasWorkbar";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import { AtlasTaskContext } from "../AtlasTaskContext";
import {
  useConfirmedNeedWorkbench,
  type ConfirmedNeedWorkbenchProps,
} from "./useConfirmedNeedWorkbench";
import { noDemand, preflightMessage } from "./confirmedNeedAuthority";
import { ConfirmedNeedTable } from "./ConfirmedNeedTable";
import { ConfirmedNeedIssuedOrders } from "./ConfirmedNeedIssuedOrders";
import { ConfirmedNeedDirtyExitDialog } from "./ConfirmedNeedDirtyExitDialog";
import {
  ConfirmedNeedCorrectionPanel,
  ConfirmedNeedCorrectionReview,
} from "./ConfirmedNeedCorrection";
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
  const [correctionReviewKey, setCorrectionReviewKey] = useState<string | null>(
    null,
  );
  const correctionReviewTrigger = useRef<HTMLButtonElement>(null);
  const [dateReset, setDateReset] = useState(0);
  const dateField = useRef<HTMLDivElement>(null);
  const cancelledDate = useRef(false);
  useEffect(() => {
    if (c.pendingTransition) {
      cancelledDate.current = false;
      return;
    }
    if (!cancelledDate.current) return;
    // Restore after the replacement field commits and the dialog trap closes.
    const frame = requestAnimationFrame(() => {
      dateField.current
        ?.querySelector<HTMLElement>('[data-part="trigger"]')
        ?.focus({ preventScroll: true });
      cancelledDate.current = false;
    });
    return () => cancelAnimationFrame(frame);
  }, [c.pendingTransition, dateReset]);
  const [workbookBusy, setWorkbookBusy] = useState(false);
  const [workbookError, setWorkbookError] = useState<string | null>(null);
  useAtlasWorkbenchStatus(props.onWorkspaceStatus, {
    unsaved: c.allDirty,
    blocked: c.busy || Boolean(c.lock) || workbookBusy,
    attention: c.lock
      ? "Cần xác nhận dữ liệu hiện tại"
      : c.busy || workbookBusy
        ? "Đang xử lý"
        : undefined,
  });
  const workbookInput = useRef<HTMLInputElement>(null);
  const compactFilters = useRef<HTMLDivElement>(null);
  const compactFilterTrigger = useRef<HTMLButtonElement>(null);
  const compactFilterOnward = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
  const contextKey = `${c.date}:${c.workbench?.confirmed_need_batch_id}:${c.workbench?.need_generation_source.run_id}:${c.workbench?.batch_version}`;
  const correctionContext = `${props.authSubject}:${contextKey}`;
  const detailOpen = detailKey === contextKey;
  const contextDisabled = c.busy || Boolean(c.lock) || workbookBusy;
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
  const dayControls = (
    <>
      {" "}
      {c.days.map((day) => (
        <Button
          key={day.date}
          size="sm"
          variant={day.date === c.date ? "secondary" : "tertiary"}
          aria-pressed={day.date === c.date}
          disabled={
            contextDisabled ||
            Boolean(c.rangeError) ||
            c.rangeBusy ||
            (!day.preflight && !day.readError)
          }
          onClick={() => c.selectDay(day.date)}
        >
          {viDate(day.date).slice(0, 5)} ·{" "}
          {day.dirty
            ? "Chưa lưu"
            : day.readError
              ? "Lỗi tải"
              : !day.preflight
                ? "Đang tải"
                : noDemand(day.preflight ?? null)
                  ? "Không có nhu cầu"
                  : day.preflight?.readiness_state === "BLOCKED"
                    ? "Cần kiểm tra"
                    : day.preflight?.downstream_currentness === "CURRENT"
                      ? "Đã lập"
                      : day.preflight?.downstream_currentness === "OUTDATED"
                        ? "Cần cập nhật"
                        : "Chưa lập"}
        </Button>
      ))}
    </>
  );
  return (
    <Box
      as="section"
      aria-label="Xác nhận nhu cầu"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      overflow="clip"
    >
      <Grid templateColumns="minmax(0, 1fr)" templateRows="auto minmax(0, 1fr)">
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh xác nhận nhu cầu"
          moduleLabel="Lập nhu cầu"
          jobLabel="Xác nhận nhu cầu"
          compactSummary={scopeSummary}
          details={[
            { label: "Ngày phục vụ", value: dateSummary },
            { label: "Trường / điểm giao", value: scopeSummary },
          ]}
        />
        <Box minW="var(--atlas-layout-zero, 0)">
          <AtlasWorkbar
            display="grid"
            role="group"
            aria-label="Phạm vi xác nhận nhu cầu"
            bg="bg.toolbar"
            px={{ base: "sm", md: "md" }}
            py={{ base: "sm", md: "var(--atlas-workbar-y, 12px)" }}
            gap="sm"
            borderBottomWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.default"
            templateColumns={{
              base: "minmax(0, 1fr) auto auto",
              lg: "minmax(270px, 1.3fr) minmax(180px, 1.2fr) minmax(180px, 1.2fr) minmax(130px, 0.8fr) auto",
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
              <AtlasWorkbarField
                ref={dateField}
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 4, lg: 1 }}
                gridColumn={{ base: "1 / -1", lg: "auto" }}
              >
                <AtlasDateRangeInput
                  key={dateReset}
                  label="Khoảng ngày"
                  value={c.range}
                  error={c.rangeError}
                  disabled={contextDisabled}
                  onValueChange={c.changeRange}
                />
              </AtlasWorkbarField>
              <Box
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 5, lg: 2 }}
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
                order={{ base: filtersOpen ? 6 : 0, lg: 3 }}
                gridColumn={{ base: filtersOpen ? "1 / -1" : "1", lg: "auto" }}
              >
                <Field.Label
                  display={{
                    base: filtersOpen ? "block" : "none",
                    lg: "block",
                  }}
                  color="fg.default"
                >
                  Tìm kiếm
                </Field.Label>
                <Input
                  aria-label="Tìm kiếm"
                  placeholder="Nguyên liệu, nơi nhận…"
                  value={c.search}
                  onChange={(e) => c.setSearch(e.target.value)}
                />
              </Field.Root>
              <Field.Root
                display={{ base: filtersOpen ? "block" : "none", lg: "block" }}
                order={{ base: 7, lg: 4 }}
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
              Ngày {dateSummary} · {scopeSummary} · Tình trạng: {filterSummary}
            </Text>
            <AtlasWorkbarActions
              ref={compactFilterOnward}
              order={{ base: 2, lg: 5 }}
              gridColumn={{ base: "3", lg: "auto" }}
            >
              <AtlasRefreshButton
                loading={c.busy}
                disabled={Boolean(c.lock) || Boolean(c.rangeError)}
                onClick={() => c.transition({ refresh: true })}
              />
            </AtlasWorkbarActions>
          </AtlasWorkbar>
          {!c.workbench && (
            <Flex
              role="group"
              aria-label="Ngày trong khoảng"
              px="md"
              py="xs"
              gap="xs"
              wrap="wrap"
            >
              {dayControls}
            </Flex>
          )}
          <AtlasOperationStatus operation={c.operation} />
          <ConfirmedNeedCommandFeedback
            lock={c.lock}
            notice={c.operation.status === "IDLE" ? c.notice : null}
            readError={c.readError}
            busy={c.busy || Boolean(c.rangeError)}
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
                py="xs"
                gap="sm"
                justify="flex-start"
                align="center"
                wrap="wrap"
              >
                <Flex
                  role="group"
                  aria-label="Ngày trong khoảng"
                  gap="xs"
                  wrap="wrap"
                >
                  {dayControls}
                </Flex>
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
                      disabled={
                        workbookBusy ||
                        c.released ||
                        c.allDirty ||
                        c.rangeBusy ||
                        c.busy ||
                        Boolean(c.lock) ||
                        !c.editable
                      }
                      onClick={() => {
                        setWorkbookError(null);
                        setWorkbookBusy(true);
                        void props.onExportShoppingList!(
                          c.workbench!,
                          c.shoppingRangeContext,
                        )
                          .catch((error: unknown) =>
                            setWorkbookError(
                              error instanceof Error
                                ? error.message
                                : "Không thể xuất Phiếu đi chợ. Hãy thử lại.",
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
                      disabled={
                        workbookBusy ||
                        c.released ||
                        c.allDirty ||
                        c.rangeBusy ||
                        c.busy ||
                        Boolean(c.lock) ||
                        !c.editable
                      }
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
                        if (
                          !file ||
                          c.allDirty ||
                          c.rangeBusy ||
                          c.released ||
                          c.busy ||
                          c.lock ||
                          !c.editable ||
                          workbookBusy
                        )
                          return;
                        const apply = c.captureShoppingListImport();
                        setWorkbookError(null);
                        setWorkbookBusy(true);
                        void props.onImportShoppingList!(
                          file,
                          c.workbench!,
                          c.drafts,
                          c.shoppingRangeContext,
                        )
                          .then(apply)
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
                {c.allDirty && props.onExportShoppingList && (
                  <Text fontSize="sm">
                    Lưu hoặc tải lại để bỏ thay đổi trước khi xuất/nhập Phiếu đi
                    chợ.
                  </Text>
                )}
              </Flex>
              {workbookError && (
                <Text px="md" pb="xs" role="alert" color="status.danger">
                  {workbookError}
                </Text>
              )}
              {c.dirty && (!c.released || c.correctionMode) && (
                <Text px="md" pb="xs" textStyle="helper" color="fg.primary">
                  Đang chỉnh sửa · chưa lưu
                </Text>
              )}
              {c.hiddenDirtyCount > 0 && (
                <Text px="md" pb="xs" textStyle="helper" color="status.warning">
                  Có {c.hiddenDirtyCount} thay đổi chưa lưu ngoài bộ lọc hiện
                  tại.
                </Text>
              )}
              {c.released && !c.correctionMode && (
                <Text px="md" pb="sm" textStyle="helper" color="fg.muted">
                  Nhu cầu đã chuyển sang mua hàng · chỉ đọc.
                </Text>
              )}
              <ConfirmedNeedCorrectionPanel c={c} />
              {c.correctionRead && props.procurementApi && c.workbench && (
                <ConfirmedNeedIssuedOrders
                  api={props.procurementApi}
                  authSubject={props.authSubject}
                  workbench={c.workbench}
                  serviceDate={c.date}
                  schoolIds={c.schoolIds}
                  onOpenOrders={props.onOpenOrders}
                />
              )}
              <ConfirmedNeedTable
                lines={c.visibleLines}
                drafts={c.drafts}
                errors={c.errors}
                editable={c.editable}
                compactEditing={c.dirty && (!c.released || c.correctionMode)}
                correctionReason={
                  c.correctionMode ? c.correctionReason : undefined
                }
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
                  {!c.correctionMode && !c.released && c.dirty && (
                    <Button
                      variant="businessPrimary"
                      data-atlas-action-priority="primary"
                      disabled={!c.canSave}
                      onClick={() => void c.save()}
                    >
                      Lưu
                    </Button>
                  )}
                  {!c.correctionMode && (c.released || c.correctionRead) && (
                    <Button
                      variant="secondary"
                      disabled={!c.canStartCorrection}
                      onClick={c.startCorrection}
                    >
                      Điều chỉnh nhu cầu đã phát hành
                    </Button>
                  )}
                  {c.correctionMode && (
                    <Button
                      ref={correctionReviewTrigger}
                      variant="businessPrimary"
                      disabled={!c.canSave}
                      onClick={() => setCorrectionReviewKey(correctionContext)}
                    >
                      Xem lại điều chỉnh
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
              {!c.correctionMode &&
                c.dirty &&
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
            onCancel={() => {
              if (c.pendingTransition?.date || c.pendingTransition?.range) {
                cancelledDate.current = true;
                setDateReset((value) => value + 1);
              }
              c.cancelTransition();
            }}
            onDiscard={c.discardTransition}
            finalFocusEl={() =>
              cancelledDate.current
                ? (dateField.current?.querySelector<HTMLElement>(
                    '[data-part="trigger"]',
                  ) ?? null)
                : null
            }
          />
          <ConfirmedNeedCorrectionReview
            c={c}
            open={c.correctionMode && correctionReviewKey === correctionContext}
            onClose={() => setCorrectionReviewKey(null)}
            finalFocusEl={() => correctionReviewTrigger.current}
          />
        </Box>
      </Grid>
    </Box>
  );
}
