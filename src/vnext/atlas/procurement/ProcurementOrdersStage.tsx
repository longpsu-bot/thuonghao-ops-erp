import {
  Box,
  Button,
  Flex,
  Grid,
  Heading,
  Field,
  NativeSelect,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useEffect, useId, useRef, useState } from "react";
import {
  canReleasePurchaseOrder,
  purchaseOrderLineUnitLabel,
  procurementOperatorMessages,
  type PurchaseOrdersData,
  type SchoolCateringPurchaseOrder,
} from "../bridges/procurement";
import { formatExactQuantityForOperator as quantity } from "./procurementExactQuantity";
import { AtlasWorkbar, AtlasWorkbarActions } from "../AtlasWorkbar";
import {
  ProcurementPxkImpact,
  type ProcurementPxkImpactProps,
} from "./ProcurementPxkImpact";

export type ProcurementExportMode =
  "all" | "details_ing" | "details_school" | "sum";
export type ProcurementExport = (
  order: SchoolCateringPurchaseOrder,
  mode?: ProcurementExportMode,
) => void | Promise<void>;
export type ProcurementZipExport = (
  orders: SchoolCateringPurchaseOrder[],
  mode: ProcurementExportMode,
  format?: "xlsx" | "pdf",
) => void | Promise<void>;
const canExport = (order: SchoolCateringPurchaseOrder) =>
  ["RELEASED_TO_SUPPLIER", "SUPERSEDED"].includes(order.status) &&
  order.document_snapshot_complete === true &&
  order.export_ready &&
  order.allowed_actions.export;
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
// Suppress only meanings already expressed by the selected state's detail.
function hasDedicatedGuidance(
  state: SchoolCateringPurchaseOrder["commitment_state"],
  code: string,
) {
  return (
    (state === "DRAFT_STALE" && code === "PO_DRAFT_STALE") ||
    (state === "REPLACEMENT_REQUIRED" &&
      ["PO_REPLACEMENT_REQUIRED", "PO_ALREADY_RELEASED"].includes(code)) ||
    (state === "CANCELLATION_REQUIRED" && code === "CANCELLATION_REQUIRED")
  );
}
export function ProcurementOrdersStage({
  data,
  disabled,
  search,
  onAction,
  onReleaseAll,
  bulkProgress,
  onExportXlsx,
  onExportPdf,
  onExportZip,
  authSubject,
  schoolDispatchApi,
  onOpenPxk,
}: {
  data: PurchaseOrdersData | null;
  disabled: boolean;
  search: string;
  onAction: (order: SchoolCateringPurchaseOrder) => void;
  onReleaseAll?: () => void;
  bulkProgress?: { completed: number; total: number } | null;
  onExportXlsx?: ProcurementExport;
  onExportPdf?: ProcurementExport;
  onExportZip?: ProcurementZipExport;
  authSubject?: string | null;
  schoolDispatchApi?: ProcurementPxkImpactProps["api"];
  onOpenPxk?: ProcurementPxkImpactProps["onOpenPxk"];
}) {
  const [selectedId, setSelectedId] = useState<string | null | undefined>(
    undefined,
  );
  const detailId = useId();
  const railButtons = useRef(new Map<string, HTMLButtonElement>());
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const [exportMode, setExportMode] = useState<ProcurementExportMode>("all");
  const exportOrders = (data?.purchase_orders ?? []).filter(canExport);
  const releaseOrders = (data?.purchase_orders ?? []).filter(
    canReleasePurchaseOrder,
  );
  const trigger = useRef<HTMLButtonElement | null>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const visible = (data?.purchase_orders ?? []).filter((order) =>
    [
      order.supplier.supplier_name,
      order.document_number ?? "",
      ...order.lines.flatMap((line) => [
        line.ingredient.ingredient_name,
        line.delivery_location.location_name,
        ...line.school_breakdown.map((school) => school.school_name),
      ]),
    ]
      .join(" ")
      .toLocaleLowerCase("vi")
      .includes(search.toLocaleLowerCase("vi")),
  );
  // undefined selects the first visible readback; null is an intentional Close.
  const selected =
    selectedId === undefined
      ? visible[0]
      : visible.find((order) => order.purchase_order_id === selectedId);
  useEffect(() => {
    if (
      selectedId &&
      !visible.some((order) => order.purchase_order_id === selectedId)
    )
      setSelectedId(undefined);
  }, [data, search, selectedId]);
  useEffect(() => {
    if (selectedId) heading.current?.focus();
    setExportError(null);
  }, [selectedId]);
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
  const exportReady = selected && canExport(selected);
  const exportOrder = async (callback: ProcurementExport | undefined) => {
    if (!selected || !exportReady || !callback || disabled || exporting) return;
    setExporting(true);
    setExportError(null);
    try {
      await callback(selected, exportMode);
    } catch {
      setExportError("Chưa xuất được chứng từ. Hãy thử xuất lại.");
    } finally {
      setExporting(false);
    }
  };
  const exportZip = async (format: "xlsx" | "pdf") => {
    if (!onExportZip || !exportOrders.length || disabled || exporting) return;
    setExporting(true);
    setExportError(null);
    try {
      await onExportZip(exportOrders, exportMode, format);
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
        ].filter(
          (code) => !hasDedicatedGuidance(selected.commitment_state, code),
        ),
        "Đơn mua có điều kiện cần kiểm tra trước khi tiếp tục.",
      )
    : [];
  if (!data) return null;
  return (
    <Box>
      <AtlasWorkbar
        px="md"
        pt="sm"
        pb="xs"
        gap="md"
        alignItems="center"
        bg="bg.toolbar"
        aria-label="Thao tác đơn mua đã tải"
      >
        <Text
          textStyle="label"
          color="fg.secondary"
          flex="1"
          minW="var(--atlas-layout-zero, 0)"
        >
          {visible.length} đơn mua đang hiển thị
        </Text>
        {onReleaseAll && (
          <Button
            variant="secondary"
            disabled={disabled || exporting || releaseOrders.length === 0}
            loading={Boolean(bulkProgress)}
            onClick={onReleaseAll}
            aria-describedby={`${detailId}-loaded-scope`}
          >
            Phát hành tất cả PO ({releaseOrders.length})
          </Button>
        )}
        <AtlasWorkbar
          aria-label="Xuất đơn mua đã tải"
          aria-describedby={`${detailId}-loaded-scope`}
          w={{ base: "full", lg: "var(--atlas-layout-auto, auto)" }}
          alignItems="center"
        >
          <Field.Root
            disabled={disabled || exporting}
            w={{ base: "full", sm: "var(--atlas-layout-auto, auto)" }}
            flexDirection="row"
            alignItems="center"
            gap="sm"
          >
            <Field.Label mb="var(--atlas-layout-zero, 0)" whiteSpace="nowrap">
              Nội dung xuất PO
            </Field.Label>
            <NativeSelect.Root
              disabled={disabled || exporting}
              w="var(--atlas-export-mode-width, 190px)"
            >
              <NativeSelect.Field
                value={exportMode}
                onChange={(event) =>
                  setExportMode(event.target.value as ProcurementExportMode)
                }
              >
                <option value="all">Tất cả</option>
                <option value="details_ing">Chi tiết theo hàng</option>
                <option value="details_school">Chi tiết theo trường</option>
                <option value="sum">Tổng</option>
              </NativeSelect.Field>
              <NativeSelect.Indicator />
            </NativeSelect.Root>
          </Field.Root>
          {onExportZip && (
            <AtlasWorkbarActions
              w={{ base: "full", sm: "var(--atlas-layout-auto, auto)" }}
              minW="var(--atlas-layout-zero, 0)"
              flexShrink="1"
              flexWrap="nowrap"
            >
              {(["xlsx", "pdf"] as const).map((format) => (
                <Button
                  key={format}
                  variant="secondary"
                  flex={{ base: "1", sm: "var(--atlas-layout-auto, auto)" }}
                  loading={exporting}
                  disabled={disabled || exporting || !exportOrders.length}
                  onClick={() => void exportZip(format)}
                >
                  Xuất {format.toUpperCase()}
                </Button>
              ))}
            </AtlasWorkbarActions>
          )}
        </AtlasWorkbar>
      </AtlasWorkbar>
      <Box px="md" pb="sm" bg="bg.toolbar">
        <Text
          id={`${detailId}-loaded-scope`}
          textStyle="helper"
          color="fg.secondary"
          maxW="75ch"
        >
          {onReleaseAll
            ? "Phát hành các bản nháp và xuất các đơn"
            : "Xuất các đơn"}{" "}
          đủ điều kiện trong dữ liệu đã tải theo khoảng ngày;{" "}
          <Box as="span" fontWeight="semibold">
            không giới hạn theo tìm kiếm.
          </Box>
        </Text>
        {bulkProgress && (
          <Text role="status" textStyle="helper">
            Đã xác nhận {bulkProgress.completed}/{bulkProgress.total} PO.
          </Text>
        )}
      </Box>
      {exportError && (
        <Text px="md" pb="sm" role="alert" color="status.danger">
          {exportError}
        </Text>
      )}
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
          lg: "minmax(240px, 280px) minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
        borderTopWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
      >
        <Flex
          as="nav"
          aria-label="Đơn mua theo nhà cung cấp"
          direction={{ base: "row", lg: "column" }}
          overflow="auto"
          maxH={{
            lg: "var(--atlas-orders-workplane-height, calc(100dvh - 300px))",
          }}
          p="sm"
          gap="xs"
          minW="var(--atlas-layout-zero, 0)"
          alignSelf="start"
        >
          {visible.map((order) => (
            <Button
              key={order.purchase_order_id}
              ref={(node) => {
                if (node)
                  railButtons.current.set(order.purchase_order_id, node);
                else railButtons.current.delete(order.purchase_order_id);
              }}
              variant="utility"
              aria-label={`Xem đơn ${order.supplier.supplier_name} · ${dateLabel(order.service_date)} · ${order.document_number ?? stateLabel[order.commitment_state]}`}
              aria-pressed={
                selected?.purchase_order_id === order.purchase_order_id
              }
              aria-expanded={
                selected?.purchase_order_id === order.purchase_order_id
              }
              aria-controls={detailId}
              h="var(--atlas-layout-auto, auto)"
              minH="var(--atlas-layout-mobile-target, 44px)"
              minW={{
                base: "var(--atlas-orders-rail-card-width, 230px)",
                lg: "var(--atlas-layout-zero, 0)",
              }}
              w={{
                base: "var(--atlas-orders-rail-card-width, 230px)",
                lg: "full",
              }}
              flexShrink="var(--atlas-layout-zero, 0)"
              whiteSpace="normal"
              textAlign="left"
              alignItems="stretch"
              flexDirection="column"
              gap="xs"
              p="sm"
              bg={
                selected?.purchase_order_id === order.purchase_order_id
                  ? "bg.selected"
                  : "bg.workbench"
              }
              borderRadius="control"
              borderWidth="var(--atlas-layout-edge, 1px)"
              borderColor={
                selected?.purchase_order_id === order.purchase_order_id
                  ? "border.accent"
                  : "border.subtle"
              }
              onClick={(event) => {
                trigger.current = event.currentTarget;
                setSelectedId(order.purchase_order_id);
              }}
            >
              <Text fontWeight="semibold" overflowWrap="anywhere">
                {order.supplier.supplier_name}
              </Text>
              <Flex
                justify="space-between"
                gap="sm"
                textStyle="helper"
                fontWeight="normal"
              >
                <Text>{dateLabel(order.service_date)}</Text>
                <Text>{order.lines.length} dòng</Text>
              </Flex>
              <Text
                textStyle="helper"
                fontWeight="normal"
                color={
                  [
                    "DRAFT_STALE",
                    "REPLACEMENT_REQUIRED",
                    "CANCELLATION_REQUIRED",
                  ].includes(order.commitment_state)
                    ? "status.warning"
                    : "fg.muted"
                }
              >
                {stateLabel[order.commitment_state]}
              </Text>
              <Text
                textStyle="helper"
                fontWeight="normal"
                color="fg.muted"
                overflowWrap="anywhere"
              >
                {order.document_number ?? "Chưa cấp số đơn"}
              </Text>
              {procurementOperatorMessages(
                order.warnings.filter(
                  (code) =>
                    order.purchase_order_id !== selected?.purchase_order_id ||
                    !hasDedicatedGuidance(order.commitment_state, code),
                ),
                "Có cảnh báo cần kiểm tra.",
              ).map((message) => (
                <Text key={message} textStyle="helper" color="status.warning">
                  ⚠ {message}
                </Text>
              ))}
            </Button>
          ))}
          {!visible.length && (
            <Text p="md" color="fg.muted">
              {search.trim()
                ? "Không có đơn mua khớp tìm kiếm trong phạm vi này."
                : "Chưa có đơn mua trong phạm vi này."}
            </Text>
          )}
        </Flex>
        {selected ? (
          <Flex
            as="aside"
            id={detailId}
            role="region"
            aria-label={`Chi tiết đơn mua ${selected.supplier.supplier_name}`}
            direction="column"
            bg="bg.workbench"
            minW="var(--atlas-layout-zero, 0)"
            borderLeftWidth={{
              base: "var(--atlas-layout-zero, 0)",
              lg: "var(--atlas-layout-edge, 1px)",
            }}
            borderTopWidth={{
              base: "var(--atlas-layout-edge, 1px)",
              lg: "var(--atlas-layout-zero, 0)",
            }}
            borderColor="border.subtle"
            maxH={{
              lg: "var(--atlas-orders-workplane-height, calc(100dvh - 300px))",
            }}
          >
            <Box
              px={{ base: "md", xl: "lg" }}
              pt="md"
              pb="sm"
              flexShrink="var(--atlas-layout-zero, 0)"
            >
              <Flex justify="space-between" gap="md" align="start">
                <Box minW="var(--atlas-layout-zero, 0)">
                  <Text color="fg.muted" textStyle="helper" mb="xs">
                    {selected.document_number ?? "Bản nháp · Chưa cấp số đơn"}
                  </Text>
                  <Heading
                    as="h2"
                    ref={heading}
                    tabIndex={-1}
                    textStyle="section"
                    overflowWrap="anywhere"
                  >
                    {selected.supplier.supplier_name}
                  </Heading>
                  <Text color="fg.muted" textStyle="helper" mt="xs">
                    Ngày dùng {dateLabel(selected.service_date)} ·{" "}
                    {stateLabel[selected.commitment_state]}
                  </Text>
                </Box>
                <Button
                  variant="tertiary"
                  flexShrink="var(--atlas-layout-zero, 0)"
                  onClick={() => {
                    setSelectedId(null);
                    const origin = trigger.current?.isConnected
                      ? trigger.current
                      : railButtons.current.get(selected.purchase_order_id);
                    origin?.focus();
                  }}
                >
                  Đóng
                </Button>
              </Flex>
              <Flex mt="sm" gap="sm" wrap="wrap">
                {(
                  [
                    [selected.replaces_purchase_order_id, "Xem đơn trước"],
                    [
                      selected.replaced_by_purchase_order_id,
                      "Xem đơn thay thế",
                    ],
                  ] as const
                ).map(([id, label]) => {
                  if (!id) return null;
                  const linked = data.purchase_orders.find(
                    (order) => order.purchase_order_id === id,
                  );
                  return linked ? (
                    <Button
                      key={label}
                      variant="secondary"
                      onClick={() => setSelectedId(id)}
                    >
                      {label} {linked.document_number ?? "chưa cấp số"}
                    </Button>
                  ) : (
                    <Text
                      key={label}
                      textStyle="helper"
                      overflowWrap="anywhere"
                    >
                      {label}: {id} · chưa có trong phạm vi đã tải
                    </Text>
                  );
                })}
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
                  <Flex
                    role="group"
                    aria-label="Xuất đơn mua đang xem"
                    gap="xs"
                    wrap="wrap"
                  >
                    {onExportXlsx && (
                      <Button
                        variant="secondary"
                        disabled={disabled || exporting}
                        onClick={() => void exportOrder(onExportXlsx)}
                      >
                        Xuất XLSX
                      </Button>
                    )}
                    {onExportPdf && (
                      <Button
                        variant="secondary"
                        disabled={disabled || exporting}
                        onClick={() => void exportOrder(onExportPdf)}
                      >
                        Xuất PDF
                      </Button>
                    )}
                  </Flex>
                )}
              </Flex>
            </Box>
            <Stack
              gap="sm"
              px={{ base: "md", xl: "lg" }}
              pb="md"
              overflowY={{ lg: "auto" }}
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
              {selected.commitment_state === "CANCELLATION_REQUIRED" && (
                <Text color="status.warning">
                  ⚠ Cần xử lý hủy cam kết với nhà cung cấp trước khi tiếp tục.
                </Text>
              )}
              {messages.map((message) => (
                <Text key={message} color="status.warning">
                  ⚠ {message}
                </Text>
              ))}
              {schoolDispatchApi && (
                <ProcurementPxkImpact
                  api={schoolDispatchApi}
                  authSubject={authSubject ?? null}
                  order={selected}
                  disabled={disabled}
                  onOpenPxk={onOpenPxk}
                />
              )}
              {selected.lines.some((line) => !line.school_breakdown.length) && (
                <Text color="fg.secondary" textStyle="body" maxW="70ch">
                  <Box as="span" fontWeight="semibold">
                    Lưu ý đối chiếu:
                  </Box>{" "}
                  Chưa có chi tiết trường nhận để đối chiếu cho một số dòng.
                  Điểm giao không thay thế thông tin trường nhận.
                </Text>
              )}
              <Heading as="h3" textStyle="body" fontWeight="semibold" pt="sm">
                Nguyên liệu và nơi nhận
              </Heading>
              <Stack
                gap="var(--atlas-layout-zero, 0)"
                aria-label="Dòng đơn mua"
              >
                {selected.lines.map((line) => (
                  <Box
                    as="section"
                    key={line.purchase_order_line_revision_id}
                    py="md"
                    borderTopWidth="var(--atlas-layout-edge, 1px)"
                    borderColor="border.subtle"
                    minW="var(--atlas-layout-zero, 0)"
                  >
                    <Grid
                      templateColumns={{
                        base: "minmax(0, 1fr)",
                        xl: "minmax(150px, .7fr) minmax(0, 1.3fr)",
                      }}
                      gap={{ base: "sm", xl: "lg" }}
                      maxW="var(--atlas-orders-document-width, 1100px)"
                    >
                      <Box>
                        <Text textStyle="body">
                          {line.ingredient.ingredient_name}
                        </Text>
                        <Text mt="xs" textStyle="quantityInline">
                          {quantity(line.ordered_quantity)}{" "}
                          <Text
                            as="span"
                            textStyle="unitInline"
                            color="fg.secondary"
                          >
                            {purchaseOrderLineUnitLabel(selected.status, line)}
                          </Text>
                        </Text>
                        <Text mt="xs" textStyle="helper" color="fg.muted">
                          Điểm giao: {line.delivery_location.location_name}
                        </Text>
                      </Box>
                      <Stack gap="sm">
                        {line.school_breakdown.map((school) => (
                          <Flex
                            key={`${school.school_id}:${school.delivery_location_id}`}
                            justify="space-between"
                            align="start"
                            gap="md"
                          >
                            <Box minW="var(--atlas-layout-zero, 0)">
                              <Text>{school.school_name}</Text>
                              <Text textStyle="helper" color="fg.muted">
                                {school.delivery_location_name}
                              </Text>
                            </Box>
                            <Text
                              whiteSpace="nowrap"
                              textStyle="quantityInline"
                            >
                              {quantity(school.ordered_quantity)}{" "}
                              <Text
                                as="span"
                                textStyle="unitInline"
                                color="fg.secondary"
                              >
                                {purchaseOrderLineUnitLabel(
                                  selected.status,
                                  line,
                                )}
                              </Text>
                            </Text>
                          </Flex>
                        ))}
                      </Stack>
                    </Grid>
                    {line.supplier_note && (
                      <Text
                        mt="sm"
                        textStyle="helper"
                        bg="bg.toolbar"
                        p="sm"
                        whiteSpace="pre-wrap"
                        overflowWrap="anywhere"
                      >
                        <Box as="span" fontWeight="semibold">
                          Ghi chú:{" "}
                        </Box>
                        {line.supplier_note}
                      </Text>
                    )}
                  </Box>
                ))}
              </Stack>
            </Stack>
          </Flex>
        ) : (
          <Text p="lg" color="fg.muted">
            {visible.length
              ? "Chọn một đơn mua để xem nội dung và thao tác."
              : "Các đơn đã phát hành vẫn được giữ trong lịch sử. Kiểm tra phạm vi ngày hoặc tìm kiếm; chưa có đơn không có nghĩa là nhu cầu bằng không."}
          </Text>
        )}
      </Grid>
    </Box>
  );
}
