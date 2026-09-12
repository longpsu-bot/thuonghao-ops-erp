import { Box, Flex, Heading, Table, Text } from "@chakra-ui/react";
import type { DishRecipeOperatorWorkbench } from "../bridges/dishRecipe";
export function EffectiveRecipeView({
  effective,
}: {
  effective: DishRecipeOperatorWorkbench | null;
}) {
  // Compare only returned composition facts. Local drafts and adjustment rules
  // do not participate in this presentation decision.
  const facts = (
    lines: {
      ingredient_id: string;
      quantity_per_basis: number;
      unit_id: string;
    }[],
  ) =>
    lines
      .map((line) =>
        JSON.stringify([
          line.ingredient_id,
          line.quantity_per_basis,
          line.unit_id,
        ]),
      )
      .sort();
  const matchesBase = Boolean(
    effective &&
    effective.basis_portions === effective.base_authoring.basis_portions &&
    JSON.stringify(facts(effective.current_effective_bom)) ===
      JSON.stringify(
        facts(
          effective.base_authoring.composition.filter(
            (l) => l.line_disposition === "PRESENT",
          ),
        ),
      ),
  );
  const locked =
    effective?.is_operationally_locked ||
    effective?.editable_state === "LOCKED_CHANGE_ORDER";
  const table = effective && (
    <Box overflow="auto" mt="sm">
      <Table.Root aria-label="Công thức hiệu lực">
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeader>Nguyên liệu</Table.ColumnHeader>
            <Table.ColumnHeader textAlign="right">
              Định lượng
            </Table.ColumnHeader>
            <Table.ColumnHeader>Đơn vị</Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {effective.current_effective_bom.map((line) => (
            <Table.Row key={line.target_id}>
              <Table.Cell>{line.ingredient_name}</Table.Cell>
              <Table.Cell textAlign="right">
                {String(line.quantity_per_basis).replace(".", ",")}
              </Table.Cell>
              <Table.Cell>{line.unit_name}</Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table.Root>
    </Box>
  );
  return (
    <Box
      mt="md"
      pt="sm"
      borderTopWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
    >
      <Heading as="h3" textStyle="section">
        Công thức hiệu lực
      </Heading>
      {!effective ? (
        <Text mt="sm">Chưa tải được công thức hiệu lực chính thức.</Text>
      ) : effective.effective_readiness.status === "READY" ? (
        <>
          <Flex gap="sm" wrap="wrap" align="baseline">
            <Text
              textStyle={matchesBase ? "helper" : "body"}
              color={matchesBase ? "fg.muted" : "fg.default"}
              mt="xs"
            >
              {matchesBase
                ? "Đang trùng với công thức gốc"
                : "Công thức hiệu lực có thay đổi so với công thức gốc"}
            </Text>
            <Text textStyle="helper" color="fg.muted" mt="xs">
              Định lượng cho {effective.basis_portions} suất · theo ngày áp dụng
            </Text>
          </Flex>
          {matchesBase && !locked ? (
            <Box as="details" mt="xs">
              <Box as="summary" textStyle="helper" color="fg.muted">
                Xem thành phần hiệu lực
              </Box>
              {table}
            </Box>
          ) : (
            table
          )}
        </>
      ) : (
        <Box mt="sm">
          <Text color="status.warning">
            Chưa sẵn sàng cho ngày áp dụng này.
          </Text>
          {effective.effective_readiness.blockers.map((b, i) => (
            <Text textStyle="helper" key={i}>
              {b.message}
            </Text>
          ))}
        </Box>
      )}
      {effective?.effective_readiness.warnings.map((warning, i) => (
        <Text mt="xs" textStyle="helper" key={i}>
          {warning.message}
        </Text>
      ))}
    </Box>
  );
}
