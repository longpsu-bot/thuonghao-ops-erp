import type { Meta, StoryObj } from "@storybook/react-vite";
import { Box, Text } from "@chakra-ui/react";
import { useMemo, useState } from "react";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { ProcurementWorkbench } from "./ProcurementWorkbench";
import {
  createProcurementReviewFixture,
  reviewDate,
  reviewFamily,
  reviewSchools,
  type ProcurementReviewScenario,
} from "./procurementReviewFixtures";

/** Pure vNext review composition; intentionally no production adapter or routing. */
export function ProcurementReview({
  scenario = "normal",
}: {
  scenario?: ProcurementReviewScenario;
}) {
  const fixture = useMemo(() => {
    const value = createProcurementReviewFixture(scenario);
    if (!["empty", "read_failure"].includes(scenario)) {
      const names = [
        "Thịt heo nạc",
        "Cà rốt",
        "Bắp cải",
        "Trứng gà",
        "Cải thìa",
        "Bí đỏ",
        "Khoai tây",
        "Đậu hũ",
        "Thịt gà",
        "Cá phi lê",
        "Dầu ăn",
        "Rau muống",
      ];
      value.allocation.rows.push(
        ...names.map((name, index) => {
          const row = reviewFamily(
            scenario === "ready"
              ? "ready"
              : index % 4 === 0
                ? "normal"
                : "manual_split",
          );
          const school = reviewSchools[index % 4]!;
          return {
            ...row,
            family: {
              ...row.family,
              ingredient_id: `review-ingredient-${index + 1}`,
              source_fingerprint: `review-source-${index + 1}`,
            },
            ingredient_id: `review-ingredient-${index + 1}`,
            ingredient_name: name,
            school_id: school.school_id,
            school_name: school.school_name,
            schools: [school],
            location_name: index % 2 === 0 ? "Bếp bán trú" : "Điểm giao khu A",
          };
        }),
      );
    }
    return value;
  }, [scenario]);
  const [exportMessage, setExportMessage] = useState("");
  const orderScenario =
    scenario.startsWith("po_") ||
    ["replacement_required", "cancellation_required", "superseded"].includes(
      scenario,
    );
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell>
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Xem thử giao diện · Dữ liệu minh họa, không ghi lên hệ thống
        </Text>
        <ProcurementWorkbench
          key={scenario}
          authSubject="review-operator"
          purchaseReviewApi={fixture.purchaseReviewApi}
          procurementApi={fixture.procurementApi}
          initialServiceDate={reviewDate}
          initialStage={orderScenario ? "orders" : "allocation"}
          schools={reviewSchools}
          onExportXlsx={() =>
            setExportMessage("Xem thử: đã chọn XLSX. Không tạo chứng từ thật.")
          }
          onExportPdf={() =>
            setExportMessage("Xem thử: đã chọn PDF. Không tạo chứng từ thật.")
          }
        />
        {exportMessage && (
          <Box role="status" p="sm">
            <Text>{exportMessage}</Text>
          </Box>
        )}
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/Procurement",
  component: ProcurementReview,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof ProcurementReview>;
export default meta;
type Story = StoryObj<typeof meta>;
export const Normal: Story = { args: { scenario: "normal" } };
export const SavedManualSplit: Story = { args: { scenario: "manual_split" } };
export const Rebalance: Story = { args: { scenario: "rebalance" } };
export const NeedsReallocation: Story = {
  args: { scenario: "needs_reallocation" },
};
export const Blocked: Story = { args: { scenario: "blocked" } };
export const Empty: Story = { args: { scenario: "empty" } };
export const ReadFailure: Story = { args: { scenario: "read_failure" } };
export const RetryableFailure: Story = {
  args: { scenario: "retryable_failure" },
};
export const UnknownOutcome: Story = { args: { scenario: "unknown" } };
export const ReadyToOrder: Story = { args: { scenario: "ready" } };
export const DraftOrder: Story = { args: { scenario: "po_draft" } };
export const StaleOrder: Story = { args: { scenario: "po_stale" } };
export const ReleasedOrder: Story = { args: { scenario: "po_released" } };
export const ReplacementRequired: Story = {
  args: { scenario: "replacement_required" },
};
export const CancellationRequired: Story = {
  args: { scenario: "cancellation_required" },
};
export const SupersededOrder: Story = { args: { scenario: "superseded" } };
