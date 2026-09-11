import type { Meta, StoryObj } from "@storybook/react-vite";
import { useMemo } from "react";
import { userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { SchoolFulfilmentWorkbench } from "./SchoolFulfilmentWorkbench";
import {
  createSchoolFulfilmentReviewFixture,
  reviewDate,
  type SchoolFulfilmentScenario,
} from "./schoolFulfilmentReviewFixtures";
export function SchoolFulfilmentReview({
  scenario = "ALL",
}: {
  scenario?: SchoolFulfilmentScenario;
}) {
  const api = useMemo(
    () => createSchoolFulfilmentReviewFixture(scenario),
    [scenario],
  );
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Đối chiếu PO / Phiếu xuất kho">
        <SchoolFulfilmentWorkbench
          key={scenario}
          api={api}
          authSubject="fixture-operator"
          initialDateStart={reviewDate}
          initialDateEnd="2026-09-26"
        />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/PO PXK Reconciliation",
  component: SchoolFulfilmentReview,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof SchoolFulfilmentReview>;
export default meta;
type Story = StoryObj<typeof meta>;
function story(
  scenario: SchoolFulfilmentScenario,
  detail = false,
  all = false,
): Story {
  return {
    args: { scenario },
    play:
      detail || all
        ? async ({ canvasElement }) => {
            const c = within(canvasElement);
            if (all)
              await userEvent.selectOptions(
                c.getByRole("combobox", { name: "Tình trạng" }),
                "all",
              );
            if (detail)
              await userEvent.click(
                (await c.findAllByRole("button", { name: "Xem đối chiếu" }))[0],
              );
          }
        : undefined,
  };
}
export const ExceptionLanding = story("ALL");
export const Matched = story("OK", true, true);
export const NoPo = story("NO_PO", true);
export const NoPxk = story("NO_PXK", true);
export const IngredientChanged = story("INGREDIENT_CHANGED", true);
export const Mismatch = story("MISMATCH", true);
export const MixedUnits = story("MIXED_UNITS", true);
export const PxkReady = story("PXK_READY", true);
export const PxkCurrent = story("PXK_CURRENT", true, true);
export const PxkReplacementRequired = story("PXK_REPLACEMENT_REQUIRED", true);
export const PxkBlocked = story("PXK_BLOCKED", true, true);
export const OperationalBlocker = story("OPERATIONAL_BLOCKER", true, true);
export const Warning = story("WARNING", true);
export const MultipleSchools = story("MULTIPLE_SCHOOLS", false, true);
export const MultipleDates = story("MULTIPLE_DATES", false, true);
export const MultiplePoDocuments = story("MULTIPLE_PO_DOCUMENTS", true);
export const Empty = story("EMPTY");
export const PermissionDenied = story("PERMISSION_DENIED");
export const ReadFailure = story("READ_FAILURE");
export const StaleOldResponse = story("STALE_OLD_RESPONSE");
