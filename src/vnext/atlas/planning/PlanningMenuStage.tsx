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
import {
  useAtlasPortalContainer,
  useAtlasWorkbenchActive,
} from "../AtlasVNextProvider";
import { viDate, planningIssueMessage } from "../bridges/planning";
export function PlanningMenuStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [choose, setChoose] = useState(false);
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
                      <Text
                        textStyle="helper"
                        color="fg.muted"
                        overflowWrap="anywhere"
                      >
                        {issue.source_row_reference}
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
      <AtlasTableViewport
        label="Bảng thực đơn theo trường"
        data-testid="weekly-menu-scroll"
        data-horizontal-scroll="local"
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
            {types.map((type) => (
              <Table.Column
                key={type.dish_type_id}
                w="var(--atlas-menu-dish-width, 180px)"
              />
            ))}
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row zIndex="var(--atlas-layout-sticky-header-z, 3)">
              <Table.ColumnHeader
                data-sticky-column="school"
                position="sticky"
                left="var(--atlas-layout-zero, 0)"
                zIndex="var(--atlas-layer-sticky-corner, 3)"
              >
                Trường / điểm giao
              </Table.ColumnHeader>
              {types.map((t) => (
                <Table.ColumnHeader key={t.dish_type_id}>
                  {t.dish_type_name}
                </Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {c.data?.schools
              .filter((s) => visibleSchoolIds.includes(s.school_id))
              .map((s) => (
                <Table.Row key={s.school_id}>
                  <Table.Cell
                    data-sticky-column="school"
                    position="sticky"
                    left="var(--atlas-layout-zero, 0)"
                    zIndex="var(--atlas-layer-sticky-cell, 1)"
                    bg="bg.workbench"
                  >
                    {s.school_name}
                  </Table.Cell>
                  {types.map((t) => {
                    const lines = c.menuRows.filter(
                      (r) =>
                        r.school_id === s.school_id &&
                        r.service_date === c.date &&
                        r.menu_slot_code === t.dish_type_code,
                    );
                    const issues = Array.from(
                      new Map(
                        c.menuSyncIssues
                          .filter(
                            (issue) =>
                              issue.school_id === s.school_id &&
                              issue.service_date === c.date &&
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
