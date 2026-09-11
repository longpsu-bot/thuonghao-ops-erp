import {
  Box,
  Button,
  Checkbox,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useState } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasSchoolScope } from "../AtlasSchoolScope";
import {
  useConfirmedNeedWorkbench,
  type ConfirmedNeedWorkbenchProps,
} from "./useConfirmedNeedWorkbench";
import { preflightMessage, weekDates } from "./confirmedNeedAuthority";
import { ConfirmedNeedTable } from "./ConfirmedNeedTable";
import { ConfirmedNeedDirtyExitDialog } from "./ConfirmedNeedDirtyExitDialog";
import { ConfirmedNeedCommandFeedback } from "./ConfirmedNeedCommandFeedback";
import { ConfirmedNeedSupportDetail } from "./ConfirmedNeedSupportDetail";
const viDate = (date: string) => date.split("-").reverse().join("/");
export function ConfirmedNeedWorkbench(props: ConfirmedNeedWorkbenchProps) {
  const c = useConfirmedNeedWorkbench(props);
  const [detailKey, setDetailKey] = useState<string | null>(null);
  const days = weekDates(c.week);
  const contextKey = `${c.date}:${c.workbench?.need_generation_source.run_id}:${c.workbench?.batch_version}`;
  const detailOpen = detailKey === contextKey;
  const contextDisabled = c.busy || Boolean(c.lock);
  return (
    <Box
      as="section"
      aria-label="Xác nhận nhu cầu"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Box p="md">
        <Text textStyle="helper" color="fg.muted">
          Lập nhu cầu
        </Text>
        <Heading as="h1" textStyle="workbenchTitle">
          Xác nhận nhu cầu
        </Heading>
      </Box>
      <Grid
        bg="bg.toolbar"
        p="md"
        gap="sm"
        alignItems="start"
        templateColumns={{
          base: "minmax(0, 1fr)",
          md: "repeat(2, minmax(0, 1fr))",
          xl: "minmax(150px, 1fr) minmax(140px, 0.9fr) minmax(160px, 1.1fr) minmax(145px, 1fr) minmax(130px, 0.8fr) auto",
        }}
      >
        <Box>
          <AtlasDateInput
            label="Tuần phục vụ"
            value={c.week}
            disabled={contextDisabled}
            onValueChange={(week) => c.transition({ week })}
          />
          <Text mt="xs" textStyle="helper" color="fg.muted">
            {viDate(c.week)} – {viDate(days[6]!)}
          </Text>
        </Box>
        <Field.Root>
          <Field.Label>Ngày phục vụ</Field.Label>
          <NativeSelect.Root disabled={contextDisabled}>
            <NativeSelect.Field
              aria-label="Ngày phục vụ"
              value={c.date}
              onChange={(e) => c.transition({ date: e.target.value })}
            >
              {days.map((d) => (
                <option key={d} value={d}>
                  {viDate(d)}
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
            disabled={contextDisabled || !c.workbench}
            onApply={(schoolIds) => c.transition({ schoolIds })}
          />
        </Box>
        <Field.Root>
          <Field.Label>Tìm kiếm</Field.Label>
          <Input
            aria-label="Tìm kiếm"
            placeholder="Nguyên liệu, nơi nhận…"
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
              <option value="all">Tất cả</option>
              <option value="needs_review">Cần rà soát</option>
              <option value="carried_forward">Giữ nguyên</option>
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
            loading={c.busy}
            disabled={Boolean(c.lock)}
            onClick={() => c.transition({ refresh: true })}
          />
        </Box>
      </Grid>
      <ConfirmedNeedCommandFeedback
        lock={c.lock}
        notice={c.notice}
        readError={c.readError}
        busy={c.busy}
        onRecover={() => void c.recover()}
      />
      {c.busy && !c.workbench ? (
        <Text p="md" role="status">
          Đang tải nhu cầu…
        </Text>
      ) : !c.workbench ? (
        <Box p="md">
          <Text textStyle="label" mb="xs">
            Ngày phục vụ {viDate(c.date)}
          </Text>
          <Text>{preflightMessage(c.preflight)}</Text>
          {c.canGenerate && (
            <Button
              mt="sm"
              variant="businessPrimary"
              onClick={() => void c.generate()}
            >
              {c.preflight?.downstream_currentness === "OUTDATED"
                ? "Cập nhật nhu cầu"
                : "Tạo nhu cầu"}
            </Button>
          )}
        </Box>
      ) : (
        <>
          <Flex
            px="md"
            py="sm"
            gap="sm"
            justify="space-between"
            align="center"
            wrap="wrap"
          >
            <Text textStyle="helper" color="fg.muted">
              {c.workbench.line_counts.total} dòng ·{" "}
              {c.workbench.line_counts.needs_review} cần rà soát ·{" "}
              {c.workbench.line_counts.confirmed} đã xác nhận ·{" "}
              {c.workbench.line_counts.adjusted} đã điều chỉnh
            </Text>
            <Checkbox.Root
              checked={c.differencesOnly}
              onCheckedChange={(d) => c.setDifferencesOnly(d.checked === true)}
            >
              <Checkbox.HiddenInput />
              <Checkbox.Control>
                <Checkbox.Indicator />
              </Checkbox.Control>
              <Checkbox.Label>Chỉ hiển thị thay đổi chưa lưu</Checkbox.Label>
            </Checkbox.Root>
          </Flex>
          {c.dirty && !c.released && (
            <Text px="md" pb="xs" textStyle="helper" color="status.warning">
              Đang chỉnh sửa · chưa lưu
            </Text>
          )}
          {c.hiddenDirtyCount > 0 && (
            <Text px="md" pb="xs" textStyle="helper" color="status.warning">
              Có {c.hiddenDirtyCount} thay đổi chưa lưu ngoài bộ lọc hiện tại.
            </Text>
          )}
          {c.released && (
            <Text px="md" pb="sm" textStyle="helper" color="fg.muted">
              Nhu cầu đã chuyển sang mua hàng · chỉ đọc.
            </Text>
          )}
          <ConfirmedNeedTable
            lines={c.visibleLines}
            drafts={c.drafts}
            errors={c.errors}
            editable={c.editable}
            onEdit={c.edit}
          />
          <Flex
            p="md"
            gap="sm"
            justify="space-between"
            align="center"
            wrap="wrap"
          >
            <Button
              variant="utility"
              aria-expanded={detailOpen}
              onClick={() => setDetailKey(detailOpen ? null : contextKey)}
            >
              {detailOpen
                ? "Ẩn cách hình thành nhu cầu"
                : "Xem cách hình thành nhu cầu"}
            </Button>
            <Flex gap="sm" wrap="wrap">
              {!c.released && c.dirty && (
                <Button
                  variant="businessPrimary"
                  disabled={!c.canSave}
                  onClick={() => void c.save()}
                >
                  Lưu
                </Button>
              )}
              <Button
                variant={c.dirty ? "secondary" : "businessPrimary"}
                disabled={!c.canContinue}
                onClick={c.continueAllocation}
              >
                Tiếp tục phân bổ NCC
              </Button>
            </Flex>
          </Flex>
          {c.dirty &&
            !c.workbench.allowed_actions.save_confirmed_needs &&
            c.workbench.disabled_reasons.save_confirmed_needs && (
              <Text px="md" pb="sm" color="status.warning">
                {c.workbench.disabled_reasons.save_confirmed_needs}
              </Text>
            )}
          {detailOpen && props.authSubject && (
            <ConfirmedNeedSupportDetail
              key={contextKey}
              api={props.needGenerationApi}
              authSubject={props.authSubject}
              date={c.date}
              runId={c.workbench.need_generation_source.run_id}
              lines={c.workbench.lines}
            />
          )}
        </>
      )}
      <ConfirmedNeedDirtyExitDialog
        open={Boolean(c.pendingTransition)}
        onCancel={c.cancelTransition}
        onDiscard={c.discardTransition}
      />
    </Box>
  );
}
