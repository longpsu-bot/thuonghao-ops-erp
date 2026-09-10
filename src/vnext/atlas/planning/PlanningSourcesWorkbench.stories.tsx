import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useMemo } from "react";
import { userEvent, within, waitFor } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { PlanningSourcesWorkbench } from "./PlanningSourcesWorkbench";
import {
  createPlanningStoryFixture,
  type PlanningReviewScenario,
} from "./planningStoryFixtures";
import { reviewWeek } from "./planningReviewFixtures";
export function PlanningReview({
  scenario = "menu",
}: {
  scenario?: PlanningReviewScenario;
}) {
  const fixture = useMemo(
    () => createPlanningStoryFixture(scenario),
    [scenario],
  );
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Lập nhu cầu">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Xem thử giao diện · Dữ liệu minh họa, không ghi lên hệ thống
        </Text>
        <PlanningSourcesWorkbench
          key={scenario}
          {...fixture}
          authSubject="fixture-operator"
          initialWeek={reviewWeek}
          initialJob={
            scenario.startsWith("attendance")
              ? "attendance"
              : scenario.startsWith("pantry")
                ? "pantry"
                : "menu"
          }
        />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/Planning sources",
  component: PlanningReview,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof PlanningReview>;
export default meta;
type Story = StoryObj<typeof meta>;
function story(scenario: PlanningReviewScenario): Story {
  return {
    args: { scenario },
    play: async ({ canvasElement }) => {
      const canvas = within(canvasElement);
      await canvas.findByRole("table");
      if (
        [
          "menu",
          "attendance",
          "pantry",
          "pantry_zero",
          "pantry_additive",
          "pantry_complete",
          "pantry_blocked",
        ].includes(scenario)
      )
        return;
      if (scenario.startsWith("menu") || scenario === "dirty_dialog") {
        await userEvent.click(
          canvas.getByRole("button", { name: "Đồng bộ Google Sheet" }),
        );
        await canvas.findByText("Đang chỉnh sửa · chưa lưu");
      } else if (scenario.startsWith("attendance")) {
        if (scenario === "attendance_paste") {
          await userEvent.click(
            canvas.getByRole("button", { name: "Dán hàng loạt" }),
          );
          await userEvent.type(
            canvas.getByRole("textbox", { name: "Dữ liệu dán" }),
            "TH001\t2026-09-07\t120\t12",
          );
          return;
        }
        const input = canvas.getByRole("textbox", {
          name: "Học sinh Trường Nguyễn Du",
        });
        await userEvent.clear(input);
        await userEvent.type(
          input,
          scenario === "attendance_invalid" ? "abc" : "0",
        );
      } else {
        const input = canvas.getByRole("textbox", { name: "Số lượng dòng 1" });
        await userEvent.clear(input);
        await userEvent.type(input, "30");
      }
      if (scenario === "dirty_dialog") {
        await userEvent.click(canvas.getByRole("tab", { name: "Sĩ số" }));
        return;
      }
      if (scenario.endsWith("dirty") || scenario.endsWith("invalid")) return;
      await userEvent.click(
        canvas.getByRole("button", { name: "Xem thay đổi" }),
      );
      await canvas.findByRole("complementary", { name: "Xem thay đổi" });
      if (scenario.endsWith("unknown") || scenario.endsWith("stale")) {
        await waitFor(() => {
          if (
            canvas.getByRole("button", { name: "Lưu" }).hasAttribute("disabled")
          )
            throw new Error("Waiting for authority");
        });
        await userEvent.click(canvas.getByRole("button", { name: "Lưu" }));
        await canvas.findByRole("button", { name: "Tải lại để xác nhận" });
      }
    },
  };
}
export const Menu = story("menu");
export const MenuDirty = story("menu_dirty");
export const MenuReview = story("menu_review");
export const MenuBlocked = story("menu_blocked");
export const MenuStale = story("menu_stale");
export const MenuUnknown = story("menu_unknown");
export const Attendance = story("attendance");
export const AttendanceDirty = story("attendance_dirty");
export const AttendanceInvalid = story("attendance_invalid");
export const AttendancePaste = story("attendance_paste");
export const AttendanceReview = story("attendance_review");
export const AttendanceCorrection = story("attendance_correction");
export const AttendanceUnknown = story("attendance_unknown");
export const PantryEmpty = story("pantry");
export const PantryNoAdditions = story("pantry_zero");
export const PantryAdditive = story("pantry_additive");
export const PantryComplete = story("pantry_complete");
export const PantryCatalogBlocker = story("pantry_blocked");
export const PantryReview = story("pantry_review");
export const PantryCorrection = story("pantry_correction");
export const PantryUnknown = story("pantry_unknown");
export const DirtyContextDialog = story("dirty_dialog");
