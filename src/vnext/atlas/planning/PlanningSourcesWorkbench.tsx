import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Input,
  NativeSelect,
  Tabs,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState, useImperativeHandle } from "react";
import type { CSSProperties } from "react";
import { AtlasWeekRangeInput } from "../AtlasWeekRangeInput";
import {
  atlasSecondaryTabList,
  atlasSecondaryTabTrigger,
} from "../AtlasTaskTabs";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import { viDate } from "../bridges/planning";
import { PlanningMenuStage } from "./PlanningMenuStage";
import { PlanningAttendanceStage } from "./PlanningAttendanceStage";
import { PlanningPantryStage } from "./PlanningPantryStage";
import { PlanningSourceReview } from "./PlanningSourceReview";
import { PlanningDirtyExitDialog } from "./PlanningDirtyExitDialog";
import {
  usePlanningSources,
  type PlanningSourcesProps,
} from "./usePlanningSources";
import { AtlasTaskContext } from "../AtlasTaskContext";
import {
  focusFirstCompactFilter,
  preserveCompactFilterFocusOrder,
} from "../compactFilterFocus";
const jobs = { menu: "Thực đơn", attendance: "Sĩ số", pantry: "Bổ sung" };
export function PlanningSourcesWorkbench(props: PlanningSourcesProps) {
  const c = usePlanningSources(props);
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  const [search, setSearch] = useState("");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const heading = useRef<HTMLHeadingElement>(null);
  const compactFilters = useRef<HTMLDivElement>(null);
  const compactFilterTrigger = useRef<HTMLButtonElement>(null);
  const compactFilterOnward = useRef<HTMLDivElement>(null);
  const previousJob = useRef(c.job);
  const reviewPanel = useRef<HTMLElement>(null);
  const reviewTrigger = useRef<HTMLButtonElement>(null);
  const wasReviewOpen = useRef(false);
  const reviewOpen = Boolean(c.preview);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
  useEffect(() => {
    if (reviewOpen) reviewPanel.current?.focus();
    else if (wasReviewOpen.current) reviewTrigger.current?.focus();
    wasReviewOpen.current = reviewOpen;
  }, [reviewOpen]);
  useEffect(() => {
    setSearch("");
    if (previousJob.current !== c.job) heading.current?.focus();
    previousJob.current = c.job;
  }, [c.job]);
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(`${c.week}T12:00:00`);
    d.setDate(d.getDate() + i);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  });
  const visibleSchoolIds = c.schools
    .filter(
      (s) =>
        (!c.schoolIds.length || c.schoolIds.includes(s.school_id)) &&
        foldVietnameseSearch(s.school_name).includes(
          foldVietnameseSearch(search.trim()),
        ),
    )
    .map((s) => s.school_id);
  const scopeSummary = c.schoolIds.length
    ? c.schoolIds.length === 1
      ? (c.schools.find((school) => school.school_id === c.schoolIds[0])
          ?.school_name ?? "1 trường")
      : `${c.schoolIds.length} trường`
    : "Tất cả trường";
  const dateSummary = viDate(c.date);
  const weekSummary = `${viDate(c.week)} – ${viDate(days[6]!)}`;
  return (
    <Box
      as="section"
      aria-label="Nguồn lập nhu cầu"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: "var(--atlas-task-context-desktop-width, 196px) minmax(0, 1fr)",
        }}
      >
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh nguồn lập nhu cầu"
          moduleLabel="Lập nhu cầu"
          jobLabel={jobs[c.job]}
          compactSummary={`${dateSummary} · ${scopeSummary}`}
          headingRef={heading}
          details={[
            { label: "Tuần phục vụ", value: weekSummary },
            { label: "Ngày phục vụ", value: dateSummary },
            { label: "Trường / điểm giao", value: scopeSummary },
          ]}
        />
        <Box minW="var(--atlas-layout-zero, 0)" bg="bg.workbench">
          <Tabs.Root
            value={c.job}
            onValueChange={(d) => c.transition({ job: d.value })}
            variant="line"
          >
            <Box px="md" py="sm">
              <Tabs.List
                aria-label="Nguồn lập nhu cầu"
                {...atlasSecondaryTabList}
              >
                {Object.entries(jobs).map(([value, label]) => (
                  <Tabs.Trigger
                    key={value}
                    value={value}
                    {...atlasSecondaryTabTrigger}
                  >
                    {label}
                  </Tabs.Trigger>
                ))}
              </Tabs.List>
            </Box>
            <Grid
              role="group"
              aria-label="Phạm vi nguồn lập nhu cầu"
              bg="bg.toolbar"
              p={{ base: "sm", md: "md" }}
              gap="sm"
              alignItems="start"
              templateColumns={{
                base: "minmax(0, 1fr) auto auto",
                md: "repeat(2, minmax(0, 1fr))",
                xl: "minmax(170px, 1fr) minmax(150px, 0.8fr) minmax(190px, 1.2fr) minmax(150px, 1fr) auto",
              }}
            >
              <Box
                ref={compactFilters}
                id="planning-source-filters"
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
                  display={{
                    base: filtersOpen ? "block" : "none",
                    md: "block",
                  }}
                  order={{ base: 5, md: 1 }}
                  gridColumn={{ base: "1 / -1", md: "auto" }}
                >
                  <AtlasWeekRangeInput
                    label="Tuần phục vụ"
                    value={c.week}
                    onValueChange={(week) => c.transition({ week })}
                  />
                </Box>
                <Field.Root
                  display={{
                    base: filtersOpen ? "block" : "none",
                    md: "block",
                  }}
                  order={{ base: 6, md: 2 }}
                  gridColumn={{ base: "1 / -1", md: "auto" }}
                >
                  <Field.Label>Ngày phục vụ</Field.Label>
                  <NativeSelect.Root>
                    <NativeSelect.Field
                      aria-label="Ngày phục vụ"
                      value={c.date}
                      onChange={(e) => c.transition({ date: e.target.value })}
                    >
                      {days.map((d, i) => (
                        <option key={d} value={d}>
                          {
                            [
                              "Thứ Hai",
                              "Thứ Ba",
                              "Thứ Tư",
                              "Thứ Năm",
                              "Thứ Sáu",
                              "Thứ Bảy",
                              "Chủ Nhật",
                            ][i]
                          }{" "}
                          · {viDate(d).slice(0, 5)}
                        </option>
                      ))}
                    </NativeSelect.Field>
                    <NativeSelect.Indicator />
                  </NativeSelect.Root>
                </Field.Root>
                <Box
                  display={{
                    base: filtersOpen ? "block" : "none",
                    md: "block",
                  }}
                  order={{ base: 7, md: 3 }}
                  gridColumn={{ base: "1 / -1", md: "auto" }}
                >
                  <Text textStyle="label" mb="xs">
                    Trường / điểm giao
                  </Text>
                  <AtlasSchoolScope
                    schools={c.schools}
                    value={c.schoolIds}
                    onApply={(schoolIds) => c.transition({ schoolIds })}
                  />
                </Box>
              </Box>
              <Field.Root
                order={{ base: 1, md: 4 }}
                gridColumn={{ base: "1", md: "auto" }}
              >
                <Field.Label display={{ base: "none", md: "block" }}>
                  Tìm trường
                </Field.Label>
                <Input
                  aria-label="Tìm trong công việc"
                  placeholder="Tên trường…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </Field.Root>
              <Button
                ref={compactFilterTrigger}
                display={{ base: "inline-flex", md: "none" }}
                order="2"
                gridColumn="2"
                variant="secondary"
                minH="var(--atlas-layout-mobile-target, 44px)"
                aria-expanded={filtersOpen}
                aria-controls="planning-source-filters"
                onClick={() => setFiltersOpen((open) => !open)}
              >
                Bộ lọc
              </Button>
              <Box
                ref={compactFilterOnward}
                order={{ base: 3, md: 5 }}
                gridColumn={{ base: "3", md: "auto" }}
                pt={{ xl: "lg" }}
              >
                <AtlasRefreshButton
                  loading={c.loading}
                  disabled={c.busy || c.locked || reviewOpen}
                  onClick={() => c.transition({ refresh: true })}
                />
              </Box>
              <Text
                display={{ base: filtersOpen ? "none" : "block", md: "none" }}
                order="4"
                gridColumn="1 / -1"
                textStyle="helper"
                color="fg.muted"
              >
                Tuần {viDate(c.week)} · Ngày {dateSummary} · {scopeSummary}
              </Text>
            </Grid>
            {c.outcome && (
              <Text
                role="status"
                p="sm"
                color={c.locked ? "status.warning" : "fg.muted"}
              >
                {c.outcome}
              </Text>
            )}
            {c.readError && (
              <Text role="alert" p="sm" color="status.danger">
                {c.readError}
              </Text>
            )}
            {(c.locked || c.readError) && (
              <Button
                m="sm"
                disabled={c.loading}
                onClick={() => void c.recover()}
              >
                {c.recoveryKind === "READ_FAILURE"
                  ? "Thử tải lại dữ liệu"
                  : c.recoveryKind === "STALE"
                    ? "Tải lại dữ liệu hiện tại"
                    : "Tải lại để xác nhận"}
              </Button>
            )}
            {(c.job === "pantry" ? [] : c.errors).map((error, i) => (
              <Text
                role="alert"
                key={i}
                px="sm"
                color="status.danger"
                textStyle="helper"
              >
                {error}
              </Text>
            ))}
            {c.job === "menu" &&
              c.importWarnings.map((warning, i) => (
                <Text key={i} px="sm" color="status.warning" textStyle="helper">
                  {warning}
                </Text>
              ))}
            <Tabs.Content value={c.job} p="var(--atlas-layout-zero, 0)">
              {c.authority ? (
                <Grid
                  data-testid="planning-source-editor-review"
                  style={
                    {
                      "--atlas-planning-review-columns":
                        "minmax(330px, .9fr) minmax(440px, 1.1fr)",
                    } as CSSProperties
                  }
                  templateColumns={{
                    base: "minmax(0, 1fr)",
                    lg: c.preview
                      ? "var(--atlas-planning-review-columns)"
                      : "minmax(0, 1fr)",
                  }}
                  alignItems="stretch"
                >
                  <Box minW="var(--atlas-layout-zero, 0)">
                    {c.job === "menu" ? (
                      <PlanningMenuStage
                        c={c}
                        visibleSchoolIds={visibleSchoolIds}
                      />
                    ) : c.job === "attendance" ? (
                      <PlanningAttendanceStage
                        c={c}
                        visibleSchoolIds={visibleSchoolIds}
                      />
                    ) : (
                      <PlanningPantryStage
                        c={c}
                        visibleSchoolIds={visibleSchoolIds}
                      />
                    )}
                    <Flex
                      p="md"
                      justify="space-between"
                      align="center"
                      gap="sm"
                      wrap="wrap"
                    >
                      <Text textStyle="helper" color="fg.muted">
                        {c.dirty ? "Đang chỉnh sửa · chưa lưu" : ""}
                      </Text>
                      {c.candidate && (
                        <Button
                          ref={reviewTrigger}
                          display={c.preview ? "none" : "inline-flex"}
                          variant="businessPrimary"
                          disabled={
                            !c.canEdit || c.syncing || c.errors.length > 0
                          }
                          onClick={() => void c.previewChanges()}
                        >
                          Xem thay đổi
                        </Button>
                      )}
                    </Flex>
                  </Box>
                  {c.preview && (
                    <PlanningSourceReview c={c} reviewRef={reviewPanel} />
                  )}
                </Grid>
              ) : (
                c.loading && <Text p="md">Đang tải nguồn kế hoạch…</Text>
              )}
            </Tabs.Content>
            <PlanningDirtyExitDialog
              open={!!c.pending}
              wholeWeek={c.pending?.noAdditions === true}
              onCancel={c.cancelTransition}
              onDiscard={c.discardTransition}
            />
          </Tabs.Root>
        </Box>
      </Grid>
    </Box>
  );
}
