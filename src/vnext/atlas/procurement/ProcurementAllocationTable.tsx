import { Box, Button, Table, Text } from "@chakra-ui/react";
import type { AllocationFamilyRow } from "../bridges/procurement";
import { AtlasTableViewport } from "../AtlasTableViewport";
import type { CSSProperties } from "react";
import {
  formatExactQuantityForOperator as quantity,
  parseExactQuantity,
  sumExactQuantities,
} from "./procurementExactQuantity";

const labels: Record<AllocationFamilyRow["state"], string> = {
  UNALLOCATED: "Chưa phân bổ",
  BALANCED: "Đã đủ",
  STALE_REBALANCE_AVAILABLE: "Cần cập nhật",
  NEEDS_REALLOCATION: "Cần phân bổ lại",
  BLOCKED: "Bị chặn",
};
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
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      <AtlasTableViewport
        label="Bảng phân bổ nhà cung ứng"
        maxH={{
          base: "var(--atlas-layout-table-mobile-height, 50dvh)",
          lg: "var(--atlas-layout-natural-height, none)",
        }}
      >
        <Table.Root
          aria-label="Phân bổ nhà cung ứng"
          style={
            {
              "--atlas-table-header-height": "38px",
              "--atlas-table-row-height": "42px",
              "--atlas-table-identity-width": "178px",
            } as CSSProperties
          }
          minW="var(--atlas-layout-procurement-table-min, 980px)"
          size="sm"
          stickyHeader
        >
          <Table.Header>
            <Table.Row h="var(--atlas-table-header-height)">
              {[
                "Nguyên liệu",
                "Trường / điểm giao",
                "Nhu cầu đã xác nhận",
                "Đã phân bổ",
                "Còn lại",
                "Nhà cung ứng",
                "Trạng thái",
                "Thao tác",
              ].map((label, index) => (
                <Table.ColumnHeader
                  key={label}
                  textAlign={index >= 2 && index <= 4 ? "end" : "start"}
                  position={
                    index === 0 ? { base: "sticky", lg: "static" } : undefined
                  }
                  left={index === 0 ? "var(--atlas-layout-zero, 0)" : undefined}
                  zIndex={
                    index === 0
                      ? "var(--atlas-layout-sticky-header-z, 3)"
                      : undefined
                  }
                  bg={index === 0 ? "bg.toolbar" : undefined}
                  h="var(--atlas-table-header-height)"
                  py="var(--atlas-layout-zero, 0)"
                >
                  {label}
                </Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {rows.map((row) => {
              const key = row.family.source_fingerprint;
              const total = sumExactQuantities(
                row.splits.map((split) => split.allocated_quantity),
              );
              const need =
                row.complete === false || row.family_quantity === null
                  ? null
                  : parseExactQuantity(row.family_quantity);
              const rest =
                total === null || need === null ? null : need - total;
              const attention = !["UNALLOCATED", "BALANCED"].includes(
                row.state,
              );
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
                    position={{ base: "sticky", lg: "relative" }}
                    left="var(--atlas-layout-zero, 0)"
                    zIndex="var(--atlas-layout-sticky-cell-z, 1)"
                    bg={selectedKey === key ? "bg.selected" : "bg.workbench"}
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
                    {row.schools
                      ?.map((school) => school.school_name)
                      .join(", ") ||
                      row.school_name ||
                      row.location_name}
                    <Text
                      data-row-secondary=""
                      textStyle="helper"
                      color="fg.muted"
                    >
                      {row.location_name}
                    </Text>
                  </Table.Cell>
                  {[need, total, rest].map((value, index) => (
                    <Table.Cell
                      key={index}
                      textAlign="end"
                      whiteSpace="nowrap"
                      fontVariantNumeric="tabular-nums"
                    >
                      {quantity(value)}{" "}
                      <Box
                        as="span"
                        data-row-secondary=""
                        textStyle="helper"
                        color="fg.muted"
                      >
                        {row.unit_code}
                      </Box>
                    </Table.Cell>
                  ))}
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
                      data-row-secondary={attention ? undefined : ""}
                    >
                      {attention && (
                        <Box as="span" aria-hidden="true">
                          ⚠{" "}
                        </Box>
                      )}
                      {labels[row.state]}
                    </Text>
                  </Table.Cell>
                  <Table.Cell>
                    <Button
                      variant="tertiary"
                      size="sm"
                      aria-label={`${action} ${row.ingredient_name} · ${row.schools?.map((school) => school.school_name).join(", ") || row.school_name || row.location_name}`}
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
