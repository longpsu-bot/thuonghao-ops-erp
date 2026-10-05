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
import { useImperativeHandle, useState } from "react";
import { useAtlasWorkbenchStatus } from "../AtlasModuleExit";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import { AtlasTableViewport } from "../AtlasTableViewport";
import {
  atlasDefaultSort,
  compareAtlasNumber,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";
import type { SchoolMasterData } from "../bridges/schoolMasterData";
import { parsePortionDraft } from "./schoolDefaultsModel";
import {
  useSchoolDefaultsWorkbench,
  type SchoolDefaultsWorkbenchProps,
} from "./useSchoolDefaultsWorkbench";

export function SchoolDefaultsWorkbench(props: SchoolDefaultsWorkbenchProps) {
  const c = useSchoolDefaultsWorkbench(props);
  useAtlasWorkbenchStatus(props.onWorkspaceStatus, {
    unsaved: c.dirtyCount > 0,
    blocked: c.saving || c.loading || Boolean(c.lock),
    attention: c.lock
      ? "Cần xác nhận dữ liệu hiện tại"
      : c.saving
        ? "Đang lưu"
        : undefined,
  });
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  const editingDisabled =
    c.saving || c.lock === "unknown" || c.lock === "readback";
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
          disabled={c.saving || c.lock === "unknown" || c.lock === "readback"}
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

      {c.schools.length > 0 && (
        <SchoolDefaultsTable
          schools={c.visibleSchools}
          drafts={c.drafts}
          disabled={editingDisabled}
          onEdit={c.edit}
        />
      )}
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
  type SortKey = "order" | "school" | "type" | "status" | "location";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  if (!schools.length)
    return <Text p="md">Không có trường phù hợp bộ lọc.</Text>;
  const sortedSchools = sortAtlasRows(schools, sort, {
    order: (left, right) =>
      compareAtlasNumber(left.display_order, right.display_order),
    school: (left, right) =>
      compareAtlasText(left.school_name, right.school_name),
    type: (left, right) =>
      compareAtlasText(left.school_type_name, right.school_type_name),
    status: (left, right) =>
      compareAtlasText(left.school_status, right.school_status),
    location: (left, right) =>
      compareAtlasText(
        left.delivery_location_name,
        right.delivery_location_name,
      ),
  });
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <AtlasTableViewport
      label="Bảng sĩ số mặc định theo trường"
      maxH={{
        base: "var(--atlas-layout-school-table-mobile-height, 55dvh)",
        lg: "var(--atlas-layout-school-table-height, calc(100dvh - 350px))",
      }}
    >
      <Table.Root
        size="sm"
        aria-label="Sĩ số mặc định theo trường"
        data-sticky-header=""
        stickyHeader
        tableLayout="fixed"
        minW="var(--atlas-layout-school-table-min, 1154px)"
        w="var(--atlas-layout-school-table-width, 1154px)"
      >
        <Table.ColumnGroup>
          <Table.Column w="var(--atlas-school-order-width, 64px)" />
          <Table.Column w="var(--atlas-school-identity-width, 240px)" />
          <Table.Column w="var(--atlas-school-type-width, 150px)" />
          <Table.Column w="var(--atlas-school-state-width, 140px)" />
          <Table.Column w="var(--atlas-school-location-width, 260px)" />
          <Table.Column w="var(--atlas-school-portion-width, 150px)" />
          <Table.Column w="var(--atlas-school-portion-width, 150px)" />
        </Table.ColumnGroup>
        <Table.Header>
          <Table.Row zIndex="var(--atlas-layout-sticky-header-z, 3)">
            <AtlasSortableColumnHeader
              label="#"
              columnKey="order"
              sort={sort}
              onSort={onSort}
            />
            <AtlasSortableColumnHeader
              label="Trường"
              columnKey="school"
              sort={sort}
              onSort={onSort}
            />
            <AtlasSortableColumnHeader
              label="Loại trường"
              columnKey="type"
              sort={sort}
              onSort={onSort}
            />
            <AtlasSortableColumnHeader
              label="Trạng thái"
              columnKey="status"
              sort={sort}
              onSort={onSort}
            />
            <AtlasSortableColumnHeader
              label="Điểm giao"
              columnKey="location"
              sort={sort}
              onSort={onSort}
            />
            <Table.ColumnHeader textAlign="right">
              Học sinh mặc định
            </Table.ColumnHeader>
            <Table.ColumnHeader textAlign="right">
              Giáo viên mặc định
            </Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {sortedSchools.map((school) => {
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
    </AtlasTableViewport>
  );
}
