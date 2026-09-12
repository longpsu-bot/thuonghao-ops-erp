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
  useEffect(() => {
    if (c.activeSurface?.kind === "priorities") panel.current?.focus();
  }, [c.activeSurface]);
  if (c.activeSurface?.kind !== "priorities" || !c.selectedIngredient)
    return null;
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
      bg="bg.subtle"
      borderLeftWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      display="flex"
      flexDirection="column"
    >
      <Flex p="md" justify="space-between" align="start" gap="sm">
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
          variant="utility"
          aria-label="Đóng chi tiết"
          onClick={c.requestClose}
        >
          Đóng
        </Button>
      </Flex>
      <Box
        px="md"
        overflowY="auto"
        maxH="var(--atlas-layout-priority-height, calc(100dvh - 430px))"
      >
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
              mb="md"
              pb="md"
              borderBottomWidth="var(--atlas-layout-edge, 1px)"
              borderColor="border.subtle"
            >
              <Field.Root
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
              </Field.Root>
              {selected?.supplier_status !== "ACTIVE" && (
                <Text color="status.warning" textStyle="helper" mt="xs">
                  Ngừng hợp tác
                </Text>
              )}
              <Field.Root mt="sm">
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
                mt="sm"
                size="sm"
                variant="utility"
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
      <Flex mt="var(--atlas-layout-auto, auto)" p="md" gap="sm" wrap="wrap">
        <Button
          disabled={
            c.priorities.length >= 6 || unusedActiveSuppliers.length === 0
          }
          onClick={add}
        >
          + Thêm nhà cung ứng
        </Button>
        <Button
          variant="businessPrimary"
          disabled={
            !c.prioritiesDirty || c.priorityErrors.length > 0 || Boolean(c.lock)
          }
          onClick={c.openPriorityReview}
        >
          Xem thay đổi
        </Button>
      </Flex>
    </Box>
  );
}
