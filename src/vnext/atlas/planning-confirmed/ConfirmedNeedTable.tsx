import { Box, Input, NativeSelect, Table, Text } from "@chakra-ui/react";
import { useId } from "react";
import {
  confirmedNeedConfirmationStateLabel,
  confirmedNeedInputDisplay,
  confirmedNeedReasonLabels,
  exactQuantityDisplay,
  initialConfirmedNeedDraft,
  subtractExactDecimals,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
} from "../bridges/confirmedNeed";
import { draftChanged, historicalQuantity } from "./confirmedNeedDraft";
export function ConfirmedNeedTable({
  lines,
  drafts,
  errors,
  editable,
  onEdit,
}: {
  lines: ConfirmedNeedLine[];
  drafts: Record<string, ConfirmedNeedDraftLine>;
  errors: Record<string, string>;
  editable: boolean;
  onEdit: (id: string, change: Partial<ConfirmedNeedDraftLine>) => void;
}) {
  const id = useId();
  return (
    <Table.ScrollArea
      overflow="auto"
      maxH={{
        base: "var(--atlas-layout-table-mobile-height, 55dvh)",
        xl: "var(--atlas-layout-table-height, calc(100dvh - 425px))",
      }}
    >
      <Table.Root aria-label="Nhu cầu xác nhận" size="sm" stickyHeader>
        <Table.Header>
          <Table.Row>
            {[
              "Nguyên liệu / nơi nhận",
              "ĐVT",
              "Nhu cầu tính",
              "Số lượng xác nhận",
              "Thay đổi",
              "Lý do / ghi chú",
            ].map((label, i) => (
              <Table.ColumnHeader
                key={label}
                textAlign={i >= 2 && i <= 4 ? "end" : "start"}
              >
                {label}
              </Table.ColumnHeader>
            ))}
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {lines.map((line, index) => {
            const draft =
              drafts[line.confirmed_need_line_id] ??
              initialConfirmedNeedDraft(line);
            const changed = draftChanged(line, draft);
            const historical = historicalQuantity(line);
            const error = errors[line.confirmed_need_line_id];
            const description = `${id}-error-${index}`;
            const delta = changed
              ? subtractExactDecimals(
                  draft.exact_quantity,
                  initialConfirmedNeedDraft(line).exact_quantity,
                )
              : null;
            const attention = ["NEW", "CHANGED", "UNREVIEWED"].includes(
              line.confirmation_state,
            );
            return (
              <Table.Row key={line.confirmed_need_line_id}>
                <Table.Cell minW="var(--atlas-layout-identity-width, 210px)">
                  <Text fontWeight="semibold">{line.ingredient.name}</Text>
                  <Text textStyle="helper" color="fg.muted">
                    {line.school.name} · {line.delivery_location.name}
                  </Text>
                  <Text
                    textStyle="helper"
                    color={attention ? "status.warning" : "fg.muted"}
                  >
                    {attention ? "⚠ " : ""}
                    {confirmedNeedConfirmationStateLabel(
                      line.confirmation_state,
                    )}
                  </Text>
                </Table.Cell>
                <Table.Cell>{line.controlled_unit.code}</Table.Cell>
                <Table.Cell textAlign="end">
                  {exactQuantityDisplay(line.theoretical_quantity)}
                </Table.Cell>
                <Table.Cell minW="var(--atlas-layout-quantity-width, 145px)">
                  <Input
                    aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                    inputMode="decimal"
                    textAlign="end"
                    value={
                      draft.quantity_entered
                        ? draft.exact_quantity
                        : confirmedNeedInputDisplay(draft.exact_quantity)
                    }
                    readOnly={historical}
                    disabled={!editable}
                    aria-invalid={Boolean(error)}
                    aria-describedby={
                      error || historical ? description : undefined
                    }
                    onChange={(e) =>
                      onEdit(line.confirmed_need_line_id, {
                        exact_quantity: e.target.value,
                        quantity_entered: true,
                      })
                    }
                  />
                  {historical && (
                    <Text id={description} textStyle="helper" color="fg.muted">
                      Giữ nguyên độ chính xác gốc · chỉ đọc.
                    </Text>
                  )}
                </Table.Cell>
                <Table.Cell textAlign="end" whiteSpace="nowrap">
                  {delta ? exactQuantityDisplay(delta) : "—"}
                </Table.Cell>
                <Table.Cell minW="var(--atlas-layout-reason-width, 255px)">
                  <Box display="grid" gap="xs">
                    <NativeSelect.Root disabled={!editable || historical}>
                      <NativeSelect.Field
                        aria-label={`Lý do ${line.ingredient.name}`}
                        value={draft.reason_code}
                        aria-invalid={Boolean(error)}
                        aria-describedby={error ? description : undefined}
                        onChange={(e) =>
                          onEdit(line.confirmed_need_line_id, {
                            reason_code: e.target
                              .value as ConfirmedNeedDraftLine["reason_code"],
                          })
                        }
                      >
                        {Object.entries(confirmedNeedReasonLabels).map(
                          ([code, label]) => (
                            <option value={code} key={code}>
                              {label}
                            </option>
                          ),
                        )}
                      </NativeSelect.Field>
                      <NativeSelect.Indicator />
                    </NativeSelect.Root>
                    {(changed ||
                      draft.reason_note ||
                      draft.reason_code !== "PROPOSAL_ACCEPTED") && (
                      <Input
                        aria-label={`Ghi chú ${line.ingredient.name}`}
                        placeholder="Ghi chú điều chỉnh"
                        value={draft.reason_note}
                        disabled={!editable || historical}
                        aria-invalid={Boolean(error)}
                        aria-describedby={error ? description : undefined}
                        onChange={(e) =>
                          onEdit(line.confirmed_need_line_id, {
                            reason_note: e.target.value,
                          })
                        }
                      />
                    )}
                    {error && (
                      <Text
                        id={description}
                        textStyle="helper"
                        color="status.danger"
                      >
                        {error}
                      </Text>
                    )}
                  </Box>
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
    </Table.ScrollArea>
  );
}
