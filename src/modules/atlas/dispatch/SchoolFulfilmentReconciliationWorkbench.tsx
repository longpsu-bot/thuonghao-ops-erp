import {
  Alert,
  Badge,
  Button,
  Card,
  Group,
  SimpleGrid,
  Stack,
  Table,
  Text,
  TextInput,
} from "@mantine/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { SchoolScopeSelector } from "../SchoolScopeSelector";
import { WorkbenchHeader } from "../WorkbenchComponents";
import type { AtlasAuthState } from "../connection/authSession";
import {
  schoolFulfilmentReadRequest,
  schoolFulfilmentWorkbenchFromResult,
  type SchoolFulfilmentReconciliationApi,
} from "./schoolFulfilmentReconciliationApi";
import {
  SCHOOL_FULFILMENT_STATUS_LABELS,
  type SchoolFulfilmentComparisonStatus,
  type SchoolFulfilmentWorkbenchData,
} from "./schoolFulfilmentReconciliationModel";
import {
  SCHOOL_DISPATCH_STATE_LABELS,
  schoolDispatchBlockerLabel,
} from "./schoolDispatchReleaseModel";

function statusColor(status: SchoolFulfilmentComparisonStatus) {
  if (status === "OK") return "green";
  if (status === "NO_PO" || status === "NO_PXK") return "gray";
  if (status === "INGREDIENT_CHANGED") return "orange";
  return "red";
}

