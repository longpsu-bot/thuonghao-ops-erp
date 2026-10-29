import {
  Box,
  Button,
  Field,
  Flex,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import type { IngredientSupplierWorkbenchController } from "./useIngredientSupplierWorkbench";

export function IngredientPriorityEditor({
  c,
}: {
  c: IngredientSupplierWorkbenchController;
}) {
  const panel = useRef<HTMLElement>(null);
  const addedSupplier = useRef<HTMLSelectElement>(null);
  const focusAddedSupplier = useRef(false);
  useEffect(() => {
    if (c.activeSurface?.kind === "priorities")
      panel.current?.focus({ preventScroll: true });
  }, [c.activeSurface]);
  useEffect(() => {
    if (!focusAddedSupplier.current) return;
    focusAddedSupplier.current = false;
    addedSupplier.current?.focus();
  }, [c.priorities.length]);
  if (c.activeSurface?.kind !== "priorities" || !c.selectedIngredient)
    return null;
  const disabled = c.saving || c.loading || Boolean(c.lock);
  const activeSuppliers = c.suppliers.filter(
    (supplier) => supplier.supplier_status === "ACTIVE",
  );
  const usedSupplierIds = new Set(c.priorities.map((item) => item.supplierId));
  const unusedActiveSuppliers = activeSuppliers.filter(
    (supplier) => !usedSupplierIds.has(supplier.supplier_id),
  );
  const add = () => {
    const supplier = unusedActiveSuppliers[0];
    const ranks = new Set(c.priorities.map((item) => item.priority));
    const priority = [1, 2, 3, 4, 5, 6].find((rank) => !ranks.has(rank)) ?? 1;
    focusAddedSupplier.current = true;
    c.setPriorities([
      ...c.priorities,
      { supplierId: supplier?.supplier_id ?? "", priority },
    ]);
  };
  return (
    <Box
      as="aside"
      ref={panel}
      tabIndex={-1}
      aria-label="Ưu tiên nhà cung ứng"
      bg="bg.workbench"
      minW="var(--atlas-layout-zero, 0)"
      minH="var(--atlas-layout-zero, 0)"
      maxH={{
        lg: "var(--atlas-layout-master-workplane-height, calc(100dvh - 340px))",
      }}
      overflow={{ lg: "hidden" }}
      display="flex"
      flexDirection="column"
    >
      <Flex
        px="md"
        py="sm"
        justify="space-between"
        align="start"
        gap="sm"
        borderBottomWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
        flexShrink="0"
      >
        <Box>
          <Text textStyle="helper" color="fg.muted">
            Ưu tiên nhà cung ứng
          </Text>
          <Heading as="h2" textStyle="section">
            {c.selectedIngredient.ingredient_name}
          </Heading>
          <Text textStyle="helper" color="fg.muted" mt="xs">
            Hướng dẫn thứ tự lựa chọn khi mua hàng.
          </Text>
        </Box>
        <Button
          size="sm"
          variant="tertiary"
          aria-label="Đóng chi tiết"
          onClick={c.requestClose}
          minH={{
            base: "var(--atlas-layout-mobile-target, 44px)",
            lg: "compact",
          }}
        >
          Đóng
        </Button>
      </Flex>
      <Box p="md" overflowY="auto" minH="var(--atlas-layout-zero, 0)" flex="1">
        {!c.priorities.length && <Text>Chưa có nhà cung ứng ưu tiên.</Text>}
        {c.priorities.map((row, index) => {
          const selected = c.suppliers.find(
            (supplier) => supplier.supplier_id === row.supplierId,
          );
          const options = c.suppliers.filter(
            (supplier) =>
              supplier.supplier_status === "ACTIVE" ||
              supplier.supplier_id === row.supplierId,
          );
          return (
            <Box
              key={`${index}-${row.supplierId}`}
              display="grid"
              gridTemplateColumns={{
                base: "minmax(0, 1fr)",
                md: "minmax(0, 1fr) minmax(120px, 180px) auto",
              }}
              gap="sm"
              alignItems="end"
              py="sm"
              borderBottomWidth="var(--atlas-layout-edge, 1px)"
              borderColor="border.subtle"
            >
              <Field.Root
                disabled={disabled}
                invalid={
                  !row.supplierId ||
                  c.priorities.filter(
                    (item) => item.supplierId === row.supplierId,
                  ).length > 1
                }
              >
                <Field.Label>Nhà cung ứng</Field.Label>
                <NativeSelect.Root>
                  <NativeSelect.Field
                    ref={
                      index === c.priorities.length - 1
                        ? addedSupplier
                        : undefined
                    }
                    aria-label={`Nhà cung ứng ưu tiên ${index + 1}`}
                    value={row.supplierId}
                    onChange={(e) =>
                      c.setPriorities(
                        c.priorities.map((item, current) =>
                          current === index
                            ? { ...item, supplierId: e.target.value }
                            : item,
                        ),
                      )
                    }
                  >
                    <option value="">Chọn nhà cung ứng</option>
                    {options.map((option) => (
                      <option
                        value={option.supplier_id}
                        key={option.supplier_id}
                      >
                        {option.supplier_name}
                        {option.supplier_status !== "ACTIVE"
                          ? " · ngừng hợp tác"
                          : ""}
                      </option>
                    ))}
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
                {selected?.supplier_status !== "ACTIVE" && (
                  <Text color="status.warning" textStyle="helper">
                    Ngừng hợp tác
                  </Text>
                )}
              </Field.Root>
              <Field.Root disabled={disabled}>
                <Field.Label>Mức ưu tiên</Field.Label>
                <Input
                  aria-label={`Mức ưu tiên ${index + 1}`}
                  inputMode="numeric"
                  value={row.priority}
                  onChange={(e) =>
                    c.setPriorities(
                      c.priorities.map((item, current) =>
                        current === index
                          ? { ...item, priority: Number(e.target.value) }
                          : item,
                      ),
                    )
                  }
                />
              </Field.Root>
              <Button
                size="sm"
                variant="tertiary"
                disabled={disabled}
                aria-label={`Gỡ ${selected?.supplier_name ?? `nhà cung ứng ${index + 1}`}`}
                onClick={() =>
                  c.setPriorities(
                    c.priorities.filter((_, current) => current !== index),
                  )
                }
              >
                Gỡ
              </Button>
            </Box>
          );
        })}
        {c.priorityErrors.map((error) => (
          <Text
            key={error}
            role="alert"
            color="status.danger"
            textStyle="helper"
          >
            {error}
          </Text>
        ))}
      </Box>
      <Flex
        p="md"
        gap="sm"
        wrap="wrap"
        borderTopWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
        flexShrink="0"
      >
        <Button
          variant="secondary"
          disabled={
            disabled ||
            c.priorities.length >= 6 ||
            unusedActiveSuppliers.length === 0
          }
          onClick={add}
        >
          + Thêm nhà cung ứng
        </Button>
        <Button
          variant="businessPrimary"
          disabled={
            disabled || !c.prioritiesDirty || c.priorityErrors.length > 0
          }
          onClick={c.openPriorityReview}
        >
          Xem thay đổi
        </Button>
      </Flex>
    </Box>
  );
}
