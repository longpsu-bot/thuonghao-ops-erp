import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useMemo } from "react";
import { userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { SchoolPxkWorkbench } from "./SchoolPxkWorkbench";
import {
  createSchoolPxkReviewFixture,
  reviewDate,
  type SchoolPxkScenario,
} from "./schoolPxkReviewFixtures";
export function SchoolPxkReview({
  scenario = "READY",
}: {
  scenario?: SchoolPxkScenario;
}) {
  const api = useMemo(() => createSchoolPxkReviewFixture(scenario), [scenario]);
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Phiếu xuất kho">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Xem thử giao diện · Dữ liệu minh họa, không ghi lên hệ thống
        </Text>
        <SchoolPxkWorkbench
          key={scenario}
          api={api}
          authSubject="fixture-operator"
          initialServiceDate={reviewDate}
          onExportXlsx={() => {}}
          onExportPdf={() => {}}
        />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/School PXK",
  component: SchoolPxkReview,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof SchoolPxkReview>;
export default meta;
type Story = StoryObj<typeof meta>;
function story(
  scenario: SchoolPxkScenario,
  action?: "detail" | "dirty" | "dialog" | "release" | "history",
): Story {
  return {
    args: { scenario },
    play: action
      ? async ({ canvasElement }) => {
          const c = within(canvasElement);
          const label =
            scenario === "REPLACEMENT_REQUIRED"
              ? "Tạo phiếu thay thế"
              : scenario === "BLOCKED"
                ? "Xem lỗi"
                : [
                      "CURRENT",
                      "EXPORT_READY",
                      "HISTORY_WITH_SUPERSEDED",
                    ].includes(scenario)
                  ? "Xem phiếu"
                  : "Phát hành";
          await userEvent.click(
            (await c.findAllByRole("button", { name: label }))[0]!,
          );
          if (action === "dirty" || action === "dialog") {
            await userEvent.type(
              c.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
              "Giao tại cổng phụ trước 06:00",
            );
            if (action === "dialog")
              await userEvent.click(
                c.getByRole("button", { name: "Làm mới dữ liệu" }),
              );
          }
          if (action === "release")
            await userEvent.click(
              c.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
            );
          if (action === "history")
            await userEvent.click(c.getByText("Lịch sử phiếu"));
        }
      : undefined,
  };
}
export const ReadyLanding = story("READY");
export const ReadyDetail = story("READY", "detail");
export const DirtyNote = story("DIRTY_NOTE", "dirty");
export const DirtyDiscardDialog = story("DIRTY_NOTE", "dialog");
export const Current = story("CURRENT", "detail");
export const ReplacementRequired = story("REPLACEMENT_REQUIRED", "detail");
export const BlockedCancellation = story("BLOCKED", "detail");
export const UnknownRelease = story("UNKNOWN_RELEASE", "release");
export const Stale = story("STALE", "release");
export const SourceChanged = story("SOURCE_CHANGED", "release");
export const SuccessThenReadbackFailure = story(
  "SUCCESS_THEN_READBACK_FAILURE",
  "release",
);
export const HistoryWithSuperseded = story(
  "HISTORY_WITH_SUPERSEDED",
  "history",
);
export const ExportReady = story("EXPORT_READY", "detail");
export const MultipleSchools = story("MULTIPLE_SCHOOLS");
export const MultipleIngredients = story("MULTIPLE_INGREDIENTS", "detail");
export const Empty = story("EMPTY");
export const PermissionDenied = story("PERMISSION_DENIED");
export const ReadFailure = story("READ_FAILURE");
