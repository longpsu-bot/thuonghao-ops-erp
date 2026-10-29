import { Box, Button, Table, Text } from "@chakra-ui/react";
import {
  schoolDispatchUnitLabel,
  type SchoolDispatchWorkbenchRow,
} from "../bridges/schoolDispatch";
import { schoolPxkRowKey } from "./useSchoolPxkWorkbench";
import { useId } from "react";
import { schoolPxkQuantity } from "./schoolPxkQuantity";
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
        overflow={{ base: "visible", lg: "auto" }}
        h="full"
        maxH="full"
      >
        <Table.Root
          aria-label="Phiếu xuất kho theo trường"
          size="sm"
          stickyHeader
          tableLayout="fixed"
          w="full"
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            lg: "var(--atlas-pxk-table-width, 810px)",
          }}
          css={{
            "@media(max-width:63.99rem)": {
              "& colgroup": { display: "none" },
              "& thead": {
                position: "absolute",
                width: "1px",
                height: "1px",
                overflow: "hidden",
                clip: "rect(0, 0, 0, 0)",
                whiteSpace: "nowrap",
              },
              "& tbody": { display: "block" },
              "& tbody tr": {
                display: "grid",
                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                gridTemplateAreas:
                  '"school school" "document state" "content content" "action action"',
                columnGap: "var(--atlas-spacing-sm)",
                rowGap: "var(--atlas-spacing-sm)",
                padding: "var(--atlas-spacing-sm)",
                borderBottom: "1px solid var(--atlas-colors-border-subtle)",
              },
              "& td": {
                display: "block",
                minWidth: 0,
                padding: 0,
                border: 0,
              },
              "& td::after": { display: "none" },
              '& td[data-pxk-field="school"]': { gridArea: "school" },
              '& td[data-pxk-field="content"]': { gridArea: "content" },
              '& td[data-pxk-field="document"]': { gridArea: "document" },
              '& td[data-pxk-field="state"]': { gridArea: "state" },
              '& td[data-pxk-field="action"]': { gridArea: "action" },
            },
          }}
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
            {rows.map((row) => {
              const lines =
                row.state === "CURRENT"
                  ? (row.current_release?.lines ?? [])
                  : row.preview.lines;
              return (
                <Table.Row
                  key={schoolPxkRowKey(row)}
                  aria-selected={selectedKey === schoolPxkRowKey(row)}
                  data-narrow-record="pxk"
                >
                  <Table.Cell
                    id={`${identityPrefix}-${schoolPxkRowKey(row)}`}
                    data-pxk-field="school"
                    position="relative"
                    whiteSpace="normal"
                    minW="var(--atlas-layout-pxk-school-min, 170px)"
                  >
                    {selectedKey === schoolPxkRowKey(row) && (
                      <Box data-selection-indicator="" aria-hidden="true" />
                    )}
                    <Text
                      data-narrow-label="Trường / điểm giao"
                      aria-hidden="true"
                      hideFrom="lg"
                      textStyle="helper"
                      color="fg.muted"
                      mb="xs"
                    >
                      Trường / điểm giao
                    </Text>
                    <Text fontWeight="semibold" overflowWrap="anywhere">
                      {row.preview.school_name}
                    </Text>
                    <Text
                      data-row-secondary
                      textStyle="helper"
                      color="fg.muted"
                    >
                      {row.preview.delivery_location_name} ·{" "}
                      {row.service_date.split("-").reverse().join("/")}
                    </Text>
                  </Table.Cell>
                  <Table.Cell data-pxk-field="content">
                    <Text
                      data-narrow-label="Nội dung"
                      aria-hidden="true"
                      hideFrom="lg"
                      textStyle="helper"
                      color="fg.muted"
                      mb="xs"
                    >
                      Nội dung
                    </Text>
                    <Text display={{ base: "none", lg: "block" }}>
                      {lines.length} nguyên liệu
                    </Text>
                    <Box hideFrom="lg">
                      {lines.map((line) => (
                        <Text
                          key={`${line.ingredient_id}:${line.unit_id}`}
                          textStyle="helper"
                          overflowWrap="anywhere"
                        >
                          <Box as="span" fontWeight="semibold">
                            {line.ingredient_name}
                          </Box>{" "}
                          · {schoolPxkQuantity(line.quantity)}{" "}
                          {schoolDispatchUnitLabel(line)}
                        </Text>
                      ))}
                    </Box>
                  </Table.Cell>
                  <Table.Cell data-pxk-field="document">
                    <Text
                      data-narrow-label="Phiếu hiện hành"
                      aria-hidden="true"
                      hideFrom="lg"
                      textStyle="helper"
                      color="fg.muted"
                      mb="xs"
                    >
                      Phiếu hiện hành
                    </Text>
                    <Text textStyle="body" overflowWrap="anywhere">
                      {row.current_release?.document_number ?? "Chưa phát hành"}
                    </Text>
                  </Table.Cell>
                  <Table.Cell
                    data-pxk-field="state"
                    color={
                      row.state === "BLOCKED"
                        ? "status.danger"
                        : row.state === "REPLACEMENT_REQUIRED"
                          ? "status.warning"
                          : "fg.muted"
                    }
                  >
                    <Text
                      data-narrow-label="Trạng thái"
                      aria-hidden="true"
                      hideFrom="lg"
                      textStyle="helper"
                      color="fg.muted"
                      mb="xs"
                    >
                      Trạng thái
                    </Text>
                    {pxkLabels[row.state]}
                  </Table.Cell>
                  <Table.Cell data-pxk-field="action">
                    <Button
                      variant="tertiary"
                      size="sm"
                      whiteSpace="normal"
                      aria-describedby={`${identityPrefix}-${schoolPxkRowKey(row)}`}
                      minH={{
                        base: "var(--atlas-layout-mobile-target, 44px)",
                        lg: "compact",
                      }}
                      minW="var(--atlas-layout-zero, 0)"
                      w={{ base: "full", lg: "var(--atlas-layout-auto, auto)" }}
                      disabled={disabled}
                      onClick={(e) => onSelect(row, e.currentTarget)}
                    >
                      {actions[row.state]}
                    </Button>
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </Table.ScrollArea>
    </Box>
  );
}
