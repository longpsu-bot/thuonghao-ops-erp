import { Box, Button, Table, Text } from "@chakra-ui/react";
import type { SchoolDispatchWorkbenchRow } from "../bridges/schoolDispatch";
import { schoolPxkRowKey } from "./useSchoolPxkWorkbench";
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
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      <Table.ScrollArea
        overflow="auto"
        maxH={{
          base: "var(--atlas-layout-pxk-mobile-table, 50dvh)",
          lg: "var(--atlas-layout-pxk-table, calc(100dvh - 290px))",
        }}
      >
        <Table.Root
          aria-label="Phiếu xuất kho theo trường"
          size="sm"
          stickyHeader
          minW="var(--atlas-layout-pxk-table-min, 570px)"
        >
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
                  position="relative"
                  minW="var(--atlas-layout-pxk-school-min, 170px)"
                >
                  {selectedKey === schoolPxkRowKey(row) && (
                    <Box data-selection-indicator="" aria-hidden="true" />
                  )}
                  <Text fontWeight="semibold">{row.preview.school_name}</Text>
                  <Text data-row-secondary textStyle="helper" color="fg.muted">
                    {row.preview.delivery_location_name}
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
                  <Text textStyle="helper">
                    {row.current_release?.document_number ?? "Chưa phát hành"}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  color={
                    row.state === "BLOCKED"
                      ? "status.danger"
                      : row.state === "REPLACEMENT_REQUIRED"
                        ? "status.warning"
                        : "fg.primary"
                  }
                >
                  {pxkLabels[row.state]}
                </Table.Cell>
                <Table.Cell>
                  <Button
                    variant="utility"
                    size="sm"
                    whiteSpace="normal"
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
