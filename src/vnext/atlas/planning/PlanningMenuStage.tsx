import {
  Box,
  Button,
  Flex,
  Popover,
  Portal,
  Stack,
  Table,
  Text,
} from "@chakra-ui/react";
import { Table as SheetIcon } from "@phosphor-icons/react";
import { useState } from "react";
import type { PlanningSourcesController } from "./usePlanningSources";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { useAtlasPortalContainer } from "../AtlasVNextProvider";
import { viDate, planningIssueMessage } from "../bridges/planning";
export function PlanningMenuStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [choose, setChoose] = useState(false);
  const portalContainer = useAtlasPortalContainer();
  const sources =
    c.data?.google_sheet_sources.filter((s) => s.source_status === "ACTIVE") ??
    [];
  const types =
    c.data?.dish_types
      .filter((t) => t.dish_type_status === "ACTIVE")
      .sort((a, b) => a.display_order - b.display_order) ?? [];
  const correctionDates = c.impact?.date_impacts ?? [];
  const issueGroups = new Map<string, number>();
  for (const issue of c.menuSyncIssues) {
    const cause =
      issue.code === "INVALID_DISH_ID" ? "UNKNOWN_DISH" : issue.code;
    issueGroups.set(cause, (issueGroups.get(cause) ?? 0) + 1);
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
            {c.menuSyncedAt
              ? `Đã đồng bộ lúc ${c.menuSyncedAt}`
              : "Nguồn soạn thực đơn chính thức"}
          </Text>
        </Box>
        {sources.length ? (
          <Popover.Root
            open={choose}
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
          bg="bg.warning"
          borderBottomWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.default"
        >
          <Text textStyle="label" color="status.danger">
            Không thể đồng bộ thực đơn
          </Text>
          {Array.from(issueGroups, ([code, count]) => (
            <Text key={code} textStyle="helper" color="fg.default">
              {code === "UNKNOWN_DISH" || code === "INVALID_DISH_ID"
                ? `${count} ô chưa xác định được món ăn.`
                : code === "AMBIGUOUS_DISH"
                  ? `${count} ô có tên món trùng và cần kiểm tra.`
                  : `${count} lỗi: ${planningIssueMessage({ code, message: "", source_row_reference: null })}`}
            </Text>
          ))}
          {!c.menuSyncIssues.length &&
            Array.from(new Set(c.errors)).map((error) => (
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
          bg="bg.warning"
          color="status.warning"
          borderBottomWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.default"
        >
          <Flex
            direction={{ base: "column", md: "row" }}
            justify="space-between"
            align={{ base: "stretch", md: "center" }}
            gap="sm"
          >
            <Box>
              <Text textStyle="label">Chưa thể đồng bộ thực đơn</Text>
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
                disabled={!c.canEdit}
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
                bg="bg.toolbar"
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
                    const line = c.menuRows.find(
                      (r) =>
                        r.school_id === s.school_id &&
                        r.service_date === c.date &&
                        r.menu_slot_code === t.dish_type_code,
                    );
                    return (
                      <Table.Cell key={t.dish_type_id}>
                        {line
                          ? (c.data?.dishes.find(
                              (d) => d.dish_id === line.dish_id,
                            )?.dish_name ?? "Món chưa nhận diện")
                          : "—"}
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
