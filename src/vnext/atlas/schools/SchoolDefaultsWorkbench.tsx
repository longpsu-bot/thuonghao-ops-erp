import { SchoolDefaultsExitDialog } from "./SchoolDefaultsExitDialog";
import {
  Box,
  Badge,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Table,
  Text,
} from "@chakra-ui/react";
import { useImperativeHandle } from "react";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import type { SchoolMasterData } from "../bridges/schoolMasterData";
import { parsePortionDraft } from "./schoolDefaultsModel";
import {
  useSchoolDefaultsWorkbench,
  type SchoolDefaultsWorkbenchProps,
} from "./useSchoolDefaultsWorkbench";

export function SchoolDefaultsWorkbench(props: SchoolDefaultsWorkbenchProps) {
  const c = useSchoolDefaultsWorkbench(props);
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  const editingDisabled =
    c.saving ||
    c.lock === "unknown" ||
    c.lock === "readback";
  const activeCount = c.schools.filter(
    (school) => school.school_status === "ACTIVE",
  ).length;

  return (
    <Box
      as="section"
      aria-label="Sĩ số mặc định"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <SchoolDefaultsExitDialog
        open={c.exitPending}
        onCancel={c.cancelExit}
        onDiscard={c.discardExit}
      />
      <Box p="md">
        <Text textStyle="helper" color="fg.muted">
          Trường học
        </Text>
        <Heading as="h1" textStyle="workbenchTitle">
          Sĩ số mặc định
        </Heading>
      </Box>

      <Grid
        bg="bg.toolbar"
        p="md"
        gap="sm"
        alignItems="end"
        templateColumns={{
          base: "minmax(0, 1fr)",
          md: "repeat(2, minmax(0, 1fr))",
          xl: "minmax(240px, 1.4fr) minmax(180px, 1fr) auto",
        }}
      >
        <Field.Root>
          <Field.Label>Tìm trường</Field.Label>
          <Input
            aria-label="Tìm trường"
            placeholder="Tên, mã, loại, khách hàng hoặc điểm giao"
            value={c.query}
            onChange={(event) => c.setQuery(event.target.value)}
          />
        </Field.Root>
        <Field.Root>
          <Field.Label>Loại trường</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label="Loại trường"
              value={c.schoolType}
              onChange={(event) => c.setSchoolType(event.target.value)}
            >
              <option value="ALL">Tất cả</option>
              {c.schoolTypes.map((type) => (
                <option value={type} key={type}>
                  {type}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <AtlasRefreshButton
          loading={c.loading}
          disabled={
            c.saving ||
            c.lock === "unknown" ||
            c.lock === "readback"
          }
          onClick={() => void c.refresh()}
        />
      </Grid>

      {(c.notice || c.error) && (
        <Box
          role={c.lock || c.error ? "alert" : "status"}
          aria-live="polite"
          px="md"
          pt="sm"
        >
          <Text
            color={
              c.lock
                ? "status.warning"
                : c.error
                  ? "status.danger"
                  : "status.success"
            }
          >
            {c.notice ?? c.error}
          </Text>
          {(c.lock || c.error) && (
            <Button
              mt="xs"
              size="sm"
              loading={c.loading}
              onClick={() => void c.refresh()}
            >
              {c.lock === "unknown" || c.lock === "readback"
                ? "Tải lại để xác nhận"
                : c.lock === "stale"
                  ? "Tải lại dữ liệu hiện tại"
                  : "Thử tải lại dữ liệu"}
            </Button>
          )}
        </Box>
      )}

      <Flex
        px="md"
        py="sm"
        align="center"
        justify="space-between"
        gap="sm"
        wrap="wrap"
      >
        <Box aria-live="polite">
          <Text textStyle="helper" color="fg.muted">
            {c.schools.length} trường · {activeCount} đang hoạt động ·{" "}
            {c.dirtyCount} thay đổi chưa lưu
            {c.hiddenDirtyCount > 0
              ? ` · ${c.hiddenDirtyCount} thay đổi ngoài bộ lọc`
              : ""}
          </Text>
          {c.invalidDraftCount > 0 && (
            <Text textStyle="helper" color="status.danger">
              {c.invalidDraftCount} trường có dữ liệu chưa hợp lệ
            </Text>
          )}
        </Box>
        <Button
          variant="businessPrimary"
          loading={c.saving}
          disabled={
            c.loading ||
            c.saving ||
            Boolean(c.lock) ||
            c.dirtyCount === 0 ||
            c.invalidDraftCount > 0
          }
          onClick={() => void c.save()}
        >
          Lưu thay đổi
        </Button>
      </Flex>

      {c.loading && c.schools.length === 0 && (
        <Text role="status" p="md">
          Đang tải dữ liệu trường học…
        </Text>
      )}
      {!c.loading && !c.error && c.schools.length === 0 && (
        <Text p="md">Chưa có trường học.</Text>
      )}

      <SchoolDefaultsTable
        schools={c.visibleSchools}
        drafts={c.drafts}
        disabled={editingDisabled}
        onEdit={c.edit}
      />
    </Box>
  );
}

function SchoolDefaultsTable({
  schools,
  drafts,
  disabled,
  onEdit,
}: {
  schools: SchoolMasterData[];
  drafts: Record<string, { student: string; teacher: string }>;
  disabled: boolean;
  onEdit: (
    school: SchoolMasterData,
    field: "student" | "teacher",
    value: string,
  ) => void;
}) {
  if (!schools.length)
    return <Text p="md">Không có trường phù hợp bộ lọc.</Text>;
  return (
    <Box overflowX="auto" minW="var(--atlas-layout-zero, 0)">
      <Table.Root
        size="sm"
        aria-label="Sĩ số mặc định theo trường"
        minW="var(--atlas-layout-school-table-min, 850px)"
      >
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeader width="var(--atlas-layout-school-order-width, 56px)">
              #
            </Table.ColumnHeader>
            <Table.ColumnHeader>Trường</Table.ColumnHeader>
            <Table.ColumnHeader>Loại trường</Table.ColumnHeader>
            <Table.ColumnHeader>Trạng thái</Table.ColumnHeader>
            <Table.ColumnHeader>Điểm giao</Table.ColumnHeader>
            <Table.ColumnHeader textAlign="right">
              Học sinh mặc định
            </Table.ColumnHeader>
            <Table.ColumnHeader textAlign="right">
              Giáo viên mặc định
            </Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {schools.map((school) => {
            const draft = drafts[school.school_id] ?? {
              student: String(school.default_student_portions),
              teacher: String(school.default_teacher_portions),
            };
            const dirty = Boolean(drafts[school.school_id]);
            const studentInvalid = parsePortionDraft(draft.student) === null;
            const teacherInvalid = parsePortionDraft(draft.teacher) === null;
            return (
              <Table.Row
                key={school.school_id}
                bg={dirty ? "bg.selected" : undefined}
              >
                <Table.Cell
                  borderLeftWidth="var(--atlas-layout-rail, 3px)"
                  borderLeftColor={dirty ? "border.accent" : "transparent"}
                  fontVariantNumeric="tabular-nums"
                >
                  {school.display_order}
                </Table.Cell>
                <Table.Cell>
                  <Text fontWeight="semibold">{school.school_name}</Text>
                  <Text
                    textStyle="helper"
                    color={dirty ? "fg.primary" : "fg.muted"}
                  >
                    {school.school_code} · {school.customer_name}
                  </Text>
                </Table.Cell>
                <Table.Cell>
                  {school.school_type_name ?? "Chưa phân loại"}
                </Table.Cell>
                <Table.Cell>
                  <Badge
                    variant={
                      school.school_status === "ACTIVE" ? "success" : "neutral"
                    }
                  >
                    {school.school_status === "ACTIVE"
                      ? "Đang hoạt động"
                      : "Ngừng hoạt động"}
                  </Badge>
                </Table.Cell>
                <Table.Cell>
                  <Text>{school.delivery_location_name}</Text>
                  <Text
                    textStyle="helper"
                    color={dirty ? "fg.primary" : "fg.muted"}
                  >
                    {school.delivery_address}
                  </Text>
                </Table.Cell>
                <Table.Cell>
                  <Input
                    type="text"
                    inputMode="numeric"
                    aria-label={`Học sinh mặc định — ${school.school_name}`}
                    aria-invalid={studentInvalid}
                    value={draft.student}
                    disabled={disabled}
                    size="sm"
                    h="compact"
                    minW="var(--atlas-layout-portion-input, 92px)"
                    textAlign="right"
                    onChange={(event) =>
                      onEdit(school, "student", event.target.value)
                    }
                  />
                </Table.Cell>
                <Table.Cell>
                  <Input
                    type="text"
                    inputMode="numeric"
                    aria-label={`Giáo viên mặc định — ${school.school_name}`}
                    aria-invalid={teacherInvalid}
                    value={draft.teacher}
                    disabled={disabled}
                    size="sm"
                    h="compact"
                    minW="var(--atlas-layout-portion-input, 92px)"
                    textAlign="right"
                    onChange={(event) =>
                      onEdit(school, "teacher", event.target.value)
                    }
                  />
                </Table.Cell>
              </Table.Row>
            );
          })}
        </Table.Body>
      </Table.Root>
    </Box>
  );
}
