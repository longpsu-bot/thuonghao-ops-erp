import {
  Box,
  Button,
  Flex,
  Input,
  Table,
  Text,
  Textarea,
} from "@chakra-ui/react";
import { useState } from "react";
import {
  validCount,
  type PlanningSourcesController,
  type PlanningSourcesProps,
} from "./usePlanningSources";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { atlasWorkbarControlHeight } from "../AtlasWorkbar";
export function PlanningAttendanceStage({
  c,
  visibleSchoolIds,
  onExportTemplate,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
  onExportTemplate?: PlanningSourcesProps["onExportAttendanceTemplate"];
}) {
  const [pasteOpen, setPasteOpen] = useState(false),
    [paste, setPaste] = useState("");
  const [templatePending, setTemplatePending] = useState(false);
  const [templateNotice, setTemplateNotice] = useState("");
  const schoolOrder = new Map(
    c.schools.map((school, index) => [school.school_id, index]),
  );
  const visible = c.attendanceRows
    .map((r, index) => ({ r, index }))
    .filter(
      ({ r }) =>
        r.service_date === c.date && visibleSchoolIds.includes(r.school_id),
    )
    .sort(
      (a, b) =>
        (schoolOrder.get(a.r.school_id) ?? Infinity) -
        (schoolOrder.get(b.r.school_id) ?? Infinity),
    );
  const valid = visible.every(
    ({ r }) => validCount(r.student_portions) && validCount(r.teacher_portions),
  );
  const students = visible.reduce(
      (sum, { r }) => sum + Number(r.student_portions),
      0,
    ),
    teachers = visible.reduce(
      (sum, { r }) => sum + Number(r.teacher_portions),
      0,
    );
  return (
    <>
      <Flex p="sm" gap="sm" align="center" justify="space-between" wrap="wrap">
        <Text textStyle="helper" color="fg.muted">
          {!visible.length
            ? "Không có sĩ số phù hợp bộ lọc trong ngày."
            : valid
              ? `Học sinh ${students} · Giáo viên ${teachers} · Tổng ${students + teachers}`
              : "Cần sửa số suất trước khi tính tổng."}
        </Text>
        <Flex gap="sm" wrap="wrap">
          <Button
            size="sm"
            h={atlasWorkbarControlHeight}
            disabled={!c.data || !onExportTemplate || templatePending}
            onClick={async () => {
              setTemplatePending(true);
              setTemplateNotice("");
              try {
                await onExportTemplate!(c.week, c.data!.schools);
                setTemplateNotice(
                  "Đã tải mẫu nhập. Sĩ số chỉ được ghi nhận sau khi rà soát và Lưu.",
                );
              } catch {
                setTemplateNotice("Không thể tải mẫu nhập sĩ số. Hãy thử lại.");
              } finally {
                setTemplatePending(false);
              }
            }}
          >
            Tải mẫu sĩ số XLSX
          </Button>
          <Button
            size="sm"
            h={atlasWorkbarControlHeight}
            disabled={!c.canEdit}
            onClick={() => setPasteOpen(!pasteOpen)}
          >
            Dán hàng loạt
          </Button>
        </Flex>
      </Flex>
      {templateNotice && (
        <Text role="status" px="sm" textStyle="helper">
          {templateNotice}
        </Text>
      )}
      {pasteOpen && (
        <Box p="sm" bg="bg.subtle">
          <Text textStyle="helper">
            Mỗi dòng: Trường · Ngày · Học sinh · Giáo viên (cách bằng Tab).{" "}
            <Text
              as="span"
              display={{ base: "inline", lg: "block" }}
              textStyle={{ base: "helper", lg: "label" }}
            >
              Thay thế dữ liệu cả tuần.
            </Text>
          </Text>
          <Textarea
            aria-label="Dữ liệu dán"
            value={paste}
            onChange={(e) => setPaste(e.target.value)}
            rows={3}
          />
          <Button
            size="sm"
            h={atlasWorkbarControlHeight}
            disabled={!paste.trim() || !c.canEdit}
            onClick={() => {
              c.pasteAttendance(paste);
              setPasteOpen(false);
            }}
          >
            Dùng dữ liệu dán
          </Button>
        </Box>
      )}
      <AtlasTableViewport
        label="Bảng sĩ số theo trường"
        maxH={
          pasteOpen
            ? "var(--atlas-layout-planning-paste-table-height, max(140px, calc(100dvh - 640px)))"
            : c.locked
              ? "var(--atlas-layout-planning-recovery-table-height, max(160px, calc(100dvh - 570px)))"
              : "var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
        }
      >
        <Table.Root
          aria-label="Sĩ số theo trường"
          tableLayout="fixed"
          w={{
            base: "full",
            md: "var(--atlas-attendance-table-width, 630px)",
          }}
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: "var(--atlas-attendance-table-width, 630px)",
          }}
          size="sm"
          stickyHeader
          css={{
            "@media(max-width:47.99rem)": {
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
              "& tr": {
                display: "grid",
                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                gridTemplateAreas:
                  '"school school" "student teacher" "total total"',
                columnGap: "var(--atlas-spacing-sm)",
                rowGap: "var(--atlas-spacing-xs)",
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
              '& td[data-attendance-field="school"]': {
                gridArea: "school",
                paddingBlockEnd: "var(--atlas-spacing-xs)",
                fontWeight: "600",
              },
              '& td[data-attendance-field="student"]': {
                gridArea: "student",
              },
              '& td[data-attendance-field="teacher"]': {
                gridArea: "teacher",
              },
              '& td[data-attendance-field="total"]': {
                gridArea: "total",
                display: "flex",
                alignItems: "baseline",
                justifyContent: "space-between",
                paddingBlockStart: "var(--atlas-spacing-xs)",
                textAlign: "start",
              },
              "& input": { width: "100%" },
            },
          }}
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-attendance-school-width, 300px)" />
            <Table.Column w="var(--atlas-attendance-count-width, 110px)" />
            <Table.Column w="var(--atlas-attendance-count-width, 110px)" />
            <Table.Column w="var(--atlas-attendance-total-width, 110px)" />
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row>
              <Table.ColumnHeader>Trường / điểm giao</Table.ColumnHeader>
              <Table.ColumnHeader textAlign="right">
                Học sinh
              </Table.ColumnHeader>
              <Table.ColumnHeader textAlign="right">
                Giáo viên
              </Table.ColumnHeader>
              <Table.ColumnHeader textAlign="right">Tổng</Table.ColumnHeader>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {visible.map(({ r, index }) => {
              const name =
                c.data?.schools.find((s) => s.school_id === r.school_id)
                  ?.school_name ?? "Trường chưa nhận diện";
              return (
                <Table.Row key={`${r.school_id}:${r.service_date}:${index}`}>
                  <Table.Cell data-attendance-field="school">{name}</Table.Cell>
                  {(["student_portions", "teacher_portions"] as const).map(
                    (field, i) => (
                      <Table.Cell
                        key={field}
                        data-attendance-field={i === 0 ? "student" : "teacher"}
                      >
                        <Text
                          hideFrom="md"
                          textStyle="helper"
                          color="fg.muted"
                          mb="xs"
                        >
                          {i === 0 ? "Học sinh" : "Giáo viên"}
                        </Text>
                        <Input
                          aria-label={`${i === 0 ? "Học sinh" : "Giáo viên"} ${name}`}
                          inputMode="numeric"
                          value={r[field]}
                          aria-invalid={!validCount(r[field])}
                          disabled={!c.canEdit}
                          onChange={(e) =>
                            c.editAttendance(index, field, e.target.value)
                          }
                          textAlign="right"
                          minW="var(--atlas-layout-count-width, 76px)"
                        />
                      </Table.Cell>
                    ),
                  )}
                  <Table.Cell data-attendance-field="total" textAlign="right">
                    <Text hideFrom="md" textStyle="helper" color="fg.muted">
                      Tổng
                    </Text>
                    <Text as="span" fontWeight="semibold">
                      {validCount(r.student_portions) &&
                      validCount(r.teacher_portions)
                        ? Number(r.student_portions) +
                          Number(r.teacher_portions)
                        : "—"}
                    </Text>
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
    </>
  );
}
