import {
  Box,
  Button,
  Dialog,
  Field,
  Flex,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useRef } from "react";
import {
  exactQuantityDisplay,
  normalizeConfirmedNeedQuantity,
} from "../bridges/confirmedNeed";
import type { useConfirmedNeedWorkbench } from "./useConfirmedNeedWorkbench";
type Controller = ReturnType<typeof useConfirmedNeedWorkbench>;

export function ConfirmedNeedCorrectionPanel({ c }: { c: Controller }) {
  if (!c.released && !c.correctionRead) return null;
  return (
    <Box px="md" pb="sm">
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
          <Field.Root required>
            <Field.Label>
              Lý do điều chỉnh sau phát hành
              <Field.RequiredIndicator />
            </Field.Label>
            <Textarea
              aria-label="Lý do điều chỉnh sau phát hành"
              required
              rows={2}
              value={c.correctionReason}
              disabled={!c.editable}
              onChange={(event) => c.setCorrectionReason(event.target.value)}
            />
          </Field.Root>
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
        <Box as="details" mt="sm">
          <Box
            as="summary"
            cursor="var(--atlas-disclosure-cursor, pointer)"
            textStyle="helper"
          >
            Nguồn và lịch sử xác nhận, điều chỉnh
          </Box>
          <Text textStyle="helper" mt="sm" overflowWrap="anywhere">
            Lần phát hành gốc:{" "}
            {c.correctionRead.binding.expected_confirmed_need_release_id}
          </Text>
          <Text textStyle="helper" overflowWrap="anywhere">
            Bàn giao gốc:{" "}
            {c.correctionRead.binding.expected_purchase_handoff_revision_id ??
              "Chưa có bàn giao"}
          </Text>
          <Box overflowX="auto" mt="sm">
            <Table.Root size="sm" aria-label="Lịch sử xác nhận và điều chỉnh">
              <Table.Header>
                <Table.Row>
                  <Table.ColumnHeader>Trường / nguyên liệu</Table.ColumnHeader>
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
                        {exactQuantityDisplay(evidence.new_confirmed_quantity)}{" "}
                        {line?.controlled_unit.code}
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
                              ? new Date(evidence.decided_at).toLocaleString(
                                  "vi-VN",
                                  { timeZone: "Asia/Ho_Chi_Minh" },
                                )
                              : "—"}
                          </Text>
                          <Text overflowWrap="anywhere">
                            Quyết định: {evidence.current_decision_id ?? "—"}
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
        </Box>
      )}
    </Box>
  );
}

export function ConfirmedNeedCorrectionReview({
  c,
  open,
  onClose,
  finalFocusEl,
}: {
  c: Controller;
  open: boolean;
  onClose: () => void;
  finalFocusEl: () => HTMLElement | null;
}) {
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Dialog.Root
      open={open}
      onOpenChange={(event) => {
        if (!event.open) onClose();
      }}
      initialFocusEl={() => cancel.current}
      finalFocusEl={finalFocusEl}
      placement="center"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          bg="bg.workbench"
          color="fg.default"
          mx="md"
          borderRadius="workbench"
          maxW="var(--atlas-correction-review-width, 760px)"
        >
          <Dialog.Header>
            <Dialog.Title>
              Xác nhận điều chỉnh nhu cầu đã phát hành
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            <Dialog.Description mb="sm">
              Chỉ các dòng dưới đây được điều chỉnh. Thao tác này chưa phát hành
              đơn mới cho nhà cung cấp.
            </Dialog.Description>
            <Text mb="sm">Lý do: {c.correctionReason}</Text>
            <Box overflowX="auto">
              <Table.Root size="sm" aria-label="Rà soát số lượng điều chỉnh">
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
                  {c.changedLines.map((line) => (
                    <Table.Row key={line.confirmed_need_line_id}>
                      <Table.Cell>
                        {line.school.name} · {line.ingredient.name} (
                        {line.controlled_unit.code})
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
          </Dialog.Body>
          <Dialog.Footer flexWrap="wrap">
            <Flex gap="sm" wrap="wrap">
              <Button ref={cancel} variant="secondary" onClick={onClose}>
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
