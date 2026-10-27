import { atlasVisuallyHidden } from "../AtlasTaskTabs";
import {
  atlasSecondaryTabList,
  atlasSecondaryTabTrigger,
} from "../AtlasTaskTabs";
import { SchoolDefaultsExitDialog } from "./SchoolDefaultsExitDialog";
import { SchoolDispatchGroupEditor } from "./SchoolDispatchGroupEditor";
import { SchoolCookingGroupEditor } from "./SchoolCookingGroupEditor";
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
  Tabs,
} from "@chakra-ui/react";
import { useImperativeHandle, useState, type ReactNode } from "react";
import { useAtlasWorkbenchStatus } from "../AtlasModuleExit";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasWorkbar, AtlasWorkbarActions } from "../AtlasWorkbar";
import {
  AtlasSortableColumnHeader,
  atlasNarrowSortableHeader,
} from "../AtlasSortableColumnHeader";
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
import { operatorMasterReference } from "../masterDataPresentation";
import {
  useSchoolDefaultsWorkbench,
  type SchoolDefaultsWorkbenchProps,
  type SchoolDefaultsController,
} from "./useSchoolDefaultsWorkbench";

export function SchoolDefaultsWorkbench(props: SchoolDefaultsWorkbenchProps) {
  const c = useSchoolDefaultsWorkbench(props);
  const [view, setView] = useState("defaults");
  const viewTitle =
    view === "cooking"
      ? "Nơi nấu"
      : view === "dispatch"
        ? "Nhóm phiếu xuất kho"
        : "Sĩ số mặc định";
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
    c.saving ||
    c.loading ||
    Boolean(c.error) ||
    c.lock === "unknown" ||
    c.lock === "readback";
  const filtered = c.visibleSchools.length !== c.schools.length;
  const activeCount = c.visibleSchools.filter(
    (school) => school.school_status === "ACTIVE",
  ).length;

  const tableTools = (
    <>
      <Box aria-live="polite">
        {c.schools.length === 0 && (c.loading || c.error) ? (
          <Text textStyle="helper" color="fg.muted">
            {c.loading
              ? "Đang tải danh sách trường…"
              : "Chưa xác định số trường. Tải lại dữ liệu để kiểm tra."}
          </Text>
        ) : (
          <Text textStyle="helper" color="fg.muted">
            {filtered ? `${c.visibleSchools.length} / ` : ""}
            {c.schools.length} trường · {activeCount} đang hoạt động
            {filtered ? " trong kết quả" : ""} · {c.dirtyCount} thay đổi chưa
            lưu
            {c.hiddenDirtyCount > 0
              ? ` · ${c.hiddenDirtyCount} thay đổi ngoài bộ lọc`
              : ""}
          </Text>
        )}
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
          c.portionDirtyCount === 0 ||
          c.invalidDraftCount > 0
        }
        onClick={() => void c.save()}
      >
        Lưu sĩ số
      </Button>
    </>
  );

  return (
    <Box
      as="section"
      aria-label={
        view === "defaults" ? viewTitle : `Thiết lập trường · ${viewTitle}`
      }
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
          {viewTitle}
        </Heading>
      </Box>
      <Tabs.Root value={view} onValueChange={({ value }) => setView(value)}>
        <Tabs.List
          aria-label="Thiết lập trường học"
          {...atlasSecondaryTabList}
          display={c.cookingSupported || c.dispatchSupported ? "flex" : "none"}
        >
          <Tabs.Trigger value="defaults" {...atlasSecondaryTabTrigger}>
            Sĩ số mặc định
          </Tabs.Trigger>
          {c.cookingSupported && (
            <Tabs.Trigger value="cooking" {...atlasSecondaryTabTrigger}>
              Nơi nấu
            </Tabs.Trigger>
          )}
          {c.dispatchSupported && (
            <Tabs.Trigger value="dispatch" {...atlasSecondaryTabTrigger}>
              Nhóm phiếu xuất kho
            </Tabs.Trigger>
          )}
        </Tabs.List>
        <Tabs.Content value={view} p="var(--atlas-layout-zero, 0)">
          {view === "defaults" && (
            <AtlasWorkbar
              display="grid"
              aria-label="Bộ lọc trường học"
              bg="bg.toolbar"
              p="md"
              gap="sm"
              alignItems="end"
              templateColumns={{
                base: "minmax(0, 1fr) auto",
                lg: "minmax(240px, 1.4fr) minmax(180px, 1fr) auto",
              }}
            >
              <Field.Root gridColumn={{ base: "1 / -1", lg: "auto" }}>
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
              <AtlasWorkbarActions>
                <AtlasRefreshButton
                  loading={c.loading}
                  disabled={
                    c.saving || c.lock === "unknown" || c.lock === "readback"
                  }
                  onClick={() => void c.refresh()}
                />
              </AtlasWorkbarActions>
            </AtlasWorkbar>
          )}

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
                  loading={c.loading || c.saving}
                  disabled={c.loading || c.saving}
                  onClick={() => void c.refresh()}
                >
                  {c.confirmGroupSave
                    ? "Xác nhận lần lưu nơi nấu"
                    : c.confirmDispatchGroupSave
                      ? "Xác nhận lần lưu nhóm phiếu xuất kho"
                      : c.lock === "unknown" || c.lock === "readback"
                        ? "Tải lại để xác nhận"
                        : c.lock === "stale"
                          ? "Tải lại dữ liệu hiện tại"
                          : "Thử tải lại dữ liệu"}
                </Button>
              )}
            </Box>
          )}

          {view === "defaults" && c.schools.length === 0 && (
            <Flex px="md" py="xs" gap="sm" align="center" wrap="wrap">
              {tableTools}
            </Flex>
          )}

          {view === "cooking" && c.cookingSupported && (
            <SchoolCookingGroupEditor
              embedded
              controller={c}
              disabled={editingDisabled || Boolean(c.lock)}
            />
          )}

          {view === "dispatch" && c.dispatchSupported && (
            <SchoolDispatchGroupEditor
              embedded
              controller={c}
              disabled={editingDisabled || Boolean(c.lock)}
            />
          )}
          {c.loading && c.schools.length === 0 && (
            <Text role="status" p="md">
              Đang tải dữ liệu trường học…
            </Text>
          )}
          {!c.loading && !c.error && c.schools.length === 0 && (
            <Text p="md">Chưa có trường học.</Text>
          )}

          {view === "defaults" && c.schools.length > 0 && (
            <SchoolDefaultsTable
              tools={tableTools}
              schools={c.visibleSchools}
              drafts={c.drafts}
              disabled={editingDisabled}
              onEdit={c.edit}
            />
          )}
        </Tabs.Content>
      </Tabs.Root>
    </Box>
  );
}

