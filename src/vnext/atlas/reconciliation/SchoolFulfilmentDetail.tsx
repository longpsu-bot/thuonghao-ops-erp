import { Box, Button, Flex, Heading, Table, Text } from "@chakra-ui/react";
import type { RefObject } from "react";
import type { SchoolFulfilmentRow } from "../bridges/schoolFulfilment";
import { SCHOOL_DISPATCH_STATE_LABELS } from "../bridges/schoolDispatch";
import { formatExactQuantity, formatExactDelta } from "../formatExactQuantity";
import { ComparisonResult, fulfilmentDate } from "./SchoolFulfilmentTable";
import { OperationalSignals } from "./SchoolFulfilmentFeedback";
export function SchoolFulfilmentDetail({
  row,
  detailRef,
  onClose,
}: {
  row: SchoolFulfilmentRow;
  detailRef: RefObject<HTMLDivElement | null>;
  onClose: () => void;
}) {
  return (
    <Box
      ref={detailRef}
      role="region"
      aria-label="Chi tiết đối chiếu"
      tabIndex={-1}
      bg="bg.subtle"
      p="md"
      minW="var(--atlas-layout-zero, 0)"
      borderLeftWidth={{ lg: "var(--atlas-layout-edge, 1px)" }}
      borderColor="border.subtle"
      maxH={{
        lg: "var(--atlas-layout-reconciliation-detail, calc(100dvh - 300px))",
      }}
      overflowY="auto"
      _focusVisible={{
        outlineWidth: "var(--atlas-layout-focus-width, 2px)",
        outlineStyle: "solid",
        outlineColor: "focus.ring",
        outlineOffset: "var(--atlas-layout-focus-offset, -2px)",
      }}
    >
      <Flex justify="space-between" align="start" gap="xs">
        <Box>
          <Heading as="h2" textStyle="section">
            {row.school_name}
          </Heading>
          <Text textStyle="helper" color="fg.muted">
            {row.delivery_location_name}
          </Text>
          <Text textStyle="helper" mt="xs">
            {fulfilmentDate(row.service_date)}
          </Text>
        </Box>
        <Button
          size="sm"
          variant="utility"
          aria-label="Đóng chi tiết"
          onClick={onClose}
        >
          Đóng
        </Button>
      </Flex>
      <Box mt="sm">
        <ComparisonResult status={row.comparison_status} />
      </Box>
      <Box my="md" textStyle="helper">
        <Text fontWeight="semibold">PO</Text>
        <Text overflowWrap="anywhere">
          {row.purchase_order_numbers.join(" · ") || "Chưa có PO"}
        </Text>
        <Text fontWeight="semibold" mt="xs">
          Phiếu xuất kho
        </Text>
        <Text overflowWrap="anywhere">
          {row.pxk_document_number || "Chưa có PXK"}
        </Text>
        <Text color="fg.muted" mt="xs">
          {SCHOOL_DISPATCH_STATE_LABELS[row.pxk_state]}
        </Text>
      </Box>
      <OperationalSignals blockers={row.blockers} warnings={row.warnings} />
      <Table.ScrollArea overflowX="auto">
        <Table.Root
          whiteSpace="normal"
          size="sm"
          aria-label="Chi tiết nguyên liệu"
          minW="var(--atlas-layout-detail-table-min, 340px)"
        >
          <Table.Header>
            <Table.Row>
              <Table.ColumnHeader>Nguyên liệu</Table.ColumnHeader>
              <Table.ColumnHeader>Đơn vị</Table.ColumnHeader>
              <Table.ColumnHeader textAlign="end">SL PO</Table.ColumnHeader>
              <Table.ColumnHeader textAlign="end">SL PXK</Table.ColumnHeader>
              <Table.ColumnHeader textAlign="end">Δ</Table.ColumnHeader>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {row.details.map((line) => (
              <Table.Row
                key={JSON.stringify([line.ingredient_id, line.unit_id])}
              >
                <Table.Cell>{line.ingredient_name}</Table.Cell>
                <Table.Cell>{line.unit_code}</Table.Cell>
                <Table.Cell textAlign="end" whiteSpace="nowrap">
                  {formatExactQuantity(line.po_quantity)}
                </Table.Cell>
                <Table.Cell textAlign="end" whiteSpace="nowrap">
                  {formatExactQuantity(line.pxk_quantity)}
                </Table.Cell>
                <Table.Cell
                  textAlign="end"
                  whiteSpace="nowrap"
                  color={
                    formatExactDelta(line.delta_quantity) === "0"
                      ? "fg.muted"
                      : "status.warning"
                  }
                  fontWeight={
                    formatExactDelta(line.delta_quantity) === "0"
                      ? "normal"
                      : "semibold"
                  }
                >
                  {formatExactDelta(line.delta_quantity)}
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table.Root>
      </Table.ScrollArea>
      <Text mt="sm" textStyle="helper" color="fg.muted">
        Δ = SL PO − SL PXK. Đối chiếu theo từng nguyên liệu và đơn vị.
      </Text>
    </Box>
  );
}
