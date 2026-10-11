import { Box, Button, Table, Text } from "@chakra-ui/react";
import type { SchoolDispatchWorkbenchRow } from "../bridges/schoolDispatch";
import { schoolPxkRowKey } from "./useSchoolPxkWorkbench";
import { useId } from "react";
export const pxkLabels = {
  READY: "Cần phát hành",
  CURRENT: "Đã phát hành",
  REPLACEMENT_REQUIRED: "Cần thay thế",
  BLOCKED: "Bị chặn",
};
const actions = {
  READY: "Phát hành",
  CURRENT: "Xem phiếu",
  REPLACEMENT_REQUIRED: "Tạo phiếu thay thế",
  BLOCKED: "Xem lỗi",
};
export function SchoolPxkTable({
  rows,
  selectedKey,
  disabled,
  onSelect,
}: {
  rows: SchoolDispatchWorkbenchRow[];
  selectedKey: string | null;
  disabled: boolean;
  onSelect: (
    row: SchoolDispatchWorkbenchRow,
    trigger: HTMLButtonElement,
  ) => void;
}) {
  const identityPrefix = useId();
  return (
    <Box
      minW="var(--atlas-layout-zero, 0)"
      minH="var(--atlas-layout-zero, 0)"
      h="full"
    >
      <Table.ScrollArea
        role="region"
        aria-label="Bảng phiếu xuất kho theo trường"
        tabIndex={0}
        overflow="auto"
        h="full"
        maxH="full"
      >
        <Table.Root
          aria-label="Phiếu xuất kho theo trường"
          size="sm"
          stickyHeader
          tableLayout="fixed"
          w="full"
          minW="var(--atlas-pxk-table-width, 810px)"
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-pxk-school-width, 240px)" />
            <Table.Column w="var(--atlas-pxk-content-width, 100px)" />
            <Table.Column w="var(--atlas-pxk-document-width, 170px)" />
            <Table.Column w="var(--atlas-pxk-state-width, 150px)" />
            <Table.Column w="var(--atlas-pxk-action-width, 150px)" />
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row>
              {[
                "Trường / điểm giao",
                "Nội dung",
                "Phiếu hiện hành",
                "Trạng thái",
                "Thao tác",
              ].map((t) => (
                <Table.ColumnHeader key={t}>{t}</Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {rows.map((row) => (
              <Table.Row
                key={schoolPxkRowKey(row)}
                aria-selected={selectedKey === schoolPxkRowKey(row)}
              >
                <Table.Cell
                  id={`${identityPrefix}-${schoolPxkRowKey(row)}`}
                  position="relative"
                  whiteSpace="normal"
                  minW="var(--atlas-layout-pxk-school-min, 170px)"
                >
                  {selectedKey === schoolPxkRowKey(row) && (
                    <Box data-selection-indicator="" aria-hidden="true" />
                  )}
                  <Text fontWeight="semibold" overflowWrap="anywhere">
                    {row.preview.school_name}
                  </Text>
                  <Text data-row-secondary textStyle="helper" color="fg.muted">
                    {row.preview.delivery_location_name} ·{" "}
                    {row.service_date.split("-").reverse().join("/")}
                  </Text>
                </Table.Cell>
                <Table.Cell>
                  {(row.state === "CURRENT"
                    ? row.current_release?.lines
                    : row.preview.lines
                  )?.length ?? 0}{" "}
                  nguyên liệu
                </Table.Cell>
                <Table.Cell>
                  <Text textStyle="body" overflowWrap="anywhere">
                    {row.current_release?.document_number ?? "Chưa phát hành"}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  color={
                    row.state === "BLOCKED"
                      ? "status.danger"
                      : row.state === "REPLACEMENT_REQUIRED"
                        ? "status.warning"
                        : "fg.muted"
                  }
                >
                  {pxkLabels[row.state]}
                </Table.Cell>
                <Table.Cell>
                  <Button
                    variant="tertiary"
                    size="sm"
                    whiteSpace="normal"
                    aria-describedby={`${identityPrefix}-${schoolPxkRowKey(row)}`}
                    minH={{
                      base: "var(--atlas-layout-mobile-target, 44px)",
                      lg: "compact",
                    }}
                    disabled={disabled}
                    onClick={(e) => onSelect(row, e.currentTarget)}
                  >
                    {actions[row.state]}
                  </Button>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table.Root>
      </Table.ScrollArea>
    </Box>
  );
}
