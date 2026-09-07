import {
  Alert,
  Badge,
  Button,
  Card,
  Divider,
  Group,
  NativeSelect,
  SimpleGrid,
  Stack,
  Table,
  Text,
  TextInput,
  Textarea,
  Title,
} from "@mantine/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import { WorkbenchHeader } from "../WorkbenchComponents";
import {
  releaseSchoolDispatchDocumentRequest,
  schoolDispatchReleaseReadRequest,
  schoolDispatchWorkbenchFromResult,
  type SchoolDispatchReleaseApi,
} from "./schoolDispatchReleaseApi";
import {
  SCHOOL_DISPATCH_STATE_LABELS,
  schoolDispatchBlockerLabel,
  type SchoolDispatchDocument,
  type SchoolDispatchWorkbenchData,
  type SchoolDispatchWorkbenchRow,
} from "./schoolDispatchReleaseModel";
import {
  downloadSchoolDispatchPdf,
  downloadSchoolDispatchXlsx,
} from "./schoolDispatchReleaseExports";

function rowKey(row: SchoolDispatchWorkbenchRow) {
  return `${row.service_date}:${row.school_id}:${row.delivery_location_id}`;
}

function dateLabel(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function resultMessage(result: AtlasRpcResult) {
  if (result.kind === "success")
    return result.response.safe_operator_message ?? "Lệnh đã hoàn tất an toàn.";
  if (result.kind === "backend_error") return result.error.safe_message;
  return result.diagnostic.safeMessage;
}

function stateColor(state: SchoolDispatchWorkbenchRow["state"]) {
  if (state === "CURRENT") return "green";
  if (state === "READY") return "blue";
  if (state === "REPLACEMENT_REQUIRED") return "orange";
  return "red";
}

function uniqueDocuments(row: SchoolDispatchWorkbenchRow) {
  return Array.from(
    new Map(
      [row.current_release, ...row.history]
        .filter((item): item is SchoolDispatchDocument => item !== null)
        .map((item) => [item.school_dispatch_release_id, item]),
    ).values(),
  );
}

export function SchoolDispatchReleaseWorkbench({
  authState,
  api,
  initialDateStart,
  initialDateEnd,
  onExportXlsx = downloadSchoolDispatchXlsx,
  onExportPdf = downloadSchoolDispatchPdf,
}: {
  authState: AtlasAuthState;
  api?: SchoolDispatchReleaseApi;
  initialDateStart: string;
  initialDateEnd: string;
  mode?: "connected" | "review";
  onExportXlsx?: (document: SchoolDispatchDocument) => void | Promise<void>;
  onExportPdf?: (document: SchoolDispatchDocument) => void | Promise<void>;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [dateStart, setDateStart] = useState(initialDateStart);
  const [dateEnd, setDateEnd] = useState(initialDateEnd);
  const [schoolId, setSchoolId] = useState("");
  const [search, setSearch] = useState("");
  const [data, setData] = useState<SchoolDispatchWorkbenchData | null>(null);
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [loadMessage, setLoadMessage] = useState<string | null>(null);
  const [commandMessage, setCommandMessage] = useState<string | null>(null);
  const [commandFailed, setCommandFailed] = useState(false);
  const [unknownOutcome, setUnknownOutcome] = useState(false);
  const [releaseNote, setReleaseNote] = useState("");
  const readIntent = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const loadAuthoritative = useCallback(async () => {
    if (!api || !authSubject) return false;
    const intent = ++readIntent.current;
    setLoading(true);
    const result = await api.getWorkbench(
      schoolDispatchReleaseReadRequest(authSubject, correlationId, {
        date_start: dateStart,
        date_end: dateEnd,
        school_ids: schoolId ? [schoolId] : [],
        search: search.trim() || null,
      }),
    );
    if (intent !== readIntent.current) return false;
    setLoading(false);
    const next = schoolDispatchWorkbenchFromResult(result);
    if (!next) {
      setLoadMessage(resultMessage(result));
      return false;
    }
    setData(next);
    setLoadMessage(null);
    setSelectedKey((current) =>
      current && next.rows.some((row) => rowKey(row) === current)
        ? current
        : next.rows[0]
          ? rowKey(next.rows[0])
          : null,
    );
    return true;
  }, [api, authSubject, correlationId, dateEnd, dateStart, schoolId, search]);

  useEffect(() => {
    void loadAuthoritative();
  }, [loadAuthoritative]);

  const selected =
    data?.rows.find((row) => rowKey(row) === selectedKey) ?? null;
  const schools = useMemo(
    () =>
      Array.from(
        new Map(
          (data?.rows ?? []).map((row) => [
            row.school_id,
            row.preview.school_name,
          ]),
        ),
        ([value, label]) => ({ value, label }),
      ),
    [data],
  );

  const reloadAfterUnknown = async () => {
    const current = await loadAuthoritative();
    if (current) {
      setUnknownOutcome(false);
      setCommandFailed(false);
      setCommandMessage("Đã tải lại dữ liệu hiện hành để xác nhận kết quả.");
    }
  };

  const release = async (row: SchoolDispatchWorkbenchRow) => {
    if (!api || !authSubject || busy || unknownOutcome) return;
    setBusy(true);
    setCommandMessage(null);
    setCommandFailed(false);
    const result = await api.releaseDocument(
      releaseSchoolDispatchDocumentRequest(
        authSubject,
        correlationId,
        row.expected_version,
        {
          service_date: row.service_date,
          school_id: row.school_id,
          delivery_location_id: row.delivery_location_id,
          expected_source_fingerprint: row.preview.source_fingerprint,
          predecessor_release_id:
            row.current_release?.school_dispatch_release_id ?? null,
        },
        releaseNote,
      ),
    );
    setBusy(false);
    setCommandMessage(resultMessage(result));
    if (result.kind === "transport_error") {
      setUnknownOutcome(true);
      setCommandFailed(true);
      return;
    }
    if (result.kind !== "success") {
      setCommandFailed(true);
      if (
        result.kind === "backend_error" &&
        ["STALE_VERSION", "SOURCE_CHANGED", "PXK_NOT_READY"].includes(
          result.error.error_code,
        )
      )
        await loadAuthoritative();
      return;
    }
    setReleaseNote("");
    await loadAuthoritative();
  };

  if (!authSubject) {
    return (
      <Alert color="yellow" title="Cần đăng nhập">
        Đăng nhập Atlas để xem Phiếu xuất kho theo phạm vi được cấp.
      </Alert>
    );
  }

  return (
    <Stack gap="lg" p={{ base: "md", md: "xl" }}>
      <WorkbenchHeader
        eyebrow="Kho"
        title="Phiếu xuất kho"
        context="Xem trước số lượng theo nhu cầu, phân bổ và đơn mua hiện hành; sau đó phát hành một chứng từ chính thức cho từng trường, ngày và điểm giao."
      />

      <Alert color="blue" title="Bản xem trước chỉ đọc">
        Phiếu xuất kho không có bản nháp. Chứng từ chỉ được tạo khi bạn chọn
        phát hành; chứng từ đã phát hành luôn được giữ nguyên để tra cứu và xuất
        lại.
      </Alert>

      <Card withBorder>
        <SimpleGrid cols={{ base: 1, sm: 2, lg: 5 }}>
          <TextInput
            type="date"
            label="Từ ngày"
            value={dateStart}
            onChange={(event) => setDateStart(event.currentTarget.value)}
          />
          <TextInput
            type="date"
            label="Đến ngày"
            value={dateEnd}
            onChange={(event) => setDateEnd(event.currentTarget.value)}
          />
          <NativeSelect
            label="Trường"
            value={schoolId}
            onChange={(event) => setSchoolId(event.currentTarget.value)}
            data={[{ value: "", label: "Tất cả trường" }, ...schools]}
          />
          <TextInput
            label="Tìm kiếm"
            placeholder="Trường, điểm giao hoặc số phiếu"
            value={search}
            onChange={(event) => setSearch(event.currentTarget.value)}
          />
          <Button
            mt={{ lg: 25 }}
            loading={loading}
            onClick={() => void loadAuthoritative()}
          >
            Tải dữ liệu hiện hành
          </Button>
        </SimpleGrid>
      </Card>

      {loadMessage && (
        <Alert color="red" title="Không thể tải dữ liệu">
          {loadMessage}
        </Alert>
      )}
      {commandMessage && (
        <Alert
          color={commandFailed ? "orange" : "green"}
          title={unknownOutcome ? "Kết quả chưa rõ" : "Kết quả thao tác"}
        >
          <Stack gap="xs">
            <Text>{commandMessage}</Text>
            {unknownOutcome && (
              <>
                <Text>
                  Atlas đã khóa thao tác phát hành tiếp theo để tránh tạo chứng
                  từ lặp. Hãy tải lại dữ liệu hiện hành trước khi tiếp tục.
                </Text>
                <Button
                  variant="light"
                  loading={loading}
                  onClick={() => void reloadAfterUnknown()}
                >
                  Tải lại để xác nhận
                </Button>
              </>
            )}
          </Stack>
        </Alert>
      )}

      <SimpleGrid cols={{ base: 1, lg: 2 }}>
        <Card withBorder>
          <Stack gap="sm">
            <Group justify="space-between">
              <Title order={2}>Trường và ngày phục vụ</Title>
              <Badge variant="light">{data?.rows.length ?? 0} mục</Badge>
            </Group>
            {!loading && data?.rows.length === 0 && (
              <Text c="dimmed">Không có phạm vi Phiếu xuất kho phù hợp.</Text>
            )}
            {(data?.rows ?? []).map((row) => (
              <Button
                key={rowKey(row)}
                variant={selectedKey === rowKey(row) ? "light" : "subtle"}
                color={stateColor(row.state)}
                justify="space-between"
                onClick={() => {
                  const nextKey = rowKey(row);
                  if (nextKey !== selectedKey) setReleaseNote("");
                  setSelectedKey(nextKey);
                }}
              >
                <span>{row.preview.school_name}</span>
                <span>{dateLabel(row.service_date)}</span>
              </Button>
            ))}
          </Stack>
        </Card>

        <Card withBorder>
          {!selected ? (
            <Text c="dimmed">Chọn một trường và ngày để xem nội dung.</Text>
          ) : (
            <Stack gap="md">
              <Group justify="space-between" align="flex-start">
                <div>
                  <Title order={2}>{selected.preview.school_name}</Title>
                  <Text c="dimmed">
                    {dateLabel(selected.service_date)} ·{" "}
                    {selected.preview.delivery_location_name}
                  </Text>
                  <Text size="sm" c="dimmed">
                    {selected.preview.delivery_address}
                  </Text>
                </div>
                <Badge color={stateColor(selected.state)}>
                  {SCHOOL_DISPATCH_STATE_LABELS[selected.state]}
                </Badge>
              </Group>

              {selected.state === "REPLACEMENT_REQUIRED" && (
                <Alert color="orange" title="Nội dung đã thay đổi">
                  Cần phát hành một Phiếu xuất kho thay thế. Phiếu cũ vẫn được
                  lưu nguyên và có thể xuất lại.
                </Alert>
              )}
              {selected.blockers.map((blocker) => (
                <Alert key={blocker} color="red" title="Chưa thể phát hành">
                  <Stack gap={4}>
                    <Text>{schoolDispatchBlockerLabel(blocker)}</Text>
                    {blocker === "CANCELLATION_REQUIRED" && (
                      <Text size="sm">
                        Atlas không tự hủy đơn mua hoặc tạo chứng từ hủy. Hãy xử
                        lý cam kết nhà cung ứng theo quy trình được phê duyệt
                        trước.
                      </Text>
                    )}
                  </Stack>
                </Alert>
              ))}

              <div style={{ overflowX: "auto" }}>
                <Table striped highlightOnHover>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>Nguyên liệu</Table.Th>
                      <Table.Th ta="right">Số lượng</Table.Th>
                      <Table.Th>Đơn vị</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {selected.preview.lines.map((line) => (
                      <Table.Tr key={`${line.ingredient_id}:${line.unit_id}`}>
                        <Table.Td>{line.ingredient_name}</Table.Td>
                        <Table.Td ta="right">{line.quantity}</Table.Td>
                        <Table.Td>{line.unit_code}</Table.Td>
                      </Table.Tr>
                    ))}
                  </Table.Tbody>
                </Table>
              </div>

              {(selected.allowed_actions.release ||
                selected.allowed_actions.replace) && (
                <Stack gap="sm">
                  <Textarea
                    label="Ghi chú trên phiếu (không bắt buộc)"
                    description="Ghi chú này được lưu nguyên trên chứng từ đã phát hành."
                    maxLength={500}
                    value={releaseNote}
                    onChange={(event) =>
                      setReleaseNote(event.currentTarget.value)
                    }
                  />
                  <Button
                    color={selected.allowed_actions.replace ? "orange" : "blue"}
                    loading={busy}
                    disabled={unknownOutcome}
                    onClick={() => void release(selected)}
                  >
                    {selected.allowed_actions.replace
                      ? "Phát hành phiếu thay thế"
                      : "Phát hành phiếu xuất kho"}
                  </Button>
                </Stack>
              )}

              {uniqueDocuments(selected).length > 0 && (
                <>
                  <Divider />
                  <Title order={3}>Chứng từ đã phát hành</Title>
                  {uniqueDocuments(selected).map((document) => (
                    <Card key={document.school_dispatch_release_id} withBorder>
                      <Group justify="space-between" align="center">
                        <div>
                          <Text fw={600}>{document.document_number}</Text>
                          <Text size="sm" c="dimmed">
                            {document.status === "SUPERSEDED"
                              ? "Đã được thay thế · vẫn có thể xuất lại"
                              : "Đang hiện hành"}
                          </Text>
                        </div>
                        <Group gap="xs">
                          <Button
                            size="xs"
                            variant="light"
                            onClick={() => void onExportXlsx(document)}
                          >
                            Xuất Excel
                          </Button>
                          <Button
                            size="xs"
                            variant="light"
                            onClick={() => void onExportPdf(document)}
                          >
                            Xuất PDF
                          </Button>
                        </Group>
                      </Group>
                    </Card>
                  ))}
                </>
              )}
            </Stack>
          )}
        </Card>
      </SimpleGrid>
    </Stack>
  );
}
