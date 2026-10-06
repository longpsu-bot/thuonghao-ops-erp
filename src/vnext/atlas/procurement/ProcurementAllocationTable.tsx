import { Box, Button, Table, Text } from "@chakra-ui/react";
import type { AllocationFamilyRow } from "../bridges/procurement";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { useState, type CSSProperties } from "react";
import {
  atlasDefaultSort,
  compareAtlasBigInt,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";
import {
  formatExactQuantityForOperator as quantity,
  parseExactQuantity,
  sumExactQuantities,
} from "./procurementExactQuantity";

function allocationIssue(row: AllocationFamilyRow, remainder: bigint | null) {
  if (row.state === "BLOCKED") return "Bị chặn";
  if (row.state === "STALE_REBALANCE_AVAILABLE") return "Cần cập nhật";
  if (row.state === "UNALLOCATED") return "Chưa phân bổ";
  if (row.state === "BALANCED") return "Đủ";
  if (remainder === null) return "Cần phân bổ lại";
  if (remainder > 0n) return `Thiếu ${quantity(remainder)} ${row.unit_code}`;
  if (remainder < 0n) return `Vượt ${quantity(-remainder)} ${row.unit_code}`;
  return "Cần phân bổ lại";
}

function allocationRemainder(row: AllocationFamilyRow) {
  const total = sumExactQuantities(
    row.splits.map((split) => split.allocated_quantity),
  );
  const need =
    row.complete === false || row.family_quantity === null
      ? null
      : parseExactQuantity(row.family_quantity);
  return total === null || need === null ? null : need - total;
}
export function ProcurementAllocationTable({
  rows,
  selectedKey,
  disabled,
  onSelect,
}: {
  rows: AllocationFamilyRow[];
  selectedKey: string | null;
  disabled: boolean;
  onSelect: (row: AllocationFamilyRow, trigger: HTMLButtonElement) => void;
}) {
  type SortKey = "ingredient" | "school" | "need" | "supplier" | "issue";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const sortedRows = sortAtlasRows(rows, sort, {
    ingredient: (left, right) =>
      compareAtlasText(left.ingredient_name, right.ingredient_name),
    school: (left, right) =>
      compareAtlasText(
        left.schools?.map((school) => school.school_name).join(", ") ||
          left.school_name ||
          left.location_name,
        right.schools?.map((school) => school.school_name).join(", ") ||
          right.school_name ||
          right.location_name,
      ),
    need: (left, right) =>
      compareAtlasBigInt(
        left.complete === false || left.family_quantity === null
          ? null
          : parseExactQuantity(left.family_quantity),
        right.complete === false || right.family_quantity === null
          ? null
          : parseExactQuantity(right.family_quantity),
      ),
    supplier: (left, right) =>
      compareAtlasText(
        left.splits.map((split) => split.supplier_name).join(", "),
        right.splits.map((split) => split.supplier_name).join(", "),
      ),
    issue: (left, right) =>
      compareAtlasText(
        allocationIssue(left, allocationRemainder(left)),
        allocationIssue(right, allocationRemainder(right)),
      ),
  });
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      <AtlasTableViewport
        label="Bảng phân bổ nhà cung ứng"
        maxH={{
          base: "var(--atlas-layout-table-mobile-height, 50dvh)",
          lg: "var(--atlas-procurement-desktop-surface-max-height, calc(100dvh - 400px))",
        }}
      >
        <Table.Root
          aria-label="Phân bổ nhà cung ứng"
          style={
            {
              "--atlas-table-header-height": "38px",
              "--atlas-table-row-height": "46px",
              "--atlas-table-identity-width": "200px",
            } as CSSProperties
          }
          minW="var(--atlas-layout-procurement-table-min, 1050px)"
          w="var(--atlas-layout-procurement-table-width, 1050px)"
          tableLayout="fixed"
          size="sm"
          stickyHeader
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-allocation-identity-width, 200px)" />
            <Table.Column w="var(--atlas-allocation-school-width, 230px)" />
            <Table.Column w="var(--atlas-allocation-quantity-width, 130px)" />
            <Table.Column w="var(--atlas-allocation-supplier-width, 190px)" />
            <Table.Column w="var(--atlas-allocation-state-width, 170px)" />
            <Table.Column w="var(--atlas-allocation-action-width, 130px)" />
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
                position="sticky"
                left="var(--atlas-layout-zero, 0)"
                zIndex="var(--atlas-layout-sticky-identity-header-z, 5)"
                h="var(--atlas-table-header-height)"
                py="var(--atlas-layout-zero, 0)"
              />
              <AtlasSortableColumnHeader
                label="Trường / điểm giao"
                columnKey="school"
                sort={sort}
                onSort={onSort}
                h="var(--atlas-table-header-height)"
                py="var(--atlas-layout-zero, 0)"
              />
              <AtlasSortableColumnHeader
                label="Nhu cầu"
                columnKey="need"
                sort={sort}
                onSort={onSort}
                textAlign="end"
                h="var(--atlas-table-header-height)"
                py="var(--atlas-layout-zero, 0)"
              />
              <AtlasSortableColumnHeader
                label="Nhà cung ứng"
                columnKey="supplier"
                sort={sort}
                onSort={onSort}
                h="var(--atlas-table-header-height)"
                py="var(--atlas-layout-zero, 0)"
              />
              <AtlasSortableColumnHeader
                label="Tình trạng / vấn đề"
                columnKey="issue"
                sort={sort}
                onSort={onSort}
                h="var(--atlas-table-header-height)"
                py="var(--atlas-layout-zero, 0)"
              />
              <Table.ColumnHeader
                h="var(--atlas-table-header-height)"
                py="var(--atlas-layout-zero, 0)"
              >
                Thao tác
              </Table.ColumnHeader>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {sortedRows.map((row) => {
              const key = row.family.source_fingerprint;
              const need =
                row.complete === false || row.family_quantity === null
                  ? null
                  : parseExactQuantity(row.family_quantity);
              const rest = allocationRemainder(row);
              const attention = row.state !== "BALANCED";
              const issue = allocationIssue(row, rest);
              const action =
                row.state === "BALANCED" ? "Xem phân bổ" : "Phân bổ NCC";
              return (
                <Table.Row
                  key={key}
                  aria-selected={selectedKey === key}
                  data-attention={attention || undefined}
                  h="var(--atlas-table-row-height)"
                >
                  <Table.Cell
                    position="sticky"
                    left="var(--atlas-layout-zero, 0)"
                    zIndex="var(--atlas-layout-sticky-cell-z, 1)"
                    style={{ background: "inherit" }}
                    minW="var(--atlas-table-identity-width)"
                    h="var(--atlas-table-row-height)"
                    py="xs"
                  >
                    {selectedKey === key && (
                      <Box data-selection-indicator="" aria-hidden="true" />
                    )}
                    <Text fontWeight="semibold">{row.ingredient_name}</Text>
                  </Table.Cell>
                  <Table.Cell minW="var(--atlas-layout-school-cell-width, 150px)">
                    <Text fontWeight="medium">
                      {row.schools
                        ?.map((school) => school.school_name)
                        .join(", ") ||
                        row.school_name ||
                        row.location_name}
                    </Text>
                    <Text
                      data-row-secondary=""
                      textStyle="helper"
                      color="fg.muted"
                    >
                      {row.location_name}
                    </Text>
                  </Table.Cell>
                  <Table.Cell textAlign="end" whiteSpace="nowrap">
                    <Text textStyle="quantityInline">
                      {quantity(need)}{" "}
                      <Box
                        as="span"
                        textStyle="unitInline"
                        data-row-secondary=""
                        color="fg.muted"
                        ml="xs"
                      >
                        {row.unit_code}
                      </Box>
                    </Text>
                  </Table.Cell>
                  <Table.Cell minW="var(--atlas-layout-supplier-cell-width, 125px)">
                    {row.splits.length
                      ? row.splits
                          .map((split) => split.supplier_name)
                          .join(", ")
                      : "—"}
                  </Table.Cell>
                  <Table.Cell minW="var(--atlas-layout-state-cell-width, 110px)">
                    <Text
                      color={
                        row.state === "BLOCKED"
                          ? "status.danger"
                          : attention
                            ? "status.warning"
                            : "fg.muted"
                      }
                      fontWeight={attention ? "semibold" : "normal"}
                      data-row-secondary={attention ? undefined : ""}
                    >
                      {attention && (
                        <Box as="span" aria-hidden="true">
                          ⚠{" "}
                        </Box>
                      )}
                      {issue}
                    </Text>
                  </Table.Cell>
                  <Table.Cell>
                    <Button
                      variant="tableAction"
                      size="sm"
                      w="full"
                      minW="var(--atlas-layout-zero, 0)"
                      px="xs"
                      aria-label={`${action} ${row.ingredient_name} · ${row.schools?.map((school) => school.school_name).join(", ") || row.school_name || row.location_name} · ${row.location_name}`}
                      aria-expanded={selectedKey === key}
                      disabled={
                        disabled || Boolean(selectedKey && selectedKey !== key)
                      }
                      onClick={(event) => onSelect(row, event.currentTarget)}
                      minH={{
                        base: "var(--atlas-layout-mobile-target, 44px)",
                        lg: "compact",
                      }}
                    >
                      {action}
                    </Button>
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
      {!rows.length && (
        <Text p="lg" color="fg.muted">
          Không có nguyên liệu phù hợp trong phạm vi này.
        </Text>
      )}
    </Box>
  );
}
