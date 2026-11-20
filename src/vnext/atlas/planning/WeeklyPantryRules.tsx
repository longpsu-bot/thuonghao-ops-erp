import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Input,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import type { PlanningSourcesController } from "./usePlanningSources";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";
import { viDate } from "../bridges/planning";
import { PantryIngredientChooser } from "./PantryIngredientChooser";
import { PantrySchoolChooser } from "./PantrySchoolChooser";

const quantity = (value: string | null) =>
  value === null
    ? "—"
    : String(value)
        .replace(/(\.\d*?[1-9])0+$|\.0+$/, "$1")
        .replace(".", ",");
const dates = (values: string[]) =>
  values.map((d) => viDate(d).slice(0, 5)).join(", ");

export function WeeklyPantryRules({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const w = c.weekly;
  const { draft, reviewed } = w;
  const schools = (c.pantryData?.schools ?? [])
    .filter(
      (s) =>
        s.school_status === "ACTIVE" && visibleSchoolIds.includes(s.school_id),
    )
    .sort(compareCanonicalSchools);
  const rank = new Map(
    schools.map((school, index) => [school.school_id, index]),
  );
  const rows = (w.data?.rules ?? [])
    .filter((r) => r.effective_from && visibleSchoolIds.includes(r.school_id))
    .sort(
      (a, b) =>
        (rank.get(a.school_id) ?? Infinity) -
        (rank.get(b.school_id) ?? Infinity),
    );
  const schoolInput = useRef<HTMLInputElement>(null);
  const rateInput = useRef<HTMLInputElement>(null);
  const formTitle = useRef<HTMLHeadingElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const addButton = useRef<HTMLButtonElement>(null);
  const wasEditing = useRef(false);
  const editing = !!draft;
  useEffect(() => {
    if (editing && !wasEditing.current)
      (schoolInput.current ?? rateInput.current ?? formTitle.current)?.focus();
    else if (!editing && wasEditing.current) {
      if (w.busy) return;
      (trigger.current?.isConnected
        ? trigger.current
        : addButton.current
      )?.focus();
    }
    wasEditing.current = editing;
  }, [editing, w.busy]);
  const projection = reviewed?.projection;
  return (
    <Stack
      as="section"
      aria-label="Hàng đặt riêng theo tuần"
      gap="md"
      px="md"
      py="sm"
    >
      <Flex justify="space-between" align="center" wrap="wrap" gap="sm">
        <Box>
          <Text as="h2" textStyle="section">
            Hàng đặt riêng theo tuần
          </Text>
          <Text textStyle="helper" color="fg.muted">
            Giao một lần vào ngày đầu tiên trường có thực đơn trong tuần.
          </Text>
        </Box>
        {!draft && w.data?.can_manage && (
          <Button
            ref={addButton}
            size="sm"
            variant="businessPrimary"
            disabled={!w.canEdit || !schools.length}
            onClick={(e) => {
              trigger.current = e.currentTarget;
              w.start(schools.length === 1 ? schools[0].school_id : "");
            }}
          >
            Thêm định mức
          </Button>
        )}
      </Flex>
      {w.error && (
        <Text role="alert" color="status.danger">
          {w.error}
        </Text>
      )}
      {w.notice && <Text role="status">{w.notice}</Text>}
      {w.impacts.map((impact) => (
        <Text key={impact.service_date} textStyle="helper">
          {viDate(impact.service_date)} · {impact.operator_message}
        </Text>
      ))}
      {w.correction && (
        <Box>
          <Button
            size="sm"
            variant="secondary"
            disabled={!w.canEdit}
            onClick={() => void w.prepareCorrection()}
          >
            Mở hiệu chỉnh nhu cầu
          </Button>
        </Box>
      )}
      {(w.reloadNeeded || w.uncertain) && (
        <Box>
          <Button size="sm" disabled={w.busy} onClick={() => void w.recover()}>
            Tải lại định mức
          </Button>
        </Box>
      )}
      {w.busy && (
        <Text role="status" textStyle="helper">
          Đang xử lý định mức…
        </Text>
      )}
      {draft && (
        <Stack
          as="section"
          aria-label="Chỉnh định mức"
          gap="sm"
          p="md"
          bg="bg.toolbar"
          borderWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.subtle"
        >
          <Text as="h3" ref={formTitle} tabIndex={-1} textStyle="section">
            {draft.stop
              ? "Ngừng áp dụng định mức"
              : draft.existing
                ? "Sửa định mức"
                : "Thêm định mức"}
          </Text>
          <Text textStyle="helper">Áp dụng từ thứ Hai {viDate(c.week)}.</Text>
          <Flex wrap="wrap" align="end" gap="md">
            {draft.existing ? (
              <Box>
                <Text textStyle="label">{w.current?.school_name}</Text>
                <Text>{w.current?.ingredient_name}</Text>
              </Box>
            ) : (
              <>
                <PantrySchoolChooser
                  schools={schools}
                  value={draft.school_id}
                  label="Trường áp dụng"
                  inputRef={schoolInput}
                  disabled={!w.canEdit || !!reviewed}
                  onChange={(school_id) => w.edit({ school_id })}
                />
                <Box
                  w={{
                    base: "full",
                    md: "var(--atlas-layout-source-width, 270px)",
                  }}
                >
                  <Text textStyle="label" mb="xs">
                    Nguyên liệu
                  </Text>
                  <PantryIngredientChooser
                    label="Nguyên liệu áp dụng"
                    ingredients={c.pantryData?.ingredients ?? []}
                    value={draft.ingredient_id}
                    disabled={!w.canEdit || !!reviewed}
                    onChange={(ingredient_id) => w.edit({ ingredient_id })}
                  />
                </Box>
              </>
            )}
            {!draft.stop && (
              <Field.Root
                invalid={!!draft.rate && !w.validRate}
                w={{
                  base: "full",
                  md: "var(--atlas-layout-source-width, 270px)",
                }}
              >
                <Field.Label>Định mức mỗi ngày có thực đơn</Field.Label>
                <Flex gap="xs" align="center">
                  <Input
                    ref={rateInput}
                    inputMode="decimal"
                    value={draft.rate}
                    disabled={!w.canEdit || !!reviewed}
                    onChange={(e) => w.edit({ rate: e.target.value })}
                  />
                  <Text textStyle="unitInline">
                    {w.ingredient?.purchase_unit.unit_name}
                  </Text>
                </Flex>
                <Field.ErrorText>
                  Nhập số lớn hơn 0, tối đa 6 chữ số sau dấu phẩy.
                </Field.ErrorText>
              </Field.Root>
            )}
          </Flex>
          {!draft.existing && w.current?.enabled && (
            <Text textStyle="helper">
              Định mức hiện tại là {quantity(w.current.quantity_per_day)}{" "}
              {w.current.unit_name}/ngày. Lưu để thay đổi định mức này.
            </Text>
          )}
          {reviewed && (
            <Box role="status">
              <Text fontWeight="semibold">
                {draft.stop
                  ? "Lượng theo định mức sau khi ngừng"
                  : "Lượng dự kiến trong tuần"}{" "}
                ·{" "}
                {quantity(
                  draft.stop ? "0" : (projection?.total_quantity ?? null),
                )}{" "}
                {draft.stop
                  ? w.current?.unit_name
                  : w.ingredient?.purchase_unit.unit_name}
              </Text>
              <Text textStyle="helper">
                {projection?.menu_dates.length
                  ? `Ngày có thực đơn: ${dates(projection.menu_dates)}`
                  : "Trường chưa có ngày thực đơn trong tuần."}
                {projection?.delivery_date
                  ? ` · ${draft.stop ? "Bỏ giao ngày" : "Giao ngày"} ${viDate(projection.delivery_date)}`
                  : ""}
              </Text>
            </Box>
          )}
          <Flex gap="sm" wrap="wrap">
            {reviewed ? (
              <Button
                size="sm"
                variant="businessPrimary"
                disabled={!w.canPreview}
                onClick={() => void w.save()}
              >
                {draft.stop ? "Xác nhận ngừng" : "Lưu định mức"}
              </Button>
            ) : (
              <Button
                size="sm"
                variant="businessPrimary"
                disabled={!w.canPreview}
                onClick={() => void w.preview()}
              >
                Xem lượng dự kiến
              </Button>
            )}
            <Button
              size="sm"
              variant="secondary"
              disabled={w.busy || w.uncertain || w.reloadNeeded}
              onClick={w.cancel}
            >
              Hủy
            </Button>
          </Flex>
        </Stack>
      )}
      {w.data && !w.data.can_manage && (
        <Text textStyle="helper">Bạn chỉ có quyền xem định mức.</Text>
      )}
      {w.data && !rows.length && (
        <Text color="fg.muted">
          Chưa có định mức áp dụng trong tuần cho các trường đang xem.
        </Text>
      )}
      {rows.map((r) => (
        <Grid
          key={r.school_id + r.ingredient_id}
          templateColumns={{
            base: "minmax(0,1fr)",
            md: "minmax(0,1.4fr) minmax(0,1.4fr) minmax(0,1fr) auto",
          }}
          gap="sm"
          alignItems="center"
          borderTopWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.subtle"
          py="sm"
        >
          <Box>
            <Text fontWeight="semibold">{r.ingredient_name}</Text>
            <Text textStyle="helper">{r.school_name}</Text>
          </Box>
          <Box>
            <Text>
              {r.enabled
                ? `${quantity(r.quantity_per_day)} ${r.unit_name}/ngày`
                : "Đã ngừng áp dụng"}
            </Text>
            <Text textStyle="helper" color="fg.muted">
              {r.enabled && r.menu_dates.length
                ? `${r.menu_dates.length} ngày có thực đơn · ${dates(r.menu_dates)}`
                : `Từ ${viDate(r.effective_from!)}`}
            </Text>
          </Box>
          <Box>
            <Text fontWeight="semibold">
              {quantity(r.total_quantity)} {r.unit_name}
            </Text>
            <Text textStyle="helper" color="fg.muted">
              {r.enabled && r.delivery_date
                ? `Giao ${viDate(r.delivery_date)}`
                : "Tuần này không giao"}
            </Text>
          </Box>
          {w.data?.can_manage && (
            <Flex gap="xs" wrap="wrap">
              <Button
                size="sm"
                variant="secondary"
                aria-label={`${r.enabled ? "Sửa" : "Áp dụng lại"} định mức ${r.ingredient_name} · ${r.school_name}`}
                disabled={!w.canEdit || !!draft}
                onClick={(e) => {
                  trigger.current = e.currentTarget;
                  w.start(r.school_id, r);
                }}
              >
                {r.enabled ? "Sửa" : "Áp dụng lại"}
              </Button>
              {r.enabled && (
                <Button
                  size="sm"
                  variant="tertiary"
                  aria-label={`Ngừng định mức ${r.ingredient_name} · ${r.school_name}`}
                  disabled={!w.canEdit || !!draft}
                  onClick={(e) => {
                    trigger.current = e.currentTarget;
                    w.start(r.school_id, r, true);
                  }}
                >
                  Ngừng
                </Button>
              )}
            </Flex>
          )}
        </Grid>
      ))}
    </Stack>
  );
}
