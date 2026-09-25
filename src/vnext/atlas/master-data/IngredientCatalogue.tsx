import { Box, Button, Table, Text } from "@chakra-ui/react";
import type { CSSProperties } from "react";
import type { IngredientMasterData } from "../bridges/ingredientSupplierMasterData";
import { formatVietnameseDecimal } from "./ingredientSupplierModel";
import { AtlasTableViewport } from "../AtlasTableViewport";

const status = {
  ACTIVE: { label: "Đang dùng", color: "fg.muted" },
  INACTIVE: { label: "Ngừng dùng", color: "status.warning" },
  ARCHIVED: { label: "Lưu trữ", color: "fg.muted" },
} as const;

export function IngredientCatalogue({
  ingredients,
  totalCount,
  countUnavailable = false,
  selectedId,
  onSelect,
}: {
  ingredients: IngredientMasterData[];
  totalCount: number;
  countUnavailable?: boolean;
  selectedId?: string;
  onSelect: (id: string, trigger: HTMLButtonElement) => void;
}) {
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      {!countUnavailable && (
        <Text px="md" py="xs" textStyle="helper" color="fg.muted">
          {ingredients.length === totalCount
            ? `${ingredients.length} nguyên liệu`
            : `${ingredients.length} / ${totalCount} nguyên liệu`}
        </Text>
      )}
      <AtlasTableViewport
        label="Danh mục nguyên liệu"
        maxH="var(--atlas-layout-catalog-height, calc(100dvh - 340px))"
      >
        {!ingredients.length && !countUnavailable ? (
          <Text p="md">Không có nguyên liệu phù hợp bộ lọc.</Text>
        ) : ingredients.length ? (
          <Table.Root
            aria-label="Danh mục nguyên liệu"
            style={
              {
                "--atlas-table-header-height": "38px",
                "--atlas-table-row-height": "42px",
                "--atlas-table-identity-width": "178px",
              } as CSSProperties
            }
            minW="var(--atlas-layout-ingredient-table-min, 940px)"
            stickyHeader
          >
            <Table.Header>
              <Table.Row h="var(--atlas-table-header-height)">
                <Table.ColumnHeader
                  position={{ base: "sticky", lg: "static" }}
                  left="var(--atlas-layout-zero, 0)"
                  zIndex="var(--atlas-layout-sticky-header-z, 3)"
                  bg="bg.toolbar"
                  minW="var(--atlas-table-identity-width)"
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
                  <Table.Row
                    key={item.ingredient_id}
                    aria-selected={chosen}
                    h="var(--atlas-table-row-height)"
                  >
                    <Table.Cell
                      position={{ base: "sticky", lg: "static" }}
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
                      <Text
                        data-row-secondary=""
                        color={status[item.ingredient_status].color}
                      >
                        {status[item.ingredient_status].label}
                      </Text>
                    </Table.Cell>
                    <Table.Cell>
                      <Text data-row-secondary="" color="fg.muted">
                        {item.purchase_unit_name ?? "—"}
                      </Text>
                    </Table.Cell>
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
                      <Text data-row-secondary="" color="fg.muted">
                        {preview || "Chưa có"}
                        {priorities.length > 2
                          ? ` · +${priorities.length - 2}`
                          : ""}
                      </Text>
                    </Table.Cell>
                    <Table.Cell>
                      <Button
                        size="sm"
                        variant="tertiary"
                        onClick={(event) =>
                          onSelect(item.ingredient_id, event.currentTarget)
                        }
                        aria-label={`${item.ingredient_status === "ARCHIVED" ? "Xem" : "Xem / sửa"} ${item.ingredient_name}`}
                        aria-expanded={chosen}
                        minH={{
                          base: "var(--atlas-layout-mobile-target, 44px)",
                          lg: "compact",
                        }}
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
        ) : null}
      </AtlasTableViewport>
    </Box>
  );
}
