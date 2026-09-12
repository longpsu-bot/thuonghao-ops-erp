import { AtlasDateInput } from "../AtlasDateInput";
import {
  Box,
  Button,
  Field,
  Grid,
  Input,
  NativeSelect,
  Text,
  Textarea,
} from "@chakra-ui/react";
import type { ReactNode } from "react";
import type { ChangeOrderController } from "./useChangeOrderWorkbench";
import {
  actionLabels,
  actionsFor,
  changeSchoolTypes,
  impactContext,
  needsQuantity,
  purchaseIngredient,
  scopeFromDecisions,
  targetIngredientId,
  targetKey,
  type ChangeDraft,
} from "./changeOrderModel";
import { parseQuantity } from "./recipeDraftModel";
export function ChangeSelect({
  label,
  value,
  onChange,
  disabled,
  children,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
  children: ReactNode;
}) {
  return (
    <Field.Root>
      <Field.Label>{label}</Field.Label>
      <NativeSelect.Root disabled={disabled}>
        <NativeSelect.Field
          value={value}
          onChange={(e) => onChange(e.target.value)}
        >
          {children}
        </NativeSelect.Field>
        <NativeSelect.Indicator />
      </NativeSelect.Root>
    </Field.Root>
  );
}
export function ChangeOrderEditor({ c }: { c: ChangeOrderController }) {
  const d = c.draft!;
  const scope = scopeFromDecisions(d.object, d.audience),
    context = impactContext(d, c.data);
  const disabled = !c.canAct || Boolean(c.preview),
    frozen = disabled || Boolean(c.editing);
  const update = (p: Partial<ChangeDraft>) => c.updateDraft(p);
  const clearTarget = {
    targetKey: "",
    ingredientId: "",
    substituteId: "",
    quantity: "",
    replaceQuantity: false,
  };
  const schools = c.data.schools.filter((s) => s.school_status === "ACTIVE");
  const dishes = c.data.dishes.filter((s) => s.dish_status === "ACTIVE");
  const ingredients = c.data.ingredients.filter(
    (s) => s.ingredient_status === "ACTIVE",
  );
  const ingredientOptions = ingredients.map((i) => (
    <option key={i.ingredient_id} value={i.ingredient_id}>
      {i.ingredient_name}
    </option>
  ));
  const dishOptions = dishes.map((i) => (
    <option key={i.dish_id} value={i.dish_id}>
      {i.dish_name}
    </option>
  ));
  const schoolOptions = schools.map((i) => (
    <option key={i.school_id} value={i.school_id}>
      {i.school_name}
    </option>
  ));
  return (
    <Box
      as="form"
      aria-label={c.editing ? "Sửa lệnh" : "Tạo lệnh điều chỉnh"}
      onSubmit={(e) => {
        e.preventDefault();
        void c.runPreview();
      }}
    >
      <Grid templateColumns="repeat(2, minmax(0, 1fr))" gap="sm" mt="sm">
        <ChangeSelect
          label="Điều chỉnh"
          value={d.object}
          disabled={frozen}
          onChange={(v) =>
            update({
              object: v as ChangeDraft["object"],
              action: "",
              ...clearTarget,
              dishId: "",
              schoolId: "",
              schoolTypeId: "",
              previewDishId: "",
              previewSchoolId: "",
            })
          }
        >
          <option value="recipe">Công thức của một món</option>
          <option value="ingredient">Một nguyên liệu</option>
        </ChangeSelect>
        <ChangeSelect
          label="Áp dụng cho"
          value={d.audience}
          disabled={frozen}
          onChange={(v) =>
            update({
              audience: v as ChangeDraft["audience"],
              action: "",
              ...clearTarget,
              schoolId: "",
              schoolTypeId: "",
              previewSchoolId: "",
            })
          }
        >
          <option value="all">Tất cả trường</option>
          <option value="one">Một trường</option>
        </ChangeSelect>
        {d.audience === "one" && (
          <ChangeSelect
            label="Trường"
            value={d.schoolId}
            disabled={frozen}
            onChange={(v) => update({ schoolId: v, ...clearTarget })}
          >
            <option value="">Chọn trường</option>
            {schoolOptions}
          </ChangeSelect>
        )}
        {d.object === "recipe" && (
          <ChangeSelect
            label="Món"
            value={d.dishId}
            disabled={frozen}
            onChange={(v) => update({ dishId: v, ...clearTarget })}
          >
            <option value="">Chọn món</option>
            {dishOptions}
          </ChangeSelect>
        )}
        {scope === "SYSTEM_DISH" && (
          <ChangeSelect
            label="Loại công thức"
            value={d.schoolTypeId}
            disabled={frozen}
            onChange={(v) => update({ schoolTypeId: v, ...clearTarget })}
          >
            <option value="">Chọn loại công thức</option>
            {changeSchoolTypes(c.data).map((t) => (
              <option key={t.school_type_id} value={t.school_type_id}>
                {t.school_type_name}
              </option>
            ))}
          </ChangeSelect>
        )}
        {scope === "SCHOOL_DISH" && (
          <Text textStyle="helper" color="fg.muted" alignSelf="end">
            Loại công thức:{" "}
            {c.data.school_types.find(
              (t) => t.school_type_id === context.schoolTypeId,
            )?.school_type_name ?? "Chọn trường trước"}
          </Text>
        )}
        {d.object === "ingredient" && (
          <ChangeSelect
            label="Nguyên liệu"
            value={d.ingredientId}
            disabled={frozen}
            onChange={(v) => update({ ingredientId: v })}
          >
            <option value="">Chọn nguyên liệu</option>
            {ingredientOptions}
          </ChangeSelect>
        )}
        <ChangeSelect
          label="Hành động"
          value={d.action}
          disabled={frozen}
          onChange={(v) =>
            update({
              action: v as ChangeDraft["action"],
              targetKey: "",
              substituteId: "",
              quantity: "",
              replaceQuantity: false,
            })
          }
        >
          <option value="">Chọn hành động</option>
          {actionsFor(scope, c.data).map((a) => (
            <option key={a} value={a}>
              {actionLabels[a]}
            </option>
          ))}
        </ChangeSelect>
        {d.object === "recipe" && d.action && d.action !== "ADD" && (
          <Box>
            <ChangeSelect
              label="Thành phần hiện tại"
              value={d.targetKey}
              disabled={frozen || c.targetLoading || !c.targets}
              onChange={(v) => update({ targetKey: v })}
            >
              <option value="">
                {c.targetLoading ? "Đang tải thành phần…" : "Chọn thành phần"}
              </option>
              {c.editing &&
                !c.targets?.effective_lines.some(
                  (l) => targetKey(l) === d.targetKey,
                ) && (
                  <option value={d.targetKey}>
                    {c.data.ingredients.find(
                      (i) =>
                        i.ingredient_id ===
                        targetIngredientId(c.editing!, c.data),
                    )?.ingredient_name ?? "Thành phần của lệnh đã chọn"}
                  </option>
                )}
              {c.targets?.effective_lines.map((l) => (
                <option key={targetKey(l)} value={targetKey(l)}>
                  {l.ingredient_name} ·{" "}
                  {l.quantity_per_basis.toLocaleString("vi-VN")} {l.unit_name}
                </option>
              ))}
            </ChangeSelect>
          </Box>
        )}
        {d.action === "ADD" && (
          <ChangeSelect
            label="Nguyên liệu thêm"
            value={d.ingredientId}
            disabled={frozen}
            onChange={(v) => update({ ingredientId: v })}
          >
            <option value="">Chọn nguyên liệu</option>
            {ingredientOptions}
          </ChangeSelect>
        )}
        {d.action === "REPLACE" && (
          <ChangeSelect
            label="Nguyên liệu thay thế"
            value={d.substituteId}
            disabled={disabled}
            onChange={(v) => update({ substituteId: v })}
          >
            <option value="">Chọn nguyên liệu</option>
            {ingredientOptions}
          </ChangeSelect>
        )}
        {d.action === "REPLACE" && (
          <ChangeSelect
            label="Định lượng"
            value={d.replaceQuantity ? "change" : "keep"}
            disabled={disabled}
            onChange={(v) =>
              update({ replaceQuantity: v === "change", quantity: "" })
            }
          >
            <option value="keep">Giữ định lượng hiện tại</option>
            <option value="change">Nhập định lượng mới</option>
          </ChangeSelect>
        )}
        {needsQuantity(d) && (
          <Field.Root
            invalid={Boolean(d.quantity && parseQuantity(d.quantity) === null)}
          >
            <Field.Label>Định lượng mới</Field.Label>
            <Input
              inputMode="decimal"
              value={d.quantity}
              disabled={disabled}
              onChange={(e) => update({ quantity: e.target.value })}
            />
            <Field.ErrorText>Nhập số thập phân lớn hơn 0.</Field.ErrorText>
            <Field.HelperText>
              {d.action === "ADJUST_QUANTITY"
                ? c.targets?.effective_lines.find(
                    (l) => targetKey(l) === d.targetKey,
                  )?.unit_name
                : (purchaseIngredient(d, c.data)?.purchase_unit_name ??
                  "Nguyên liệu chưa có đơn vị mua")}
            </Field.HelperText>
          </Field.Root>
        )}
        {d.action === "REMOVE" && (
          <Text gridColumn="1 / -1" textStyle="helper" color="fg.muted">
            Thành phần đã chọn sẽ được bỏ khỏi công thức trong thời gian hiệu
            lực.
          </Text>
        )}
        {d.object === "ingredient" && (
          <Box
            as="fieldset"
            gridColumn="1 / -1"
            borderWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.subtle"
            borderRadius="control"
            p="sm"
          >
            <Text as="legend" textStyle="helper">
              Ngữ cảnh kiểm tra tác động
            </Text>
            <Grid templateColumns="repeat(2, minmax(0, 1fr))" gap="sm">
              {d.audience === "all" && (
                <ChangeSelect
                  label="Trường kiểm tra"
                  value={d.previewSchoolId}
                  disabled={disabled}
                  onChange={(v) => update({ previewSchoolId: v })}
                >
                  <option value="">Chọn trường</option>
                  {schoolOptions}
                </ChangeSelect>
              )}
              <ChangeSelect
                label="Món kiểm tra"
                value={d.previewDishId}
                disabled={disabled}
                onChange={(v) => update({ previewDishId: v })}
              >
                <option value="">Chọn món</option>
                {dishOptions}
              </ChangeSelect>
            </Grid>
            <Text textStyle="helper" color="fg.muted" mt="xs">
              Chỉ kiểm tra tác động; phạm vi áp dụng giữ nguyên.
            </Text>
          </Box>
        )}
        <AtlasDateInput
          label="Hiệu lực từ"
          value={d.effectiveFrom}
          disabled={disabled}
          onValueChange={(v) =>
            update({
              effectiveFrom: v,
              targetKey: c.editing ? d.targetKey : "",
            })
          }
        />
        <Box>
          <ChangeSelect
            label="Thời hạn"
            value={d.effectiveTo ? "until" : "open"}
            disabled={disabled}
            onChange={(v) =>
              update({
                effectiveTo:
                  v === "until"
                    ? new Date(Date.parse(d.effectiveFrom) + 86400000)
                        .toISOString()
                        .slice(0, 10)
                    : "",
              })
            }
          >
            <option value="open">Không giới hạn</option>
            <option value="until">Đến trước một ngày</option>
          </ChangeSelect>
          {d.effectiveTo && (
            <AtlasDateInput
              label="Đến trước"
              value={d.effectiveTo}
              disabled={disabled}
              onValueChange={(v) => update({ effectiveTo: v })}
            />
          )}
          <Text textStyle="helper" color="fg.muted">
            Nếu nhập, lệnh không còn hiệu lực từ ngày này.
          </Text>
          {d.effectiveTo && d.effectiveTo <= d.effectiveFrom && (
            <Text role="alert" textStyle="helper" color="status.danger">
              Ngày kết thúc phải sau ngày bắt đầu.
            </Text>
          )}
        </Box>
        <Field.Root gridColumn="1 / -1">
          <Field.Label>Lý do điều chỉnh</Field.Label>
          <Textarea
            rows={2}
            value={d.reason}
            disabled={disabled}
            onChange={(e) => update({ reason: e.target.value })}
          />
        </Field.Root>
      </Grid>
      {c.targets?.blockers.map((b, i) => (
        <Text key={i} role="alert" color="status.danger" textStyle="helper">
          {b.message}
        </Text>
      ))}
      <Box
        position="sticky"
        bottom="var(--atlas-layout-zero, 0)"
        bg="bg.workbench"
        py="sm"
      >
        <Button
          type="submit"
          variant="businessPrimary"
          loading={c.previewLoading}
          disabled={!c.canPreview}
        >
          Xem tác động
        </Button>
      </Box>
    </Box>
  );
}
