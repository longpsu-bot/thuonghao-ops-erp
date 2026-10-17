import {
  Box,
  Button,
  Dialog,
  Field,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useRef } from "react";
import {
  confirmedNeedCorrectionMessage,
  confirmedNeedReasonLabels,
  exactQuantityDisplay,
  type JsonValue,
} from "../bridges/confirmedNeed";
import type { useConfirmedNeedWorkbench } from "./useConfirmedNeedWorkbench";
type Controller = ReturnType<typeof useConfirmedNeedWorkbench>;
const zero = (v: string) => /^0(?:\.0+)?$/.test(v);
const quantity = (v: unknown) =>
  typeof v === "string" && /^-?\d+(?:\.\d{1,6})?$/.test(v)
    ? exactQuantityDisplay(v)
    : "Chưa xác định";
const record = (v: JsonValue): Record<string, JsonValue> | null =>
  v !== null && typeof v === "object" && !Array.isArray(v) ? v : null;
const label = (v: unknown, fallback: string) =>
  typeof v === "string" &&
  v.trim() &&
  !/^(?:v1-|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$)/i.test(
    v,
  ) &&
  v.trim().toLowerCase() !== "supplier label unavailable"
    ? v
    : fallback;
export function ConfirmedNeedCorrectionDialog({
  c,
  returnFocusEl,
}: {
  c: Controller;
  returnFocusEl: () => HTMLElement | null;
}) {
  const last = useRef(c.correction);
  if (c.correction) last.current = c.correction;
  const form = c.correction ?? last.current;
  const input = useRef<HTMLInputElement>(null);
  const preview = form?.preview;
  const selected = c.workbench?.lines.find(
    (line) =>
      line.confirmed_need_line_id === form?.target.confirmed_need_line_id,
  );
  const locked = c.busy || c.lock === "unknown" || form?.status === "READBACK";
  const frozen = locked || form?.status === "RETRYABLE";
  const unit = label(
    preview ? preview.display.unit_name : selected?.controlled_unit.name,
    "Chưa có tên đơn vị tính",
  );
  return (
    <Dialog.Root
      open={Boolean(c.correction)}
      onOpenChange={(d) => {
        if (!d.open && !locked) c.closeCorrection();
      }}
      initialFocusEl={() => input.current}
      restoreFocus={false}
      onExitComplete={() => {
        if (!c.correction && !c.busy)
          returnFocusEl()?.focus({ preventScroll: true });
      }}
      closeOnEscape={!locked}
      closeOnInteractOutside={false}
      placement="center"
      size="xl"
      scrollBehavior="inside"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          bg="bg.workbench"
          color="fg.default"
          borderRadius="workbench"
          mx="md"
        >
          <Dialog.Header>
            <Dialog.Title>Điều chỉnh nhu cầu</Dialog.Title>
          </Dialog.Header>
          {form && (
            <>
              <Dialog.Body>
                {selected && (
                  <Box mb="md">
                    <Text fontWeight="semibold">
                      {label(
                        selected.ingredient.name,
                        "Chưa có tên nguyên liệu",
                      )}{" "}
                      · {label(selected.school.name, "Chưa có tên trường")}
                    </Text>
                    <Text color="fg.muted">
                      {selected.service_date.split("-").reverse().join("/")} ·{" "}
                      {label(
                        selected.delivery_location.name,
                        "Chưa có tên điểm giao",
                      )}
                    </Text>
                  </Box>
                )}
                <Text mb="md" color="fg.muted">
                  Chỉ lưu số lượng nhu cầu của dòng đã chọn. Đơn mua và phiếu
                  xuất đã phát hành được giữ nguyên; mọi phát hành tiếp theo cần
                  được rà soát riêng.
                </Text>
                <Grid
                  templateColumns={{
                    base: "minmax(0, 1fr)",
                    md: "minmax(0, 1fr) minmax(0, 1fr)",
                  }}
                  gap="md"
                >
                  <Field.Root>
                    <Field.Label>Số lượng mới</Field.Label>
                    <Input
                      ref={input}
                      inputMode="decimal"
                      value={form.quantity}
                      disabled={frozen}
                      onChange={(e) =>
                        c.updateCorrection({ quantity: e.target.value })
                      }
                    />
                    <Field.HelperText>Đơn vị tính: {unit}</Field.HelperText>
                  </Field.Root>
                  <Field.Root>
                    <Field.Label>Lý do điều chỉnh</Field.Label>
                    <NativeSelect.Root disabled={frozen}>
                      <NativeSelect.Field
                        value={form.reason_code}
                        onChange={(e) =>
                          c.updateCorrection({
                            reason_code: e.target
                              .value as typeof form.reason_code,
                          })
                        }
                      >
                        {Object.entries(confirmedNeedReasonLabels)
                          .filter(([code]) => code !== "PROPOSAL_ACCEPTED")
                          .map(([code, name]) => (
                            <option key={code} value={code}>
                              {name}
                            </option>
                          ))}
                      </NativeSelect.Field>
                      <NativeSelect.Indicator />
                    </NativeSelect.Root>
                  </Field.Root>
                  <Field.Root gridColumn="1 / -1">
                    <Field.Label>Ghi chú điều chỉnh</Field.Label>
                    <Textarea
                      value={form.reason_note}
                      disabled={frozen}
                      onChange={(e) =>
                        c.updateCorrection({ reason_note: e.target.value })
                      }
                    />
                  </Field.Root>
                </Grid>
                {form.error && (
                  <Text role="alert" mt="md" color="status.danger">
                    {form.error}
                  </Text>
                )}
                {form.status === "UNKNOWN" && (
                  <Text mt="sm">
                    Kết quả yêu cầu ban đầu chưa xác định. Giữ nguyên nội dung;
                    chỉ thử lại đúng yêu cầu đã gửi.
                  </Text>
                )}
                {form.status === "READBACK" && (
                  <Text mt="sm">
                    Đã nhận kết quả lưu, đang xác nhận dữ liệu hiện tại. Chưa
                    thể đóng hoặc gửi yêu cầu khác.
                  </Text>
                )}
                {preview && (
                  <Box
                    role="region"
                    aria-label="Ảnh hưởng điều chỉnh"
                    mt="lg"
                    borderTopWidth="var(--atlas-layout-edge, 1px)"
                    borderColor="border.subtle"
                    pt="md"
                  >
                    <Heading size="md">
                      {label(
                        preview.display.ingredient_name,
                        "Chưa có tên nguyên liệu",
                      )}
                    </Heading>
                    <Text color="fg.muted" mb="md">
                      {preview.family.service_date
                        .split("-")
                        .reverse()
                        .join("/")}{" "}
                      ·{" "}
                      {label(
                        preview.display.delivery_location_name,
                        "Chưa có tên điểm giao",
                      )}{" "}
                      · {unit}
                    </Text>
                    <Table.Root size="sm">
                      <Table.Header>
                        <Table.Row>
                          <Table.ColumnHeader>Đang có</Table.ColumnHeader>
                          <Table.ColumnHeader>
                            Sau điều chỉnh
                          </Table.ColumnHeader>
                          <Table.ColumnHeader>Chênh lệch</Table.ColumnHeader>
                        </Table.Row>
                      </Table.Header>
                      <Table.Body>
                        <Table.Row>
                          <Table.Cell>
                            {quantity(preview.quantity.before)}
                          </Table.Cell>
                          <Table.Cell>
                            {quantity(preview.quantity.after)}
                          </Table.Cell>
                          <Table.Cell>
                            {!preview.quantity.delta.startsWith("-") &&
                            !zero(preview.quantity.delta)
                              ? "+"
                              : ""}
                            {quantity(preview.quantity.delta)}
                          </Table.Cell>
                        </Table.Row>
                      </Table.Body>
                    </Table.Root>
                    <Heading size="sm" mt="md" mb="sm">
                      Toàn bộ nhóm nhu cầu · {preview.display.schools.length}{" "}
                      trường
                    </Heading>
                    <Text mb="sm">
                      Tổng nhóm: {quantity(preview.family.quantity_before)} →{" "}
                      {quantity(preview.family.quantity_after)} {unit}. Bao gồm
                      các trường ngoài bộ lọc hiện tại.
                    </Text>
                    <Table.Root size="sm">
                      <Table.Header>
                        <Table.Row>
                          <Table.ColumnHeader>Trường</Table.ColumnHeader>
                          <Table.ColumnHeader textAlign="end">
                            Số lượng đang có
                          </Table.ColumnHeader>
                        </Table.Row>
                      </Table.Header>
                      <Table.Body>
                        {preview.family.contributions.map((member) => {
                          const school = preview.display.schools.find(
                            (s) =>
                              s.confirmed_need_line_id ===
                              member.confirmed_need_line_id,
                          );
                          return (
                            <Table.Row key={member.confirmed_need_line_id}>
                              <Table.Cell>
                                {label(
                                  school?.school_name,
                                  "Chưa có tên trường",
                                )}
                                {member.confirmed_need_line_id ===
                                form.target.confirmed_need_line_id
                                  ? " · Dòng điều chỉnh"
                                  : ""}
                              </Table.Cell>
                              <Table.Cell textAlign="end">
                                {quantity(member.quantity)}
                              </Table.Cell>
                            </Table.Row>
                          );
                        })}
                      </Table.Body>
                    </Table.Root>
                    {zero(preview.family.quantity_after) ? (
                      <Text mt="sm" color="status.warning">
                        Toàn bộ nhóm nhu cầu bằng 0. Cần xử lý cam kết còn lại
                        theo quy trình hủy hiện có; không tự tạo đơn mua hoặc
                        phiếu xuất rỗng. Chứng từ cũ được giữ nguyên.
                      </Text>
                    ) : zero(preview.quantity.after) ? (
                      <Text mt="sm">
                        Các trường khác vẫn có nhu cầu. Dòng được chọn bằng 0
                        không có nghĩa toàn bộ nhóm bằng 0.
                      </Text>
                    ) : null}
                    <Heading size="sm" mt="md">
                      Phân bổ được phép xem
                    </Heading>
                    <Text textStyle="helper" color="fg.muted">
                      Chỉ hiển thị chi tiết phân bổ trong phạm vi được phép xem.
                      Thông tin này không phải điều kiện cấp thêm quyền điều
                      chỉnh nhu cầu.
                    </Text>
                    {preview.procurement_details.map((raw, index) => {
                      const detail = record(raw);
                      const splits = detail?.supplier_splits;
                      return (
                        <Box key={index} mt="sm">
                          {Array.isArray(splits) ? (
                            splits.map((value, i) => {
                              const split = record(value);
                              return split ? (
                                <Box key={i} mb="sm">
                                  <Text>
                                    {label(
                                      split.supplier_name,
                                      "Chưa có tên nhà cung cấp",
                                    )}{" "}
                                    · {quantity(split.allocated_quantity)}{" "}
                                    {unit}
                                  </Text>
                                  {typeof split.supplier_note === "string" &&
                                    split.supplier_note.trim() && (
                                      <Text textStyle="helper">
                                        Ghi chú NCC: {split.supplier_note}
                                      </Text>
                                    )}
                                </Box>
                              ) : (
                                <Text key={i}>
                                  Chưa đủ dữ liệu chi tiết phân bổ.
                                </Text>
                              );
                            })
                          ) : (
                            <Text>Chưa đủ dữ liệu chi tiết phân bổ.</Text>
                          )}
                        </Box>
                      );
                    })}
                    <Heading size="sm" mt="md">
                      Đơn mua liên quan được phép xem
                    </Heading>
                    <Text textStyle="helper" color="fg.muted">
                      Chỉ hiển thị đơn mua trong phạm vi được phép xem. Danh
                      sách này không xác nhận toàn bộ cam kết; các đơn ngoài
                      phạm vi xem không được thể hiện.
                    </Text>
                    {preview.purchase_orders.map((raw, index) => {
                      const po = record(raw);
                      const statuses: Record<string, string> = {
                        DRAFT: "Bản nháp",
                        RELEASED_TO_SUPPLIER: "Đã phát hành",
                        SUPERSEDED: "Đã được thay thế",
                      };
                      return po ? (
                        <Box key={index} mt="sm">
                          <Text>
                            {label(po.document_number, "Chưa có số đơn")} ·{" "}
                            {label(
                              po.supplier_name,
                              "Chưa có tên nhà cung cấp",
                            )}
                          </Text>
                          <Text textStyle="helper">
                            {typeof po.purchase_order_status === "string"
                              ? (statuses[po.purchase_order_status] ??
                                "Chưa xác định tình trạng")
                              : "Chưa xác định tình trạng"}
                          </Text>
                        </Box>
                      ) : (
                        <Text key={index}>
                          Chưa đủ dữ liệu chứng từ để hiển thị.
                        </Text>
                      );
                    })}
                    {!preview.allowed_actions.correct && (
                      <Text role="alert" mt="md" color="status.warning">
                        {confirmedNeedCorrectionMessage(
                          preview.disabled_reasons.correct ?? "UNAVAILABLE",
                        )}
                      </Text>
                    )}
                  </Box>
                )}
              </Dialog.Body>
              <Dialog.Footer flexWrap="wrap" gap="sm">
                <Button
                  variant="secondary"
                  disabled={locked}
                  onClick={c.closeCorrection}
                >
                  Đóng
                </Button>
                {["UNKNOWN", "RETRYABLE"].includes(form.status) ? (
                  <Button
                    variant="businessPrimary"
                    disabled={c.busy}
                    onClick={() => void c.retryCorrection()}
                  >
                    Thử lại đúng yêu cầu
                  </Button>
                ) : form.status === "READBACK" || form.status === "STALE" ? (
                  <Button
                    variant="businessPrimary"
                    disabled={c.busy}
                    onClick={() => void c.recover()}
                  >
                    {form.status === "READBACK"
                      ? "Tải lại để xác nhận"
                      : "Tải lại dữ liệu"}
                  </Button>
                ) : (
                  <>
                    <Button
                      variant="secondary"
                      disabled={frozen || form.status === "PREVIEWING"}
                      loading={form.status === "PREVIEWING"}
                      onClick={() => void c.previewCorrection()}
                    >
                      Xem ảnh hưởng
                    </Button>
                    <Button
                      variant="businessPrimary"
                      disabled={
                        frozen ||
                        !preview?.allowed_actions.correct ||
                        Boolean(c.rangeError)
                      }
                      loading={c.busy}
                      onClick={() => void c.saveCorrection()}
                    >
                      Lưu điều chỉnh
                    </Button>
                  </>
                )}
              </Dialog.Footer>
            </>
          )}
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
