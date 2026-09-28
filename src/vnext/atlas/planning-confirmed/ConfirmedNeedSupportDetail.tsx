import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  NativeSelect,
  Table,
  Text,
} from "@chakra-ui/react";
import { useEffect, useState } from "react";
import {
  formatQuantity,
  exactQuantityDisplay,
  needGenerationResultMessage,
  needGenerationWorkbenchFromResult,
  type ConfirmedNeedLine,
  type NeedGenerationApi,
  type NeedGenerationDetailGroup,
  type NeedGenerationFilters,
  type NeedGenerationWorkbenchData,
} from "../bridges/confirmedNeed";
import { AtlasTableViewport } from "../AtlasTableViewport";
export function ConfirmedNeedSupportDetail({
  api,
  authSubject,
  date,
  runId,
  batchId,
  lines,
}: {
  api: NeedGenerationApi;
  authSubject: string;
  date: string;
  runId: string;
  batchId: string;
  lines: ConfirmedNeedLine[];
}) {
  const [correlation] = useState(() => crypto.randomUUID());
  const [filters, setFilters] = useState<NeedGenerationFilters>({
    service_date: date,
    school_id: null,
    ingredient_id: null,
    contribution_family: null,
  });
  const [draft, setDraft] = useState(filters);
  const [offset, setOffset] = useState(0);
  const [group, setGroup] = useState<NeedGenerationDetailGroup | null>(null);
  const [data, setData] = useState<NeedGenerationWorkbenchData | null>(null);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refresh, setRefresh] = useState(0);
  useEffect(() => {
    let active = true;
    setBusy(true);
    setError(null);
    setData(null);
    void api
      .getWorkbench(
        authSubject,
        correlation,
        date,
        date,
        runId,
        filters,
        offset,
        25,
        group,
      )
      .then((r) => {
        if (!active) return;
        const next = needGenerationWorkbenchFromResult(r);
        if (
          next &&
          next.period.period_start === date &&
          next.period.period_end === date &&
          next.selected_run?.need_generation_run_id === runId &&
          next.materialization.confirmed_need_batch_id === batchId &&
          next.grouped_requirements.every((g) => g.service_date === date) &&
          next.pagination.offset === offset &&
          next.grouped_requirements.length <= 25
        )
          setData(next);
        else
          setError(
            r.kind === "success"
              ? "Chưa tải được chi tiết nhu cầu hiện tại."
              : needGenerationResultMessage(r),
          );
      })
      .catch(() => {
        if (active) setError("Không thể tải chi tiết nhu cầu.");
      })
      .finally(() => {
        if (active) setBusy(false);
      });
    return () => {
      active = false;
    };
  }, [
    api,
    authSubject,
    correlation,
    date,
    runId,
    batchId,
    filters,
    offset,
    group,
    refresh,
  ]);
  const schools = Array.from(
    new Map(lines.map((l) => [l.school.id, l.school])).values(),
  );
  const ingredients = Array.from(
    new Map(lines.map((l) => [l.ingredient.id, l.ingredient])).values(),
  );
  return (
    <Box
      bg="bg.subtle"
      p="md"
      borderTopWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Heading as="h2" fontSize="lg" mb="xs">
        Cách hình thành nhu cầu
      </Heading>
      <Text textStyle="helper" color="fg.muted" mb="sm">
        Nhu cầu được tính từ Công thức và Bổ sung. Bằng chứng dưới đây giữ riêng
        nhu cầu tính, bước làm tròn đề xuất và bước xác nhận của con người.
      </Text>
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          md: "repeat(3, minmax(0, 1fr)) auto",
        }}
        gap="sm"
        alignItems="end"
        mb="sm"
      >
        <Field.Root>
          <Field.Label>Trường</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label="Trường chi tiết"
              value={draft.school_id ?? ""}
              onChange={(e) =>
                setDraft((d) => ({ ...d, school_id: e.target.value || null }))
              }
            >
              <option value="">Tất cả</option>
              {schools.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Field.Root>
          <Field.Label>Nguyên liệu</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label="Nguyên liệu chi tiết"
              value={draft.ingredient_id ?? ""}
              onChange={(e) =>
                setDraft((d) => ({
                  ...d,
                  ingredient_id: e.target.value || null,
                }))
              }
            >
              <option value="">Tất cả</option>
              {ingredients.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Field.Root>
          <Field.Label>Nguồn đóng góp</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label="Nguồn đóng góp"
              value={draft.contribution_family ?? ""}
              onChange={(e) =>
                setDraft((d) => ({
                  ...d,
                  contribution_family: (e.target.value ||
                    null) as NeedGenerationFilters["contribution_family"],
                }))
              }
            >
              <option value="">Tất cả</option>
              <option value="RECIPE_DERIVED">Công thức</option>
              <option value="PANTRY_DIRECT">Bổ sung</option>
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Button
          disabled={busy}
          onClick={() => {
            setFilters({ ...draft });
            setOffset(0);
            setGroup(null);
          }}
        >
          Áp dụng chi tiết
        </Button>
      </Grid>
      {busy && <Text role="status">Đang tải chi tiết…</Text>}
      {error && (
        <Box>
          <Text role="alert">{error}</Text>
          <Button onClick={() => setRefresh((n) => n + 1)}>
            Tải lại chi tiết
          </Button>
        </Box>
      )}
      {data && (
        <>
          <AtlasTableViewport label="Bằng chứng hình thành nhu cầu">
            <Table.Root
              size="sm"
              aria-label="Cách hình thành nhu cầu"
              minW="var(--atlas-layout-need-evidence-min, 840px)"
            >
              <Table.Header>
                <Table.Row>
                  {[
                    "Trường / điểm giao",
                    "Nguyên liệu",
                    "Nguồn đóng góp",
                    "Đề xuất vận hành",
                    "Xác nhận",
                  ].map((t) => (
                    <Table.ColumnHeader key={t}>{t}</Table.ColumnHeader>
                  ))}
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {data.grouped_requirements.map((g) => {
                  const detailIdentityMatches =
                    data.grouped_requirements.filter(
                      (candidate) =>
                        candidate.service_date === g.service_date &&
                        candidate.school_id === g.school_id &&
                        candidate.delivery_location_id ===
                          g.delivery_location_id &&
                        candidate.ingredient_id === g.ingredient_id &&
                        candidate.unit_id === g.unit_id,
                    );
                  const matches = lines.filter(
                    (line) =>
                      line.service_date === g.service_date &&
                      line.customer.id === g.customer_id &&
                      line.school.id === g.school_id &&
                      line.delivery_location.id === g.delivery_location_id &&
                      line.ingredient.id === g.ingredient_id &&
                      line.controlled_unit.id === g.unit_id,
                  );
                  const line =
                    detailIdentityMatches.length === 1 && matches.length === 1
                      ? matches[0]!
                      : null;
                  const identity = `${g.service_date}:${g.customer_id}:${g.school_id}:${g.delivery_location_id}:${g.ingredient_id}:${g.unit_id}`;
                  return (
                    <Table.Row key={identity}>
                      <Table.Cell>
                        {g.school_name}
                        <Text textStyle="helper" color="fg.muted">
                          {g.delivery_location_name}
                        </Text>
                      </Table.Cell>
                      <Table.Cell>
                        <Text fontWeight="semibold">{g.ingredient_name}</Text>
                        <Button
                          variant="tertiary"
                          size="sm"
                          aria-label={`Xem chi tiết ${g.ingredient_name}`}
                          disabled={!line}
                          onClick={() =>
                            setGroup({
                              service_date: g.service_date,
                              school_id: g.school_id,
                              delivery_location_id: g.delivery_location_id,
                              ingredient_id: g.ingredient_id,
                              unit_id: g.unit_id,
                            })
                          }
                        >
                          Xem chi tiết
                        </Button>
                        {!line && (
                          <Text textStyle="helper" color="status.warning">
                            Không đối chiếu được đầy đủ bằng chứng của dòng nhu
                            cầu hiện tại.
                          </Text>
                        )}
                      </Table.Cell>
                      <Table.Cell whiteSpace="nowrap">
                        <Text>
                          Từ công thức:{" "}
                          {formatQuantity(g.recipe_derived_quantity)}{" "}
                          {g.unit_name}
                        </Text>
                        <Text>
                          Bổ sung: {formatQuantity(g.pantry_direct_quantity)}{" "}
                          {g.unit_name}
                        </Text>
                        {line && (
                          <Text fontWeight="semibold">
                            Nhu cầu tính:{" "}
                            {exactQuantityDisplay(line.theoretical_quantity)}{" "}
                            {line.controlled_unit.code}
                          </Text>
                        )}
                      </Table.Cell>
                      <Table.Cell whiteSpace="nowrap">
                        {line?.proposal_rounding_step ? (
                          <>
                            <Text textStyle="helper" color="fg.muted">
                              Làm tròn lên theo bước nguyên liệu:{" "}
                              {exactQuantityDisplay(
                                line.proposal_rounding_step,
                              )}{" "}
                              {line.controlled_unit.code}
                            </Text>
                            <Text fontWeight="semibold">
                              Đề xuất vận hành:{" "}
                              {exactQuantityDisplay(
                                line.proposed_confirmed_quantity,
                              )}{" "}
                              {line.controlled_unit.code}
                            </Text>
                          </>
                        ) : (
                          <Text color="status.warning">
                            Chưa có bằng chứng làm tròn đề xuất.
                          </Text>
                        )}
                      </Table.Cell>
                      <Table.Cell whiteSpace="nowrap">
                        {line?.effective_policy ? (
                          <Text textStyle="helper" color="fg.muted">
                            Bước xác nhận:{" "}
                            {exactQuantityDisplay(
                              line.effective_policy.planning_step,
                            )}{" "}
                            {line.controlled_unit.code}
                          </Text>
                        ) : (
                          <Text color="status.warning">
                            Chưa có bước xác nhận hiệu lực.
                          </Text>
                        )}
                        {line?.confirmed_quantity_after && (
                          <Text fontWeight="semibold">
                            Đã xác nhận:{" "}
                            {exactQuantityDisplay(
                              line.confirmed_quantity_after,
                            )}{" "}
                            {line.controlled_unit.code}
                          </Text>
                        )}
                      </Table.Cell>
                    </Table.Row>
                  );
                })}
              </Table.Body>
            </Table.Root>
          </AtlasTableViewport>
          <Flex gap="sm" align="center" mt="sm" wrap="wrap">
            <Button
              disabled={busy || offset === 0}
              onClick={() => {
                setOffset((n) => Math.max(0, n - 25));
                setGroup(null);
              }}
            >
              Trang trước
            </Button>
            <Text textStyle="helper">{data.pagination.total_groups} nhóm</Text>
            <Button
              disabled={busy || !data.pagination.has_more}
              onClick={() => {
                setOffset((n) => n + 25);
                setGroup(null);
              }}
            >
              Trang sau
            </Button>
          </Flex>
          {group && (
            <Box mt="sm" aria-label="Nguồn đóng góp chi tiết">
              {data.atomic_detail.map((a, i) => (
                <Text key={i} textStyle="helper">
                  {a.contribution_family === "RECIPE_DERIVED"
                    ? "Công thức"
                    : "Bổ sung"}{" "}
                  · {a.dish_name ?? a.pantry_purpose}{" "}
                  {a.pantry_source_reference
                    ? `· ${a.pantry_source_reference}`
                    : ""}{" "}
                  · {formatQuantity(a.theoretical_quantity)} {a.unit_name}
                </Text>
              ))}
            </Box>
          )}
        </>
      )}
    </Box>
  );
}
