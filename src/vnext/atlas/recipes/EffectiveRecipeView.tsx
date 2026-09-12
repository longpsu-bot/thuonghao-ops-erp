import { Box, Heading, Table, Text } from "@chakra-ui/react";
import type { DishRecipeOperatorWorkbench } from "../bridges/dishRecipe";
export function EffectiveRecipeView({
  effective,
}: {
  effective: DishRecipeOperatorWorkbench | null;
}) {
  return (
    <Box
      mt="md"
      pt="md"
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
          <Text textStyle="helper" color="fg.muted" mt="xs">
            Định lượng cho {effective.basis_portions} suất · theo ngày áp dụng
          </Text>
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
