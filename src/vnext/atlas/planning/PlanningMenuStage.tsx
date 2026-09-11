import {
  Box,
  Button,
  Flex,
  Popover,
  Stack,
  Table,
  Text,
} from "@chakra-ui/react";
import { Table as SheetIcon } from "@phosphor-icons/react";
import { useState } from "react";
import type { PlanningSourcesController } from "./usePlanningSources";
export function PlanningMenuStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [choose, setChoose] = useState(false);
  const sources =
    c.data?.google_sheet_sources.filter((s) => s.source_status === "ACTIVE") ??
    [];
  const types =
    c.data?.dish_types
      .filter((t) => t.dish_type_status === "ACTIVE")
      .sort((a, b) => a.display_order - b.display_order) ?? [];
  return (
    <>
      <Flex p="sm" gap="sm" align="center" wrap="wrap">
        <Text textStyle="helper" color="fg.muted">
          Google Sheets ·{" "}
          {c.menuSource.name || sources[0]?.source_name || "Chưa có nguồn"}
        </Text>
        {sources.length ? (
          <Popover.Root
            open={choose}
            onOpenChange={(d) => setChoose(d.open)}
            lazyMount
            unmountOnExit
          >
            {sources.length > 1 ? (
              <Popover.Trigger asChild>
                <Button size="sm" disabled={!c.canEdit}>
                  <SheetIcon />
                  Đồng bộ Google Sheet
                </Button>
              </Popover.Trigger>
            ) : (
              <Button
                size="sm"
                disabled={!c.canEdit || c.syncing}
                onClick={() =>
                  void c.syncGoogle(sources[0].weekly_menu_google_source_id)
                }
              >
                <SheetIcon />
                Đồng bộ Google Sheet
              </Button>
            )}
            <Popover.Positioner>
              <Popover.Content bg="bg.workbench" color="fg.default">
                <Popover.Body>
                  <Stack gap="xs">
                    {sources.map((s) => (
                      <Button
                        key={s.weekly_menu_google_source_id}
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
          </Popover.Root>
        ) : (
          <Text textStyle="helper">
            Liên hệ quản trị để cấu hình nguồn thực đơn.
          </Text>
        )}
        {c.syncing && (
          <Text role="status" textStyle="helper">
            Đang lấy dữ liệu Google Sheet…
          </Text>
        )}
      </Flex>
      <Box
        overflow="auto"
        maxH={
          c.locked
            ? "var(--atlas-layout-planning-recovery-table-height, max(160px, calc(100dvh - 570px)))"
            : "var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
        }
      >
        <Table.Root aria-label="Thực đơn theo trường" size="sm" stickyHeader>
          <Table.Header>
            <Table.Row>
              <Table.ColumnHeader>Trường / điểm giao</Table.ColumnHeader>
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
                  <Table.Cell>{s.school_name}</Table.Cell>
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
      </Box>
    </>
  );
}
