import { Box, Button, Table, Text } from "@chakra-ui/react";
import {
  SCHOOL_FULFILMENT_STATUS_LABELS,
  type SchoolFulfilmentComparisonStatus,
  type SchoolFulfilmentRow,
} from "../bridges/schoolFulfilment";
import { formatExactQuantity, formatExactDelta } from "../formatExactQuantity";
import { fulfilmentRowKey } from "./useSchoolFulfilmentWorkbench";
export const fulfilmentDate = (value: string) =>
  value.split("-").reverse().join("/");
export function ComparisonResult({
  status,
}: {
  status: SchoolFulfilmentComparisonStatus;
}) {
  return (
    <Text
      textStyle="table"
      color={status === "OK" ? "fg.muted" : "status.warning"}
      fontWeight={status === "OK" ? "normal" : "semibold"}
    >
      {status !== "OK" && (
        <Box as="span" aria-hidden="true" mr="xs">
          △
        </Box>
      )}
      {SCHOOL_FULFILMENT_STATUS_LABELS[status]}
    </Text>
  );
}
export function SchoolFulfilmentTable({
  rows,
  selectedKey,
  onSelect,
}: {
  rows: SchoolFulfilmentRow[];
  selectedKey: string | null;
  onSelect: (row: SchoolFulfilmentRow, trigger: HTMLButtonElement) => void;
}) {
  return (
    <Table.ScrollArea
      overflow="auto"
      minW="var(--atlas-layout-zero, 0)"
      maxH={{
        base: "var(--atlas-layout-mobile-table, 50dvh)",
        lg: "var(--atlas-layout-reconciliation-table, calc(100dvh - 300px))",
      }}
    >
      <Table.Root
        whiteSpace="normal"
        aria-label="Đối chiếu theo trường"
        size="sm"
        stickyHeader
        minW="var(--atlas-layout-reconciliation-table-min, 740px)"
      >
        <Table.Header>
          <Table.Row>
            {[
              "Ngày",
              "Trường / điểm giao",
              "Đối chiếu",
              "PO / PXK",
              "Số lượng",
              "Thao tác",
            ].map((t) => (
              <Table.ColumnHeader key={t}>{t}</Table.ColumnHeader>
            ))}
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {rows.map((row) => (
            <Table.Row
              key={fulfilmentRowKey(row)}
              aria-selected={selectedKey === fulfilmentRowKey(row)}
            >
              <Table.Cell position="relative" whiteSpace="nowrap">
                {selectedKey === fulfilmentRowKey(row) && (
                  <Box data-selection-indicator="" aria-hidden="true" />
                )}
                <Text textStyle="helper">
                  {fulfilmentDate(row.service_date)}
                </Text>
              </Table.Cell>
              <Table.Cell minW="var(--atlas-layout-school-min, 145px)">
                <Text fontWeight="semibold">{row.school_name}</Text>
                <Text data-row-secondary textStyle="helper" color="fg.muted">
                  {row.delivery_location_name}
                </Text>
              </Table.Cell>
              <Table.Cell minW="var(--atlas-layout-comparison-min, 105px)">
                <ComparisonResult status={row.comparison_status} />
              </Table.Cell>
              <Table.Cell minW="var(--atlas-layout-documents-min, 120px)">
                <Text textStyle="helper" overflowWrap="anywhere">
                  {row.purchase_order_numbers.join(" · ") || "Chưa có PO"}
                </Text>
                <Text
                  textStyle="helper"
                  overflowWrap="anywhere"
                  data-row-secondary
                  color="fg.muted"
                >
                  {row.pxk_document_number || "Chưa có PXK"}
                </Text>
              </Table.Cell>
              <Table.Cell minW="var(--atlas-layout-totals-min, 145px)">
                {row.quantity_totals_by_unit.map((total) => (
                  <Text key={total.unit_id} textStyle="helper">
                    {total.unit_code} · PO{" "}
                    {formatExactQuantity(total.po_quantity)} · PXK{" "}
                    {formatExactQuantity(total.pxk_quantity)} · Δ{" "}
                    {formatExactDelta(total.delta_quantity)}
                  </Text>
                ))}
              </Table.Cell>
              <Table.Cell minW="var(--atlas-layout-row-action-min, 88px)">
                <Button
                  variant="utility"
                  size="sm"
                  whiteSpace="normal"
                  onClick={(event) => onSelect(row, event.currentTarget)}
                >
                  Xem đối chiếu
                </Button>
              </Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table.Root>
    </Table.ScrollArea>
  );
}
