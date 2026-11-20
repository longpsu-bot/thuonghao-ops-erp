import { confirmedNeedUnitLabel } from "./confirmedNeedDraft";
import {
  Box,
  Button,
  Dialog,
  NativeSelect,
  Input,
  Field,
  Flex,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useRef, useState, type ReactNode } from "react";
import {
  confirmedNeedReasonLabels,
  type ConfirmedNeedLine,
  type ConfirmedNeedDraftLine,
  exactQuantityDisplay,
  normalizeConfirmedNeedQuantity,
} from "../bridges/confirmedNeed";
import type { useConfirmedNeedWorkbench } from "./useConfirmedNeedWorkbench";
type Controller = ReturnType<typeof useConfirmedNeedWorkbench>;

export function ConfirmedNeedCorrectionPanel({
  c,
  children,
}: {
  c: Controller;
  children?: ReactNode;
}) {
  const [historyOpen, setHistoryOpen] = useState(false);
  if (!c.released && !c.correctionRead) return null;
  return (
    <Box px="md">
      {c.correctionMode ? (
        <Box
          borderWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.interactive"
          borderRadius="workbench"
          p="sm"
        >
          <Text fontWeight="semibold">Điều chỉnh nhu cầu đã phát hành</Text>
          <Text textStyle="helper" color="fg.muted" mb="sm">
            Nhập số lượng mới cho các dòng cần đổi. Các dòng còn lại giữ nguyên;
            đơn đã phát hành giữ nguyên cho đến khi có đơn thay thế.
          </Text>
          <Button
            mt="sm"
            variant="tertiary"
            disabled={c.busy || Boolean(c.lock)}
            onClick={c.cancelCorrection}
          >
            Hủy điều chỉnh
          </Button>
        </Box>
      ) : !c.canStartCorrection &&
        c.workbench?.disabled_reasons.correct_released_confirmed_needs ? (
        <Text textStyle="helper" color="fg.muted">
          {c.workbench.disabled_reasons.correct_released_confirmed_needs}
        </Text>
      ) : null}
      {c.correctionRead?.pendingObligations.includes(
        "PROCUREMENT_CURRENTNESS_REVIEW",
      ) && (
        <Text mt="sm" textStyle="helper">
          Nhu cầu đã điều chỉnh. Mở Phân bổ NCC để kiểm tra phân bổ, chuẩn bị
          đơn và đơn thay thế; chưa có đơn mới được phát hành bởi thao tác lưu
          nhu cầu.
        </Text>
      )}
      {c.correctionRead && (
        <Box pb="xs">
          <details
            onToggle={(event) => setHistoryOpen(event.currentTarget.open)}
          >
            <Box
              as="summary"
              cursor="var(--atlas-disclosure-cursor, pointer)"
              textStyle="helper"
              color="fg.primary"
              w="var(--atlas-disclosure-width, fit-content)"
            >
              Lịch sử xác nhận{children ? " và đơn mua" : ""}
            </Box>
            {historyOpen && (
              <>
                {children}
                <Text textStyle="helper" mt="sm" overflowWrap="anywhere">
                  Lần phát hành gốc:{" "}
                  {c.correctionRead.binding.expected_confirmed_need_release_id}
                </Text>
                <Text textStyle="helper" overflowWrap="anywhere">
                  Bàn giao gốc:{" "}
                  {c.correctionRead.binding
                    .expected_purchase_handoff_revision_id ??
                    "Chưa có bàn giao"}
                </Text>
                <Box overflowX="auto" mt="sm">
                  <Table.Root
                    size="sm"
                    aria-label="Lịch sử xác nhận và điều chỉnh"
                  >
                    <Table.Header>
                      <Table.Row>
                        <Table.ColumnHeader>
                          Trường / nguyên liệu
                        </Table.ColumnHeader>
                        <Table.ColumnHeader>Trước → sau</Table.ColumnHeader>
                        <Table.ColumnHeader>Chênh lệch</Table.ColumnHeader>
                        <Table.ColumnHeader>
                          Lý do / người ghi nhận
                        </Table.ColumnHeader>
                      </Table.Row>
                    </Table.Header>
                    <Table.Body>
                      {c.correctionRead.lines.map((evidence) => {
                        const line = c.workbench?.lines.find(
                          (item) =>
                            item.confirmed_need_line_id ===
                            evidence.confirmed_need_line_id,
                        );
                        return (
                          <Table.Row key={evidence.confirmed_need_line_id}>
                            <Table.Cell>
                              {line
                                ? `${line.school.name} · ${line.ingredient.name}`
                                : evidence.confirmed_need_line_id}
                            </Table.Cell>
                            <Table.Cell whiteSpace="nowrap">
                              {evidence.old_confirmed_quantity === null
                                ? "—"
                                : exactQuantityDisplay(
                                    evidence.old_confirmed_quantity,
                                  )}{" "}
                              →{" "}
                              {exactQuantityDisplay(
                                evidence.new_confirmed_quantity,
                              )}{" "}
                              {line
                                ? confirmedNeedUnitLabel(line.controlled_unit)
                                : ""}
                            </Table.Cell>
                            <Table.Cell>
                              {evidence.difference === null
                                ? "—"
                                : exactQuantityDisplay(evidence.difference)}
                            </Table.Cell>
                            <Table.Cell minW="var(--atlas-correction-evidence-width, 220px)">
                              <Text>
                                {evidence.reason_note ?? "Không có ghi chú"}
                              </Text>
                              <Box as="details" textStyle="helper">
                                <Box
                                  as="summary"
                                  cursor="var(--atlas-disclosure-cursor, pointer)"
                                >
                                  Người ghi nhận và dấu vết
                                </Box>
                                <Text overflowWrap="anywhere">
                                  {evidence.decided_by_actor_id ?? "—"} ·{" "}
                                  {evidence.decided_at
                                    ? new Date(
                                        evidence.decided_at,
                                      ).toLocaleString("vi-VN", {
                                        timeZone: "Asia/Ho_Chi_Minh",
                                      })
                                    : "—"}
                                </Text>
                                <Text overflowWrap="anywhere">
                                  Quyết định:{" "}
                                  {evidence.current_decision_id ?? "—"}
                                </Text>
                                <Text overflowWrap="anywhere">
                                  Quyết định trước:{" "}
                                  {evidence.predecessor_decision_id ?? "—"}
                                </Text>
                                <Text overflowWrap="anywhere">
                                  Phiên bản dòng: {evidence.current_revision_id}
                                </Text>
                                <Text overflowWrap="anywhere">
                                  Phiên bản trước:{" "}
                                  {evidence.predecessor_revision_id ?? "—"}
                                </Text>
                              </Box>
                            </Table.Cell>
                          </Table.Row>
                        );
                      })}
                    </Table.Body>
                  </Table.Root>
                </Box>
              </>
            )}
          </details>
        </Box>
      )}
    </Box>
  );
}