export function SchoolFulfilmentReconciliationWorkbench({
  authState,
  api,
  initialDateStart,
  initialDateEnd,
}: {
  authState: AtlasAuthState;
  api?: SchoolFulfilmentReconciliationApi;
  initialDateStart: string;
  initialDateEnd: string;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [dateStart, setDateStart] = useState(initialDateStart);
  const [dateEnd, setDateEnd] = useState(initialDateEnd);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [search, setSearch] = useState("");
  const [data, setData] = useState<SchoolFulfilmentWorkbenchData | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const readIntent = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const load = useCallback(async () => {
    if (!api || !authSubject) return;
    const intent = ++readIntent.current;
    setLoading(true);
    const result = await api.getWorkbench(
      schoolFulfilmentReadRequest(authSubject, correlationId, {
        date_start: dateStart,
        date_end: dateEnd,
        school_ids: schoolIds,
        search: search.trim() || null,
      }),
    );
    if (intent !== readIntent.current) return;
    setLoading(false);
    const next = schoolFulfilmentWorkbenchFromResult(result);
    if (!next) {
      setMessage(
        result.kind === "backend_error"
          ? result.error.safe_message
          : result.kind === "transport_error"
            ? result.diagnostic.safeMessage
            : "Không thể tải đối chiếu.",
      );
      return;
    }
    setData(next);
    setMessage(null);
  }, [api, authSubject, correlationId, dateEnd, dateStart, schoolIds, search]);

  useEffect(() => {
    void load();
  }, [load]);
  const schools = useMemo(
    () =>
      Array.from(
        new Map(
          (data?.rows ?? []).map((row) => [
            row.school_id,
            { school_id: row.school_id, school_name: row.school_name },
          ]),
        ).values(),
      ),
    [data],
  );

  if (!authSubject)
    return (
      <Alert color="yellow" title="Cần đăng nhập">
        Đăng nhập Atlas để xem đối chiếu theo phạm vi được cấp.
      </Alert>
    );
  return (
    <Stack gap="lg" p={{ base: "md", md: "xl" }}>
      <WorkbenchHeader
        eyebrow="Kho"
        title="Đối chiếu PO / Phiếu xuất kho"
        context="So sánh chính xác cam kết mua hàng thuộc từng trường với Phiếu xuất kho hiện hành, không cộng gộp khác đơn vị."
      />
      <Alert color="blue" title="Chỉ đọc">
        Trạng thái đối chiếu được hệ thống suy ra. Các vướng mắc vận hành được
        hiển thị riêng và không bị che bởi số lượng khớp.
      </Alert>
      <Card withBorder>
        <SimpleGrid cols={{ base: 1, sm: 2, lg: 5 }}>
          <TextInput
            type="date"
            label="Từ ngày"
            value={dateStart}
            onChange={(e) => setDateStart(e.currentTarget.value)}
          />
          <TextInput
            type="date"
            label="Đến ngày"
            value={dateEnd}
            onChange={(e) => setDateEnd(e.currentTarget.value)}
          />
          <SchoolScopeSelector
            schools={schools}
            selectedSchoolIds={schoolIds}
            onChange={setSchoolIds}
          />
          <TextInput
            label="Tìm kiếm"
            placeholder="Trường, điểm giao, PO hoặc PXK"
            value={search}
            onChange={(e) => setSearch(e.currentTarget.value)}
          />
          <Button mt={{ lg: 25 }} loading={loading} onClick={() => void load()}>
            Tải đối chiếu
          </Button>
        </SimpleGrid>
      </Card>
      {message && <Alert color="red">{message}</Alert>}
      <Card withBorder p={0}>
        <div style={{ overflowX: "auto" }}>
          <Table striped highlightOnHover>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Ngày</Table.Th>
                <Table.Th>Trường / điểm giao</Table.Th>
                <Table.Th>PO</Table.Th>
                <Table.Th>PXK</Table.Th>
                <Table.Th>Số lượng theo đơn vị</Table.Th>
                <Table.Th>Đối chiếu</Table.Th>
                <Table.Th>Vận hành</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {(data?.rows ?? []).map((row) => (
                <Table.Tr
                  key={`${row.service_date}:${row.school_id}:${row.delivery_location_id}`}
                >
                  <Table.Td>{row.service_date}</Table.Td>
                  <Table.Td>
                    <Text fw={600}>{row.school_name}</Text>
                    <Text size="sm" c="dimmed">
                      {row.delivery_location_name}
                    </Text>
                  </Table.Td>
                  <Table.Td>
                    {row.purchase_order_numbers.join(", ") || "—"}
                  </Table.Td>
                  <Table.Td>{row.pxk_document_number || "—"}</Table.Td>
                  <Table.Td>
                    <Stack gap={2}>
                      {row.quantity_totals_by_unit.map((total) => (
                        <Text size="sm" key={total.unit_id}>
                          {total.unit_code}: PO {total.po_quantity} / PXK{" "}
                          {total.pxk_quantity} / Δ {total.delta_quantity}
                        </Text>
                      ))}
                    </Stack>
                  </Table.Td>
                  <Table.Td>
                    <Badge color={statusColor(row.comparison_status)}>
                      {SCHOOL_FULFILMENT_STATUS_LABELS[row.comparison_status]}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Stack gap={4}>
                      <Badge
                        variant="light"
                        color={
                          row.pxk_state === "CURRENT"
                            ? "green"
                            : row.pxk_state === "READY"
                              ? "blue"
                              : "orange"
                        }
                      >
                        {SCHOOL_DISPATCH_STATE_LABELS[row.pxk_state]}
                      </Badge>
                      {row.blockers.map((code) => (
                        <Text key={code} size="xs" c="red">
                          {schoolDispatchBlockerLabel(code)}
                        </Text>
                      ))}
                    </Stack>
                  </Table.Td>
                </Table.Tr>
              ))}
              {data && data.rows.length === 0 && (
                <Table.Tr>
                  <Table.Td colSpan={7}>
                    <Text ta="center" c="dimmed" py="xl">
                      Không có phạm vi đối chiếu hiện hành phù hợp.
                    </Text>
                  </Table.Td>
                </Table.Tr>
              )}
            </Table.Tbody>
          </Table>
        </div>
      </Card>
      <Card withBorder>
        <Text fw={700} mb="sm">
          Chi tiết nguyên liệu
        </Text>
        <div style={{ overflowX: "auto" }}>
          <Table>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Nguyên liệu</Table.Th>
                <Table.Th>Đơn vị</Table.Th>
                <Table.Th>SL PO</Table.Th>
                <Table.Th>SL PXK</Table.Th>
                <Table.Th>Δ</Table.Th>
                <Table.Th>Nguồn chứng từ</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {(data?.rows ?? []).flatMap((row) =>
                row.details.map((detail) => (
                  <Table.Tr
                    key={`${row.service_date}:${row.school_id}:${detail.ingredient_id}:${detail.unit_id}`}
                  >
                    <Table.Td>{detail.ingredient_name}</Table.Td>
                    <Table.Td>{detail.unit_code}</Table.Td>
                    <Table.Td>{detail.po_quantity}</Table.Td>
                    <Table.Td>{detail.pxk_quantity}</Table.Td>
                    <Table.Td>{detail.delta_quantity}</Table.Td>
                    <Table.Td>
                      {[...row.purchase_order_numbers, row.pxk_document_number]
                        .filter(Boolean)
                        .join(" · ") || "—"}
                    </Table.Td>
                  </Table.Tr>
                )),
              )}
            </Table.Tbody>
          </Table>
        </div>
      </Card>
      <Group justify="space-between">
        <Text size="sm" c="dimmed">
          Chi tiết đối chiếu giữ nguyên độ chính xác từ PostgreSQL.
        </Text>
        <Badge variant="outline">Không có thao tác ghi</Badge>
      </Group>
    </Stack>
  );
}
