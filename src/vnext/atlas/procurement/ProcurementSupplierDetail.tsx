import {
  Box,
  Button,
  Dialog,
  Field,
  Flex,
  Heading,
  Input,
  NativeSelect,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState } from "react";
import {
  procurementOperatorMessages,
  type AllocationFamilyRow,
  type AllocationProposalSplit,
  type SupplierSplitInput,
} from "../bridges/procurement";
import {
  formatExactQuantityForOperator as quantity,
  parseExactQuantity,
  sumExactQuantities,
} from "./procurementExactQuantity";

export function ProcurementSupplierDetail({
  row,
  disabled,
  onSave,
  onClose,
}: {
  row: AllocationFamilyRow;
  disabled: boolean;
  onSave: (splits: SupplierSplitInput[]) => void;
  onClose: () => void;
}) {
  const eligible = (id: string) =>
    row.eligible_suppliers.some((supplier) => supplier.supplier_id === id);
  const saved = row.splits.filter((split) => eligible(split.supplier_id));
  const [draft, setDraft] = useState<SupplierSplitInput[]>(() =>
    saved.map(({ supplier_id, allocated_quantity }) => ({
      supplier_id,
      allocated_quantity,
    })),
  );
  const [added, setAdded] = useState<string[]>([]);
  const [adding, setAdding] = useState(false);
  const [supplierId, setSupplierId] = useState("");
  const [discardOpen, setDiscardOpen] = useState(false);
  const heading = useRef<HTMLHeadingElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const cancelButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    heading.current?.focus();
  }, []);
  const total = sumExactQuantities(
    draft.map((split) => split.allocated_quantity),
  );
  const need =
    row.complete === false || row.family_quantity === null
      ? null
      : parseExactQuantity(row.family_quantity);
  const remainder = total === null || need === null ? null : need - total;
  const locked = disabled || row.complete === false;
  const canSave =
    !locked &&
    row.allowed_actions.save_allocation &&
    remainder === 0n &&
    draft.some(
      (split) => (parseExactQuantity(split.allocated_quantity) ?? 0n) > 0n,
    );
  const dirty =
    draft.length !== saved.length ||
    draft.some((split) => {
      const original = saved.find(
        (value) => value.supplier_id === split.supplier_id,
      );
      const parsed = parseExactQuantity(split.allocated_quantity);
      return (
        !original ||
        parsed === null ||
        parsed !== parseExactQuantity(original.allocated_quantity)
      );
    });
  const available = row.eligible_suppliers.filter(
    (supplier) =>
      !draft.some((split) => split.supplier_id === supplier.supplier_id),
  );
  const apply = (proposal: AllocationProposalSplit[]) => {
    if (locked || proposal.some((split) => !eligible(split.supplier_id)))
      return;
    setDraft(
      proposal.map(({ supplier_id, allocated_quantity }) => ({
        supplier_id,
        allocated_quantity,
      })),
    );
    setAdded(
      proposal
        .map((split) => split.supplier_id)
        .filter((id) => !saved.some((split) => split.supplier_id === id)),
    );
  };
  const proposal = (
    title: string,
    values: AllocationProposalSplit[],
    action: string,
  ) => (
    <Box
      bg="bg.info"
      p="sm"
      borderRadius="control"
      role="region"
      aria-label={title}
    >
      <Text fontWeight="semibold" color="status.info">
        {title}
      </Text>
      {title === "Đề xuất cân bằng lại" && (
        <Text textStyle="helper" mt="xs">
          Phân bổ đã lưu được giữ nguyên đến khi bạn áp dụng và lưu đề xuất.
        </Text>
      )}
      {values.map((split) => (
        <Text key={split.supplier_id} mt="xs">
          {row.eligible_suppliers.find(
            (supplier) => supplier.supplier_id === split.supplier_id,
          )?.supplier_name ?? "Nhà cung ứng không còn phù hợp"}{" "}
          · {quantity(split.allocated_quantity)} {row.unit_code}
        </Text>
      ))}
      <Button
        size="sm"
        variant="secondary"
        mt="sm"
        disabled={
          locked || values.some((split) => !eligible(split.supplier_id))
        }
        onClick={() => apply(values)}
      >
        {action}
      </Button>
    </Box>
  );
  return (
    <Flex
      as="aside"
      role="region"
      aria-label={`Phân bổ ${row.ingredient_name}`}
      direction="column"
      minW="var(--atlas-layout-zero, 0)"
      bg="bg.subtle"
      borderColor="border.subtle"
      borderLeftWidth={{
        base: "var(--atlas-layout-zero, 0)",
        xl: "var(--atlas-layout-edge, 1px)",
      }}
      borderTopWidth={{
        base: "var(--atlas-layout-edge, 1px)",
        xl: "var(--atlas-layout-zero, 0)",
      }}
      maxH={{
        base: "var(--atlas-layout-detail-mobile-height, 80dvh)",
        xl: "var(--atlas-layout-detail-height, calc(100dvh - 360px))",
      }}
    >
      <Box p="md" pb="sm">
        <Heading as="h2" textStyle="section" tabIndex={-1} ref={heading}>
          {row.ingredient_name}
        </Heading>
        <Text color="fg.muted" textStyle="helper" mt="xs">
          {row.schools?.map((school) => school.school_name).join(", ") ||
            row.school_name}{" "}
          · {row.location_name}
        </Text>
      </Box>
      <Flex
        role="status"
        aria-label="Cân đối phân bổ"
        aria-live="polite"
        mx="md"
        pb="sm"
        gap="sm"
        justify="space-between"
        borderBottomWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
      >
        {(
          [
            ["Nhu cầu đã xác nhận", need],
            ["Đã phân bổ", total],
            ["Còn lại", remainder],
          ] as const
        ).map(([label, value]) => (
          <Box key={label} minW="var(--atlas-layout-zero, 0)">
            <Text textStyle="helper" color="fg.muted">
              {label}
            </Text>
            <Text
              fontWeight="semibold"
              fontVariantNumeric="tabular-nums"
              color={
                label === "Còn lại" && value !== 0n
                  ? "status.warning"
                  : "fg.primary"
              }
            >
              {quantity(value)} {row.unit_code}
            </Text>
          </Box>
        ))}
      </Flex>
      <Stack
        p="md"
        gap="md"
        overflowY="auto"
        minH="var(--atlas-layout-zero, 0)"
        flex="1"
      >
        {row.splits
          .filter((split) => !eligible(split.supplier_id))
          .map((split) => (
            <Box
              key={split.supplier_id}
              role="alert"
              bg="bg.warning"
              color="status.warning"
              p="sm"
              borderRadius="control"
            >
              ⚠ {split.supplier_name} không còn phù hợp (
              {quantity(split.allocated_quantity)} {row.unit_code}). Cần chọn
              nhà cung ứng thay thế; phần đã lưu không tự chuyển.
            </Box>
          ))}
        {draft.length === 0 && (
          <Text color="fg.muted">Chưa có nhà cung ứng trong bản nháp.</Text>
        )}
        {draft.map((split) => {
          const supplier = row.eligible_suppliers.find(
            (item) => item.supplier_id === split.supplier_id,
          )!;
          const invalid = parseExactQuantity(split.allocated_quantity) === null;
          return (
            <Field.Root key={split.supplier_id} invalid={invalid}>
              <Field.Label>{supplier.supplier_name}</Field.Label>
              <Flex gap="xs" w="full" align="center">
                <Input
                  aria-label={`Phân bổ ${supplier.supplier_name}`}
                  aria-invalid={invalid}
                  inputMode="decimal"
                  value={split.allocated_quantity}
                  disabled={locked}
                  onChange={(event) =>
                    setDraft((values) =>
                      values.map((value) =>
                        value.supplier_id === split.supplier_id
                          ? { ...value, allocated_quantity: event.target.value }
                          : value,
                      ),
                    )
                  }
                  minW="var(--atlas-layout-zero, 0)"
                />
                <Text>{row.unit_code}</Text>
                {added.includes(split.supplier_id) && (
                  <Button
                    size="sm"
                    variant="utility"
                    aria-label={`Xóa ${supplier.supplier_name}`}
                    disabled={locked}
                    onClick={() =>
                      setDraft((values) =>
                        values.filter(
                          (value) => value.supplier_id !== split.supplier_id,
                        ),
                      )
                    }
                  >
                    Xóa
                  </Button>
                )}
              </Flex>
              {invalid && (
                <Field.ErrorText>
                  Nhập số không âm, tối đa 6 chữ số sau dấu chấm.
                </Field.ErrorText>
              )}
            </Field.Root>
          );
        })}
        <Box>
          <Button
            size="sm"
            variant="secondary"
            disabled={locked || available.length === 0}
            onClick={() => {
              setAdding(!adding);
              setSupplierId("");
            }}
          >
            + Thêm nhà cung ứng
          </Button>
          {adding && (
            <Stack mt="sm" gap="sm">
              <NativeSelect.Root disabled={locked}>
                <NativeSelect.Field
                  aria-label="Nhà cung ứng đủ điều kiện"
                  value={supplierId}
                  onChange={(event) => setSupplierId(event.target.value)}
                >
                  <option value="">Chọn nhà cung ứng</option>
                  {available.map((supplier) => (
                    <option
                      key={supplier.supplier_id}
                      value={supplier.supplier_id}
                    >
                      {supplier.supplier_name}
                    </option>
                  ))}
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
              <Button
                size="sm"
                disabled={
                  locked ||
                  !available.some(
                    (supplier) => supplier.supplier_id === supplierId,
                  )
                }
                onClick={() => {
                  setDraft((values) => [
                    ...values,
                    { supplier_id: supplierId, allocated_quantity: "" },
                  ]);
                  setAdded((ids) => [...ids, supplierId]);
                  setAdding(false);
                }}
              >
                Thêm
              </Button>
            </Stack>
          )}
        </Box>
        {row.recommendation &&
          proposal("Đề xuất của Atlas", [row.recommendation], "Dùng đề xuất")}
        {row.rebalance_proposal &&
          proposal(
            "Đề xuất cân bằng lại",
            row.rebalance_proposal,
            "Áp dụng đề xuất",
          )}
        {procurementOperatorMessages(
          [...row.blockers, ...row.disabled_reasons, ...row.warnings],
          "Máy chủ chưa cho phép tiếp tục phân bổ này.",
        ).map((message) => (
          <Text key={message} role="alert" color="status.warning">
            ⚠ {message}
          </Text>
        ))}
      </Stack>
      <Flex
        as="footer"
        justify="space-between"
        gap="sm"
        p="md"
        borderTopWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
        flexShrink="0"
      >
        <Button
          ref={closeButton}
          onClick={() => (dirty ? setDiscardOpen(true) : onClose())}
        >
          Đóng
        </Button>
        <Button
          variant="businessPrimary"
          disabled={!canSave}
          onClick={() =>
            onSave(
              draft.filter(
                (split) =>
                  (parseExactQuantity(split.allocated_quantity) ?? 0n) > 0n,
              ),
            )
          }
        >
          Lưu phân bổ
        </Button>
      </Flex>
      <Dialog.Root
        open={discardOpen}
        onOpenChange={({ open }) => setDiscardOpen(open)}
        initialFocusEl={() => cancelButton.current}
        finalFocusEl={() => closeButton.current}
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
                Có thay đổi phân bổ chưa lưu
              </Dialog.Title>
            </Dialog.Header>
            <Dialog.Body>Đóng và bỏ các thay đổi này?</Dialog.Body>
            <Dialog.Footer flexWrap="wrap">
              <Button ref={cancelButton} onClick={() => setDiscardOpen(false)}>
                Tiếp tục chỉnh sửa
              </Button>
              <Button
                variant="destructive"
                onClick={() => {
                  setDiscardOpen(false);
                  onClose();
                }}
              >
                Bỏ thay đổi và đóng
              </Button>
            </Dialog.Footer>
          </Dialog.Content>
        </Dialog.Positioner>
      </Dialog.Root>
    </Flex>
  );
}
