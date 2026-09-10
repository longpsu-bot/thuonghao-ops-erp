import {
  Box,
  Button,
  Flex,
  Grid,
  Heading,
  Stack,
  Table,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState } from "react";
import {
  procurementOperatorMessages,
  type PurchaseOrdersData,
  type SchoolCateringPurchaseOrder,
} from "../bridges/procurement";
import { formatExactQuantityForOperator as quantity } from "./procurementExactQuantity";

export type ProcurementExport = (
  order: SchoolCateringPurchaseOrder,
) => void | Promise<void>;
const dateLabel = (date: string) => date.split("-").reverse().join("/");
const stateLabel: Record<
  SchoolCateringPurchaseOrder["commitment_state"],
  string
> = {
  DRAFT_CURRENT: "Bản nháp",
  DRAFT_STALE: "Cần cập nhật",
  CURRENT: "Đã phát hành",
  REPLACEMENT_REQUIRED: "Cần thay thế",
  CANCELLATION_REQUIRED: "Cần xử lý hủy",
  SUPERSEDED: "Đã được thay thế",
};
export function ProcurementOrdersStage({
  data,
  disabled,
  search,
  onAction,
  onExportXlsx,
  onExportPdf,
}: {
  data: PurchaseOrdersData | null;
  disabled: boolean;
  search: string;
  onAction: (order: SchoolCateringPurchaseOrder) => void;
  onExportXlsx?: ProcurementExport;
  onExportPdf?: ProcurementExport;
}) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const selected = data?.purchase_orders.find(
    (order) => order.purchase_order_id === selectedId,
  );
  useEffect(() => {
    if (!selected) setSelectedId(null);
  }, [selected]);
  useEffect(() => {
    heading.current?.focus();
    setExportError(null);
  }, [selectedId]);
  const visible = (data?.purchase_orders ?? []).filter((order) =>
    [
      order.supplier.supplier_name,
      order.document_number ?? "",
      ...order.lines.flatMap((line) => [
        line.ingredient.ingredient_name,
        line.delivery_location.location_name,
      ]),
    ]
      .join(" ")
      .toLocaleLowerCase("vi")
      .includes(search.toLocaleLowerCase("vi")),
  );
  const locations = (order: SchoolCateringPurchaseOrder) =>
    [
      ...new Set(
        order.lines.map((line) => line.delivery_location.location_name),
      ),
    ].join(", ");
  const primary =
    selected?.status === "DRAFT"
      ? selected.commitment_state === "DRAFT_STALE"
        ? "Tạo lại đơn cần cập nhật"
        : selected.commitment_state === "DRAFT_CURRENT"
          ? "Phát hành cho NCC"
          : null
      : selected?.status === "RELEASED_TO_SUPPLIER" &&
          selected.commitment_state === "REPLACEMENT_REQUIRED"
        ? "Tạo đơn thay thế"
        : null;
  const allowed =
    selected &&
    (selected.commitment_state === "DRAFT_STALE" ||
      (selected.commitment_state === "DRAFT_CURRENT" &&
        !selected.stale &&
        selected.release_eligible &&
        selected.allowed_actions.release) ||
      (selected.commitment_state === "REPLACEMENT_REQUIRED" &&
        selected.allowed_actions.create_replacement));
  const exportReady =
    selected &&
    ["RELEASED_TO_SUPPLIER", "SUPERSEDED"].includes(selected.status) &&
    selected.export_ready &&
    selected.allowed_actions.export;
  const exportOrder = async (callback: ProcurementExport | undefined) => {
    if (!selected || !exportReady || !callback || disabled || exporting) return;
    setExporting(true);
    setExportError(null);
    try {
      await callback(selected);
    } catch {
      setExportError("Chưa xuất được chứng từ. Hãy thử xuất lại.");
    } finally {
      setExporting(false);
    }
  };
  const messages = selected
    ? procurementOperatorMessages(
        [
          ...selected.blockers,
          ...selected.disabled_reasons,
          ...selected.warnings,
        ],
        "Đơn mua có điều kiện cần kiểm tra trước khi tiếp tục.",
      )
    : [];
  return (
    <Box>
      <Text px="md" py="sm" textStyle="helper" color="fg.muted">
        {visible.length} đơn mua theo nhà cung cấp
      </Text>
      {procurementOperatorMessages(
        [...(data?.blockers ?? []), ...(data?.warnings ?? [])],
        "Có điều kiện cần kiểm tra trước khi tiếp tục.",
      ).map((message) => (
        <Text key={message} px="md" pb="sm" color="status.warning">
          ⚠ {message}
        </Text>
      ))}
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          xl: selected
            ? "minmax(0, 62fr) minmax(320px, 38fr)"
            : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
      >
        <Box minW="var(--atlas-layout-zero, 0)">
          <Table.ScrollArea
            maxH={{
              base: "var(--atlas-layout-table-mobile-height, 50dvh)",
              xl: "var(--atlas-layout-table-height, calc(100dvh - 360px))",
            }}
            overflow="auto"
          >
            <Table.Root aria-label="Đơn mua" size="sm" stickyHeader>
              <Table.Header>
                <Table.Row>
                  {[
                    "Nhà cung cấp",
                    "Ngày giao",
                    "Trường / điểm giao",
                    "Số dòng",
                    "Trạng thái",
                    "Số đơn",
                    "Thao tác",
                  ].map((label) => (
                    <Table.ColumnHeader key={label}>{label}</Table.ColumnHeader>
                  ))}
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {visible.map((order) => (
                  <Table.Row
                    key={order.purchase_order_id}
                    aria-selected={selectedId === order.purchase_order_id}
                  >
                    <Table.Cell
                      position="relative"
                      minW="var(--atlas-layout-order-supplier-width, 140px)"
                    >
                      {selectedId === order.purchase_order_id && (
                        <Box data-selection-indicator="" aria-hidden="true" />
                      )}
                      <Text fontWeight="semibold">
                        {order.supplier.supplier_name}
                      </Text>
                    </Table.Cell>
                    <Table.Cell whiteSpace="nowrap">
                      {dateLabel(order.service_date)}
                    </Table.Cell>
                    <Table.Cell minW="var(--atlas-layout-order-location-width, 140px)">
                      {locations(order)}
                    </Table.Cell>
                    <Table.Cell textAlign="end">
                      {order.lines.length}
                    </Table.Cell>
                    <Table.Cell minW="var(--atlas-layout-order-state-width, 115px)">
                      <Text
                        color={
                          [
                            "DRAFT_STALE",
                            "REPLACEMENT_REQUIRED",
                            "CANCELLATION_REQUIRED",
                          ].includes(order.commitment_state)
                            ? "status.warning"
                            : "fg.muted"
                        }
                        data-row-secondary=""
                      >
                        {[
                          "DRAFT_STALE",
                          "REPLACEMENT_REQUIRED",
                          "CANCELLATION_REQUIRED",
                        ].includes(order.commitment_state) && "⚠ "}
                        {stateLabel[order.commitment_state]}
                      </Text>
                      {procurementOperatorMessages(
                        order.warnings,
                        "Có cảnh báo cần kiểm tra.",
                      ).map((message) => (
                        <Text
                          key={message}
                          textStyle="helper"
                          color="status.warning"
                        >
                          ⚠ {message}
                        </Text>
                      ))}
                    </Table.Cell>
                    <Table.Cell>{order.document_number ?? "—"}</Table.Cell>
                    <Table.Cell>
                      <Button
                        size="sm"
                        variant="utility"
                        aria-label={`Xem đơn ${order.supplier.supplier_name}`}
                        aria-expanded={selectedId === order.purchase_order_id}
                        onClick={(event) => {
                          trigger.current = event.currentTarget;
                          setSelectedId(order.purchase_order_id);
                        }}
                      >
                        Xem đơn
                      </Button>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table.Body>
            </Table.Root>
          </Table.ScrollArea>
          {!visible.length && (
            <Text p="lg" color="fg.muted">
              Chưa có đơn mua trong phạm vi này.
            </Text>
          )}
        </Box>
        {selected && (
          <Flex
            as="aside"
            role="region"
            aria-label={`Chi tiết đơn mua ${selected.supplier.supplier_name}`}
            direction="column"
            bg="bg.subtle"
            minW="var(--atlas-layout-zero, 0)"
            borderLeftWidth={{
              base: "var(--atlas-layout-zero, 0)",
              xl: "var(--atlas-layout-edge, 1px)",
            }}
            borderTopWidth={{
              base: "var(--atlas-layout-edge, 1px)",
              xl: "var(--atlas-layout-zero, 0)",
            }}
            borderColor="border.subtle"
            maxH={{
              base: "var(--atlas-layout-detail-mobile-height, 80dvh)",
              xl: "var(--atlas-layout-detail-height, calc(100dvh - 360px))",
            }}
          >
            <Box p="md">
              <Heading as="h2" ref={heading} tabIndex={-1} textStyle="section">
                {selected.supplier.supplier_name}
              </Heading>
              <Text color="fg.muted" mt="xs">
                Ngày giao {dateLabel(selected.service_date)}
              </Text>
              {selected.document_number && (
                <Text fontWeight="semibold" mt="xs">
                  {selected.document_number}
                </Text>
              )}
            </Box>
            <Stack
              gap="sm"
              px="md"
              pb="md"
              overflowY="auto"
              minH="var(--atlas-layout-zero, 0)"
              flex="1"
            >
              {selected.commitment_state === "DRAFT_STALE" && (
                <Text color="status.warning">
                  ⚠ Bản nháp cần tạo lại theo phân bổ hiện tại trước khi phát
                  hành.
                </Text>
              )}
              {selected.commitment_state === "REPLACEMENT_REQUIRED" && (
                <Text color="status.warning">
                  ⚠ Đơn đã phát hành được giữ nguyên. Tạo và kiểm tra đơn thay
                  thế đầy đủ.
                </Text>
              )}
              {selected.commitment_state === "CANCELLATION_REQUIRED" &&
                !selected.blockers.includes("CANCELLATION_REQUIRED") && (
                  <Text color="status.warning">
                    ⚠ Cần xử lý hủy cam kết với nhà cung cấp trước khi tiếp tục.
                  </Text>
                )}
              {messages.map((message) => (
                <Text key={message} color="status.warning">
                  ⚠ {message}
                </Text>
              ))}
              <Table.ScrollArea>
                <Table.Root
                  aria-label={`Dòng đơn mua ${selected.supplier.supplier_name}`}
                  size="sm"
                >
                  <Table.Header>
                    <Table.Row>
                      {["Nguyên liệu", "Điểm giao", "Số lượng", "Đơn vị"].map(
                        (label) => (
                          <Table.ColumnHeader key={label}>
                            {label}
                          </Table.ColumnHeader>
                        ),
                      )}
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {selected.lines.map((line) => (
                      <Table.Row key={line.purchase_order_line_revision_id}>
                        <Table.Cell>
                          {line.ingredient.ingredient_name}
                        </Table.Cell>
                        <Table.Cell>
                          {line.delivery_location.location_name}
                        </Table.Cell>
                        <Table.Cell textAlign="end" whiteSpace="nowrap">
                          {quantity(line.ordered_quantity)}
                        </Table.Cell>
                        <Table.Cell>{line.unit.unit_code}</Table.Cell>
                      </Table.Row>
                    ))}
                  </Table.Body>
                </Table.Root>
              </Table.ScrollArea>
              {exportError && (
                <Text role="alert" color="status.warning">
                  {exportError}
                </Text>
              )}
            </Stack>
            <Flex
              p="md"
              gap="sm"
              wrap="wrap"
              justify="space-between"
              borderTopWidth="var(--atlas-layout-edge, 1px)"
              borderColor="border.subtle"
              flexShrink="0"
            >
              <Button
                onClick={() => {
                  setSelectedId(null);
                  trigger.current?.focus();
                }}
              >
                Đóng
              </Button>
              {primary && (
                <Button
                  variant="businessPrimary"
                  disabled={disabled || !allowed}
                  onClick={() => onAction(selected)}
                >
                  {primary}
                </Button>
              )}
              {exportReady && (
                <Flex gap="xs">
                  {onExportXlsx && (
                    <Button
                      variant="secondary"
                      disabled={disabled || exporting}
                      onClick={() => void exportOrder(onExportXlsx)}
                    >
                      XLSX
                    </Button>
                  )}
                  {onExportPdf && (
                    <Button
                      variant="utility"
                      disabled={disabled || exporting}
                      onClick={() => void exportOrder(onExportPdf)}
                    >
                      PDF
                    </Button>
                  )}
                </Flex>
              )}
            </Flex>
          </Flex>
        )}
      </Grid>
    </Box>
  );
}
