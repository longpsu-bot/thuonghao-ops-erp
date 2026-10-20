import type { SchoolCateringPurchaseOrder } from "../bridges/procurement";
import type { SchoolDispatchReleaseApi } from "../bridges/schoolDispatch";
import {
  SCHOOL_DISPATCH_STATE_LABELS,
  schoolDispatchBlockerLabel,
  schoolDispatchReleaseReadRequest,
  type SchoolDispatchWorkbenchRow,
} from "../bridges/schoolDispatch";
import { Box, Button, Flex, Text } from "@chakra-ui/react";
import { useEffect, useState } from "react";
export type ProcurementPxkImpactProps = {
  authSubject: string | null;
  api: SchoolDispatchReleaseApi;
  order: SchoolCateringPurchaseOrder;
  disabled: boolean;
  onOpenPxk?: (date: string, schoolIds: string[]) => void;
};
export function ProcurementPxkImpact({
  authSubject,
  api,
  order,
  disabled,
  onOpenPxk,
}: ProcurementPxkImpactProps) {
  const [read, setRead] = useState<{
    rows: SchoolDispatchWorkbenchRow[];
    error: boolean;
  } | null>(null);
  const [refresh, setRefresh] = useState(0);
  const scope = order.lines.flatMap((line) =>
    line.school_breakdown.map((school) => ({
      date: line.service_date,
      school: school.school_id,
      location: school.delivery_location_id,
    })),
  );
  const schoolIds = [...new Set(scope.map((row) => row.school))];
  const issued =
    order.status === "RELEASED_TO_SUPPLIER" || order.status === "SUPERSEDED";
  useEffect(() => {
    let live = true;
    setRead(null);
    if (!authSubject || disabled || !issued || !schoolIds.length) return;
    void api
      .getWorkbench(
        schoolDispatchReleaseReadRequest(authSubject, crypto.randomUUID(), {
          date_start: order.service_date,
          date_end: order.service_date,
          school_ids: schoolIds,
          search: null,
        }),
      )
      .then((result) => {
        if (!live) return;
        const response = result.kind === "success" ? result.response : null;
        if (
          !response ||
          response.contract_version !== "SCHOOL-DISPATCH-RELEASE.v1" ||
          response.date_start !== order.service_date ||
          response.date_end !== order.service_date ||
          !Array.isArray(response.rows)
        ) {
          setRead({ rows: [], error: true });
          return;
        }
        const rows = (response.rows as SchoolDispatchWorkbenchRow[]).filter(
          (row) =>
            scope.some(
              (item) =>
                item.date === row.service_date &&
                item.school === row.school_id &&
                item.location === row.delivery_location_id,
            ),
        );
        if (
          rows.some(
            (row) =>
              !(row.state in SCHOOL_DISPATCH_STATE_LABELS) ||
              !row.preview ||
              !Array.isArray(row.blockers),
          )
        )
          setRead({ rows: [], error: true });
        else setRead({ rows, error: false });
      })
      .catch(() => {
        if (live) setRead({ rows: [], error: true });
      });
    return () => {
      live = false;
    };
  }, [api, authSubject, disabled, issued, order, refresh]);
  if (!issued || !schoolIds.length) return null;
  return (
    <Box
      borderTopWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      pt="sm"
      aria-label="Ảnh hưởng Phiếu xuất kho"
    >
      <Text fontWeight="semibold">
        Phiếu xuất kho theo Trường/ngày của đơn đang xem
      </Text>
      <Text textStyle="helper" color="fg.muted">
        Phát hành đơn mua không tự phát hành Phiếu xuất kho. Kiểm tra phiếu hiện
        tại trước khi quyết định tạo phiếu thay thế.
      </Text>
      {read?.error ? (
        <Text role="alert" color="status.warning">
          Chưa xác nhận ảnh hưởng PXK. Hãy tải lại hoặc mở Phiếu xuất kho để
          kiểm tra quyền và nguồn hiện tại.
        </Text>
      ) : !read ? (
        <Text role="status">Đang kiểm tra PXK…</Text>
      ) : read.rows.length ? (
        read.rows.map((row) => (
          <Box
            key={`${row.service_date}:${row.school_id}:${row.delivery_location_id}`}
            mt="xs"
          >
            <Text>
              {row.preview.school_name} · {row.preview.delivery_location_name}:{" "}
              <Text as="span" fontWeight="semibold">
                {SCHOOL_DISPATCH_STATE_LABELS[row.state]}
              </Text>
            </Text>
            {row.current_release && (
              <Text textStyle="helper">
                Phiếu hiện tại: {row.current_release.document_number} ·{" "}
                {row.history.length} lần phát hành trong lịch sử
              </Text>
            )}
            {row.blockers.map((code) => (
              <Text key={code} textStyle="helper" color="status.warning">
                {schoolDispatchBlockerLabel(code)}
              </Text>
            ))}
          </Box>
        ))
      ) : (
        <Text>
          Chưa có dòng PXK trong phạm vi Trường/ngày/điểm giao đã đọc.
        </Text>
      )}
      <Flex gap="sm" wrap="wrap" mt="sm">
        <Button
          variant="tertiary"
          disabled={disabled || !read}
          onClick={() => setRefresh((value) => value + 1)}
        >
          Tải lại ảnh hưởng PXK
        </Button>
        {onOpenPxk && (
          <Button
            variant="secondary"
            disabled={disabled}
            onClick={() => onOpenPxk(order.service_date, schoolIds)}
          >
            Mở Phiếu xuất kho
          </Button>
        )}
      </Flex>
    </Box>
  );
}
