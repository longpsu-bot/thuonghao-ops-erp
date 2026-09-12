import { AtlasDateInput } from "../AtlasDateInput";
import {
  Box,
  Button,
  Dialog,
  Field,
  Grid,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useRef, useState } from "react";
import type {
  EffectiveCompositionResult,
  RecipeAdjustmentWorkbenchData,
} from "../bridges/recipeAdjustment";
import type { ChangeOrderController } from "./useChangeOrderWorkbench";
import { ChangeSelect } from "./ChangeOrderEditor";
import { periodLabel, validDate, vietnamLocalDate } from "./changeOrderModel";
export function ChangeComposition({
  title,
  value,
  data,
}: {
  title: string;
  value: EffectiveCompositionResult;
  data: RecipeAdjustmentWorkbenchData;
}) {
  return (
    <Box minW="var(--atlas-layout-zero, 0)" overflowX="auto">
      <Text fontWeight="semibold" mb="xs">
        {title}
      </Text>
      <Table.Root
        size="sm"
        aria-label={title}
        minW="var(--atlas-layout-zero, 0)"
        w="full"
        tableLayout="fixed"
        css={{
          "& th, & td": { whiteSpace: "normal", overflowWrap: "anywhere" },
        }}
      >
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeader>Nguyên liệu</Table.ColumnHeader>
            <Table.ColumnHeader textAlign="end">Định lượng</Table.ColumnHeader>
            <Table.ColumnHeader>Đơn vị</Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {value.lines.map((l, i) => (
            <Table.Row
              key={`${l.base_recipe_line_id ?? l.adjustment_line_id}:${i}`}
            >
              <Table.Cell>
                {data.ingredients.find(
                  (x) => x.ingredient_id === l.final_ingredient_id,
                )?.ingredient_name ?? "Thành phần"}
                {l.final_disposition === "REMOVED" && (
                  <Text textStyle="helper" color="status.danger">
                    Đã bỏ
                  </Text>
                )}
              </Table.Cell>
              <Table.Cell textAlign="end">
                {l.final_quantity_per_basis.toLocaleString("vi-VN", {
                  maximumFractionDigits: 6,
                })}
              </Table.Cell>
              <Table.Cell>
                {data.units.find((u) => u.unit_id === l.final_unit_id)
                  ?.unit_name ?? "—"}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table.Root>
      {value.blockers.map((b, i) => (
        <Text key={i} role="alert">
          {b.message}
        </Text>
      ))}
    </Box>
  );
}
export function ChangeOrderReview({ c }: { c: ChangeOrderController }) {
  const back = useRef<HTMLButtonElement>(null),
    p = c.preview;
  return (
    <Dialog.Root
      open={Boolean(p)}
      onOpenChange={({ open }) => !open && c.backToEdit()}
      initialFocusEl={() => back.current}
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
          maxW="var(--atlas-layout-review-width, 920px)"
          maxH="var(--atlas-layout-review-height, 92dvh)"
        >
          <Dialog.Header>
            <Dialog.Title>Xem tác động</Dialog.Title>
          </Dialog.Header>
          <Dialog.Body overflowY="auto">
            {p && (
              <>
                <Text textStyle="helper" mb="sm">
                  {periodLabel(
                    c.draft!.effectiveFrom,
                    c.draft!.effectiveTo || null,
                  )}{" "}
                  · {p.affected_line_count} thành phần chịu tác động
                </Text>
                <Grid
                  templateColumns={{
                    base: "minmax(0, 1fr)",
                    md: "repeat(2, minmax(0, 1fr))",
                  }}
                  gap="md"
                >
                  <ChangeComposition
                    title="Trước điều chỉnh"
                    value={p.before}
                    data={c.data}
                  />
                  <ChangeComposition
                    title="Sau điều chỉnh"
                    value={p.after}
                    data={c.data}
                  />
                </Grid>
                {p.warnings.map((w, i) => (
                  <Text mt="sm" key={i} role="status" color="status.warning">
                    {w.message}
                  </Text>
                ))}
                {p.blockers.map((b, i) => (
                  <Text mt="sm" key={i} role="alert" color="status.danger">
                    {b.message}
                  </Text>
                ))}
                {p.school_id === null && (
                  <Box as="details" mt="md">
                    <Text
                      as="summary"
                      cursor="var(--atlas-pointer, pointer)"
                      fontWeight="medium"
                    >
                      Kiểm tra tại một trường
                    </Text>
                    <Box mt="sm">
                      <ChangeSelect
                        label="Kiểm tra tác động tại trường"
                        value={c.inspectionSchool}
                        disabled={c.busy || Boolean(c.lock)}
                        onChange={(v) => void c.inspectSchool(v)}
                      >
                        <option value="">Chọn trường để kiểm tra</option>
                        {c.data.schools
                          .filter(
                            (s) =>
                              s.school_status === "ACTIVE" &&
                              s.school_type_id === p.school_type_id,
                          )
                          .map((s) => (
                            <option key={s.school_id} value={s.school_id}>
                              {s.school_name}
                            </option>
                          ))}
                      </ChangeSelect>
                      <Text textStyle="helper" color="fg.muted" my="xs">
                        Công thức đang hiệu lực tại trường · chỉ đọc, không thay
                        đổi lệnh đang xem.
                      </Text>
                      {c.inspectionLoading && (
                        <Text role="status">Đang kiểm tra…</Text>
                      )}
                      {c.inspectionMessage && (
                        <Text role="alert">{c.inspectionMessage}</Text>
                      )}
                      {c.inspection && (
                        <ChangeComposition
                          title="Công thức tại trường"
                          value={c.inspection}
                          data={c.data}
                        />
                      )}
                    </Box>
                  </Box>
                )}
              </>
            )}
          </Dialog.Body>
          <Dialog.Footer flexWrap="wrap">
            <Button
              ref={back}
              onClick={c.backToEdit}
              disabled={c.busy || Boolean(c.lock)}
            >
              Tiếp tục chỉnh sửa
            </Button>
            {p?.can_save && !p.blockers.length && (
              <Button
                variant="businessPrimary"
                loading={c.busy}
                disabled={!c.canAct}
                onClick={() => void c.save()}
              >
                {c.editing ? "Lưu sửa lệnh" : "Lưu lệnh điều chỉnh"}
              </Button>
            )}
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
export function ChangeOrderCancel({ c }: { c: ChangeOrderController }) {
  const row = c.cancelTarget!,
    from = row.command_revision.effective_from;
  const [date, setDate] = useState(
      from > vietnamLocalDate() ? from : vietnamLocalDate(),
    ),
    [reason, setReason] = useState("");
  const back = useRef<HTMLButtonElement>(null);
  const valid =
    validDate(date) &&
    date >= from &&
    (!row.command_revision.effective_to ||
      date < row.command_revision.effective_to) &&
    Boolean(reason.trim());
  return (
    <Dialog.Root
      open
      onOpenChange={({ open }) => !open && c.closeCancel()}
      initialFocusEl={() => back.current}
      placement="center"
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          bg="bg.workbench"
          color="fg.default"
          mx="md"
          borderRadius="workbench"
        >
          <Dialog.Header>
            <Dialog.Title>Hủy lệnh</Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            {c.message && (
              <Text role="alert" color="status.danger" mb="sm">
                {c.message}
              </Text>
            )}
            <AtlasDateInput
              label="Hủy từ ngày"
              value={date}
              onValueChange={setDate}
              disabled={c.busy}
            />
            <Field.Root mt="sm">
              <Field.Label>Lý do hủy</Field.Label>
              <Textarea
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                disabled={c.busy}
              />
            </Field.Root>
            <Text textStyle="helper" mt="sm">
              Lịch sử lệnh được giữ nguyên. Lệnh ngừng áp dụng từ ngày đã chọn.
            </Text>
          </Dialog.Body>
          <Dialog.Footer flexWrap="wrap">
            <Button ref={back} disabled={c.busy} onClick={c.closeCancel}>
              Tiếp tục xem lệnh
            </Button>
            <Button
              variant="destructive"
              disabled={!valid || !c.canAct}
              loading={c.busy}
              onClick={() => void c.cancel(date, reason)}
            >
              Xác nhận hủy
            </Button>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
