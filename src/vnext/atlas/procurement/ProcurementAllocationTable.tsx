import {
  AtlasSortableColumnHeader,
  atlasNarrowSortableHeader,
} from "../AtlasSortableColumnHeader";
import { Box, Button, Flex, Table, Text } from "@chakra-ui/react";
import type { AllocationFamilyRow } from "../bridges/procurement";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { useState, type ReactNode } from "react";
import {
  atlasDefaultSort,
  nextAtlasSort,
  compareAtlasBigInt,
  compareAtlasText,
  type AtlasSortState,
} from "../atlasTableSort";
import {
  formatExactQuantityForOperator as quantity,
  parseExactQuantity,
  sumExactQuantities,
} from "./procurementExactQuantity";
import {
  allocationRecipient,
  compareAllocationRecipients,
  derivedDefaultAllocation,
} from "./procurementAllocationPresentation";

function allocationIssue(row: AllocationFamilyRow, remainder: bigint | null) {
  if (row.state === "BLOCKED") return "Bị chặn";
  if (row.state === "STALE_REBALANCE_AVAILABLE") return "Cần cập nhật";
  if (derivedDefaultAllocation(row)) return "Đủ";
  if (row.state === "UNALLOCATED") return "Chưa phân bổ";
  if (row.state === "BALANCED") return "Đủ";
  if (remainder === null) return "Cần phân bổ lại";
  if (remainder > 0n) return `Thiếu ${quantity(remainder)} ${row.unit_code}`;
  if (remainder < 0n) return `Vượt ${quantity(-remainder)} ${row.unit_code}`;
  return "Cần phân bổ lại";
}

