import {
  Box,
  Button,
  Field,
  Grid,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useEffect, useId, useRef, useState } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasWorkbar, AtlasWorkbarActions } from "../AtlasWorkbar";
import { AtlasTaskContext } from "../AtlasTaskContext";
import {
  focusFirstCompactFilter,
  preserveCompactFilterFocusOrder,
} from "../compactFilterFocus";
import { SCHOOL_FULFILMENT_STATUS_LABELS } from "../bridges/schoolFulfilment";
import {
  useSchoolFulfilmentWorkbench,
  fulfilmentRowKey,
  type SchoolFulfilmentWorkbenchProps,
} from "./useSchoolFulfilmentWorkbench";
import { needsAttention } from "./schoolFulfilmentAttention";
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
  const filterId = useId();
  const [filtersOpen, setFiltersOpen] = useState(false);
  const compactFilters = useRef<HTMLDivElement>(null);
  const compactFilterTrigger = useRef<HTMLButtonElement>(null);
  const compactFilterOnward = useRef<HTMLDivElement>(null);
  const detail = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const search = useRef<HTMLInputElement>(null);
  const selectedKey = c.selected ? fulfilmentRowKey(c.selected) : null;
  const previousKey = useRef<string | null>(null);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
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
  const dateSummary =
    c.dateStart.split("-").reverse().join("/") +
    (c.dateEnd !== c.dateStart
      ? ` — ${c.dateEnd.split("-").reverse().join("/")}`
      : "");
  const scopeSummary =
    c.schoolIds.length === 0
      ? "Tất cả trường"
      : c.schoolIds.length === 1
        ? (c.schools.find((school) => school.school_id === c.schoolIds[0])
            ?.school_name ?? "1 trường")
        : `${c.schoolIds.length} trường`;
  const filterSummary =
    c.filter === "exceptions"
      ? "Cần xử lý"
      : c.filter === "all"
        ? "Tất cả"
        : (SCHOOL_FULFILMENT_STATUS_LABELS[c.filter] ?? "Tất cả");
  return (
    <Box
      as="section"
      aria-label="Đối chiếu PO / Phiếu xuất kho"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      minH="var(--atlas-layout-zero, 0)"
    >
      <AtlasTaskContext
        ariaLabel="Ngữ cảnh đối chiếu PO / Phiếu xuất kho"
        moduleLabel="Đối chiếu PO / Phiếu xuất kho"
        jobLabel="Đối chiếu PO / Phiếu xuất kho"
        compactSummary={`${dateSummary} · ${scopeSummary}`}
      />
      <AtlasWorkbar
        display="grid"
        aria-label="Phạm vi đối chiếu"
        bg="bg.toolbar"
        px={{ base: "sm", md: "md" }}
        py="sm"
        gap="sm"
        alignItems="end"
        templateColumns={{
          base: "minmax(0, 1fr) auto auto",
          md: "repeat(2, minmax(0, 1fr))",
          xl: "minmax(130px, .9fr) minmax(130px, .9fr) minmax(170px, 1.4fr) minmax(140px, 1.2fr) minmax(145px, 1fr) auto",
        }}
      >
        <Box
          ref={compactFilters}
          id={filterId}
          display="contents"
          onKeyDown={(event) => {
            if (filtersOpen)
              preserveCompactFilterFocusOrder(
                event,
                compactFilters.current,
                compactFilterTrigger.current,
                compactFilterOnward.current,
              );
          }}
        >
          <Box
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 4, md: 1 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
            <AtlasDateInput
              label="Từ ngày"
              value={c.dateStart}
              onValueChange={c.setDateStart}
            />
          </Box>
          <Box
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 5, md: 2 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
            <AtlasDateInput
              label="Đến ngày"
              value={c.dateEnd}
              onValueChange={c.setDateEnd}
            />
          </Box>
          <Box
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 6, md: 3 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
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
          <Field.Root
            display={{ base: filtersOpen ? "block" : "none", md: "block" }}
            order={{ base: 7, md: 5 }}
            gridColumn={{ base: "1 / -1", md: "auto" }}
          >
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
        </Box>
        <Field.Root
          minW="var(--atlas-layout-zero, 0)"
          w="full"
          order={{ base: 0, md: 4 }}
          gridColumn={{ base: "1", md: "auto" }}
        >
          <Field.Label display={{ base: "none", md: "block" }}>
            Tìm kiếm
          </Field.Label>
          <Input
            ref={search}
            minW="var(--atlas-layout-zero, 0)"
            w="full"
            aria-label="Tìm kiếm"
            placeholder="Trường, phiếu, nguyên liệu…"
            value={c.search}
            onChange={(e) => c.setSearch(e.target.value)}
          />
        </Field.Root>
        <Button
          ref={compactFilterTrigger}
          display={{ base: "inline-flex", md: "none" }}
          order="1"
          gridColumn="2"
          variant="secondary"
          aria-expanded={filtersOpen}
          aria-controls={filterId}
          onClick={() => setFiltersOpen((open) => !open)}
        >
          Bộ lọc
        </Button>
        <Text
          display={{ base: filtersOpen ? "none" : "block", md: "none" }}
          order="3"
          gridColumn="1 / -1"
          textStyle="helper"
          color="fg.muted"
        >
          Tình trạng: {filterSummary}
        </Text>
        <AtlasWorkbarActions
          ref={compactFilterOnward}
          order={{ base: 2, md: 6 }}
          gridColumn={{ base: "3", md: "auto" }}
        >
          <AtlasRefreshButton
            loading={c.loading}
            disabled={!!c.rangeError || !props.authSubject}
            onClick={c.refresh}
          />
        </AtlasWorkbarActions>
      </AtlasWorkbar>
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
            Cần xử lý {c.rows.filter(needsAttention).length} · Khớp{" "}
            {c.rows.filter((r) => r.comparison_status === "OK").length}
          </Text>
          <Text px="md" pb="sm" textStyle="helper" color="fg.muted">
            Cần xử lý gồm chênh lệch đối chiếu hoặc vướng mắc vận hành. Dòng
            khớp vẫn có thể cần xử lý.
          </Text>
          <Grid
            data-reconciliation-master-detail=""
            templateColumns={{
              base: "minmax(0, 1fr)",
              lg: c.selected
                ? "minmax(280px, 340px) minmax(0, 1fr)"
                : "minmax(0, 1fr)",
            }}
            minW="var(--atlas-layout-zero, 0)"
            alignItems="start"
          >
            <Box
              display={{ base: c.selected ? "none" : "block", lg: "block" }}
              minW="var(--atlas-layout-zero, 0)"
            >
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
                    : "Chưa có dữ liệu đối chiếu cho trường và khoảng ngày đã chọn."}
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
