import { Box, Button, Text } from "@chakra-ui/react";
import { useEffect, useState } from "react";
import {
  purchaseOrdersFromResult,
  purchaseOrdersReadRequest,
  type SchoolCateringProcurementApi,
  type SchoolCateringPurchaseOrder,
} from "../bridges/procurement";
import type { ConfirmedNeedWorkbenchData } from "../bridges/confirmedNeed";
import { formatExactQuantityForOperator } from "../procurement/procurementExactQuantity";
export function ConfirmedNeedIssuedOrders({
  api,
  authSubject,
  workbench,
  serviceDate,
  schoolIds,
  onOpenOrders,
}: {
  api: SchoolCateringProcurementApi;
  authSubject: string | null;
  workbench: ConfirmedNeedWorkbenchData;
  serviceDate: string;
  schoolIds: string[];
  onOpenOrders?: (date: string) => void;
}) {
  const [read, setRead] = useState<{
    orders: SchoolCateringPurchaseOrder[];
    error: boolean;
  } | null>(null);
  const [refresh, setRefresh] = useState(0);
  useEffect(() => {
    let live = true;
    setRead(null);
    if (!authSubject) return;
    void api
      .getPurchaseOrders(
        purchaseOrdersReadRequest(authSubject, crypto.randomUUID(), {
          date_start: serviceDate,
          date_end: serviceDate,
          supplier_ids: [],
          statuses: [],
          search: null,
        }),
      )
      .then((result) => {
        if (!live) return;
        const data = purchaseOrdersFromResult(result);
        if (
          !data ||
          data.date_start !== serviceDate ||
          data.date_end !== serviceDate
        ) {
          setRead({ orders: [], error: true });
          return;
        }
        const scoped = workbench.lines.filter(
          (line) => !schoolIds.length || schoolIds.includes(line.school.id),
        );
        const orders = data.purchase_orders.filter(
          (order) =>
            ["RELEASED_TO_SUPPLIER", "SUPERSEDED"].includes(order.status) &&
            order.lines.some(
              (line) =>
                line.service_date === serviceDate &&
                line.school_breakdown.some((school) =>
                  scoped.some(
                    (need) =>
                      need.school.id === school.school_id &&
                      need.delivery_location.id === school.delivery_location_id,
                  ),
                ),
            ),
        );
        setRead({ orders, error: false });
      })
      .catch(() => {
        if (live) setRead({ orders: [], error: true });
      });
    return () => {
      live = false;
    };
  }, [api, authSubject, workbench, serviceDate, schoolIds, refresh]);
  return (
    <Box px="md" pb="sm">
      <Text textStyle="helper" fontWeight="semibold">
        Đơn đã phát hành có Trường/ngày/điểm giao trong phạm vi nhu cầu
      </Text>
      {read?.error ? (
        <Text role="alert" color="status.warning">
          Chưa tải được đơn đã phát hành. Kiểm tra tại Đơn mua trước khi tiếp
          tục.
        </Text>
      ) : !read ? (
        <Text textStyle="helper">Đang tải đơn đã phát hành…</Text>
      ) : !read.orders.length ? (
        <Text textStyle="helper">
          Chưa có đơn đã phát hành trong phạm vi vừa đọc.
        </Text>
      ) : (
        read.orders.map((order) => (
          <Box as="details" key={order.purchase_order_id} mt="xs">
            <Box as="summary" cursor="var(--atlas-disclosure-cursor, pointer)">
              {order.document_number} · {order.supplier.supplier_name}
              {order.status === "SUPERSEDED" ? " · Đã được thay thế" : ""}
            </Box>
            <Text textStyle="helper">
              Toàn bộ đơn nhà cung cấp/ngày, gồm cả các trường khác nếu có:
            </Text>
            {order.lines.map((line) => (
              <Text
                key={line.purchase_order_line_revision_id}
                textStyle="helper"
              >
                {line.ingredient_name_snapshot ??
                  line.ingredient.ingredient_name}
                : {formatExactQuantityForOperator(line.ordered_quantity)}{" "}
                {line.unit_code_snapshot ?? line.unit.unit_code} ·{" "}
                {line.delivery_location.location_name}
              </Text>
            ))}
          </Box>
        ))
      )}
      <Button
        mt="xs"
        variant="tertiary"
        disabled={!read}
        onClick={() => setRefresh((value) => value + 1)}
      >
        Tải lại đơn liên quan
      </Button>
      {onOpenOrders && (
        <Button
          mt="xs"
          ml="sm"
          variant="secondary"
          onClick={() => onOpenOrders(serviceDate)}
        >
          Mở Đơn mua và lịch sử
        </Button>
      )}
    </Box>
  );
}