export function ConfirmedNeedSaveReview({
  c,
  open,
  lines,
  onClose,
  finalFocusEl,
}: {
  c: Controller;
  open: boolean;
  lines: ConfirmedNeedLine[];
  onClose: () => void;
  finalFocusEl: () => HTMLElement | null;
}) {
  const firstReason = useRef<HTMLSelectElement>(null);
  const reasonField = useRef<HTMLTextAreaElement>(null);
  return (
    <Dialog.Root
      open={open}
      onOpenChange={(event) => {
        if (!event.open) onClose();
      }}
      initialFocusEl={() =>
        c.correctionMode ? reasonField.current : firstReason.current
      }
      finalFocusEl={finalFocusEl}
      motionPreset="none"
      scrollBehavior="inside"
      placement="center"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          _open={{ animationStyle: "detailEnter" }}
          bg="bg.workbench"
          color="fg.default"
          mx="md"
          borderRadius="workbench"
          maxW="var(--atlas-correction-review-width, 760px)"
        >
          <Dialog.Header>
            <Dialog.Title>
              {c.correctionMode
                ? "Xác nhận điều chỉnh nhu cầu đã phát hành"
                : "Lý do điều chỉnh"}
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            {c.correctionMode ? (
              <>
                <Dialog.Description mb="sm">
                  Chỉ các dòng dưới đây được điều chỉnh. Thao tác này chưa phát
                  hành đơn mới cho nhà cung cấp.
                </Dialog.Description>
                <Field.Root required>
                  <Field.Label>
                    Lý do điều chỉnh sau phát hành
                    <Field.RequiredIndicator />
                  </Field.Label>
                  <Textarea
                    aria-label="Lý do điều chỉnh sau phát hành"
                    ref={reasonField}
                    required
                    rows={2}
                    value={c.correctionReason}
                    disabled={!c.editable}
                    onChange={(event) =>
                      c.setCorrectionReason(event.target.value)
                    }
                  />
                </Field.Root>
                <Box overflowX="auto">
                  <Table.Root
                    size="sm"
                    aria-label="Rà soát số lượng điều chỉnh"
                  >
                    <Table.Header>
                      <Table.Row>
                        <Table.ColumnHeader>
                          Trường / nguyên liệu
                        </Table.ColumnHeader>
                        <Table.ColumnHeader>Đã xác nhận</Table.ColumnHeader>
                        <Table.ColumnHeader>Đề nghị mới</Table.ColumnHeader>
                      </Table.Row>
                    </Table.Header>
                    <Table.Body>
                      {lines.map((line) => (
                        <Table.Row key={line.confirmed_need_line_id}>
                          <Table.Cell>
                            {line.school.name} · {line.ingredient.name} (
                            {confirmedNeedUnitLabel(line.controlled_unit)})
                          </Table.Cell>
                          <Table.Cell>
                            {exactQuantityDisplay(
                              line.confirmed_quantity_after ?? "0",
                            )}
                          </Table.Cell>
                          <Table.Cell>
                            {exactQuantityDisplay(
                              normalizeConfirmedNeedQuantity(
                                c.drafts[line.confirmed_need_line_id]!
                                  .exact_quantity,
                              ) ?? "0",
                            )}
                          </Table.Cell>
                        </Table.Row>
                      ))}
                    </Table.Body>
                  </Table.Root>
                </Box>
              </>
            ) : (
              lines.map((line, index) => {
                const id = line.confirmed_need_line_id;
                const draft = c.drafts[id]!;
                const error = c.errors[id];
                const unit = confirmedNeedUnitLabel(line.controlled_unit);
                return (
                  <Box
                    key={id}
                    data-review-line-id={id}
                    as="fieldset"
                    minW="var(--atlas-layout-zero, 0)"
                    py="sm"
                    borderTopWidth={
                      index ? "var(--atlas-layout-edge, 1px)" : undefined
                    }
                    borderColor="border.subtle"
                  >
                    <Box as="legend" fontWeight="semibold">
                      {line.ingredient.name}
                    </Box>
                    <Text textStyle="helper" color="fg.muted">
                      {line.school.name}
                      {line.school.name !== line.delivery_location.name &&
                        ` · ${line.delivery_location.name}`}{" "}
                      · {line.service_date.split("-").reverse().join("/")}
                    </Text>
                    <Text my="xs" textStyle="quantityInline">
                      {exactQuantityDisplay(
                        line.confirmed_quantity_after ??
                          line.proposed_confirmed_quantity,
                      )}{" "}
                      →{" "}
                      {exactQuantityDisplay(
                        normalizeConfirmedNeedQuantity(draft.exact_quantity) ??
                          draft.exact_quantity,
                      )}{" "}
                      {unit}
                    </Text>
                    <Flex gap="sm" direction={{ base: "column", md: "row" }}>
                      <Field.Root flex="1" invalid={error?.field === "reason"}>
                        <Field.Label>Lý do</Field.Label>
                        <NativeSelect.Root>
                          <NativeSelect.Field
                            ref={index === 0 ? firstReason : undefined}
                            aria-label={`Lý do ${line.ingredient.name}`}
                            value={draft.reason_code}
                            onChange={(event) =>
                              c.edit(id, {
                                reason_code: event.target
                                  .value as ConfirmedNeedDraftLine["reason_code"],
                              })
                            }
                          >
                            {Object.entries(confirmedNeedReasonLabels).map(
                              ([code, label]) => (
                                <option key={code} value={code}>
                                  {label}
                                </option>
                              ),
                            )}
                          </NativeSelect.Field>
                          <NativeSelect.Indicator />
                        </NativeSelect.Root>
                        <Field.ErrorText>{error?.message}</Field.ErrorText>
                      </Field.Root>
                      <Field.Root flex="1" invalid={error?.field === "note"}>
                        <Field.Label>Ghi chú (tùy chọn)</Field.Label>
                        <Input
                          aria-label={`Ghi chú ${line.ingredient.name}`}
                          value={draft.reason_note}
                          onChange={(event) =>
                            c.edit(id, { reason_note: event.target.value })
                          }
                        />
                        <Field.ErrorText>{error?.message}</Field.ErrorText>
                      </Field.Root>
                    </Flex>
                  </Box>
                );
              })
            )}
            {!c.correctionMode && c.changedLines.length > 1 && (
              <Text textStyle="helper" color="fg.muted" mt="sm">
                Tổng số dòng sẽ lưu: {c.changedLines.length}.
              </Text>
            )}
          </Dialog.Body>
          <Dialog.Footer flexWrap="wrap">
            <Flex gap="sm" wrap="wrap">
              <Button variant="secondary" onClick={onClose}>
                Quay lại chỉnh sửa
              </Button>
              <Button
                variant="businessPrimary"
                disabled={!c.canSave}
                onClick={() => {
                  onClose();
                  void c.save();
                }}
              >
                Lưu điều chỉnh
              </Button>
            </Flex>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
