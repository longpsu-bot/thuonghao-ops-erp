import { Badge, Box, Button, Table, Text } from "@chakra-ui/react";
import type { IngredientMasterData } from "../bridges/ingredientSupplierMasterData";
import { formatVietnameseDecimal } from "./ingredientSupplierModel";

const status = {
  ACTIVE: { label: "Đang dùng", variant: "success" as const },
  INACTIVE: { label: "Ngừng dùng", variant: "warning" as const },
  ARCHIVED: { label: "Lưu trữ", variant: "neutral" as const },
};

export function IngredientCatalogue({
  ingredients,
  selectedId,
  onSelect,
}: {
  ingredients: IngredientMasterData[];
  selectedId?: string;
  onSelect: (id: string) => void;
}) {
  if (!ingredients.length)
    return <Text p="md">Không có nguyên liệu phù hợp bộ lọc.</Text>;
  return (
    <Box
      overflow="auto"
      maxH="var(--atlas-layout-catalog-height, calc(100dvh - 310px))"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Table.Root
        aria-label="Danh mục nguyên liệu"
        minW="var(--atlas-layout-ingredient-table-min, 880px)"
        stickyHeader
      >
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeader>Nguyên liệu</Table.ColumnHeader>
            <Table.ColumnHeader>Trạng thái</Table.ColumnHeader>
            <Table.ColumnHeader>Đơn vị mua</Table.ColumnHeader>
            <Table.ColumnHeader>Loại / nhóm đặt hàng</Table.ColumnHeader>
            <Table.ColumnHeader textAlign="right">
              Mức làm tròn
            </Table.ColumnHeader>
            <Table.ColumnHeader>Ưu tiên NCC</Table.ColumnHeader>
            <Table.ColumnHeader>Thao tác</Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {ingredients.map((item) => {
            const chosen = item.ingredient_id === selectedId;
            const priorities = [...item.supplier_priorities].sort(
              (a, b) => a.priority - b.priority,
            );
            const preview = priorities
              .slice(0, 2)
              .map(
                (priority) => `${priority.priority} ${priority.supplier_name}`,
              )
              .join(" · ");
            return (
              <Table.Row key={item.ingredient_id} aria-selected={chosen}>
                <Table.Cell position="relative">
                  {chosen && (
                    <Box data-selection-indicator aria-hidden="true" />
                  )}
                  <Text fontWeight="semibold">{item.ingredient_name}</Text>
                </Table.Cell>
                <Table.Cell>
                  <Badge variant={status[item.ingredient_status].variant}>
                    {status[item.ingredient_status].label}
                  </Badge>
                </Table.Cell>
                <Table.Cell>{item.purchase_unit_name ?? "—"}</Table.Cell>
                <Table.Cell>
                  <Text>{item.ingredient_type_name ?? "—"}</Text>
                  <Text data-row-secondary textStyle="helper" color="fg.muted">
                    {item.ingredient_order_group_name ?? "—"}
                  </Text>
                </Table.Cell>
                <Table.Cell textAlign="right">
                  {item.order_step === null
                    ? "—"
                    : formatVietnameseDecimal(item.order_step)}
                </Table.Cell>
                <Table.Cell>
                  {preview || "Chưa có"}
                  {priorities.length > 2 ? ` · +${priorities.length - 2}` : ""}
                </Table.Cell>
                <Table.Cell>
                  <Button
                    size="sm"
                    variant="utility"
                    onClick={() => onSelect(item.ingredient_id)}
                    aria-label={`${item.ingredient_status === "ARCHIVED" ? "Xem" : "Xem / sửa"} ${item.ingredient_name}`}
                  >
                    {item.ingredient_status === "ARCHIVED"
                      ? "Xem"
                      : "Xem / sửa"}
                  </Button>
                </Table.Cell>
              </Table.Row>
            );
          })}
        </Table.Body>
      </Table.Root>
    </Box>
  );
}
