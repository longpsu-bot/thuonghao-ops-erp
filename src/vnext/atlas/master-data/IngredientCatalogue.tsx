import { Box, Button, Table, Text } from "@chakra-ui/react";
import { Fragment, useState, type CSSProperties } from "react";
import type { IngredientMasterData } from "../bridges/ingredientSupplierMasterData";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import { AtlasTableViewport } from "../AtlasTableViewport";
import {
  atlasDefaultSort,
  compareAtlasText,
  nextAtlasSort,
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
}: {
  ingredients: IngredientMasterData[];
  totalCount: number;
  countUnavailable?: boolean;
  selectedId?: string;
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
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
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
                "--atlas-table-identity-width": "220px",
              } as CSSProperties
            }
            minW="var(--atlas-layout-ingredient-table-min, 1050px)"
            w="var(--atlas-layout-ingredient-table-width, 1050px)"
            tableLayout="fixed"
            stickyHeader
          >
            <Table.ColumnGroup>
              <Table.Column w="var(--atlas-ingredient-identity-width, 220px)" />
              <Table.Column w="var(--atlas-ingredient-state-width, 110px)" />
              <Table.Column w="var(--atlas-ingredient-unit-width, 110px)" />
              <Table.Column w="var(--atlas-ingredient-type-width, 200px)" />
              <Table.Column w="var(--atlas-ingredient-rounding-width, 100px)" />
              <Table.Column w="var(--atlas-ingredient-supplier-width, 200px)" />
              <Table.Column w="var(--atlas-ingredient-action-width, 110px)" />
            </Table.ColumnGroup>
            <Table.Header>
              <Table.Row
                h="var(--atlas-table-header-height)"
                zIndex="var(--atlas-layout-sticky-header-z, 3)"
              >
                <AtlasSortableColumnHeader
                  label="Nguyên liệu"
                  columnKey="ingredient"
                  sort={sort}
                  onSort={onSort}
                  position={{ base: "sticky", lg: "static" }}
                  left={{
                    base: "var(--atlas-layout-zero, 0)",
                    lg: "var(--atlas-layout-auto, auto)",
                  }}
                  zIndex="var(--atlas-layout-sticky-identity-header-z, 5)"
                  bg="bg.toolbar"
                  minW="var(--atlas-table-identity-width)"
                />
                <AtlasSortableColumnHeader
                  label="Trạng thái"
                  columnKey="status"
                  sort={sort}
                  onSort={onSort}
                />
                <AtlasSortableColumnHeader
                  label="Đơn vị mua"
                  columnKey="unit"
                  sort={sort}
                  onSort={onSort}
                />
                <AtlasSortableColumnHeader
                  label="Loại / nhóm đặt hàng"
                  columnKey="type"
                  sort={sort}
                  onSort={onSort}
                />
                <Table.ColumnHeader textAlign="right">
                  Mức làm tròn
                </Table.ColumnHeader>
                <AtlasSortableColumnHeader
                  label="Ưu tiên NCC"
                  columnKey="supplier"
                  sort={sort}
                  onSort={onSort}
                />
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
                  <Table.Row
                    key={item.ingredient_id}
                    aria-selected={chosen}
                    h="var(--atlas-table-row-height)"
                  >
                    <Table.Cell
                      position={{ base: "sticky", lg: "static" }}
                      left="var(--atlas-layout-zero, 0)"
                      zIndex="var(--atlas-layout-sticky-cell-z, 1)"
                      style={{ background: "inherit" }}
                    >
                      {chosen && (
                        <Box data-selection-indicator aria-hidden="true" />
                      )}
                      <Text fontWeight="semibold">{item.ingredient_name}</Text>
                    </Table.Cell>
                    <Table.Cell>
                      <Text
                        data-row-secondary={
                          item.ingredient_status === "INACTIVE" ? undefined : ""
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
                      <Text textStyle="quantityInline">
                        {item.order_step === null
                          ? "—"
                          : formatVietnameseDecimal(item.order_step)}
                      </Text>
                    </Table.Cell>
                    <Table.Cell>
                      <Text data-row-secondary="" color="fg.muted">
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
                    </Table.Cell>
                    <Table.Cell>
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
