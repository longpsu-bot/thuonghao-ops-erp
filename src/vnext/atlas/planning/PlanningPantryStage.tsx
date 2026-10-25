import {
  Box,
  Button,
  Field,
  Flex,
  Input,
  IconButton,
  NativeSelect,
  Table,
  Text,
} from "@chakra-ui/react";
import { Fragment, useId, useRef, useState } from "react";
import { Trash } from "@phosphor-icons/react";
import { PantryIngredientChooser } from "./PantryIngredientChooser";
import { PantrySchoolChooser } from "./PantrySchoolChooser";
import { AtlasQuantityContext } from "../AtlasQuantityContext";
import type { PlanningSourcesController } from "./usePlanningSources";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { atlasWorkbarControlHeight } from "../AtlasWorkbar";
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
  const [addCategory, setAddCategory] = useState(
    "planning_identified_supplement",
  );
  const categoryLabels: Record<string, string> = {
    planning_identified_supplement: "Bổ sung",
    school_requested_supplement: "Hàng đặt riêng",
  };
  const creationPurposes = (c.pantryData?.purposes ?? []).filter(
    (purpose) =>
      purpose.purpose_status === "ACTIVE" &&
      categoryLabels[purpose.purpose_code],
  );
  const targetPurpose = creationPurposes.find(
    (purpose) => purpose.purpose_code === addCategory,
  );
  const rowPurpose = (purposeId: string) =>
    c.pantryData?.purposes.find(
      (purpose) => purpose.pantry_need_purpose_id === purposeId,
    );
  const sourceLabel = (purposeId: string) => {
    const purpose = rowPurpose(purposeId);
    const saved = c.pantryData?.batch?.active_lines.find(
      (line) => line.pantry_need_purpose_id === purposeId,
    );
    const code = purpose?.purpose_code ?? saved?.purpose_code ?? "";
    return (
      categoryLabels[code] ??
      purpose?.purpose_name_vi ??
      saved?.purpose_name_vi ??
      "Phân loại đã lưu"
    );
  };
  const quantityContextId = useId();
  const addButton = useRef<HTMLButtonElement>(null);
  const addSchoolInput = useRef<HTMLInputElement>(null);
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
          (schoolOrder.get(b.r.school_id) ?? Infinity) ||
        a.r.pantry_need_purpose_id.localeCompare(b.r.pantry_need_purpose_id),
    );
  const automaticSchool =
    c.schoolIds.length === 1
      ? schools.find((s) => s.school_id === c.schoolIds[0])
      : undefined;
  const targetSchoolId =
    automaticSchool?.school_id ??
    (schools.some((s) => s.school_id === addSchool) ? addSchool : "");
  const schoolMode = (schoolId: string) =>
    c.modes.find(
      (mode) => mode.school_id === schoolId && mode.service_date === c.date,
    )?.direct_need_mode ?? "ADDITIVE";
  const modeLabels = {
    ADDITIVE: "Cộng với thực đơn",
    COMPLETE: "Danh sách đầy đủ (lịch sử)",
  };
  return (
    <>
      <Flex p="sm" gap="sm" wrap="wrap" align="end">
        {automaticSchool ? (
          <Box>
            <Text fontWeight="semibold">
              Thêm cho {automaticSchool.school_name}
            </Text>
            <Text textStyle="helper" color="fg.muted">
              {automaticSchool.default_delivery_location.location_name}
            </Text>
          </Box>
        ) : (
          <Field.Root
            display={{ base: "contents", lg: "flex" }}
            w={{
              base: "full",
              md: "var(--atlas-layout-add-school-width, 220px)",
            }}
            gap="xs"
          >
            <Field.Label display={{ base: "none", lg: "block" }}>
              Trường cần thêm hàng
            </Field.Label>
            <PantrySchoolChooser
              inputRef={addSchoolInput}
              schools={schools}
              value={targetSchoolId}
              onChange={setAddSchool}
              disabled={!c.canEdit}
            />
          </Field.Root>
        )}
        <Field.Root
          disabled={!c.canEdit || !targetSchoolId}
          w={{ base: "full", md: "var(--atlas-layout-source-width, 270px)" }}
          gap="xs"
        >
          <Field.Label>Nguồn của dòng mới</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              value={addCategory}
              onChange={(event) => setAddCategory(event.target.value)}
            >
              {Object.entries(categoryLabels).map(([code, label]) => (
                <option
                  key={code}
                  value={code}
                  disabled={
                    !creationPurposes.some((p) => p.purpose_code === code)
                  }
                >
                  {label}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Button
          ref={addButton}
          size="sm"
          h={atlasWorkbarControlHeight}
          disabled={!c.canEdit || !targetSchoolId || !targetPurpose}
          onClick={() =>
            c.addPantryRow(
              targetSchoolId,
              targetPurpose?.pantry_need_purpose_id,
            )
          }
        >
          + Thêm dòng
        </Button>
      </Flex>
      {!targetSchoolId && (
        <Text
          display={{ base: "none", lg: "block" }}
          px="sm"
          pb="sm"
          textStyle="helper"
          color="fg.muted"
        >
          Chọn trường cần thêm hàng để bật Thêm dòng.
        </Text>
      )}
      {!targetPurpose && (
        <Text px="sm" role="status" textStyle="helper" color="status.warning">
          Nguồn đã chọn chưa có trong danh mục đang hoạt động. Hãy tải lại danh
          mục trước khi thêm dòng.
        </Text>
      )}
      {c.dirty && rows.length < c.pantryRows.length && (
        <Text role="status" px="sm" textStyle="helper" color="fg.muted">
          {c.pantryRows.length - rows.length} dòng ngoài bộ lọc vẫn được giữ để
          lưu.
        </Text>
      )}
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
              : "Không có bổ sung hoặc hàng đặt riêng trong ngày này."}
        </Text>
      )}
      <AtlasTableViewport
        label="Bảng hàng đặt riêng"
        maxH="var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
      >
        <Table.Root
          aria-label="Hàng đặt riêng"
          tableLayout="fixed"
          w="full"
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: "var(--atlas-pantry-table-width, 1156px)",
          }}
          size="sm"
          stickyHeader
          css={{
            "@media(max-width:47.99rem)": {
              "& colgroup": { display: "none" },
              "& thead": {
                position: "absolute",
                width: "1px",
                height: "1px",
                overflow: "hidden",
                clip: "rect(0, 0, 0, 0)",
                whiteSpace: "nowrap",
              },
              "& tbody": { display: "block" },
              "& tr": {
                display: "grid",
                gridTemplateColumns: "minmax(0, 1fr) auto",
                borderBottom: "1px solid var(--atlas-colors-border-subtle)",
              },
              "& td": { display: "block", minWidth: 0, border: 0 },
              "& td:not(:last-child)": { gridColumn: "1 / -1" },
              "& tr[data-pantry-line] td:first-of-type": { display: "none" },
              "& td[data-pantry-quantity]": { gridColumn: "1 / -1" },
            },
          }}
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
                        <Text textStyle="helper" color="fg.muted">
                          {modeLabels[schoolMode(s.school_id)]}
                        </Text>
                      </Flex>
                    </Table.Cell>
                  </Table.Row>
                  {rows
                    .filter(({ r }) => r.school_id === s.school_id)
                    .map(({ r, index }, groupIndex, schoolRows) => {
                      const startsSource =
                        groupIndex === 0 ||
                        schoolRows[groupIndex - 1].r.pantry_need_purpose_id !==
                          r.pantry_need_purpose_id;
                      const errors = c.pantryRowErrors[index];
                      const ingredient = c.pantryData?.ingredients.find(
                        (i) => i.ingredient_id === r.ingredient_id,
                      );
                      const unit = ingredient?.purchase_unit.unit_name;
                      const saved = c.pantryData?.batch?.active_lines.find(
                        (line) =>
                          line.source_row_reference === r.source_row_reference,
                      );
                      const selectedSchool = c.pantryData?.schools.find(
                        (school) => school.school_id === r.school_id,
                      );
                      return (
                        <Fragment key={r.source_row_reference || index}>
                          {startsSource && (
                            <Table.Row
                              data-pantry-source={r.pantry_need_purpose_id}
                            >
                              <Table.Cell colSpan={6} py="xs" bg="bg.subtle">
                                <Text fontWeight="semibold">
                                  {sourceLabel(r.pantry_need_purpose_id)}
                                </Text>
                              </Table.Cell>
                            </Table.Row>
                          )}
                          <Table.Row data-pantry-line="">
                            <Table.Cell>
                              <Text fontWeight="medium">
                                {selectedSchool?.school_name}
                              </Text>
                              <PantryFeedback
                                helper={
                                  selectedSchool?.default_delivery_location
                                    .location_name
                                }
                              />
                              <Text textStyle="helper" color="fg.muted">
                                {r.service_date.split("-").reverse().join("/")}
                              </Text>
                            </Table.Cell>
                            <Table.Cell>
                              <Field.Root invalid={!!errors.ingredient}>
                                <Field.Label hideFrom="md">
                                  Nguyên liệu
                                </Field.Label>
                                <PantryIngredientChooser
                                  label={`Nguyên liệu dòng ${index + 1}`}
                                  ingredients={c.pantryData?.ingredients ?? []}
                                  value={r.ingredient_id}
                                  disabled={!c.canEdit}
                                  invalid={!!errors.ingredient}
                                  onChange={(ingredient_id) =>
                                    c.editPantryRow(index, { ingredient_id })
                                  }
                                />
                                <PantryFeedback
                                  error={errors.ingredient}
                                  helper={unit}
                                />
                              </Field.Root>
                            </Table.Cell>
                            <Table.Cell data-pantry-quantity="">
                              <AtlasQuantityContext
                                id={`${quantityContextId}-${r.source_row_reference}`}
                                recipient={selectedSchool?.school_name}
                                location={
                                  selectedSchool?.default_delivery_location
                                    .location_name
                                }
                                ingredient={
                                  ingredient?.ingredient_name ??
                                  "Chọn nguyên liệu"
                                }
                                date={r.service_date}
                                unit={ingredient?.purchase_unit.unit_code}
                                source={sourceLabel(r.pantry_need_purpose_id)}
                              />
                              <Text textStyle="helper" color="fg.muted" mb="xs">
                                {saved
                                  ? `Đã lưu${saved.ingredient_id !== r.ingredient_id ? ` ${saved.ingredient_name}` : ""}: ${saved.requested_quantity} ${saved.unit_code}`
                                  : "Dòng mới · chưa lưu"}
                              </Text>
                              <Field.Root invalid={!!errors.quantity}>
                                <Field.Label hideFrom="md">
                                  Số lượng đang nhập
                                </Field.Label>
                                <Flex gap="xs" align="center">
                                  <Input
                                    aria-label={`Số lượng dòng ${index + 1}`}
                                    aria-describedby={`${quantityContextId}-${r.source_row_reference}`}
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
                                  <Text textStyle="unitInline">
                                    {ingredient?.purchase_unit.unit_code}
                                  </Text>
                                </Flex>
                                <PantryFeedback error={errors.quantity} />
                              </Field.Root>
                            </Table.Cell>
                            <Table.Cell>
                              <Field.Root>
                                <Field.Label hideFrom="md">
                                  Ghi chú / Lý do
                                </Field.Label>
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
                                <PantryFeedback
                                  helper={
                                    rowPurpose(r.pantry_need_purpose_id)
                                      ?.note_rule === "REQUIRED"
                                      ? "Cần ghi chú theo phân loại đã lưu."
                                      : rowPurpose(r.pantry_need_purpose_id)
                                            ?.note_rule === "PROHIBITED"
                                        ? "Phân loại này không nhận ghi chú."
                                        : "Không bắt buộc."
                                  }
                                />
                              </Field.Root>
                            </Table.Cell>
                            <Table.Cell>
                              <Field.Root>
                                <Field.Label hideFrom="md">
                                  Tham chiếu
                                </Field.Label>
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
                              </Field.Root>
                            </Table.Cell>
                            <Table.Cell>
                              <IconButton
                                variant="tertiary"
                                size="sm"
                                aria-label={`Xóa dòng ${index + 1}${ingredient ? ` · ${ingredient.ingredient_name}` : ""}`}
                                title={`Xóa dòng ${index + 1}`}
                                disabled={!c.canEdit}
                                onClick={() => {
                                  c.removePantryRow(index);
                                  if (
                                    addButton.current &&
                                    !addButton.current.disabled
                                  )
                                    addButton.current.focus();
                                  else addSchoolInput.current?.focus();
                                }}
                              >
                                <Trash aria-hidden="true" />
                              </IconButton>
                            </Table.Cell>
                          </Table.Row>
                        </Fragment>
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