function SchoolDefaultsTable({
  tools,
  schools,
  drafts,
  disabled,
  onEdit,
  cooking,
  dispatch,
}: {
  tools: ReactNode;
  schools: SchoolMasterData[];
  drafts: Record<string, { student: string; teacher: string }>;
  disabled: boolean;
  onEdit: (
    school: SchoolMasterData,
    field: "student" | "teacher",
    value: string,
  ) => void;
  cooking?: SchoolDefaultsController;
  dispatch?: SchoolDefaultsController;
}) {
  type SortKey = "order" | "school" | "type" | "status" | "location";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
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
    <Box>
      {tools && (
        <Flex
          px="md"
          py="xs"
          gap="sm"
          align="center"
          wrap="wrap"
          justify="space-between"
          bg="bg.toolbar"
        >
          {tools}
        </Flex>
      )}
      <AtlasTableViewport
        label="Bảng sĩ số mặc định theo trường"
        maxH={{
          base: "var(--atlas-layout-school-table-mobile-height, 60dvh)",
          lg: "var(--atlas-layout-school-table-height, calc(100dvh - 350px))",
        }}
      >
        <Table.Root
          size="sm"
          aria-label="Sĩ số mặc định theo trường"
          data-sticky-header=""
          stickyHeader
          tableLayout="fixed"
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: "var(--atlas-school-table-width, 1000px)",
          }}
          w="full"
          css={{
            "& th, & td": {
              paddingBlock: "var(--atlas-spacing-xs)",
              verticalAlign: "middle",
            },
          }}
          display={{ base: "block", md: "table" }}
        >
          <Table.ColumnGroup
            display={{ base: "none", md: "table-column-group" }}
          >
            <Table.Column w="var(--atlas-school-order-width, 44px)" />
            <Table.Column w="var(--atlas-school-identity-width, 25%)" />
            <Table.Column w="var(--atlas-school-type-width, 100px)" />
            <Table.Column w="var(--atlas-school-status-width, 130px)" />
            <Table.Column w="var(--atlas-school-defaults-width, 220px)" />
            <Table.Column />
          </Table.ColumnGroup>
          <Table.Header css={atlasNarrowSortableHeader}>
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
              <Table.ColumnHeader>
                Sĩ số mặc định
                <Text textStyle="helper" color="fg.muted">
                  Học sinh / Giáo viên
                </Text>
              </Table.ColumnHeader>
              <AtlasSortableColumnHeader
                label="Điểm giao"
                columnKey="location"
                sort={sort}
                onSort={onSort}
              />
            </Table.Row>
          </Table.Header>
          <Table.Body display={{ base: "block", md: "table-row-group" }}>
            {sortedSchools.map((school) => {
              const draft = drafts[school.school_id] ?? {
                student: String(school.default_student_portions),
                teacher: String(school.default_teacher_portions),
              };
              const dirty =
                Boolean(drafts[school.school_id]) ||
                Boolean(
                  dispatch &&
                  Object.hasOwn(dispatch.dispatchDrafts, school.school_id),
                ) ||
                Boolean(
                  cooking &&
                  Object.hasOwn(cooking.cookingDrafts, school.school_id),
                );
              const studentInvalid = parsePortionDraft(draft.student) === null;
              const teacherInvalid = parsePortionDraft(draft.teacher) === null;
              return (
                <Table.Row
                  key={school.school_id}
                  bg={dirty ? "bg.selected" : undefined}
                  display={{ base: "grid", md: "table-row" }}
                  gridTemplateColumns="minmax(0, 1fr)"
                  borderBottomWidth="var(--atlas-layout-edge, 1px)"
                  borderColor="border.default"
                >
                  <Table.Cell
                    fontVariantNumeric="tabular-nums"
                    display={{ base: "none", md: "table-cell" }}
                  >
                    {school.display_order}
                  </Table.Cell>
                  <Table.Cell
                    minW="var(--atlas-layout-zero, 0)"
                    verticalAlign="top"
                    overflowWrap="anywhere"
                  >
                    <Text hideFrom="md" textStyle="helper" color="fg.muted">
                      #{school.display_order}
                    </Text>
                    <Text fontWeight="semibold">{school.school_name}</Text>
                    <Text
                      textStyle="helper"
                      color={dirty ? "fg.primary" : "fg.muted"}
                    >
                      {operatorMasterReference(school.school_code)
                        ? `${school.school_code} · `
                        : ""}
                      {school.customer_name}
                    </Text>
                  </Table.Cell>
                  <Table.Cell>
                    <Text textStyle="helper" color="fg.muted">
                      {school.school_type_name ?? "Chưa phân loại"}
                    </Text>
                  </Table.Cell>
                  <Table.Cell>
                    <Badge
                      variant={
                        school.school_status === "ACTIVE"
                          ? "success"
                          : "neutral"
                      }
                    >
                      {school.school_status === "ACTIVE"
                        ? "Đang hoạt động"
                        : "Ngừng hoạt động"}
                    </Badge>
                  </Table.Cell>
                  <Table.Cell verticalAlign="top">
                    <Grid templateColumns="repeat(2, minmax(0, 1fr))" gap="sm">
                      <Field.Root minW="var(--atlas-layout-zero, 0)">
                        <Field.Label
                          css={{
                            "@media(min-width:48rem)": atlasVisuallyHidden,
                          }}
                        >
                          Học sinh
                        </Field.Label>
                        <Input
                          type="text"
                          inputMode="numeric"
                          aria-label={`Học sinh mặc định — ${school.school_name}`}
                          aria-invalid={studentInvalid}
                          value={draft.student}
                          disabled={disabled}
                          size="sm"
                          h="compact"
                          minW="var(--atlas-layout-zero, 0)"
                          textAlign="right"
                          onChange={(event) =>
                            onEdit(school, "student", event.target.value)
                          }
                        />
                      </Field.Root>
                      <Field.Root minW="var(--atlas-layout-zero, 0)">
                        <Field.Label
                          css={{
                            "@media(min-width:48rem)": atlasVisuallyHidden,
                          }}
                        >
                          Giáo viên
                        </Field.Label>
                        <Input
                          type="text"
                          inputMode="numeric"
                          aria-label={`Giáo viên mặc định — ${school.school_name}`}
                          aria-invalid={teacherInvalid}
                          value={draft.teacher}
                          disabled={disabled}
                          size="sm"
                          h="compact"
                          minW="var(--atlas-layout-zero, 0)"
                          textAlign="right"
                          onChange={(event) =>
                            onEdit(school, "teacher", event.target.value)
                          }
                        />
                      </Field.Root>
                    </Grid>
                  </Table.Cell>
                  <Table.Cell
                    minW="var(--atlas-layout-zero, 0)"
                    verticalAlign="top"
                    overflowWrap="anywhere"
                  >
                    <Text>{school.delivery_location_name}</Text>
                    <Text
                      textStyle="helper"
                      color={dirty ? "fg.primary" : "fg.muted"}
                    >
                      {school.delivery_address}
                    </Text>
                    {(cooking || dispatch) && (
                      <Grid
                        mt="sm"
                        gap="sm"
                        templateColumns={{
                          base: "minmax(0, 1fr)",
                          xl: "repeat(2, minmax(0, 1fr))",
                        }}
                      >
                        {cooking && (
                          <Box minW="var(--atlas-layout-zero, 0)">
                            <Text textStyle="helper" color="fg.muted" mb="xs">
                              Nấu tại
                            </Text>
                            <NativeSelect.Root
                              size="sm"
                              disabled={
                                disabled || school.school_status !== "ACTIVE"
                              }
                            >
                              <NativeSelect.Field
                                aria-label={`Nấu tại — ${school.school_name}`}
                                value={
                                  cooking.cookingDrafts[school.school_id] ??
                                  school.cooking_group_id ??
                                  ""
                                }
                                onChange={(event) =>
                                  cooking.editCooking(
                                    school,
                                    event.target.value,
                                  )
                                }
                              >
                                <option value="">Không gán nơi nấu</option>
                                {cooking.cookingGroups
                                  .filter((group) => group.active)
                                  .map((group) => (
                                    <option
                                      key={group.cooking_group_id}
                                      value={group.cooking_group_id}
                                      disabled={
                                        !group.location_kind ||
                                        (group.location_kind === "SCHOOL" &&
                                          !group.host_school_id)
                                      }
                                    >
                                      {group.cooking_group_name}
                                      {!group.location_kind ||
                                      (group.location_kind === "SCHOOL" &&
                                        !group.host_school_id)
                                        ? " · Cần đối soát nơi nấu"
                                        : ""}
                                    </option>
                                  ))}
                                {school.cooking_group_id &&
                                  !cooking.cookingGroups.some(
                                    (group) =>
                                      group.active &&
                                      group.cooking_group_id ===
                                        school.cooking_group_id,
                                  ) && (
                                    <option
                                      value={school.cooking_group_id}
                                      disabled
                                    >
                                      {school.cooking_group_name} · Ngừng hoạt
                                      động
                                    </option>
                                  )}
                              </NativeSelect.Field>
                              <NativeSelect.Indicator />
                            </NativeSelect.Root>
                            {Object.hasOwn(
                              cooking.cookingDrafts,
                              school.school_id,
                            ) && (
                              <Button
                                size="sm"
                                mt="xs"
                                disabled={disabled || Boolean(cooking.lock)}
                                aria-label={`Lưu Nấu tại — ${school.school_name}`}
                                onClick={() =>
                                  void cooking.saveSchoolCooking(school)
                                }
                              >
                                Lưu Nấu tại
                              </Button>
                            )}
                          </Box>
                        )}
                        {dispatch && (
                          <Box minW="var(--atlas-layout-zero, 0)">
                            <Text textStyle="helper" color="fg.muted" mb="xs">
                              Nhóm Dispatch
                            </Text>
                            <NativeSelect.Root
                              size="sm"
                              disabled={
                                disabled || school.school_status !== "ACTIVE"
                              }
                            >
                              <NativeSelect.Field
                                aria-label={`Nhóm Dispatch — ${school.school_name}`}
                                value={
                                  dispatch.dispatchDrafts[school.school_id] ??
                                  school.dispatch_group_id ??
                                  ""
                                }
                                onChange={(event) =>
                                  dispatch.editDispatch(
                                    school,
                                    event.target.value,
                                  )
                                }
                              >
                                <option value="">
                                  Không gán nhóm Dispatch
                                </option>
                                {dispatch.dispatchGroups
                                  .filter((group) => group.active)
                                  .map((group) => (
                                    <option
                                      key={group.dispatch_group_id}
                                      value={group.dispatch_group_id}
                                    >
                                      {group.dispatch_group_name}
                                    </option>
                                  ))}
                                {school.dispatch_group_id &&
                                  !dispatch.dispatchGroups.some(
                                    (group) =>
                                      group.active &&
                                      group.dispatch_group_id ===
                                        school.dispatch_group_id,
                                  ) && (
                                    <option
                                      value={school.dispatch_group_id}
                                      disabled
                                    >
                                      {school.dispatch_group_name} · Ngừng hoạt
                                      động
                                    </option>
                                  )}
                              </NativeSelect.Field>
                              <NativeSelect.Indicator />
                            </NativeSelect.Root>
                            {Object.hasOwn(
                              dispatch.dispatchDrafts,
                              school.school_id,
                            ) && (
                              <Button
                                size="sm"
                                mt="xs"
                                disabled={disabled || Boolean(dispatch.lock)}
                                aria-label={`Lưu Nhóm Dispatch — ${school.school_name}`}
                                onClick={() =>
                                  void dispatch.saveSchoolDispatch(school)
                                }
                              >
                                Lưu Nhóm Dispatch
                              </Button>
                            )}
                          </Box>
                        )}
                      </Grid>
                    )}
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
      {!schools.length && <Text p="md">Không có trường phù hợp bộ lọc.</Text>}
    </Box>
  );
}
