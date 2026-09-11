import {
  Box,
  Field,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { SCHOOL_FULFILMENT_STATUS_LABELS } from "../bridges/schoolFulfilment";
import {
  useSchoolFulfilmentWorkbench,
  fulfilmentRowKey,
  type SchoolFulfilmentWorkbenchProps,
} from "./useSchoolFulfilmentWorkbench";
import { SchoolFulfilmentTable } from "./SchoolFulfilmentTable";
import { SchoolFulfilmentDetail } from "./SchoolFulfilmentDetail";
import {
  OperationalSignals,
  SchoolFulfilmentFeedback,
} from "./SchoolFulfilmentFeedback";
export function SchoolFulfilmentWorkbench(
  props: SchoolFulfilmentWorkbenchProps,
) {
  const c = useSchoolFulfilmentWorkbench(props);
  const detail = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const search = useRef<HTMLInputElement>(null);
  const selectedKey = c.selected ? fulfilmentRowKey(c.selected) : null;
  const previousKey = useRef<string | null>(null);
  useEffect(() => {
    if (selectedKey && selectedKey !== previousKey.current)
      detail.current?.focus();
    else if (
      !selectedKey &&
      previousKey.current &&
      (document.activeElement === document.body ||
        document.activeElement === null)
    ) {
      if (trigger.current?.isConnected) trigger.current.focus();
      else search.current?.focus();
    }
    previousKey.current = selectedKey;
  }, [selectedKey]);
  return (
    <Box
      as="section"
      aria-label="Đối chiếu PO / Phiếu xuất kho"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Heading as="h1" textStyle="workbenchTitle" p="md">
        Đối chiếu PO / Phiếu xuất kho
      </Heading>
      <Grid
        bg="bg.toolbar"
        p="md"
        gap="sm"
        alignItems="start"
        templateColumns={{
          base: "minmax(0, 1fr)",
          md: "repeat(2, minmax(0, 1fr))",
          xl: "minmax(130px, .9fr) minmax(130px, .9fr) minmax(170px, 1.4fr) minmax(140px, 1.2fr) minmax(145px, 1fr) auto",
        }}
      >
        <AtlasDateInput
          label="Từ ngày"
          value={c.dateStart}
          onValueChange={c.setDateStart}
        />
        <AtlasDateInput
          label="Đến ngày"
          value={c.dateEnd}
          onValueChange={c.setDateEnd}
        />
        <Box>
          <Text textStyle="label" mb="xs">
            Trường / điểm giao
          </Text>
          <AtlasSchoolScope
            schools={c.schools}
            value={c.schoolIds}
            disabled={!c.schools.length}
            onApply={c.applySchools}
          />
        </Box>
        <Field.Root>
          <Field.Label>Tìm kiếm</Field.Label>
          <Input
            ref={search}
            aria-label="Tìm kiếm"
            placeholder="Trường, phiếu, nguyên liệu…"
            value={c.search}
            onChange={(e) => c.setSearch(e.target.value)}
          />
        </Field.Root>
        <Field.Root>
          <Field.Label>Tình trạng</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label="Tình trạng"
              value={c.filter}
              onChange={(e) => c.setFilter(e.target.value)}
            >
              <option value="exceptions">Cần xử lý</option>
              <option value="all">Tất cả</option>
              {Object.entries(SCHOOL_FULFILMENT_STATUS_LABELS).map(
                ([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ),
              )}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Box
          pt={{
            base: "var(--atlas-layout-zero, 0)",
            xl: "var(--atlas-layout-refresh-offset, 26px)",
          }}
        >
          <AtlasRefreshButton
            loading={c.loading}
            disabled={!!c.rangeError || !props.authSubject}
            onClick={c.refresh}
          />
        </Box>
      </Grid>
      {c.rangeError && (
        <Text role="alert" color="status.danger" px="md" py="sm">
          {c.rangeError}
        </Text>
      )}
      {!props.authSubject && (
        <Text role="status" p="md">
          Đăng nhập để xem đối chiếu theo phạm vi được cấp.
        </Text>
      )}
      <SchoolFulfilmentFeedback
        error={c.readError}
        loading={c.loading}
        onRetry={c.refresh}
      />
      {c.loading && (
        <Text role="status" p="md" color="fg.muted">
          Đang tải đối chiếu…
        </Text>
      )}
      {!c.loading && !c.readError && !c.rangeError && props.authSubject && (
        <>
          <Box px="md">
            <OperationalSignals blockers={c.blockers} warnings={c.warnings} />
          </Box>
          <Text px="md" py="sm" textStyle="helper" color="fg.muted">
            Cần xử lý{" "}
            {c.rows.filter((r) => r.comparison_status !== "OK").length} · Khớp{" "}
            {c.rows.filter((r) => r.comparison_status === "OK").length}
          </Text>
          <Grid
            templateColumns={{
              base: "minmax(0, 1fr)",
              lg: c.selected
                ? "minmax(0, 62fr) minmax(320px, 38fr)"
                : "minmax(0, 1fr)",
            }}
            alignItems="start"
          >
            <Box minW="var(--atlas-layout-zero, 0)">
              <SchoolFulfilmentTable
                rows={c.visibleRows}
                selectedKey={selectedKey}
                onSelect={(row, button) => {
                  trigger.current = button;
                  c.select(row);
                }}
              />
              {!c.visibleRows.length && (
                <Text p="md" textStyle="body" color="fg.muted">
                  {c.rows.length
                    ? "Không có kết quả phù hợp bộ lọc."
                    : "Không có phạm vi đối chiếu hiện hành phù hợp."}
                </Text>
              )}
            </Box>
            {c.selected && (
              <SchoolFulfilmentDetail
                row={c.selected}
                detailRef={detail}
                onClose={() => {
                  c.select(null);
                  trigger.current?.focus();
                }}
              />
            )}
          </Grid>
        </>
      )}
    </Box>
  );
}
