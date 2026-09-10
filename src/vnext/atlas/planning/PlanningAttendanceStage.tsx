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
} from "./usePlanningSources";
export function PlanningAttendanceStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [pasteOpen, setPasteOpen] = useState(false),
    [paste, setPaste] = useState("");
  const visible = c.attendanceRows
    .map((r, index) => ({ r, index }))
    .filter(
      ({ r }) =>
        r.service_date === c.date && visibleSchoolIds.includes(r.school_id),
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
          {valid
            ? `Học sinh ${students} · Giáo viên ${teachers} · Tổng ${students + teachers}`
            : "Cần sửa số suất trước khi tính tổng."}
        </Text>
        <Button
          size="sm"
          disabled={!c.canEdit}
          onClick={() => setPasteOpen(!pasteOpen)}
        >
          Dán hàng loạt
        </Button>
      </Flex>
      {pasteOpen && (
        <Box p="sm" bg="bg.subtle">
          <Text textStyle="helper">
            Mỗi dòng: Trường · Ngày · Học sinh · Giáo viên (cách bằng Tab). Thay
            thế dữ liệu cả tuần.
          </Text>
          <Textarea
            aria-label="Dữ liệu dán"
            value={paste}
            onChange={(e) => setPaste(e.target.value)}
            rows={3}
          />
          <Button
            size="sm"
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
      <Box
        overflow="auto"
        maxH={
          pasteOpen
            ? "var(--atlas-layout-planning-paste-table-height, max(140px, calc(100dvh - 640px)))"
            : c.locked
              ? "var(--atlas-layout-planning-recovery-table-height, max(160px, calc(100dvh - 570px)))"
              : "var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
        }
      >
        <Table.Root aria-label="Sĩ số theo trường" size="sm" stickyHeader>
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
                  <Table.Cell>{name}</Table.Cell>
                  {(["student_portions", "teacher_portions"] as const).map(
                    (field, i) => (
                      <Table.Cell key={field}>
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
                  <Table.Cell textAlign="right">
                    {validCount(r.student_portions) &&
                    validCount(r.teacher_portions)
                      ? Number(r.student_portions) + Number(r.teacher_portions)
                      : "—"}
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </Box>
    </>
  );
}
