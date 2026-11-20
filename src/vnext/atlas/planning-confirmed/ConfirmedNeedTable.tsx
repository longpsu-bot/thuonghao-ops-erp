import { Icon, Box, Button, Input, Table, Text } from "@chakra-ui/react";
import { WarningCircle } from "@phosphor-icons/react";
import { useId, useState } from "react";
import type { CSSProperties } from "react";
import {
  AtlasSortableColumnHeader,
  atlasRecordSortHeader,
} from "../AtlasSortableColumnHeader";
import { atlasVisuallyHidden } from "../AtlasTaskTabs";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { AtlasQuantityContext } from "../AtlasQuantityContext";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";
import {
  atlasDefaultSort,
  compareAtlasBigInt,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";
import {
  confirmedNeedConfirmationStateLabel,
  confirmedNeedInputDisplay,
  confirmedNeedReasonLabels,
  exactDecimalEqual,
  exactQuantityDisplay,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedQuantity,
  subtractExactDecimals,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
} from "../bridges/confirmedNeed";
import {
  confirmedNeedSchool,
  confirmedNeedUnitLabel,
  type ConfirmedNeedDraftError,
  historicalQuantity,
} from "./confirmedNeedDraft";
import { parseExactQuantity } from "../procurement/procurementExactQuantity";
export function ConfirmedNeedTable({
  lines,
  drafts,
  errors,
  editable,
  onEditReason,
  onEdit,
}: {
  lines: ConfirmedNeedLine[];
  drafts: Record<string, ConfirmedNeedDraftLine>;
  errors: Record<string, ConfirmedNeedDraftError>;
  editable: boolean;
  onEditReason?: (line: ConfirmedNeedLine, trigger: HTMLButtonElement) => void;
  onEdit: (id: string, change: Partial<ConfirmedNeedDraftLine>) => void;
}) {
  type SortKey = "school" | "ingredient" | "proposal";
  const id = useId();
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const compareSchool = (left: ConfirmedNeedLine, right: ConfirmedNeedLine) =>
    compareCanonicalSchools(
      confirmedNeedSchool(left.school),
      confirmedNeedSchool(right.school),
    ) ||
    compareAtlasText(left.delivery_location.name, right.delivery_location.name);
  const comparators = {
    school: (left, right) =>
      compareAtlasText(left.school.name, right.school.name) ||
      compareAtlasText(
        left.delivery_location.name,
        right.delivery_location.name,
      ),
    ingredient: (left, right) =>
      compareAtlasText(left.ingredient.name, right.ingredient.name),
    proposal: (left, right) =>
      compareAtlasBigInt(
        parseExactQuantity(left.proposed_confirmed_quantity),
        parseExactQuantity(right.proposed_confirmed_quantity),
      ),
  } satisfies Record<
    SortKey,
    (left: ConfirmedNeedLine, right: ConfirmedNeedLine) => number
  >;
  const sortedLines =
    sort.direction === "default" || sort.key === null
      ? [...lines].sort(
          (left, right) =>
            compareSchool(left, right) ||
            compareAtlasText(left.ingredient.name, right.ingredient.name) ||
            left.service_date.localeCompare(right.service_date),
        )
      : sortAtlasRows(lines, sort, comparators);
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <AtlasTableViewport
      label="Bảng xác nhận nhu cầu"
      onFocusCapture={(event) => {
        const control = event.target;
        if (
          !(control instanceof HTMLElement) ||
          !control.matches("input, select")
        )
          return;
        const viewport = event.currentTarget;
        const visible = viewport.getBoundingClientRect();
        const bounds = control.getBoundingClientRect();
        const stickyIdentity = control
          .closest("[data-confirmed-need-line]")
          ?.querySelector<HTMLElement>('[data-field="identity"]');
        const usableLeft = control.closest('[data-field="identity"]')
          ? visible.left
          : Math.max(
              visible.left,
              stickyIdentity?.getBoundingClientRect().right ?? visible.left,
            );
        // Native focus can leave a partially visible field clipped. Reveal only
        // its nearest horizontal edge within this table, including space covered
        // by the frozen recipient cell, without moving the page.
        if (bounds.left < usableLeft)
          viewport.scrollLeft += bounds.left - usableLeft;
        else if (bounds.right > visible.right)
          viewport.scrollLeft += bounds.right - visible.right;
      }}
      fillAvailableHeight
    >
      <Table.Root
        aria-label="Nhu cầu xác nhận"
        size="sm"
        stickyHeader
        style={
          {
            "--atlas-confirmed-need-header-height": "38px",
            "--atlas-confirmed-need-row-min-height": "46px",
          } as CSSProperties
        }
        minW="var(--atlas-layout-confirmed-need-table-min, 910px)"
        w="full"
        tableLayout="fixed"
        css={{
          "@media(min-width:48rem)": {
            "& tbody td": {
              paddingBlock: "var(--atlas-spacing-1, 4px)",
              verticalAlign: "middle",
            },
            "& [data-role=service-date], & [data-row-secondary]": {
              display: "inline",
            },
            "& [data-row-secondary]::before": { content: '" · "' },
          },
          "@media(max-width:47.99rem)": {
            minWidth: 0,
            "& colgroup": { display: "none" },
            "& thead th:has(button)": {
              flex: "1 1 calc(33.333% - var(--atlas-spacing-xs))",
              height: "auto",
            },
            "& tbody": { display: "block" },
            "& tbody tr": {
              display: "grid",
              gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
              gridTemplateAreas:
                '"identity identity" "ingredient ingredient" "proposal confirmation" "saved delta"',
              columnGap: "var(--atlas-spacing-md)",
              rowGap: "var(--atlas-spacing-xs)",
              padding: "var(--atlas-spacing-sm)",
              borderBottom: "1px solid var(--atlas-colors-border-strong)",
            },
            "& td": {
              display: "block",
              minWidth: 0,
              padding: 0,
              border: 0,
              textAlign: "start",
              whiteSpace: "normal",
              overflowWrap: "anywhere",
            },
            "& td::after": { display: "none" },
            "& td[data-field=identity]": {
              gridArea: "identity",
              position: "static",
              display: "flex",
              flexWrap: "wrap",
              columnGap: "var(--atlas-spacing-sm)",
            },
            "& [data-role=recipient]": { width: "100%" },
            "& td[data-field=ingredient]": {
              gridArea: "ingredient",
              paddingBottom: "var(--atlas-spacing-xs)",
              borderBottom: "1px solid var(--atlas-colors-border-subtle)",
            },
            "& td[data-field=operational-proposal]": { gridArea: "proposal" },
            "& td[data-field=saved]": { gridArea: "saved" },
            "& td[data-field=confirmation]": { gridArea: "confirmation" },
            "& td[data-field=delta]": {
              gridArea: "delta",
            },
            // Row facts are visible; retain the input's existing accessible description.
            "& [data-quantity-context]": atlasVisuallyHidden,
          },
        }}
      >
        <Table.ColumnGroup>
          <Table.Column w="var(--atlas-confirmed-school-width, 220px)" />
          <Table.Column w="var(--atlas-confirmed-ingredient-width, 180px)" />
          <Table.Column w="var(--atlas-confirmed-proposal-width, 140px)" />
          <Table.Column w="var(--atlas-confirmed-saved-width, 105px)" />
          <Table.Column w="var(--atlas-confirmed-quantity-width, 155px)" />
          <Table.Column w="var(--atlas-confirmed-delta-width, 110px)" />
        </Table.ColumnGroup>
        <Table.Header css={atlasRecordSortHeader}>
          <Table.Row zIndex="var(--atlas-layout-sticky-header-z, 3)">
            <AtlasSortableColumnHeader
              label="Trường / nơi nhận"
              columnKey="school"
              sort={sort}
              onSort={onSort}
              position="sticky"
              left="var(--atlas-layout-zero, 0)"
              zIndex="var(--atlas-layout-sticky-identity-header-z, 5)"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            />
            <AtlasSortableColumnHeader
              label="Nguyên liệu"
              columnKey="ingredient"
              sort={sort}
              onSort={onSort}
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            />
            <AtlasSortableColumnHeader
              label="Đề xuất vận hành"
              columnKey="proposal"
              sort={sort}
              onSort={onSort}
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            />
            <Table.ColumnHeader
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            >
              Đã lưu
            </Table.ColumnHeader>
            <Table.ColumnHeader
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            >
              Số lượng xác nhận
            </Table.ColumnHeader>
            <Table.ColumnHeader
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            >
              Thay đổi
            </Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {sortedLines.map((line, index) => {
            const draft =
              drafts[line.confirmed_need_line_id] ??
              initialConfirmedNeedDraft(line);
            const saved = initialConfirmedNeedDraft(line);
            const historical = historicalQuantity(line);
            const error = errors[line.confirmed_need_line_id];
            const quantityInvalid = error?.field === "quantity";
            const description = `${id}-error-${index}`;
            const normalizedQuantity = normalizeConfirmedNeedQuantity(
              draft.exact_quantity,
            );
            const adjusted = Boolean(
              normalizedQuantity &&
              !exactDecimalEqual(
                normalizedQuantity,
                line.proposed_confirmed_quantity,
              ),
            );
            const delta =
              adjusted && normalizedQuantity
                ? subtractExactDecimals(
                    normalizedQuantity,
                    line.proposed_confirmed_quantity,
                  )
                : null;
            const attention = ["NEW", "CHANGED", "UNREVIEWED"].includes(
              line.confirmation_state,
            );
            const duplicateRecipient =
              line.school.name.trim() === line.delivery_location.name.trim();
            return (
              <Table.Row
                key={line.confirmed_need_line_id}
                data-confirmed-need-line
                data-confirmed-need-line-id={line.confirmed_need_line_id}
                minH="var(--atlas-confirmed-need-row-min-height)"
              >
                <Table.Cell
                  data-field="identity"
                  minW="var(--atlas-layout-identity-width, 230px)"
                  position="sticky"
                  left="var(--atlas-layout-zero, 0)"
                  style={{
                    zIndex: "var(--atlas-layout-sticky-identity-z, 2)",
                    background: "var(--atlas-colors-bg-workbench)",
                  }}
                >
                  <Text data-role="recipient" fontWeight="semibold">
                    {line.school.name}
                  </Text>
                  <Text
                    data-role="service-date"
                    textStyle="helper"
                    color="fg.muted"
                  >
                    {line.service_date.split("-").reverse().join("/")}
                  </Text>
                  {!duplicateRecipient && (
                    <Text
                      data-row-secondary=""
                      textStyle="helper"
                      color="fg.muted"
                    >
                      {line.delivery_location.name}
                    </Text>
                  )}
                  {attention && (
                    <Text textStyle="helper" color="status.warning">
                      <Icon asChild aria-hidden="true" mr="xs">
                        <WarningCircle />
                      </Icon>
                      {confirmedNeedConfirmationStateLabel(
                        line.confirmation_state,
                      )}
                    </Text>
                  )}
                </Table.Cell>
                <Table.Cell data-field="ingredient">
                  <Text data-role="ingredient-name" fontWeight="medium">
                    {line.ingredient.name}
                  </Text>
                  {line.current_decision_id &&
                    (saved.reason_code !== "PROPOSAL_ACCEPTED" ||
                      saved.reason_note) && (
                      <Box
                        textStyle="helper"
                        color="fg.muted"
                        overflowWrap="anywhere"
                      >
                        {editable && !historical && onEditReason ? (
                          <Button
                            variant="tertiary"
                            size="xs"
                            aria-label={`Sửa lý do ${line.ingredient.name}`}
                            onClick={(event) =>
                              onEditReason(line, event.currentTarget)
                            }
                          >
                            {confirmedNeedReasonLabels[saved.reason_code]}
                          </Button>
                        ) : (
                          confirmedNeedReasonLabels[saved.reason_code]
                        )}
                        {saved.reason_note && <Text>{saved.reason_note}</Text>}
                      </Box>
                    )}
                </Table.Cell>
                <Table.Cell
                  data-field="operational-proposal"
                  textAlign="end"
                  whiteSpace="nowrap"
                >
                  <Text
                    hideFrom="md"
                    aria-hidden="true"
                    textStyle="label"
                    color="fg.muted"
                  >
                    Đề xuất vận hành
                  </Text>
                  <Text textStyle="quantityInline">
                    {exactQuantityDisplay(line.proposed_confirmed_quantity)}{" "}
                    <Box
                      as="span"
                      textStyle="unitInline"
                      color="fg.muted"
                      ml="xs"
                    >
                      {confirmedNeedUnitLabel(line.controlled_unit)}
                    </Box>
                  </Text>
                </Table.Cell>
                <Table.Cell
                  data-field="saved"
                  textAlign="end"
                  whiteSpace="nowrap"
                >
                  <Text
                    hideFrom="md"
                    aria-hidden="true"
                    textStyle="label"
                    color="fg.muted"
                  >
                    Đã lưu
                  </Text>
                  <Text
                    textStyle={
                      line.confirmed_quantity_after === null
                        ? "helper"
                        : "quantityInline"
                    }
                    color="fg.muted"
                  >
                    {line.confirmed_quantity_after === null ? (
                      "Chưa lưu"
                    ) : (
                      <>
                        {exactQuantityDisplay(line.confirmed_quantity_after)}{" "}
                        <Box as="span" textStyle="unitInline" ml="xs">
                          {confirmedNeedUnitLabel(line.controlled_unit)}
                        </Box>
                      </>
                    )}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  data-field="confirmation"
                  data-adjustment-state={
                    quantityInvalid
                      ? "invalid"
                      : adjusted
                        ? "valid"
                        : "unchanged"
                  }
                  minW="var(--atlas-layout-quantity-width, 145px)"
                  style={{
                    background: quantityInvalid
                      ? "var(--atlas-colors-bg-danger)"
                      : adjusted
                        ? "var(--atlas-colors-bg-selected)"
                        : undefined,
                  }}
                >
                  <Text
                    hideFrom="md"
                    aria-hidden="true"
                    textStyle="label"
                    color="fg.muted"
                  >
                    Số lượng xác nhận
                  </Text>
                  <AtlasQuantityContext
                    id={`${id}-quantity-${line.confirmed_need_line_id}`}
                    recipient={line.school.name}
                    location={
                      duplicateRecipient
                        ? undefined
                        : line.delivery_location.name
                    }
                    ingredient={line.ingredient.name}
                    unit={confirmedNeedUnitLabel(line.controlled_unit)}
                    date={line.service_date}
                    source="Xác nhận nhu cầu"
                  />
                  <Box
                    display="grid"
                    gridTemplateColumns="minmax(0, 1fr) auto"
                    gap="xs"
                    alignItems="center"
                  >
                    <Input
                      aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                      inputMode="decimal"
                      textAlign="end"
                      value={
                        draft.quantity_entered
                          ? draft.exact_quantity
                          : confirmedNeedInputDisplay(
                              draft.exact_quantity,
                              editable && !historical ? "." : ",",
                            )
                      }
                      readOnly={historical}
                      disabled={!editable}
                      aria-invalid={quantityInvalid}
                      borderColor={
                        quantityInvalid
                          ? "status.danger"
                          : adjusted
                            ? "border.interactive"
                            : undefined
                      }
                      fontWeight={adjusted ? "semibold" : "medium"}
                      aria-describedby={`${id}-quantity-${line.confirmed_need_line_id}${quantityInvalid || historical ? ` ${description}` : ""}`}
                      onChange={(e) =>
                        onEdit(line.confirmed_need_line_id, {
                          exact_quantity: e.target.value,
                          quantity_entered: true,
                        })
                      }
                    />
                    <Text textStyle="unitInline" color="fg.muted">
                      {confirmedNeedUnitLabel(line.controlled_unit)}
                    </Text>
                  </Box>
                  {quantityInvalid && (
                    <Text
                      id={description}
                      textStyle="helper"
                      color="status.danger"
                    >
                      {error.message}
                    </Text>
                  )}
                  {historical && !quantityInvalid && (
                    <Text id={description} textStyle="helper" color="fg.muted">
                      Giữ nguyên độ chính xác gốc · chỉ đọc.
                    </Text>
                  )}
                </Table.Cell>
                <Table.Cell
                  data-field="delta"
                  textAlign="end"
                  whiteSpace="nowrap"
                >
                  <Text
                    hideFrom="md"
                    aria-hidden="true"
                    textStyle="label"
                    color="fg.muted"
                  >
                    Thay đổi
                  </Text>
                  {delta ? (
                    <Text
                      data-role="quantity-delta"
                      textStyle="quantityInline"
                      color="fg.primary"
                    >
                      {exactQuantityDisplay(delta)}{" "}
                      <Box
                        as="span"
                        textStyle="unitInline"
                        color="fg.primary"
                        ml="xs"
                      >
                        {confirmedNeedUnitLabel(line.controlled_unit)}
                      </Box>
                    </Text>
                  ) : (
                    <Box as="span" data-role="quantity-delta">
                      —
                    </Box>
                  )}
                </Table.Cell>
              </Table.Row>
            );
          })}
        </Table.Body>
      </Table.Root>
      {!lines.length && (
        <Text p="md" color="fg.muted">
          Không có dòng phù hợp bộ lọc.
        </Text>
      )}
    </AtlasTableViewport>
  );
}
