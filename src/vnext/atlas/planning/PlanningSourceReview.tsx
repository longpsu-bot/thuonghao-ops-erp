import { Box, Button, Flex, Heading, Table, Text } from "@chakra-ui/react";
import {
  activeMenuRows,
  attendanceReviewChanges,
  menuReviewChanges,
  viDate,
  type MenuLine,
  type AttendanceLine,
} from "../bridges/planning";
import type { PlanningSourcesController } from "./usePlanningSources";
import { planningPantryReviewRows } from "./planningPantryReviewRows";
export function PlanningSourceReview({ c }: { c: PlanningSourcesController }) {
  if (!c.preview) return null;
  const school = (id: string) =>
    c.data?.schools.find((s) => s.school_id === id)?.school_name ??
    "Trường chưa nhận diện";
  const dish = (id: string | null) =>
    id
      ? (c.data?.dishes.find((d) => d.dish_id === id)?.dish_name ??
        "Món chưa nhận diện")
      : "—";
  const changes =
    c.job === "menu"
      ? menuReviewChanges(
          activeMenuRows(c.data?.weekly_menu ?? null),
          c.preview.canonical_rows as MenuLine[],
        ).map((r) => ({
          school: school(r.school_id),
          context: `${viDate(r.service_date)} · ${c.data?.dish_types.find((t) => t.dish_type_code === r.menu_slot_code)?.dish_type_name ?? "Loại món"}`,
          before: dish(r.previous_dish_id),
          after: dish(r.proposed_dish_id),
          action: !r.previous_dish_id
            ? "Thêm"
            : !r.proposed_dish_id
              ? "Bỏ"
              : "Đổi",
        }))
      : c.job === "attendance"
        ? attendanceReviewChanges(
            c.previousAttendance,
            c.preview.canonical_rows as AttendanceLine[],
          ).map((r) => ({
            school: school(r.school_id),
            context: viDate(r.service_date),
            before: `HS ${r.previous_student_portions ?? "—"} · GV ${r.previous_teacher_portions ?? "—"}`,
            after: `HS ${r.proposed_student_portions ?? "—"} · GV ${r.proposed_teacher_portions ?? "—"}`,
            action: "Đổi",
          }))
        : planningPantryReviewRows(c);
  const correction =
    c.impact?.date_impacts.flatMap((d) =>
      [
        "PLANNING_RELEASE_CORRECTION_REQUIRED",
        "LEGACY_RANGE_CORRECTION_REQUIRED",
      ].includes(d.correction_policy)
        ? d.chains.filter((chain) => chain.confirmed_need_batch_id)
        : [],
    ) ?? [];
  const nextChain = correction[0];
  return (
    <Box
      as="aside"
      aria-label="Xem thay đổi"
      bg="bg.subtle"
      borderLeftWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      display="flex"
      flexDirection="column"
    >
      <Flex p="md" justify="space-between" align="center">
        <Box>
          <Heading as="h2" textStyle="section">
            Xem thay đổi
          </Heading>
          <Text textStyle="helper" color="fg.muted">
            {changes.length} thay đổi · toàn tuần
          </Text>
        </Box>
        <Button variant="utility" size="sm" onClick={c.closeReview}>
          Đóng
        </Button>
      </Flex>
      <Box
        overflow="auto"
        flex="1"
        maxH="var(--atlas-layout-review-height, max(240px, calc(100dvh - 510px)))"
        px="sm"
      >
        {changes.length > 0 && (
          <Table.Root size="sm" aria-label="So sánh thay đổi">
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeader>Trường</Table.ColumnHeader>
                <Table.ColumnHeader>Trước</Table.ColumnHeader>
                <Table.ColumnHeader>Đề xuất</Table.ColumnHeader>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {changes.map((r, i) => (
                <Table.Row key={i}>
                  <Table.Cell>
                    {r.school}
                    <Text textStyle="helper" color="fg.muted">
                      {r.context} · {r.action}
                    </Text>
                  </Table.Cell>
                  <Table.Cell>{r.before}</Table.Cell>
                  <Table.Cell>{r.after}</Table.Cell>
                </Table.Row>
              ))}
            </Table.Body>
          </Table.Root>
        )}
        {c.job === "pantry" && c.noAdditions && (
          <Text py="sm">Xác nhận toàn tuần không có bổ sung.</Text>
        )}
        {c.preview.issues.blockers.map((i, n) => (
          <Text role="alert" key={n} py="xs" color="status.danger">
            {i.message}
          </Text>
        ))}
        {c.preview.issues.warnings.map((i, n) => (
          <Text key={n} py="xs" textStyle="helper" color="status.warning">
            {i.message}
          </Text>
        ))}
        {c.impact?.date_impacts.map((d) => (
          <Text key={d.service_date} py="sm" textStyle="helper">
            {viDate(d.service_date)} · {d.operator_message}
          </Text>
        ))}
        {!c.impact?.save_allowed && (
          <Text color="status.warning" py="sm">
            Chưa thể lưu; cần kiểm tra điều kiện hoặc hoàn tất hiệu chỉnh.
          </Text>
        )}
      </Box>
      <Flex p="md" gap="sm" justify="end" wrap="wrap">
        <Button onClick={c.closeReview}>Quay lại</Button>
        {nextChain && !c.impact?.save_allowed ? (
          <Button
            variant="businessPrimary"
            disabled={!c.canEdit}
            onClick={() => void c.prepareCorrection(nextChain)}
          >
            Chuẩn bị hiệu chỉnh
          </Button>
        ) : (
          <Button
            variant="businessPrimary"
            disabled={
              !c.canEdit || !c.preview.can_save || !c.impact?.save_allowed
            }
            onClick={() => void c.save()}
          >
            Lưu
          </Button>
        )}
      </Flex>
    </Box>
  );
}
