import { AtlasSortControl } from "../AtlasSortControl";
import { Box, Button, Flex, Table, Text } from "@chakra-ui/react";
import { Fragment, useState } from "react";
import type { IngredientMasterData } from "../bridges/ingredientSupplierMasterData";
import { AtlasTableViewport } from "../AtlasTableViewport";
import {
  atlasDefaultSort,
  compareAtlasText,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";
import { formatVietnameseDecimal } from "./ingredientSupplierModel";

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
  detailOpen,
}: {
  ingredients: IngredientMasterData[];
  totalCount: number;
  countUnavailable?: boolean;
  selectedId?: string;
  detailOpen?: boolean;
  onSelect: (id: string, trigger: HTMLButtonElement) => void;
}) {
  type SortKey = "ingredient" | "status" | "unit" | "type" | "supplier";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const sortedIngredients = sortAtlasRows(ingredients, sort, {
    ingredient: (left, right) =>
      compareAtlasText(left.ingredient_name, right.ingredient_name),
    status: (left, right) =>
      compareAtlasText(left.ingredient_status, right.ingredient_status),
    unit: (left, right) =>
      compareAtlasText(left.purchase_unit_name, right.purchase_unit_name),
    type: (left, right) =>
      compareAtlasText(
        `${left.ingredient_type_name ?? ""} ${left.ingredient_order_group_name ?? ""}`,
        `${right.ingredient_type_name ?? ""} ${right.ingredient_order_group_name ?? ""}`,
      ),
    supplier: (left, right) =>
      compareAtlasText(
        [...left.supplier_priorities].sort((a, b) => a.priority - b.priority)[0]
          ?.supplier_name,
        [...right.supplier_priorities].sort(
          (a, b) => a.priority - b.priority,
        )[0]?.supplier_name,
      ),
  });
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      {!countUnavailable && (
        <Text px="md" py="xs" textStyle="helper" color="fg.muted">
          {ingredients.length === totalCount
            ? `${ingredients.length} nguyên liệu`
            : `${ingredients.length} / ${totalCount} nguyên liệu`}
        </Text>
      )}
      <AtlasSortControl
        label="Sắp xếp nguyên liệu"
        axes={
          [
            ["ingredient", "Nguyên liệu"],
            ["status", "Trạng thái"],
            ["unit", "Đơn vị mua"],
            ["type", "Loại / nhóm đặt hàng"],
            ["supplier", "Ưu tiên NCC"],
          ] as const
        }
        value={sort}
        onChange={setSort}
      />
      <AtlasTableViewport
        label="Danh mục nguyên liệu"
        maxH={{
          base: detailOpen
            ? "var(--atlas-ingredient-list-selected-height, 35dvh)"
            : "var(--atlas-ingredient-list-height, 60dvh)",
          lg: "var(--atlas-layout-catalog-height, calc(100dvh - 340px))",
        }}
      >
        {!ingredients.length && !countUnavailable ? (
          <Text p="md">Không có nguyên liệu phù hợp bộ lọc.</Text>
        ) : ingredients.length ? (
          <Table.Root
            aria-label="Danh mục nguyên liệu"
            minW="var(--atlas-layout-zero, 0)"
            w="full"
            tableLayout="fixed"
            stickyHeader
          >
            <Table.ColumnGroup>
              <Table.Column />
              <Table.Column w="var(--atlas-ingredient-action-width, 96px)" />
            </Table.ColumnGroup>
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeader>
                  Nguyên liệu và thông tin mua
                </Table.ColumnHeader>
                <Table.ColumnHeader>Thao tác</Table.ColumnHeader>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {sortedIngredients.map((item) => {
                const chosen = item.ingredient_id === selectedId;
                const priorities = [...item.supplier_priorities].sort(
                  (a, b) => a.priority - b.priority,
                );
                return (
                  <Table.Row key={item.ingredient_id} aria-selected={chosen}>
                    <Table.Cell
                      position="relative"
                      verticalAlign="top"
                      overflowWrap="anywhere"
                    >
                      {chosen && (
                        <Box data-selection-indicator aria-hidden="true" />
                      )}
                      <Text fontWeight="semibold">{item.ingredient_name}</Text>
                      <Box mt="xs">
                        <Text
                          data-row-secondary={
                            item.ingredient_status === "INACTIVE"
                              ? undefined
                              : ""
                          }
                          color={status[item.ingredient_status].color}
                          fontWeight={
                            item.ingredient_status === "INACTIVE"
                              ? "semibold"
                              : "normal"
                          }
                        >
                          {status[item.ingredient_status].label}
                        </Text>
                      </Box>
                      <Box mt="xs">
                        <Text data-row-secondary="" color="fg.muted">
                          Đơn vị mua: {item.purchase_unit_name ?? "—"}
                        </Text>
                      </Box>
                      <Box mt="xs">
                        <Text>{item.ingredient_type_name ?? "—"}</Text>
                        <Text
                          data-row-secondary
                          textStyle="helper"
                          color="fg.muted"
                        >
                          {item.ingredient_order_group_name ?? "—"}
                        </Text>
                      </Box>
                      <Box mt="xs">
                        <Text textStyle="quantityInline">
                          Mức làm tròn:{" "}
                          {item.order_step === null
                            ? "—"
                            : formatVietnameseDecimal(item.order_step)}
                        </Text>
                      </Box>
                      <Box mt="xs">
                        <Text data-row-secondary="" color="fg.muted">
                          Ưu tiên NCC:{" "}
                          {priorities.length
                            ? priorities.slice(0, 2).map((priority, index) => (
                                <Fragment key={priority.supplier_id}>
                                  {index > 0 ? " · " : ""}
                                  <Box as="span" fontWeight="semibold">
                                    {priority.priority}
                                  </Box>{" "}
                                  {priority.supplier_name}
                                </Fragment>
                              ))
                            : "Chưa có"}
                          {priorities.length > 2
                            ? ` · +${priorities.length - 2}`
                            : ""}
                        </Text>
                      </Box>
                    </Table.Cell>
                    <Table.Cell verticalAlign="top">
                      <Button
                        size="sm"
                        variant="tableAction"
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
