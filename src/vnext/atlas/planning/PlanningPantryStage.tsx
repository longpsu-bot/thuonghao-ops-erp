import {
  Box,
  Button,
  Checkbox,
  Field,
  Flex,
  Input,
  NativeSelect,
  Table,
  Text,
} from "@chakra-ui/react";
import { Fragment, useState } from "react";
import type { PlanningSourcesController } from "./usePlanningSources";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { pantryIssueCopy } from "./pantryIssueCopy";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";

function PantryFeedback({
  error,
  helper,
}: {
  error?: string;
  helper?: string;
}) {
  return (
    <Box
      data-pantry-feedback=""
      minH="var(--atlas-layout-pantry-feedback, 18px)"
    >
      {error ? (
        <Field.ErrorText>{error}</Field.ErrorText>
      ) : helper ? (
        <Text textStyle="helper" color="fg.muted">
          {helper}
        </Text>
      ) : null}
    </Box>
  );
}

export function PlanningPantryStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [addSchool, setAddSchool] = useState("");
  const schoolOrder = new Map(
    c.schools.map((school, index) => [school.school_id, index]),
  );
  const schools = (c.pantryData?.schools ?? [])
    .filter(
      (s) =>
        s.school_status === "ACTIVE" && visibleSchoolIds.includes(s.school_id),
    )
    .sort(compareCanonicalSchools);
  const rows = c.pantryRows
    .map((r, index) => ({ r, index }))
    .filter(
      ({ r }) =>
        r.service_date === c.date && visibleSchoolIds.includes(r.school_id),
    )
    .sort(
      (a, b) =>
        (schoolOrder.get(a.r.school_id) ?? Infinity) -
        (schoolOrder.get(b.r.school_id) ?? Infinity),
    );
  return (
    <>
      <Flex p="sm" gap="sm" wrap="wrap" align="center">
        <NativeSelect.Root
          disabled={!c.canEdit || c.noAdditions}
          w="var(--atlas-layout-add-school-width, 220px)"
        >
          <NativeSelect.Field
            aria-label="Trường cần thêm hàng"
            value={addSchool}
            onChange={(e) => setAddSchool(e.target.value)}
          >
            <option value="">Chọn trường cần thêm hàng</option>
            {schools.map((s) => (
              <option key={s.school_id} value={s.school_id}>
                {s.school_name}
              </option>
            ))}
          </NativeSelect.Field>
          <NativeSelect.Indicator />
        </NativeSelect.Root>
        <Button
          size="sm"
          disabled={
            !c.canEdit ||
            c.noAdditions ||
            !schools.some((s) => s.school_id === addSchool)
          }
          onClick={() => c.addPantryRow(addSchool)}
        >
          + Thêm dòng
        </Button>
        <Checkbox.Root
          checked={c.noAdditions}
          disabled={!c.canEdit || c.schoolIds.length > 0}
          onCheckedChange={(d) => c.requestNoAdditions(d.checked === true)}
        >
          <Checkbox.HiddenInput />
          <Checkbox.Control>
            <Checkbox.Indicator />
          </Checkbox.Control>
          <Checkbox.Label>
            Xác nhận cả tuần không có hàng đặt riêng
          </Checkbox.Label>
        </Checkbox.Root>
        {c.schoolIds.length > 0 && (
          <Text textStyle="helper" color="fg.muted">
            Chọn Tất cả trường để thay đổi xác nhận cho cả tuần.
          </Text>
        )}
      </Flex>
      {c.pantryData?.catalog_issues.blockers.map((i, n) => (
        <Text key={n} role="alert" p="sm" color="status.danger">
          {pantryIssueCopy(i)}
        </Text>
      ))}
      {c.pantryData?.catalog_issues.warnings.map((i, n) => (
        <Text key={n} p="sm" textStyle="helper" color="status.warning">
          {pantryIssueCopy(i)}
        </Text>
      ))}
      {!rows.length && (
        <Text p="md" color="fg.muted">
          {!visibleSchoolIds.length
            ? "Không có trường phù hợp bộ lọc."
            : c.pantryRows.some((row) => row.service_date === c.date)
              ? "Không có hàng đặt riêng khớp bộ lọc trong ngày này."
              : c.noAdditions
                ? "Đã chọn xác nhận không có hàng đặt riêng trong cả tuần."
                : "Chưa có hàng đặt riêng trong ngày này. Chưa xác nhận cả tuần không có hàng đặt riêng."}
        </Text>
      )}
      <AtlasTableViewport
        label="Bảng hàng đặt riêng"
        maxH="var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
      >
        <Table.Root
          aria-label="Hàng đặt riêng"
          tableLayout="fixed"
          w="var(--atlas-pantry-table-width, 1156px)"
          minW="var(--atlas-pantry-table-width, 1156px)"
          size="sm"
          stickyHeader
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-pantry-school-column, 210px)" />
            <Table.Column w="var(--atlas-pantry-ingredient-column, 210px)" />
            <Table.Column w="var(--atlas-pantry-quantity-column, 130px)" />
            <Table.Column w="var(--atlas-pantry-note-column, 190px)" />
            <Table.Column w="var(--atlas-pantry-reference-column, 130px)" />
            <Table.Column w="var(--atlas-pantry-action-column, 96px)" />
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row>
              {[
                "Trường / điểm giao",
                "Nguyên liệu / Đơn vị",
                "Số lượng",
                "Ghi chú / Lý do",
                "Tham chiếu",
                "",
              ].map((name, i) => (
                <Table.ColumnHeader key={i}>{name}</Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {schools
              .filter((s) => rows.some(({ r }) => r.school_id === s.school_id))
              .map((s) => (
                <Fragment key={s.school_id}>
                  <Table.Row bg="bg.subtle">
                    <Table.Cell colSpan={6}>
                      <Flex align="center" gap="sm" wrap="wrap">
                        <Box>
                          <Text fontWeight="semibold">{s.school_name}</Text>
                          <Text textStyle="helper" color="fg.muted">
                            {s.default_delivery_location.location_name}
                          </Text>
                        </Box>
                        <NativeSelect.Root
                          disabled={!c.canEdit}
                          w="var(--atlas-layout-mode-width, 230px)"
                        >
                          <NativeSelect.Field
                            aria-label={`Cách kết hợp ${s.school_name}`}
                            value={
                              c.modes.find(
                                (m) =>
                                  m.school_id === s.school_id &&
                                  m.service_date === c.date,
                              )?.direct_need_mode ?? "ADDITIVE"
                            }
                            onChange={(e) =>
                              c.setMode(
                                s.school_id,
                                e.target.value === "COMPLETE"
                                  ? "COMPLETE"
                                  : "ADDITIVE",
                              )
                            }
                          >
                            <option value="ADDITIVE">Cộng với thực đơn</option>
                            <option value="COMPLETE">Danh sách đầy đủ</option>
                          </NativeSelect.Field>
                          <NativeSelect.Indicator />
                        </NativeSelect.Root>
                      </Flex>
                    </Table.Cell>
                  </Table.Row>
                  {rows
                    .filter(({ r }) => r.school_id === s.school_id)
                    .map(({ r, index }) => {
                      const errors = c.pantryRowErrors[index];
                      const unit = c.pantryData?.ingredients.find(
                        (i) => i.ingredient_id === r.ingredient_id,
                      )?.purchase_unit.unit_name;
                      const selectedSchool = c.pantryData?.schools.find(
                        (school) => school.school_id === r.school_id,
                      );
                      return (
                        <Table.Row key={r.source_row_reference || index}>
                          <Table.Cell>
                            <NativeSelect.Root disabled={!c.canEdit}>
                              <NativeSelect.Field
                                aria-label={`Trường dòng ${index + 1}`}
                                value={r.school_id}
                                minW="var(--atlas-layout-pantry-school-width, 180px)"
                                onChange={(e) =>
                                  c.editPantryRow(index, {
                                    school_id: e.target.value,
                                  })
                                }
                              >
                                {c.schools
                                  .filter(
                                    (school) =>
                                      school.school_status === "ACTIVE",
                                  )
                                  .map((school) => (
                                    <option
                                      key={school.school_id}
                                      value={school.school_id}
                                    >
                                      {school.school_name}
                                    </option>
                                  ))}
                              </NativeSelect.Field>
                              <NativeSelect.Indicator />
                            </NativeSelect.Root>
                            <PantryFeedback
                              helper={
                                selectedSchool?.default_delivery_location
                                  .location_name
                              }
                            />
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.ingredient}>
                              <NativeSelect.Root
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-ingredient-width, 180px)"
                              >
                                <NativeSelect.Field
                                  aria-label={`Nguyên liệu dòng ${index + 1}`}
                                  value={r.ingredient_id}
                                  onChange={(e) =>
                                    c.editPantryRow(index, {
                                      ingredient_id: e.target.value,
                                    })
                                  }
                                >
                                  <option value="">Chọn nguyên liệu</option>
                                  {c.pantryData?.ingredients
                                    .filter(
                                      (i) => i.ingredient_status === "ACTIVE",
                                    )
                                    .map((i) => (
                                      <option
                                        key={i.ingredient_id}
                                        value={i.ingredient_id}
                                      >
                                        {i.ingredient_name}
                                      </option>
                                    ))}
                                </NativeSelect.Field>
                                <NativeSelect.Indicator />
                              </NativeSelect.Root>
                              <PantryFeedback
                                error={errors.ingredient}
                                helper={unit}
                              />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.quantity}>
                              <Input
                                aria-label={`Số lượng dòng ${index + 1}`}
                                inputMode="decimal"
                                value={r.requested_quantity}
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-quantity-width, 90px)"
                                onChange={(e) =>
                                  c.editPantryRow(index, {
                                    requested_quantity: e.target.value,
                                  })
                                }
                              />
                              <PantryFeedback error={errors.quantity} />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root>
                              <Input
                                aria-label={`Ghi chú dòng ${index + 1}`}
                                value={r.note}
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-note-width, 150px)"
                                onChange={(e) =>
                                  c.editPantryRow(index, {
                                    note: e.target.value,
                                  })
                                }
                              />
                              <PantryFeedback helper="Không bắt buộc." />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Input
                              aria-label={`Tham chiếu dòng ${index + 1}`}
                              value={r.source_request_reference}
                              disabled={!c.canEdit}
                              minW="var(--atlas-layout-reference-width, 110px)"
                              onChange={(e) =>
                                c.editPantryRow(index, {
                                  source_request_reference: e.target.value,
                                })
                              }
                            />
                            <PantryFeedback />
                          </Table.Cell>
                          <Table.Cell>
                            <Button
                              variant="tertiary"
                              size="sm"
                              aria-label={`Bỏ dòng ${index + 1}`}
                              disabled={!c.canEdit}
                              onClick={() => c.removePantryRow(index)}
                            >
                              Bỏ
                            </Button>
                          </Table.Cell>
                        </Table.Row>
                      );
                    })}
                </Fragment>
              ))}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
    </>
  );
}