function allocationRemainder(row: AllocationFamilyRow) {
  const derived = derivedDefaultAllocation(row);
  const total = sumExactQuantities(
    row.splits.length
      ? row.splits.map((split) => split.allocated_quantity)
      : derived
        ? [derived.recommendation.allocated_quantity]
        : [],
  );
  const need =
    row.complete === false || row.family_quantity === null
      ? null
      : parseExactQuantity(row.family_quantity);
  return total === null || need === null ? null : need - total;
}
export function ProcurementAllocationTable({
  rows,
  tools,
  selectedKey,
  disabled,
  showServiceDate = new Set(rows.map((row) => row.service_date)).size > 1,
  onSelect,
}: {
  rows: AllocationFamilyRow[];
  tools?: ReactNode;
  selectedKey: string | null;
  disabled: boolean;
  showServiceDate?: boolean;
  onSelect: (row: AllocationFamilyRow, trigger: HTMLButtonElement) => void;
}) {
  type SortKey = "ingredient" | "school" | "need" | "supplier" | "issue";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const suppliers = (row: AllocationFamilyRow) => {
    const derived = derivedDefaultAllocation(row);
    return row.splits.length
      ? row.splits.map((split) => split.supplier_name).join(", ")
      : (derived?.supplier.supplier_name ?? "");
  };
  const comparators = {
    ingredient: (left, right) =>
      compareAtlasText(left.ingredient_name, right.ingredient_name),
    school: compareAllocationRecipients,
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
      compareAtlasText(suppliers(left), suppliers(right)),
    issue: (left, right) =>
      compareAtlasText(
        allocationIssue(left, allocationRemainder(left)),
        allocationIssue(right, allocationRemainder(right)),
      ),
  } satisfies Record<
    SortKey,
    (left: AllocationFamilyRow, right: AllocationFamilyRow) => number
  >;
  const byDate = (left: AllocationFamilyRow, right: AllocationFamilyRow) =>
    left.service_date.localeCompare(right.service_date);
  const sortedRows =
    sort.direction === "default" || sort.key === null
      ? [...rows].sort(
          (left, right) =>
            compareAllocationRecipients(left, right) ||
            compareAtlasText(left.ingredient_name, right.ingredient_name) ||
            byDate(left, right),
        )
      : [...rows].sort(
          (left, right) =>
            comparators[sort.key!](left, right) *
              (sort.direction === "ascending" ? 1 : -1) || byDate(left, right),
        );
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      {tools && (
        <Flex
          px="md"
          py="xs"
          gap="sm"
          align="center"
          wrap="wrap"
          justify="space-between"
          bg="bg.toolbar"
        >
          {tools}
        </Flex>
      )}
      <AtlasTableViewport
        label="Bảng phân bổ nhà cung ứng"
        maxH={{
          base: selectedKey
            ? "var(--atlas-allocation-directory-selected-height, 35dvh)"
            : "var(--atlas-layout-table-mobile-height, 50dvh)",
          lg: "var(--atlas-procurement-desktop-surface-max-height, calc(100dvh - 400px))",
        }}
      >
        <Table.Root
          aria-label="Phân bổ nhà cung ứng"
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: "var(--atlas-allocation-table-width, 1120px)",
          }}
          w="full"
          tableLayout="fixed"
          size="sm"
          stickyHeader
          css={{
            "& th, & td": {
              paddingBlock: "var(--atlas-spacing-xs)",
              verticalAlign: "middle",
            },
            "@media(max-width:47.99rem)": {
              "& colgroup": { display: "none" },
              "& tbody": { display: "block" },
              "& tbody tr": {
                display: "grid",
                gridTemplateColumns: "minmax(0, 1fr) minmax(0, 1fr)",
                borderBottom: "1px solid var(--atlas-colors-border-subtle)",
              },
              "& td": { display: "block", minWidth: 0, border: "none" },
              "& td[data-allocation-quantity]": { gridColumn: "1 / -1" },
              "& td:first-of-type, & td:nth-of-type(2)": {
                gridColumn: "1 / -1",
              },
            },
          }}
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-allocation-recipient-width, 220px)" />
            <Table.Column w="var(--atlas-allocation-ingredient-width, 180px)" />
            {showServiceDate && (
              <Table.Column w="var(--atlas-allocation-date-width, 110px)" />
            )}
            <Table.Column w="var(--atlas-allocation-need-width, 110px)" />
            <Table.Column w="var(--atlas-allocation-supplier-width, 180px)" />
            <Table.Column w="var(--atlas-allocation-issue-width, 170px)" />
            <Table.Column w="var(--atlas-allocation-action-width, 148px)" />
          </Table.ColumnGroup>
          <Table.Header css={atlasNarrowSortableHeader}>
            <Table.Row>
              {(
                [
                  ["Trường / điểm giao", "school"],
                  ["Nguyên liệu", "ingredient"],
                  ...(showServiceDate ? [["Ngày dùng", null] as const] : []),
                  ["Nhu cầu", "need"],
                  ["Nhà cung ứng", "supplier"],
                  ["Tình trạng / vấn đề", "issue"],
                  ["Thao tác", null],
                ] as const
              ).map(([label, key]) =>
                key ? (
                  <AtlasSortableColumnHeader
                    key={label}
                    label={label}
                    columnKey={key}
                    sort={sort}
                    onSort={onSort}
                    textAlign={key === "need" ? "end" : "start"}
                    position={
                      key === "school"
                        ? { base: "static", md: "sticky" }
                        : undefined
                    }
                    left={
                      key === "school"
                        ? "var(--atlas-layout-zero, 0)"
                        : undefined
                    }
                    bg="bg.toolbar"
                  />
                ) : (
                  <Table.ColumnHeader
                    key={label}
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
            {sortedRows.map((row) => {
              const key = row.family.source_fingerprint;
              const need =
                row.complete === false || row.family_quantity === null
                  ? null
                  : parseExactQuantity(row.family_quantity);
              const rest = allocationRemainder(row);
              const derived = derivedDefaultAllocation(row);
              const recipient = allocationRecipient(row);
              const attention = row.state !== "BALANCED" && !derived;
              const issue = allocationIssue(row, rest);
              const action = derived
                ? "Thay đổi"
                : row.state === "BALANCED"
                  ? "Xem phân bổ"
                  : "Phân bổ NCC";
              return (
                <Table.Row
                  key={key}
                  aria-selected={selectedKey === key}
                  data-attention={attention || undefined}
                >
                  <Table.Cell
                    data-sticky-column=""
                    position={{ base: "relative", md: "sticky" }}
                    left="var(--atlas-layout-zero, 0)"
                    bg="bg.workbench"
                    zIndex="var(--atlas-layout-sticky-cell, 1)"
                    verticalAlign="top"
                    overflowWrap="anywhere"
                  >
                    {selectedKey === key && (
                      <Box data-selection-indicator="" aria-hidden="true" />
                    )}
                    <Text data-allocation-recipient fontWeight="semibold">
                      {recipient.primary}
                    </Text>
                    {recipient.secondary && (
                      <Text
                        data-row-secondary=""
                        textStyle="helper"
                        color="fg.muted"
                      >
                        {recipient.secondary}
                      </Text>
                    )}
                  </Table.Cell>
                  <Table.Cell>
                    <Text data-allocation-ingredient fontWeight="semibold">
                      {row.ingredient_name}
                    </Text>
                  </Table.Cell>
                  {showServiceDate && (
                    <Table.Cell>
                      <Text
                        data-allocation-date
                        textStyle="helper"
                        color="fg.muted"
                      >
                        <Box as="span" hideFrom="md">
                          Ngày dùng{" "}
                        </Box>
                        {row.service_date.split("-").reverse().join("/")}
                      </Text>
                    </Table.Cell>
                  )}
                  <Table.Cell
                    data-allocation-quantity
                    textAlign={{ base: "left", md: "right" }}
                  >
                    <Text
                      textStyle="quantityInline"
                      whiteSpace={{ base: "normal", md: "nowrap" }}
                      overflowWrap="anywhere"
                    >
                      <Box as="span" hideFrom="md">
                        Nhu cầu:{" "}
                      </Box>{" "}
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
                  <Table.Cell>
                    {row.splits.length ? (
                      row.splits.map((split) => split.supplier_name).join(", ")
                    ) : derived ? (
                      <>
                        <Text fontWeight="medium">
                          {derived.supplier.supplier_name}
                        </Text>
                        <Text
                          data-row-secondary=""
                          textStyle="helper"
                          color="fg.muted"
                        >
                          Mặc định #{derived.supplier.priority}
                        </Text>
                      </>
                    ) : (
                      "—"
                    )}
                  </Table.Cell>
                  <Table.Cell>
                    <Text
                      data-allocation-issue
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
                  <Table.Cell
                    data-sticky-column=""
                    position={{ base: "static", md: "sticky" }}
                    right="var(--atlas-layout-zero, 0)"
                    bg="bg.workbench"
                    zIndex="var(--atlas-layout-sticky-cell, 1)"
                  >
                    <Button
                      variant="tableAction"
                      size="sm"
                      w="full"
                      minW="var(--atlas-layout-zero, 0)"
                      px="xs"
                      aria-label={`${action} ${row.ingredient_name} · ${recipient.primary}${recipient.secondary ? ` · ${recipient.secondary}` : ""}${showServiceDate ? ` · ${row.service_date.split("-").reverse().join("/")}` : ""}`}
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
