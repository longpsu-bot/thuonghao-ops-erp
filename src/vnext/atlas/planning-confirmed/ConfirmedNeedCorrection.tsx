import { confirmedNeedUnitLabel } from "./confirmedNeedDraft";
import {
  Box,
  Button,
  Dialog,
  Input,
  Field,
  Flex,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useRef, useState, type ReactNode } from "react";
import {
  type ConfirmedNeedLine,
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
                <Text textStyle="helper" mt="sm">
                  {c.correctionRead.binding
                    .expected_purchase_handoff_revision_id
                    ? "Nhu cầu đã được bàn giao cho bộ phận mua hàng."
                    : "Nhu cầu chưa được bàn giao cho bộ phận mua hàng."}
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
                          Lý do / thời điểm ghi nhận
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
                                : "Chưa có tên trường và nguyên liệu"}
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
                              {evidence.decided_at && (
                                <Text textStyle="helper" color="fg.muted">
                                  {new Date(evidence.decided_at).toLocaleString(
                                    "vi-VN",
                                    { timeZone: "Asia/Ho_Chi_Minh" },
                                  )}
                                </Text>
                              )}
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
  const sharedReason = useRef<HTMLInputElement>(null);
  const reasonField = useRef<HTMLTextAreaElement>(null);
  return (
    <Dialog.Root
      open={open}
      onOpenChange={(event) => {
        if (!event.open) onClose();
      }}
      initialFocusEl={() =>
        c.correctionMode ? reasonField.current : sharedReason.current
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
          data-need-save-review=""
          _open={{ animationStyle: "detailEnter" }}
          bg="bg.workbench"
          color="fg.default"
          mx="md"
          borderRadius="workbench"
          maxW={
            c.correctionMode
              ? "var(--atlas-correction-review-width, 760px)"
              : "var(--atlas-dialog-width, 480px)"
          }
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
              <>
                <Dialog.Description mb="sm">
                  {lines.length} dòng điều chỉnh trong lần lưu này.
                </Dialog.Description>
                <Field.Root>
                  <Field.Label>Lý do chung (tùy chọn)</Field.Label>
                  <Input
                    data-need-save-reason=""
                    ref={sharedReason}
                    maxLength={500}
                    value={c.saveReason}
                    onChange={(event) => c.setSaveReason(event.target.value)}
                  />
                </Field.Root>
              </>
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
