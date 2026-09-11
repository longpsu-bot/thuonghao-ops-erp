import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Tabs,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
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
const jobs = { menu: "Thực đơn", attendance: "Sĩ số", pantry: "Bổ sung" };
export function PlanningSourcesWorkbench(props: PlanningSourcesProps) {
  const c = usePlanningSources(props);
  const [search, setSearch] = useState("");
  const heading = useRef<HTMLHeadingElement>(null);
  const previousJob = useRef(c.job);
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
      <Tabs.Root
        value={c.job}
        onValueChange={(d) => c.transition({ job: d.value })}
        variant="line"
      >
        <Flex p="md" justify="space-between" align="end" gap="sm" wrap="wrap">
          <Box>
            <Text textStyle="helper" color="fg.muted">
              Lập nhu cầu
            </Text>
            <Heading
              as="h1"
              textStyle="workbenchTitle"
              tabIndex={-1}
              ref={heading}
            >
              {jobs[c.job]}
            </Heading>
          </Box>
          <Tabs.List
            aria-label="Công việc lập nhu cầu"
            borderColor="border.subtle"
          >
            {Object.entries(jobs).map(([value, label]) => (
              <Tabs.Trigger
                key={value}
                value={value}
                color="fg.muted"
                _selected={{ color: "fg.primary", bg: "bg.selected" }}
                _before={{ bg: "border.accent" }}
              >
                {label}
              </Tabs.Trigger>
            ))}
          </Tabs.List>
        </Flex>
        <Grid
          bg="bg.toolbar"
          p="md"
          gap="sm"
          alignItems="start"
          templateColumns={{
            base: "minmax(0, 1fr)",
            md: "repeat(2, minmax(0, 1fr))",
            xl: "minmax(170px, 1fr) minmax(150px, 0.8fr) minmax(190px, 1.2fr) minmax(150px, 1fr) auto",
          }}
        >
          <Box>
            <AtlasDateInput
              label="Tuần phục vụ"
              value={c.week}
              onValueChange={(week) => c.transition({ week })}
            />
            <Text textStyle="helper" color="fg.muted" mt="xs">
              {viDate(c.week)} – {viDate(days[6])}
            </Text>
          </Box>
          <Field.Root>
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
          <Box>
            <Text textStyle="label" mb="xs">
              Trường / điểm giao
            </Text>
            <AtlasSchoolScope
              schools={c.schools}
              value={c.schoolIds}
              onApply={(schoolIds) => c.transition({ schoolIds })}
            />
          </Box>
          <Field.Root>
            <Field.Label>Tìm trường</Field.Label>
            <Input
              aria-label="Tìm trong công việc"
              placeholder="Tên trường…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </Field.Root>
          <Box pt={{ xl: "lg" }}>
            <AtlasRefreshButton
              loading={c.loading}
              disabled={c.busy || c.locked}
              onClick={() => c.transition({ refresh: true })}
            />
          </Box>
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
          <Button m="sm" disabled={c.loading} onClick={() => void c.recover()}>
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
              templateColumns={{
                base: "minmax(0, 1fr)",
                xl: c.preview
                  ? "minmax(0, 62fr) minmax(320px, 38fr)"
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
                  {!c.preview && c.candidate && (
                    <Button
                      variant="businessPrimary"
                      disabled={!c.canEdit || c.syncing || c.errors.length > 0}
                      onClick={() => void c.previewChanges()}
                    >
                      Xem thay đổi
                    </Button>
                  )}
                </Flex>
              </Box>
              {c.preview && <PlanningSourceReview c={c} />}
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
  );
}
