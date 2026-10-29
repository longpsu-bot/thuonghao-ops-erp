import {
  AtlasSortableColumnHeader,
  atlasNarrowSortableHeader,
} from "../AtlasSortableColumnHeader";
import { Box, Button, Flex, Table, Text } from "@chakra-ui/react";
import { Fragment, useState } from "react";
import type { IngredientMasterData } from "../bridges/ingredientSupplierMasterData";
import { AtlasTableViewport } from "../AtlasTableViewport";
import {
  atlasDefaultSort,
  nextAtlasSort,
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
  countUnavailable = false,
  selectedId,
  onSelect,
  detailOpen,
}: {
  ingredients: IngredientMasterData[];
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
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <Box
      data-testid="ingredient-catalogue"
      data-selected-presentation={detailOpen ? "identity-rail" : undefined}
      display="block"
      css={
        detailOpen
          ? { "@media(max-width: 61.99rem)": { display: "none" } }
          : undefined
      }
      minW="var(--atlas-layout-zero, 0)"
    >
      <AtlasTableViewport
        label="Danh mục nguyên liệu"
        maxH={{
          base: "var(--atlas-ingredient-list-height, 60dvh)",
          lg: "var(--atlas-layout-catalog-height, calc(100dvh - 340px))",
        }}
      >
        {!ingredients.length && !countUnavailable ? (
          <Text p="md">Không có nguyên liệu phù hợp bộ lọc.</Text>
        ) : ingredients.length ? (
          <Table.Root
            aria-label="Danh mục nguyên liệu"
            minW={{
              base: "var(--atlas-layout-zero, 0)",
              md: detailOpen
                ? "var(--atlas-layout-zero, 0)"
                : "var(--atlas-ingredient-table-width, 900px)",
            }}
            w="full"
            tableLayout="fixed"
            stickyHeader
            size="sm"
            css={{
              "& th, & td": {
                paddingBlock: "var(--atlas-spacing-xs)",
                verticalAlign: "middle",
              },
              "@media(max-width: 47.99rem)": {
                "& colgroup": { display: "none" },
                "& tbody": { display: "block" },
                "& tbody tr": {
                  display: "grid",
                  gridTemplateColumns: "minmax(0, 1fr) minmax(0, 1fr)",
                  borderBottom: "1px solid var(--atlas-colors-border-subtle)",
                },
                "& td": { display: "block", minWidth: 0, border: "none" },
                "& td:first-of-type": { gridColumn: "1 / -1" },
              },
            }}
          >
            <Table.ColumnGroup>
              <Table.Column
                w={
                  detailOpen
                    ? "var(--atlas-master-rail-name-width, 48%)"
                    : "var(--atlas-ingredient-name-width, 22%)"
                }
              />
              <Table.Column
                w={
                  detailOpen
                    ? "var(--atlas-master-rail-status-width, 26%)"
                    : "var(--atlas-ingredient-status-width, 13%)"
                }
              />
              <Table.Column
                display={{ lg: detailOpen ? "none" : "table-column" }}
                w="var(--atlas-ingredient-unit-width, 10%)"
              />
              <Table.Column
                display={{ lg: detailOpen ? "none" : "table-column" }}
                w="var(--atlas-ingredient-type-width, 17%)"
              />
              <Table.Column
                display={{ lg: detailOpen ? "none" : "table-column" }}
                w="var(--atlas-ingredient-step-width, 10%)"
              />
              <Table.Column
                display={{ lg: detailOpen ? "none" : "table-column" }}
                w="var(--atlas-ingredient-supplier-width, 18%)"
              />
              <Table.Column
                w={
                  detailOpen
                    ? "var(--atlas-master-rail-action-width, 26%)"
                    : "var(--atlas-ingredient-action-width, 10%)"
                }
              />
            </Table.ColumnGroup>
            <Table.Header css={atlasNarrowSortableHeader}>
              <Table.Row>
                {(
                  [
                    ["Nguyên liệu", "ingredient"],
                    ["Trạng thái", "status"],
                    ["Đơn vị mua", "unit"],
                    ["Loại / nhóm đặt hàng", "type"],
                    ["Mức làm tròn", null],
                    ["Ưu tiên NCC", "supplier"],
                    ["Thao tác", null],
                  ] as const
                ).map(([label, key]) =>
                  key ? (
                    <AtlasSortableColumnHeader
                      key={label}
                      label={label}
                      display={{
                        lg:
                          detailOpen && key !== "ingredient" && key !== "status"
                            ? "none"
                            : "table-cell",
                      }}
                      columnKey={key}
                      sort={sort}
                      onSort={onSort}
                      position={
                        key === "ingredient"
                          ? { base: "static", md: "sticky" }
                          : undefined
                      }
                      left={
                        key === "ingredient"
                          ? "var(--atlas-layout-zero, 0)"
                          : undefined
                      }
                      bg="bg.toolbar"
                    />
                  ) : (
                    <Table.ColumnHeader
                      key={label}
                      display={{
                        lg:
                          detailOpen &&
                          label !== "Thao tác" &&
                          label !== "Trạng thái"
                            ? "none"
                            : "table-cell",
                      }}
                      position={
                        label === "Thao tác"
                          ? { base: "static", md: "sticky" }
                          : undefined
                      }
                      right={
                        label === "Thao tác"
                          ? "var(--atlas-layout-zero, 0)"
                          : undefined
                      }
                      bg="bg.toolbar"
                    >
                      {label}
                    </Table.ColumnHeader>
                  ),
                )}
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
                      data-sticky-column=""
                      position={{ base: "relative", md: "sticky" }}
                      left="var(--atlas-layout-zero, 0)"
                      bg="bg.workbench"
                      zIndex="var(--atlas-layout-sticky-cell, 1)"
                      verticalAlign="top"
                      overflowWrap="anywhere"
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
                    <Table.Cell
                      display={{ lg: detailOpen ? "none" : "table-cell" }}
                    >
                      <Text data-row-secondary="" color="fg.muted">
                        <Box as="span" hideFrom="md">
                          Đơn vị mua:{" "}
                        </Box>{" "}
                        {item.purchase_unit_name ?? "—"}
                      </Text>
                    </Table.Cell>
                    <Table.Cell
                      display={{ lg: detailOpen ? "none" : "table-cell" }}
                    >
                      <Text>{item.ingredient_type_name ?? "—"}</Text>
                      <Text
                        data-row-secondary
                        textStyle="helper"
                        color="fg.muted"
                      >
                        {item.ingredient_order_group_name ?? "—"}
                      </Text>
                    </Table.Cell>
                    <Table.Cell
                      display={{ lg: detailOpen ? "none" : "table-cell" }}
                      textAlign={{ base: "left", md: "right" }}
                    >
                      <Text textStyle="quantityInline">
                        <Box as="span" hideFrom="md">
                          Mức làm tròn:{" "}
                        </Box>{" "}
                        {item.order_step === null
                          ? "—"
                          : formatVietnameseDecimal(item.order_step)}
                      </Text>
                    </Table.Cell>
                    <Table.Cell
                      display={{ lg: detailOpen ? "none" : "table-cell" }}
                    >
                      <Text data-row-secondary="" color="fg.muted">
                        <Box as="span" hideFrom="md">
                          Ưu tiên NCC:{" "}
                        </Box>{" "}
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
                    <Table.Cell
                      data-sticky-column=""
                      position={{ base: "static", md: "sticky" }}
                      right="var(--atlas-layout-zero, 0)"
                      bg="bg.workbench"
                      zIndex="var(--atlas-layout-sticky-cell, 1)"
                    >
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
                        {detailOpen || item.ingredient_status === "ARCHIVED"
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
