import {
  Box,
  Button,
  Flex,
  Icon,
  Popover,
  Portal,
  Stack,
  Table,
  Text,
} from "@chakra-ui/react";
import {
  Table as SheetIcon,
  WarningCircle,
  Warning,
} from "@phosphor-icons/react";
import { useLayoutEffect, useState } from "react";
import type { PlanningSourcesController } from "./usePlanningSources";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import {
  atlasDefaultSort,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";
import { atlasWorkbarControlHeight } from "../AtlasWorkbar";
import {
  useAtlasPortalContainer,
  useAtlasWorkbenchActive,
} from "../AtlasVNextProvider";
import { viDate, planningIssueMessage } from "../bridges/planning";
export function PlanningMenuStage({
  c,
  days,
  visibleSchoolIds,
  fitWorkspace,
}: {
  c: PlanningSourcesController;
  days: string[];
  visibleSchoolIds: string[];
  fitWorkspace: boolean;
}) {
  const [choose, setChoose] = useState(false);
  const [sort, setSort] =
    useState<AtlasSortState<"school" | "date">>(atlasDefaultSort);
  const active = useAtlasWorkbenchActive();
  useLayoutEffect(() => {
    if (!active) setChoose(false);
  }, [active]);
  const portalContainer = useAtlasPortalContainer();
  const sources =
    c.data?.google_sheet_sources.filter((s) => s.source_status === "ACTIVE") ??
    [];
  const types =
    c.data?.dish_types
      .filter((t) => t.dish_type_status === "ACTIVE")
      .sort((a, b) => a.display_order - b.display_order) ?? [];
  const correctionDates = c.impact?.date_impacts ?? [];
  const sourceDates = new Set(
    [...c.menuRows, ...c.menuSyncIssues].map(
      (row) => `${row.school_id}|${row.service_date}`,
    ),
  );
  const rows = sortAtlasRows(
    c.schools
      .filter((school) => visibleSchoolIds.includes(school.school_id))
      .flatMap((school) =>
        days
          .filter((date) => sourceDates.has(`${school.school_id}|${date}`))
          .map((date) => ({ school, date })),
      ),
    sort,
    {
      school: (left, right) =>
        compareAtlasText(left.school.school_name, right.school.school_name),
      date: (left, right) => compareAtlasText(left.date, right.date),
    },
  );
  const onSort = (key: "school" | "date") =>
    setSort((current) => nextAtlasSort(current, key));
  const invalidCellCount = new Set(
    c.menuSyncIssues.map((issue) => issue.source_row_reference).filter(Boolean),
  ).size;
  const issueGroups = new Map<
    string,
    { cells: Set<string>; located: boolean }
  >();
  for (const [index, issue] of c.menuSyncIssues.entries()) {
    const cause =
      issue.code === "INVALID_DISH_ID" ? "UNKNOWN_DISH" : issue.code;
    const group = issueGroups.get(cause) ?? {
      cells: new Set<string>(),
      located: true,
    };
    group.cells.add(issue.source_row_reference ?? `unlocated:${index}`);
    group.located &&= !!issue.source_row_reference;
    issueGroups.set(cause, group);
  }
  const correctionChain = correctionDates
    .filter((impact) =>
      [
        "PLANNING_RELEASE_CORRECTION_REQUIRED",
        "LEGACY_RANGE_CORRECTION_REQUIRED",
      ].includes(impact.correction_policy),
    )
    .flatMap((impact) => impact.chains)
    .find((chain) => chain.confirmed_need_batch_id);
  return (
    <>
      <Flex
        px={{ base: "sm", md: "md" }}
        py="sm"
        gap="sm"
        align={{ base: "stretch", md: "center" }}
        justify="space-between"
        direction={{ base: "column", md: "row" }}
        bg="bg.toolbar"
        borderBottomWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.default"
      >
        <Box minW="var(--atlas-layout-zero, 0)">
          <Text textStyle="label" color="fg.default">
            Google Sheets ·{" "}
            {c.menuSource.name || sources[0]?.source_name || "Chưa có nguồn"}
          </Text>
          <Text textStyle="helper" color="fg.muted">
            {c.dirty
              ? c.errors.length || c.menuSyncIssues.length
                ? "Bản đồng bộ chưa lưu · Sửa ô lỗi trong Google Sheet rồi đồng bộ lại."
                : "Bản đồng bộ chưa lưu."
              : c.menuSyncedAt
                ? `Đã đồng bộ lúc ${c.menuSyncedAt}`
                : "Nguồn soạn thực đơn chính thức"}
          </Text>
        </Box>
        {sources.length ? (
          <Popover.Root
            open={active && choose}
            onOpenChange={(d) => setChoose(d.open)}
            lazyMount
            unmountOnExit
          >
            {sources.length > 1 ? (
              <Popover.Trigger asChild>
                <Button
                  size="sm"
                  h={atlasWorkbarControlHeight}
                  variant="businessPrimary"
                  disabled={!c.canEdit || c.syncing}
                >
                  <SheetIcon />
                  Đồng bộ Google Sheet
                </Button>
              </Popover.Trigger>
            ) : (
              <Button
                size="sm"
                h={atlasWorkbarControlHeight}
                variant="businessPrimary"
                disabled={!c.canEdit || c.syncing}
                onClick={() =>
                  void c.syncGoogle(sources[0].weekly_menu_google_source_id)
                }
              >
                <SheetIcon />
                Đồng bộ Google Sheet
              </Button>
            )}
            <Portal container={portalContainer}>
              <Popover.Positioner>
                <Popover.Content bg="bg.workbench" color="fg.default">
                  <Popover.Body>
                    <Stack gap="xs">
                      {sources.map((s) => (
                        <Button
                          key={s.weekly_menu_google_source_id}
                          variant="secondary"
                          onClick={() => {
                            setChoose(false);
                            void c.syncGoogle(s.weekly_menu_google_source_id);
                          }}
                        >
                          {s.source_name}
                        </Button>
                      ))}
                    </Stack>
                  </Popover.Body>
                </Popover.Content>
              </Popover.Positioner>
            </Portal>
          </Popover.Root>
        ) : (
          <Text textStyle="helper">
            Liên hệ quản trị để cấu hình nguồn thực đơn.
          </Text>
        )}
        {c.syncing && (
          <Text role="status" textStyle="helper">
            Đang kiểm tra và đồng bộ Google Sheet…
          </Text>
        )}
      </Flex>
      {(c.errors.length > 0 || c.menuSyncIssues.length > 0) && (
        <Box
          role="alert"
          aria-label="Không thể đồng bộ thực đơn"
          px={{ base: "sm", md: "md" }}
          py="sm"
          layerStyle="feedbackDanger"
          borderBottomWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.danger"
        >
          <Text textStyle="label" color="status.danger">
            <Icon asChild mr="xs">
              <WarningCircle aria-hidden="true" />
            </Icon>
            {invalidCellCount
              ? `${invalidCellCount} ô cần xử lý trước khi lưu.`
              : "Không thể đồng bộ thực đơn"}
          </Text>
          {Array.from(issueGroups, ([code, group]) => (
            <Text key={code} textStyle="helper" color="fg.default">
              {code === "UNKNOWN_DISH" || code === "INVALID_DISH_ID"
                ? `${group.cells.size} ${group.located ? "ô" : "lỗi"} chưa xác định được món ăn.`
                : code === "AMBIGUOUS_DISH"
                  ? `${group.cells.size} ${group.located ? "ô" : "lỗi"} có tên món trùng và cần kiểm tra.`
                  : `${group.cells.size} lỗi: ${planningIssueMessage({ code, message: "", source_row_reference: null })}`}
            </Text>
          ))}
          {Array.from(new Set(c.errors))
            .filter(
              (error) =>
                !c.menuSyncIssues.some(
                  (issue) =>
                    planningIssueMessage({ ...issue, message: "" }) === error,
                ),
            )
            .map((error) => (
              <Text key={error} textStyle="helper">
                {error}
              </Text>
            ))}
          {c.menuSyncIssues.some((issue) => issue.source_value) && (
            <Box as="details" mt="xs">
              <Box
                as="summary"
                textStyle="helper"
                cursor="var(--atlas-layout-cursor, pointer)"
              >
                Xem ô cần kiểm tra
              </Box>
              <Stack
                gap="xs"
                mt="xs"
                maxH="var(--atlas-menu-issues-height, 160px)"
                overflowY="auto"
              >
                {c.menuSyncIssues
                  .filter((issue) => issue.source_value)
                  .map((issue, index) => (
                    <Box
                      key={`${issue.source_row_reference}:${issue.code}:${index}`}
                    >
                      <Text textStyle="label">{issue.source_value}</Text>
                      <Text textStyle="helper" color="fg.muted">
                        {issue.menu_slot_name} · dòng {issue.source_row_number}
                      </Text>
                      <Text textStyle="helper" color="fg.muted">
                        {issue.school_name || "Chưa xác định trường"} ·{" "}
                        {issue.service_date
                          ? viDate(issue.service_date)
                          : issue.source_date_value || "Chưa có ngày"}
                      </Text>
                      <Text textStyle="helper">
                        {planningIssueMessage({ ...issue, message: "" })}
                      </Text>
                    </Box>
                  ))}
              </Stack>
            </Box>
          )}
        </Box>
      )}
      {!!c.importWarnings.length && (
        <Box as="details" px={{ base: "sm", md: "md" }} py="xs">
          <Box
            as="summary"
            textStyle="helper"
            color="status.warning"
            cursor="var(--atlas-layout-cursor, pointer)"
          >
            Lưu ý nguồn ({c.importWarnings.length})
          </Box>
          <Stack
            gap="xs"
            maxH="var(--atlas-menu-issues-height, 160px)"
            overflowY="auto"
          >
            {Array.from(new Set(c.importWarnings)).map((warning) => (
              <Text key={warning} textStyle="helper">
                {warning}
              </Text>
            ))}
          </Stack>
        </Box>
      )}
      {c.job === "menu" && c.impact && !c.impact.save_allowed && (
        <Box
          role="alert"
          aria-label="Chưa thể đồng bộ thực đơn"
          px={{ base: "sm", md: "md" }}
          py="sm"
          layerStyle="feedbackWarning"
          color="status.warning"
          borderBottomWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.warning"
        >
          <Flex
            direction={{ base: "column", md: "row" }}
            justify="space-between"
            align={{ base: "stretch", md: "center" }}
            gap="sm"
          >
            <Box>
              <Text textStyle="label">
                <Icon asChild mr="xs">
                  <Warning aria-hidden="true" />
                </Icon>
                Chưa thể đồng bộ thực đơn
              </Text>
              {correctionDates.map((impact) => (
                <Text key={impact.service_date} mt="xs" textStyle="helper">
                  {viDate(impact.service_date)} · {impact.operator_message}
                </Text>
              ))}
            </Box>
            {correctionChain && (
              <Button
                variant="businessPrimary"
                flexShrink="0"
                disabled={
                  !c.canEdit ||
                  c.errors.length > 0 ||
                  c.menuSyncIssues.length > 0
                }
                onClick={() => void c.prepareCorrection(correctionChain)}
              >
                Chuẩn bị hiệu chỉnh
              </Button>
            )}
          </Flex>
        </Box>
      )}
      {!visibleSchoolIds.length && (
        <Text role="status" p="sm" color="fg.muted">
          Không có trường phù hợp bộ lọc.
        </Text>
      )}
      {visibleSchoolIds.length > 0 && rows.length === 0 && (
        <Text role="status" p="sm" color="fg.muted">
          Chưa có thực đơn trong tuần cho các trường đã chọn. Đồng bộ Google
          Sheet để tải thực đơn.
        </Text>
      )}
      <AtlasTableViewport
        label="Bảng thực đơn theo trường"
        data-testid="weekly-menu-scroll"
        data-horizontal-scroll="local"
        fillAvailableHeight={fitWorkspace}
        maxH={
          c.locked
            ? "var(--atlas-layout-planning-recovery-table-height, max(160px, calc(100dvh - 570px)))"
            : "var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
        }
      >
        <Table.Root
          aria-label="Thực đơn theo trường"
          size="sm"
          stickyHeader
          tableLayout="fixed"
          w="var(--atlas-layout-menu-table-width, max-content)"
          minW="var(--atlas-layout-menu-table-width, max-content)"
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-menu-school-width, 220px)" />
            <Table.Column w="var(--atlas-menu-date-width, 120px)" />
            {types.map((type) => (
              <Table.Column
                key={type.dish_type_id}
                w="var(--atlas-menu-dish-width, 180px)"
              />
            ))}
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row zIndex="var(--atlas-layout-sticky-header-z, 3)">
              <AtlasSortableColumnHeader
                label="Trường / điểm giao"
                columnKey="school"
                sort={sort}
                onSort={onSort}
                data-sticky-column="school"
                position="sticky"
                left="var(--atlas-layout-zero, 0)"
                zIndex="var(--atlas-layer-sticky-corner, 3)"
              />
              <AtlasSortableColumnHeader
                label="Ngày phục vụ"
                columnKey="date"
                sort={sort}
                onSort={onSort}
              />
              {types.map((t) => (
                <Table.ColumnHeader key={t.dish_type_id}>
                  {t.dish_type_name}
                </Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {rows.map(({ school: s, date }) => (
              <Table.Row key={`${s.school_id}|${date}`}>
                <Table.Cell
                  data-sticky-column="school"
                  position="sticky"
                  left="var(--atlas-layout-zero, 0)"
                  zIndex="var(--atlas-layer-sticky-cell, 1)"
                  bg="bg.workbench"
                >
                  {s.school_name}
                </Table.Cell>
                <Table.Cell>{viDate(date)}</Table.Cell>
                {types.map((t) => {
                  const lines = c.menuRows.filter(
                    (r) =>
                      r.school_id === s.school_id &&
                      r.service_date === date &&
                      r.menu_slot_code === t.dish_type_code,
                  );
                  const issues = Array.from(
                    new Map(
                      c.menuSyncIssues
                        .filter(
                          (issue) =>
                            issue.school_id === s.school_id &&
                            issue.service_date === date &&
                            issue.menu_slot_code === t.dish_type_code,
                        )
                        .map((issue) => [issue.source_row_reference, issue]),
                    ).values(),
                  );
                  return (
                    <Table.Cell
                      key={t.dish_type_id}
                      data-invalid={issues.length > 0 ? "true" : undefined}
                      bg={issues.length ? "bg.danger" : undefined}
                    >
                      {!lines.length && !issues.length && "—"}
                      {lines.map((line, index) => {
                        const dish = c.data?.dishes.find(
                          (d) => d.dish_id === line.dish_id,
                        );
                        return dish || !issues.length ? (
                          <Text
                            key={`${line.source_row_reference}:${index}`}
                            textStyle="body"
                          >
                            {dish?.dish_name ?? "Món chưa nhận diện"}
                          </Text>
                        ) : null;
                      })}
                      {issues.map((issue) => (
                        <Box key={issue.source_row_reference}>
                          <Text textStyle="helper" color="status.danger">
                            <Icon asChild mr="xs">
                              <WarningCircle aria-hidden="true" />
                            </Icon>
                            {issue.code === "UNKNOWN_DISH" ||
                            issue.code === "INVALID_DISH_ID"
                              ? `Không tìm thấy món “${issue.source_value?.trim()}”`
                              : issue.code === "AMBIGUOUS_DISH"
                                ? `Món “${issue.source_value?.trim()}” có tên trùng; cần kiểm tra.`
                                : planningIssueMessage({
                                    ...issue,
                                    message: "",
                                  })}
                          </Text>
                          <Text textStyle="helper" color="fg.muted">
                            Dòng {issue.source_row_number} · cần xử lý
                          </Text>
                        </Box>
                      ))}
                    </Table.Cell>
                  );
                })}
              </Table.Row>
            ))}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
    </>
  );
}
