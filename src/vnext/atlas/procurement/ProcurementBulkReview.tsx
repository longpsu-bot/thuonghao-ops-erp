import {
  Box,
  Button,
  Checkbox,
  Dialog,
  Flex,
  Heading,
  Stack,
  Table,
  Text,
  VisuallyHidden,
} from "@chakra-ui/react";
import { useEffect, useImperativeHandle, useRef, useState } from "react";
import {
  useAtlasWorkbenchStatus,
  type AtlasModuleExitProps,
} from "../AtlasModuleExit";
import { AtlasTableViewport } from "../AtlasTableViewport";
import type {
  BulkAllocationFamily,
  SupplierAllocationBatchCandidate,
  SupplierAllocationBulkPreview,
} from "../bridges/procurement";
import { formatExactQuantityForOperator as quantity } from "./procurementExactQuantity";

const key = (row: BulkAllocationFamily) =>
  JSON.stringify([
    row.service_date,
    row.delivery_location_id,
    row.ingredient_id,
    row.unit_id,
  ]);
const exclusions: Record<string, string> = {
  ZERO_QUANTITY: "Nhu cầu bằng 0 — không áp dụng",
  NO_ELIGIBLE_SUPPLIER: "Chưa có NCC đủ điều kiện",
  NO_UNIQUE_PREFERRED_SUPPLIER: "Chưa xác định được một NCC ưu tiên duy nhất",
  EXISTING_DECISION_PRESERVED: "Giữ nguyên phân bổ đã lưu",
  CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING: "Nguồn nhu cầu chưa xác định duy nhất",
  CONFIRMED_NEED_INCOMPLETE: "Nhu cầu chưa đủ dữ liệu",
  SCHOOL_LINEAGE_UNAVAILABLE: "Chưa đủ thông tin trường đóng góp",
};
export function ProcurementBulkReview({
  preview,
  disabled,
  onApply,
  onClose,
  exitRef,
  onWorkspaceStatus,
}: AtlasModuleExitProps & {
  preview: SupplierAllocationBulkPreview;
  disabled: boolean;
  onApply: (candidates: SupplierAllocationBatchCandidate[]) => void;
  onClose: () => void;
}) {
  const initial = preview.families
    .filter((r) => r.candidate?.proposal_kind === "DEFAULT")
    .map(key);
  const [selected, setSelected] = useState<string[]>(initial);
  const [discard, setDiscard] = useState(false);
  const pending = useRef<(() => void) | null>(null);
  const close = useRef<HTMLButtonElement>(null);
  const cancel = useRef<HTMLButtonElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    heading.current?.focus();
  }, []);
  const dirty =
    JSON.stringify([...selected].sort()) !==
    JSON.stringify([...initial].sort());
  useAtlasWorkbenchStatus(onWorkspaceStatus, {
    unsaved: dirty,
    blocked: disabled,
  });
  const requestExit = (next: () => void) => {
    if (disabled) return;
    if (!dirty) next();
    else {
      pending.current = next;
      setDiscard(true);
    }
  };
  useImperativeHandle(exitRef, () => ({ requestExit }));
  const candidates = preview.families
    .filter((r) => selected.includes(key(r)))
    .flatMap((r) => (r.candidate ? [r.candidate] : []));
  return (
    <Box
      as="section"
      role="region"
      aria-label="Xem trước phân bổ hàng loạt"
      p="md"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Stack gap="sm" mb="md">
        <Heading ref={heading} tabIndex={-1} textStyle="section">
          Xem trước phân bổ hàng loạt
        </Heading>
        <Text textStyle="body">
          {preview.total_count} nhóm trong phạm vi · {preview.applicable_count}{" "}
          có đề xuất · {preview.excluded_count} giữ nguyên / chưa thể áp dụng.
        </Text>
        <Text textStyle="helper" color="fg.muted">
          Mỗi nhóm gồm toàn bộ nhu cầu cùng ngày, điểm giao, nguyên liệu và đơn
          vị. Chọn trường không tách phần nhu cầu của trường đó. Cân bằng lại
          cần được chọn rõ trước khi lưu.
        </Text>
        <Text textStyle="helper" color="fg.muted">
          Chỉ hiển thị đơn mua trong phạm vi được phép; danh sách trống không
          chứng minh không có cam kết. Thao tác này chỉ lưu phân bổ, không tạo
          hay phát hành đơn mua.
        </Text>
      </Stack>
      <AtlasTableViewport
        label="Các nhóm phân bổ hàng loạt"
        maxH="var(--atlas-procurement-desktop-surface-max-height, calc(100dvh - 400px))"
      >
        <Table.Root
          aria-label="Các nhóm phân bổ hàng loạt"
          minW="var(--atlas-layout-procurement-table-min, 1050px)"
          size="sm"
        >
          <Table.Header>
            <Table.Row>
              {[
                "Chọn",
                "Nhu cầu / trường",
                "Đã lưu",
                "Đề xuất được xem trước",
                "Đơn mua được phép xem",
              ].map((t) => (
                <Table.ColumnHeader key={t}>{t}</Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {preview.families.map((row) => {
              const candidate = row.candidate;
              const supplier = (id: string) =>
                row.eligible_suppliers.find((s) => s.supplier_id === id)
                  ?.supplier_name ??
                row.splits.find((s) => s.supplier_id === id)?.supplier_name ??
                "NCC cần kiểm tra";
              const unit =
                row.unit_label && !/^v\d+-/i.test(row.unit_label)
                  ? row.unit_label
                  : "Chưa có tên đơn vị";
              return (
                <Table.Row key={key(row)} verticalAlign="top">
                  <Table.Cell>
                    <Checkbox.Root
                      disabled={disabled || !candidate || !preview.allowed}
                      checked={selected.includes(key(row))}
                      onCheckedChange={({ checked }) =>
                        setSelected((old) =>
                          checked
                            ? [...old, key(row)]
                            : old.filter((k) => k !== key(row)),
                        )
                      }
                    >
                      <Checkbox.HiddenInput
                        aria-label={`Chọn ${row.ingredient_name} — ${row.location_name} — ${row.service_date}`}
                      />
                      <Checkbox.Control>
                        <Checkbox.Indicator />
                      </Checkbox.Control>
                      <Checkbox.Label>
                        Chọn{" "}
                        <VisuallyHidden>
                          {row.ingredient_name} — {row.location_name} —{" "}
                          {row.service_date}
                        </VisuallyHidden>
                      </Checkbox.Label>
                    </Checkbox.Root>
                  </Table.Cell>
                  <Table.Cell
                    maxW="var(--atlas-layout-bulk-school-width, 290px)"
                    whiteSpace="normal"
                    overflowWrap="anywhere"
                  >
                    <Text fontWeight="semibold">{row.ingredient_name}</Text>
                    <Text>
                      {row.family_quantity === null
                        ? "Chưa xác định"
                        : quantity(row.family_quantity)}{" "}
                      <Text as="span">{unit}</Text>
                    </Text>
                    <Text textStyle="helper">
                      {row.service_date.split("-").reverse().join("/")} ·{" "}
                      {row.location_name}
                    </Text>
                    {row.schools.length ? (
                      <Text textStyle="helper">
                        {row.schools.map((s) => s.school_name).join(" · ")}
                      </Text>
                    ) : (
                      <Text textStyle="helper" color="status.warning">
                        Chưa đủ thông tin trường
                      </Text>
                    )}
                    {row.contributions.map((c, i) => (
                      <Text key={i} textStyle="helper" color="fg.muted">
                        {row.schools.find((s) => s.school_id === c.school_id)
                          ?.school_name ?? "Trường chưa xác định"}
                        :{" "}
                        {c.contribution_quantity == null
                          ? "Chưa xác định"
                          : quantity(c.contribution_quantity)}
                      </Text>
                    ))}
                  </Table.Cell>
                  <Table.Cell whiteSpace="normal">
                    {row.splits.length ? (
                      row.splits.map((s) => (
                        <Box key={s.supplier_id} mb="xs">
                          <Text>
                            {s.supplier_name} · {quantity(s.allocated_quantity)}
                          </Text>
                          {s.supplier_note && (
                            <Text textStyle="helper">
                              Ghi chú: {s.supplier_note}
                            </Text>
                          )}
                        </Box>
                      ))
                    ) : (
                      <Text color="fg.muted">Chưa lưu phân bổ</Text>
                    )}
                  </Table.Cell>
                  <Table.Cell whiteSpace="normal">
                    {candidate ? (
                      <>
                        <Text fontWeight="semibold">
                          {candidate.proposal_kind === "DEFAULT"
                            ? "Gán NCC mặc định"
                            : "Cân bằng lại theo tỷ lệ đã lưu"}
                        </Text>
                        {candidate.proposed_splits.map((s) => (
                          <Box key={s.supplier_id} mb="xs">
                            <Text>
                              {supplier(s.supplier_id)} ·{" "}
                              {quantity(s.allocated_quantity)}
                            </Text>
                            {s.supplier_note && (
                              <Text textStyle="helper">
                                Ghi chú: {s.supplier_note}
                              </Text>
                            )}
                          </Box>
                        ))}
                      </>
                    ) : (
                      <Text color="fg.muted">
                        {exclusions[row.exclusion_reason ?? ""] ??
                          "Chưa thể áp dụng — kiểm tra dữ liệu hiện tại"}
                      </Text>
                    )}
                  </Table.Cell>
                  <Table.Cell whiteSpace="normal">
                    {row.purchase_order_impact.documents.map((po) => (
                      <Text key={po.purchase_order_id} textStyle="helper">
                        {po.document_number ?? "Đơn nháp"} · {po.supplier_name}{" "}
                        ·{" "}
                        {po.status === "DRAFT"
                          ? "Nháp"
                          : po.status === "RELEASED_TO_SUPPLIER"
                            ? "Đã phát hành"
                            : "Cần kiểm tra"}
                      </Text>
                    ))}
                    <Text textStyle="helper" color="fg.muted">
                      Chỉ các đơn được phép xem
                    </Text>
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
      {!preview.families.length && (
        <Text py="md">Không có nhóm nhu cầu trong phạm vi đã chọn.</Text>
      )}
      <Flex mt="md" justify="space-between" gap="sm" wrap="wrap">
        <Button
          ref={close}
          disabled={disabled}
          onClick={() => requestExit(onClose)}
        >
          Đóng xem trước
        </Button>
        <Button
          variant="businessPrimary"
          disabled={disabled || !preview.allowed || !candidates.length}
          onClick={() => onApply(candidates)}
        >
          Áp dụng và lưu {candidates.length} nhóm
        </Button>
      </Flex>
      <Dialog.Root
        open={discard}
        onOpenChange={({ open }) => {
          setDiscard(open);
          if (!open) pending.current = null;
        }}
        initialFocusEl={() => cancel.current}
        finalFocusEl={() => close.current}
        placement="center"
        motionPreset="none"
        lazyMount
        unmountOnExit
      >
        <Dialog.Backdrop
          bg="bg.navigation"
          opacity="var(--atlas-layout-backdrop-opacity, 0.45)"
          animation="var(--atlas-layout-motion, none)"
        />
        <Dialog.Positioner p="md">
          <Dialog.Content
            bg="bg.workbench"
            color="fg.default"
            borderRadius="workbench"
            boxShadow="var(--atlas-layout-shadow, none)"
          >
            <Dialog.Header>
              <Dialog.Title textStyle="section">
                Có lựa chọn phân bổ chưa lưu
              </Dialog.Title>
            </Dialog.Header>
            <Dialog.Body>Đóng và bỏ các lựa chọn đã thay đổi?</Dialog.Body>
            <Dialog.Footer flexWrap="wrap">
              <Button ref={cancel} onClick={() => setDiscard(false)}>
                Tiếp tục xem trước
              </Button>
              <Button
                variant="destructive"
                onClick={() => {
                  setDiscard(false);
                  const next = pending.current;
                  pending.current = null;
                  if (!disabled) next?.();
                }}
              >
                Bỏ lựa chọn và đóng
              </Button>
            </Dialog.Footer>
          </Dialog.Content>
        </Dialog.Positioner>
      </Dialog.Root>
    </Box>
  );
}
