import {
  AtlasSortableColumnHeader,
  atlasNarrowSortableHeader,
} from "../AtlasSortableColumnHeader";
import { Icon, Box, Button, Flex, Table, Text } from "@chakra-ui/react";
import { WarningCircle } from "@phosphor-icons/react";
import {
  allocationFamilyUnitLabel,
  type AllocationFamilyRow,
} from "../bridges/procurement";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { useId, useState, type ReactNode } from "react";
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
  if (remainder > 0n)
    return `Thiếu ${quantity(remainder)} ${allocationFamilyUnitLabel(row)}`;
  if (remainder < 0n)
    return `Vượt ${quantity(-remainder)} ${allocationFamilyUnitLabel(row)}`;
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
  onSelect,
}: {
  rows: AllocationFamilyRow[];
  tools?: ReactNode;
  selectedKey: string | null;
  disabled: boolean;
  onSelect: (row: AllocationFamilyRow, trigger: HTMLButtonElement) => void;
}) {
  const multiDay = new Set(rows.map((row) => row.service_date)).size > 1;
  type SortKey =
    "date" | "ingredient" | "school" | "need" | "supplier" | "issue";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const [sortsOpen, setSortsOpen] = useState(false);
  const sortsId = useId();
  const suppliers = (row: AllocationFamilyRow) => {
    const derived = derivedDefaultAllocation(row);
    return row.splits.length
      ? row.splits.map((split) => split.supplier_name).join(", ")
      : (derived?.supplier.supplier_name ?? "");
  };
  const comparators = {
    ingredient: (left, right) =>
      compareAtlasText(left.ingredient_name, right.ingredient_name),
    date: (left, right) => left.service_date.localeCompare(right.service_date),
    school: (left, right) =>
      compareAtlasText(
        allocationRecipient(left).primary,
        allocationRecipient(right).primary,
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
  const sortedRows =
    sort.direction === "default" || sort.key === null
      ? [...rows].sort(
          (left, right) =>
            compareAllocationRecipients(left, right) ||
            comparators.date(left, right) ||
            comparators.ingredient(left, right),
        )
      : [...rows].sort(
          (left, right) =>
            comparators[sort.key!](left, right) *
              (sort.direction === "ascending" ? 1 : -1) ||
            comparators.date(left, right),
        );
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      {tools && (
        <Flex
          px="md"
          py="sm"
          gap="sm"
          align="center"
          wrap="wrap"
          bg="bg.toolbar"
          borderBottomWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.subtle"
        >
          {tools}
        </Flex>
      )}
      <Button
        display={{ base: "inline-flex", md: "none" }}
        variant="secondary"
        size="sm"
        mx="sm"
        my="xs"
        minH="var(--atlas-layout-mobile-target, 44px)"
        aria-expanded={sortsOpen}
        aria-controls={sortsId}
        onClick={() => setSortsOpen((open) => !open)}
      >
        Sắp xếp
      </Button>
      <AtlasTableViewport
        label="Bảng phân bổ nhà cung ứng"
        maxH={{
          base: "var(--atlas-layout-table-mobile-height, 50dvh)",
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
                gridTemplateAreas:
                  '"date date" "recipient recipient" "ingredient ingredient" "quantity issue" "supplier supplier" "action action"',
                columnGap: "var(--atlas-spacing-sm)",
                borderBottom: "1px solid var(--atlas-colors-border-subtle)",
              },
              "& td": {
                display: "block",
                minWidth: 0,
                border: "none",
                borderInlineEndWidth: 0,
              },
              "& td::after": { display: "none" },
              "& td[data-allocation-recipient-cell]": { gridArea: "recipient" },
              "& td[data-allocation-ingredient-cell]": {
                gridArea: "ingredient",
              },
              "& td[data-allocation-date-cell]": { gridArea: "date" },
              "& td[data-allocation-quantity-cell]": { gridArea: "quantity" },
              "& td[data-allocation-supplier-cell]": { gridArea: "supplier" },
              "& td[data-allocation-issue-cell]": { gridArea: "issue" },
              "& td[data-allocation-action-cell]": { gridArea: "action" },
            },
          }}
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-allocation-date-width, 110px)" />
            <Table.Column w="var(--atlas-allocation-recipient-width, 220px)" />
            <Table.Column w="var(--atlas-allocation-ingredient-width, 180px)" />
            <Table.Column w="var(--atlas-allocation-need-width, 110px)" />
            <Table.Column w="var(--atlas-allocation-supplier-width, 180px)" />
            <Table.Column w="var(--atlas-allocation-issue-width, 170px)" />
            <Table.Column w="var(--atlas-allocation-action-width, 148px)" />
          </Table.ColumnGroup>
          <Table.Header
            id={sortsId}
            display={{
              base: sortsOpen ? "table-header-group" : "none",
              md: "table-header-group",
            }}
            css={{
              ...atlasNarrowSortableHeader,
              "@media(max-width:47.99rem)": {
                ...atlasNarrowSortableHeader["@media(max-width:47.99rem)"],
                display: sortsOpen ? "block" : "none",
                overflowX: "visible",
                "& tr": {
                  display: "flex",
                  flexWrap: "wrap",
                  width: "100%",
                  minWidth: "var(--atlas-layout-zero, 0)",
                  gap: "var(--atlas-spacing-xs)",
                  padding: "var(--atlas-spacing-xs) var(--atlas-spacing-sm)",
                },
                "& th": {
                  display: "block",
                  flex: "1 1 calc(50% - var(--atlas-spacing-xs))",
                  minWidth: "var(--atlas-layout-zero, 0)",
                  padding: 0,
                  whiteSpace: "normal",
                },
                "& th[data-allocation-static-header]": { display: "none" },
                "& button": {
                  minHeight: "var(--atlas-layout-mobile-target, 44px)",
                  minWidth: "var(--atlas-layout-zero, 0)",
                  width: "100%",
                  whiteSpace: "normal",
                },
              },
            }}
          >
            <Table.Row>
              {(
                [
                  ["Ngày dùng", "date"],
                  ["Trường / điểm giao", "school"],
                  ["Nguyên liệu", "ingredient"],
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
                    data-sticky-column={key === "school" ? "" : undefined}
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
                    data-allocation-static-header=""
                    data-sticky-column={label === "Thao tác" ? "" : undefined}
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
                  <Table.Cell data-allocation-date-cell="">
                    <Text textStyle="helper" color="fg.muted" hideFrom="md">
                      Ngày dùng
                    </Text>
                    <Text
                      data-allocation-date
                      textStyle="helper"
                      color="fg.muted"
                    >
                      {row.service_date.split("-").reverse().join("/")}
                    </Text>
                  </Table.Cell>
                  <Table.Cell
                    data-allocation-recipient-cell=""
                    data-sticky-column=""
                    position={{ base: "relative", md: "sticky" }}
                    left="var(--atlas-layout-zero, 0)"
                    bg="bg.workbench"
                    zIndex="var(--atlas-layout-sticky-cell, 1)"
                    verticalAlign="top"
                    overflowWrap="anywhere"
                  >
                    <Text
                      display={{ base: "block", md: "none" }}
                      textStyle="helper"
                      color="fg.muted"
                    >
                      Trường / điểm giao
                    </Text>
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
                  <Table.Cell data-allocation-ingredient-cell="">
                    <Text
                      display={{ base: "block", md: "none" }}
                      textStyle="helper"
                      color="fg.muted"
                    >
                      Nguyên liệu
                    </Text>
                    <Text data-allocation-ingredient fontWeight="semibold">
                      {row.ingredient_name}
                    </Text>
                  </Table.Cell>
                  <Table.Cell
                    data-allocation-quantity=""
                    data-allocation-quantity-cell=""
                    gridColumn={{
                      base: "1",
                      md: "auto",
                    }}
                    textAlign={{ base: "left", md: "right" }}
                  >
                    <Text
                      display={{ base: "block", md: "none" }}
                      textStyle="helper"
                      color="fg.muted"
                      textAlign="start"
                    >
                      Nhu cầu
                    </Text>
                    <Text
                      textStyle="quantityInline"
                      whiteSpace={{ base: "normal", md: "nowrap" }}
                      overflowWrap="anywhere"
                    >
                      {quantity(need)}{" "}
                      <Box
                        as="span"
                        textStyle="unitInline"
                        data-row-secondary=""
                        color="fg.muted"
                        ml="xs"
                      >
                        {allocationFamilyUnitLabel(row)}
                      </Box>
                    </Text>
                  </Table.Cell>
                  <Table.Cell data-allocation-supplier-cell="">
                    <Text
                      display={{ base: "block", md: "none" }}
                      textStyle="helper"
                      color="fg.muted"
                    >
                      Nhà cung ứng
                    </Text>
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
                  <Table.Cell
                    data-allocation-issue-cell=""
                    gridColumn={{
                      base: "2",
                      md: "auto",
                    }}
                  >
                    <Text
                      display={{ base: "block", md: "none" }}
                      textStyle="helper"
                      color="fg.muted"
                    >
                      Tình trạng / vấn đề
                    </Text>
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
                          <Icon asChild aria-hidden="true" mr="xs">
                            <WarningCircle />
                          </Icon>
                        </Box>
                      )}
                      {issue}
                    </Text>
                  </Table.Cell>
                  <Table.Cell
                    data-allocation-action-cell=""
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
                      aria-label={`${action} ${row.ingredient_name} · ${recipient.primary}${recipient.secondary ? ` · ${recipient.secondary}` : ""}${multiDay ? ` · ${row.service_date.split("-").reverse().join("/")}` : ""}`}
                      aria-haspopup="dialog"
                      aria-expanded={selectedKey === key}
                      disabled={disabled || Boolean(selectedKey)}
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
