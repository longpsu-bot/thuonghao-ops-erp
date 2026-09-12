import {
  Badge,
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
import { catalogueOptionsForIngredient } from "./ingredientSupplierModel";

const label = {
  ACTIVE: "Đang dùng",
  INACTIVE: "Ngừng dùng",
  ARCHIVED: "Lưu trữ",
} as const;

export function IngredientDetail({
  c,
}: {
  c: IngredientSupplierWorkbenchController;
}) {
  const panel = useRef<HTMLElement>(null);
  useEffect(() => {
    if (c.activeSurface?.kind === "ingredient") panel.current?.focus();
  }, [c.activeSurface]);
  if (c.activeSurface?.kind !== "ingredient") return null;
  const creating = c.activeSurface.id === "NEW";
  const item = c.selectedIngredient;
  const archived = item?.ingredient_status === "ARCHIVED";
  const units = catalogueOptionsForIngredient(
    preserveCurrentCatalogueValue(
      c.units.map((unit) => ({
        id: unit.unit_id,
        name: unit.unit_name,
        status: unit.unit_status,
      })),
      item?.purchase_unit_id,
      item?.purchase_unit_name,
    ),
    item?.purchase_unit_id ?? null,
  );
  const types = catalogueOptionsForIngredient(
    preserveCurrentCatalogueValue(
      c.ingredientTypes.map((type) => ({
        id: type.ingredient_type_id,
        name: type.ingredient_type_name,
        status: type.ingredient_type_status,
      })),
      item?.ingredient_type_id,
      item?.ingredient_type_name,
    ),
    item?.ingredient_type_id ?? null,
  );
  const groups = catalogueOptionsForIngredient(
    preserveCurrentCatalogueValue(
      c.ingredientOrderGroups.map((group) => ({
        id: group.ingredient_order_group_id,
        name: group.ingredient_order_group_name,
        status: group.ingredient_order_group_status,
      })),
      item?.ingredient_order_group_id,
      item?.ingredient_order_group_name,
    ),
    item?.ingredient_order_group_id ?? null,
  );
  return (
    <Box
      as="aside"
      ref={panel}
      tabIndex={-1}
      aria-label="Chi tiết nguyên liệu"
      bg="bg.subtle"
      borderLeftWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      display="flex"
      flexDirection="column"
    >
      <Flex p="md" justify="space-between" gap="sm" align="start">
        <Box>
          <Text textStyle="helper" color="fg.muted">
            Nguyên liệu
          </Text>
          <Heading as="h2" textStyle="section">
            {creating ? "Tạo nguyên liệu" : item?.ingredient_name}
          </Heading>
          {item && (
            <Badge
              mt="xs"
              variant={
                item.ingredient_status === "ACTIVE"
                  ? "success"
                  : item.ingredient_status === "INACTIVE"
                    ? "warning"
                    : "neutral"
              }
            >
              {label[item.ingredient_status]}
            </Badge>
          )}
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
      {archived ? (
        <Box p="md">
          <Text>Nguyên liệu đã lưu trữ chỉ có thể xem.</Text>
          <Fact label="Đơn vị mua" value={item?.purchase_unit_name} />
          <Fact label="Loại nguyên liệu" value={item?.ingredient_type_name} />
          <Fact
            label="Nhóm đặt hàng"
            value={item?.ingredient_order_group_name}
          />
          <Fact
            label="Mức làm tròn"
            value={
              item?.order_step === null ? undefined : String(item?.order_step)
            }
          />
        </Box>
      ) : (
        <>
          <Box px="md" pb="md" display="grid" gap="sm">
            <Field.Root
              required
              invalid={c.ingredientDraft.ingredientName.trim() === ""}
            >
              <Field.Label>Tên nguyên liệu</Field.Label>
              <Input
                required
                aria-invalid={c.ingredientDraft.ingredientName.trim() === ""}
                value={c.ingredientDraft.ingredientName}
                onChange={(e) =>
                  c.setIngredientField("ingredientName", e.target.value)
                }
              />
            </Field.Root>
            <SelectField
              label="Đơn vị mua"
              value={c.ingredientDraft.purchaseUnitId}
              options={units}
              onChange={(value) =>
                c.setIngredientField("purchaseUnitId", value)
              }
            />
            <SelectField
              label="Loại nguyên liệu"
              value={c.ingredientDraft.ingredientTypeId}
              options={types}
              onChange={(value) =>
                c.setIngredientField("ingredientTypeId", value)
              }
            />
            <SelectField
              label="Nhóm đặt hàng"
              value={c.ingredientDraft.ingredientOrderGroupId}
              options={groups}
              onChange={(value) =>
                c.setIngredientField("ingredientOrderGroupId", value)
              }
            />
            <Field.Root
              required
              invalid={c.ingredientDraft.orderStep !== "" && !c.ingredientValid}
            >
              <Field.Label>Mức làm tròn khi đặt hàng</Field.Label>
              <Input
                required
                inputMode="decimal"
                aria-invalid={
                  c.ingredientDraft.orderStep !== "" && !c.ingredientValid
                }
                value={c.ingredientDraft.orderStep}
                onChange={(e) =>
                  c.setIngredientField("orderStep", e.target.value)
                }
              />
              <Field.HelperText>
                Nhập số dương, ví dụ 0,5 hoặc 1.
              </Field.HelperText>
            </Field.Root>
          </Box>
          <Flex mt="var(--atlas-layout-auto, auto)" p="md" gap="sm" wrap="wrap">
            <Button
              variant="businessPrimary"
              disabled={
                !c.ingredientDirty || !c.ingredientValid || Boolean(c.lock)
              }
              onClick={c.openIngredientReview}
            >
              Xem thay đổi
            </Button>
            {item?.ingredient_status === "ACTIVE" && (
              <>
                <Button onClick={() => c.requestPriorities(item.ingredient_id)}>
                  Ưu tiên NCC
                </Button>
                <Button
                  variant="destructive"
                  onClick={() =>
                    c.requestLifecycle(item.ingredient_id, "INACTIVE")
                  }
                >
                  Ngừng dùng
                </Button>
              </>
            )}
            {item?.ingredient_status === "INACTIVE" && (
              <>
                <Button
                  onClick={() =>
                    c.requestLifecycle(item.ingredient_id, "ACTIVE")
                  }
                >
                  Kích hoạt
                </Button>
                <Button
                  variant="destructive"
                  onClick={() =>
                    c.requestLifecycle(item.ingredient_id, "ARCHIVED")
                  }
                >
                  Lưu trữ
                </Button>
              </>
            )}
          </Flex>
        </>
      )}
    </Box>
  );
}

function SelectField({
  label: fieldLabel,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: { id: string; name: string; currentInactive: boolean }[];
  onChange: (value: string) => void;
}) {
  return (
    <Field.Root required invalid={!value}>
      <Field.Label>{fieldLabel}</Field.Label>
      <NativeSelect.Root>
        <NativeSelect.Field
          aria-label={fieldLabel}
          aria-required="true"
          aria-invalid={!value}
          value={value}
          onChange={(e) => onChange(e.target.value)}
        >
          <option value="">Chọn</option>
          {options.map((option) => (
            <option key={option.id} value={option.id}>
              {option.name}
              {option.currentInactive ? " · ngừng dùng" : ""}
            </option>
          ))}
        </NativeSelect.Field>
        <NativeSelect.Indicator />
      </NativeSelect.Root>
    </Field.Root>
  );
}
function Fact({
  label: factLabel,
  value,
}: {
  label: string;
  value?: string | null;
}) {
  return (
    <Box mt="md">
      <Text textStyle="label">{factLabel}</Text>
      <Text>{value || "—"}</Text>
    </Box>
  );
}

function preserveCurrentCatalogueValue<
  T extends { id: string; name: string; status: "ACTIVE" | "INACTIVE" },
>(items: T[], currentId?: string | null, currentName?: string | null) {
  if (!currentId || !currentName || items.some((item) => item.id === currentId))
    return items;
  return [
    ...items,
    { id: currentId, name: currentName, status: "INACTIVE" } as T,
  ];
}
