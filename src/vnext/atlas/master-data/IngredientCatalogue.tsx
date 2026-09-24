import { Badge, Box, Button, Table, Text } from "@chakra-ui/react";
import type { IngredientMasterData } from "../bridges/ingredientSupplierMasterData";
import { formatVietnameseDecimal } from "./ingredientSupplierModel";
import { AtlasTableViewport } from "../AtlasTableViewport";

const status = {
  ACTIVE: { label: "Đang dùng", variant: "success" as const },
  INACTIVE: { label: "Ngừng dùng", variant: "warning" as const },
  ARCHIVED: { label: "Lưu trữ", variant: "neutral" as const },
};

export function IngredientCatalogue({
  ingredients,
  totalCount,
  selectedId,
  onSelect,
}: {
  ingredients: IngredientMasterData[];
  totalCount: number;
  selectedId?: string;
  onSelect: (id: string) => void;
}) {
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      <Text px="md" py="xs" textStyle="helper" color="fg.muted">
        {ingredients.length === totalCount
          ? `${ingredients.length} nguyên liệu`
          : `${ingredients.length} / ${totalCount} nguyên liệu`}
      </Text>
      <AtlasTableViewport
        label="Danh mục nguyên liệu"
        maxH="var(--atlas-layout-catalog-height, calc(100dvh - 340px))"
      >
        {!ingredients.length ? (
          <Text p="md">Không có nguyên liệu phù hợp bộ lọc.</Text>
        ) : (
          <Table.Root
            aria-label="Danh mục nguyên liệu"
            minW="var(--atlas-layout-ingredient-table-min, 940px)"
            stickyHeader
          >
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeader
                  position={{ base: "sticky", md: "static" }}
                  left="var(--atlas-layout-zero, 0)"
                  zIndex="var(--atlas-layout-sticky-header-z, 3)"
                  bg="bg.toolbar"
                >
                  Nguyên liệu
                </Table.ColumnHeader>
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
                    (priority) =>
                      `${priority.priority} ${priority.supplier_name}`,
                  )
                  .join(" · ");
                return (
                  <Table.Row key={item.ingredient_id} aria-selected={chosen}>
                    <Table.Cell
                      position={{ base: "sticky", md: "static" }}
                      left="var(--atlas-layout-zero, 0)"
                      zIndex="var(--atlas-layout-sticky-cell-z, 1)"
                      bg={chosen ? "bg.selected" : "bg.workbench"}
                    >
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
                      <Text
                        data-row-secondary
                        textStyle="helper"
                        color="fg.muted"
                      >
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
                      {priorities.length > 2
                        ? ` · +${priorities.length - 2}`
                        : ""}
                    </Table.Cell>
                    <Table.Cell>
                      <Button
                        size="sm"
                        variant="tertiary"
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
        )}
      </AtlasTableViewport>
    </Box>
  );
}
