import {
  Box,
  Button,
  Field,
  Flex,
  Heading,
  Stack,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useState, type RefObject } from "react";
import {
  schoolDispatchBlockerLabel,
  type SchoolDispatchDocument,
  type SchoolDispatchLine,
  type SchoolDispatchWorkbenchRow,
} from "../bridges/schoolDispatch";
import { schoolPxkQuantity } from "./schoolPxkQuantity";
import { pxkLabels } from "./SchoolPxkTable";
import type { SchoolPxkWorkbenchProps } from "./useSchoolPxkWorkbench";
function Lines({
  lines,
  label,
}: {
  lines: SchoolDispatchLine[];
  label: string;
}) {
  return (
    <Table.ScrollArea overflowX="auto">
      <Table.Root size="sm" aria-label={label}>
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeader>Nguyên liệu</Table.ColumnHeader>
            <Table.ColumnHeader textAlign="end">Số lượng</Table.ColumnHeader>
            <Table.ColumnHeader>Đơn vị</Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {lines.map((l) => (
            <Table.Row key={`${l.ingredient_id}:${l.unit_id}`}>
              <Table.Cell>{l.ingredient_name}</Table.Cell>
              <Table.Cell textAlign="end" whiteSpace="nowrap">
                {schoolPxkQuantity(l.quantity)}
              </Table.Cell>
              <Table.Cell>{l.unit_code}</Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table.Root>
    </Table.ScrollArea>
  );
}
type Exports = Pick<SchoolPxkWorkbenchProps, "onExportXlsx" | "onExportPdf">;
function OfficialDocument({
  document,
  collapsed = false,
  ...exports
}: { document: SchoolDispatchDocument; collapsed?: boolean } & Exports) {
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const run = async (callback: NonNullable<Exports["onExportXlsx"]>) => {
    if (exporting) return;
    setExporting(true);
    setError(null);
    try {
      await callback(document);
    } catch {
      setError("Không thể xuất phiếu. Vui lòng thử lại.");
    } finally {
      setExporting(false);
    }
  };
  return (
    <Stack gap="xs">
      <Flex justify="space-between" align="start" gap="xs" wrap="wrap">
        <Box>
          <Text fontWeight="semibold">{document.document_number}</Text>
          <Text textStyle="helper" color="fg.muted">
            {document.status === "SUPERSEDED"
              ? "Đã được thay thế"
              : "Phiếu chính thức"}{" "}
            ·{" "}
            {new Date(document.released_at).toLocaleString("vi-VN", {
              timeZone: "Asia/Ho_Chi_Minh",
            })}
          </Text>
        </Box>
        {document.export_ready && (
          <Flex gap="xs">
            {exports.onExportXlsx && (
              <Button
                size="sm"
                variant="utility"
                disabled={exporting}
                onClick={() => void run(exports.onExportXlsx!)}
              >
                XLSX
              </Button>
            )}
            {exports.onExportPdf && (
              <Button
                size="sm"
                variant="utility"
                disabled={exporting}
                onClick={() => void run(exports.onExportPdf!)}
              >
                PDF
              </Button>
            )}
          </Flex>
        )}
      </Flex>
      {error && (
        <Text role="alert" color="status.danger">
          {error}
        </Text>
      )}
      {collapsed ? (
        <details>
          <summary>Nội dung phiếu hiện hành · giữ nguyên</summary>
          {document.note && (
            <Text textStyle="helper">Ghi chú: {document.note}</Text>
          )}
          <Lines
            lines={document.lines}
            label={`Nội dung ${document.document_number}`}
          />
        </details>
      ) : (
        <>
          {document.note && (
            <Text textStyle="helper">Ghi chú: {document.note}</Text>
          )}
          <Lines
            lines={document.lines}
            label={`Nội dung ${document.document_number}`}
          />
        </>
      )}
    </Stack>
  );
}
export function SchoolPxkDetail({
  row,
  note,
  onNote,
  canRelease,
  actionAllowed,
  busy,
  locked,
  onRelease,
  onClose,
  detailRef,
  ...exports
}: {
  row: SchoolDispatchWorkbenchRow;
  note: string;
  onNote: (s: string) => void;
  canRelease: boolean;
  actionAllowed: boolean;
  busy: boolean;
  locked: boolean;
  onRelease: () => void;
  onClose: () => void;
  detailRef: RefObject<HTMLDivElement | null>;
} & Exports) {
  const identity =
    row.state === "CURRENT" && row.current_release
      ? row.current_release
      : row.preview;
  const history = Array.from(
    new Map(
      row.history
        .filter(
          (d) =>
            d.school_dispatch_release_id !==
            row.current_release?.school_dispatch_release_id,
        )
        .map((d) => [d.school_dispatch_release_id, d]),
    ).values(),
  );
  return (
    <Flex
      ref={detailRef}
      role="region"
      aria-label="Nội dung phiếu"
      tabIndex={-1}
      direction="column"
      bg="bg.subtle"
      minW="var(--atlas-layout-zero, 0)"
      maxH={{
        base: "var(--atlas-layout-pxk-mobile-detail, none)",
        lg: "var(--atlas-layout-pxk-detail, calc(100dvh - 290px))",
      }}
      borderLeftWidth={{
        base: "var(--atlas-layout-zero, 0)",
        lg: "var(--atlas-layout-edge, 1px)",
      }}
      borderColor="border.subtle"
      _focusVisible={{
        outlineWidth: "var(--atlas-layout-focus-width, 2px)",
        outlineStyle: "solid",
        outlineColor: "focus.ring",
      }}
    >
      <Flex px="md" pt="sm" justify="space-between" align="start" gap="xs">
        <Box>
          <Heading as="h2" textStyle="section">
            {identity.school_name}
          </Heading>
          <Text textStyle="helper" color="fg.primary">
            {pxkLabels[row.state]}
          </Text>
        </Box>
        <Button
          size="sm"
          variant="utility"
          aria-label="Đóng chi tiết"
          disabled={busy || locked}
          onClick={onClose}
        >
          Đóng
        </Button>
      </Flex>
      <Stack
        p="md"
        pt="xs"
        gap="sm"
        overflowY="auto"
        minH="var(--atlas-layout-zero, 0)"
      >
        <Box>
          <Text>
            {identity.delivery_location_name} ·{" "}
            {identity.service_date.split("-").reverse().join("/")}
          </Text>
          <Text textStyle="helper" color="fg.muted">
            {identity.delivery_address}
          </Text>
        </Box>
        {row.state === "REPLACEMENT_REQUIRED" && (
          <Text color="status.warning">
            Nội dung nguồn đã thay đổi. Cần phát hành phiếu thay thế.
          </Text>
        )}
        {Array.from(new Set([...row.blockers, ...row.preview.blockers])).map(
          (code) => (
            <Box
              key={code}
              role="note"
              borderLeftWidth="var(--atlas-layout-rail, 3px)"
              borderColor="status.danger"
              pl="sm"
            >
              <Text color="status.danger">
                {schoolDispatchBlockerLabel(code)}
              </Text>
              {code === "CANCELLATION_REQUIRED" && (
                <Text textStyle="helper">
                  Atlas không tự hủy đơn mua hoặc tạo chứng từ hủy. Hãy xử lý
                  cam kết nhà cung ứng theo quy trình được phê duyệt trước.
                </Text>
              )}
            </Box>
          ),
        )}
        {row.state === "CURRENT" && row.current_release ? (
          <OfficialDocument document={row.current_release} {...exports} />
        ) : (
          <>
            {row.current_release && (
              <OfficialDocument
                document={row.current_release}
                collapsed
                {...exports}
              />
            )}
            <Box>
              {row.state === "REPLACEMENT_REQUIRED" && (
                <Text textStyle="label" mb="xs">
                  Nội dung phiếu thay thế
                </Text>
              )}
              <Lines lines={row.preview.lines} label="Nội dung dự kiến" />
            </Box>
            {actionAllowed && (
              <Field.Root>
                <Field.Label>Ghi chú trên phiếu</Field.Label>
                <Textarea
                  aria-label="Ghi chú trên phiếu"
                  value={note}
                  maxLength={500}
                  rows={2}
                  disabled={busy || locked || !canRelease}
                  onChange={(e) => onNote(e.target.value)}
                />
                <Field.HelperText>Không bắt buộc</Field.HelperText>
              </Field.Root>
            )}
          </>
        )}
        {history.length > 0 && (
          <Box
            asChild
            borderTopWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.subtle"
            pt="sm"
          >
            <details>
              <summary>Lịch sử phiếu</summary>
              <Stack gap="md" mt="sm">
                {history.map((d) => (
                  <OfficialDocument
                    key={d.school_dispatch_release_id}
                    document={d}
                    {...exports}
                  />
                ))}
              </Stack>
            </details>
          </Box>
        )}
      </Stack>
      {actionAllowed && (
        <Box
          p="sm"
          mt="var(--atlas-layout-auto, auto)"
          borderTopWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.subtle"
        >
          <Button
            w="full"
            variant="businessPrimary"
            disabled={!canRelease}
            loading={busy}
            onClick={onRelease}
          >
            {row.state === "REPLACEMENT_REQUIRED"
              ? "Phát hành phiếu thay thế"
              : "Phát hành phiếu xuất kho"}
          </Button>
        </Box>
      )}
    </Flex>
  );
}
