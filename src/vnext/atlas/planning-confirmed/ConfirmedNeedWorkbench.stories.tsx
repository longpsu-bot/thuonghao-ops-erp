import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useMemo, useState } from "react";
import { userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { ConfirmedNeedWorkbench } from "./ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
  type ConfirmedReviewScenario,
} from "./confirmedNeedReviewFixtures";
export function ConfirmedNeedReview({
  scenario = "normal",
}: {
  scenario?: ConfirmedReviewScenario;
}) {
  const fixture = useMemo(
    () => createConfirmedNeedReviewFixture(scenario),
    [scenario],
  );
  const [allocationDate, setAllocationDate] = useState<string | null>(null);
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Lập nhu cầu">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Xem thử giao diện · Dữ liệu minh họa, không ghi lên hệ thống
        </Text>
        <ConfirmedNeedWorkbench
          key={scenario}
          {...fixture}
          authSubject="fixture-operator"
          initialServiceDate={reviewDate}
          onContinueAllocation={setAllocationDate}
        />
        {allocationDate && (
          <Text role="status">
            Tiếp tục phân bổ NCC cho ngày{" "}
            {allocationDate.split("-").reverse().join("/")}
          </Text>
        )}
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/Confirmed Need",
  component: ConfirmedNeedReview,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof ConfirmedNeedReview>;
export default meta;
type Story = StoryObj<typeof meta>;
type Action =
  | "dirty"
  | "invalid"
  | "reason"
  | "note"
  | "save"
  | "generate"
  | "support"
  | "continue"
  | "recover";
function story(scenario: ConfirmedReviewScenario, action?: Action): Story {
  return {
    args: { scenario },
    play: action
      ? async ({ canvasElement }) => {
          const c = within(canvasElement);
          if (action === "generate") {
            await userEvent.click(
              await c.findByRole("button", {
                name:
                  scenario === "outdated" ? "Cập nhật nhu cầu" : "Tạo nhu cầu",
              }),
            );
            return;
          }
          await c.findByRole("table", { name: "Nhu cầu xác nhận" });
          if (action === "support") {
            await userEvent.click(
              c.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
            );
            return;
          }
          if (action === "continue") {
            await userEvent.click(
              c.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
            );
            return;
          }
          const q = c.getByRole("textbox", {
            name: "Số lượng xác nhận Gạo thơm",
          });
          await userEvent.clear(q);
          await userEvent.type(q, action === "invalid" ? "10,123" : "12,5");
          if (action === "reason" || action === "invalid") return;
          await userEvent.selectOptions(
            c.getByRole("combobox", { name: "Lý do Gạo thơm" }),
            "OTHER",
          );
          if (action === "note") return;
          await userEvent.type(
            c.getByRole("textbox", { name: "Ghi chú Gạo thơm" }),
            "Bếp yêu cầu",
          );
          if (action === "save" || action === "recover")
            await userEvent.click(c.getByRole("button", { name: "Lưu" }));
          if (action === "recover")
            await userEvent.click(
              await c.findByRole("button", { name: "Tải lại để xác nhận" }),
            );
        }
      : undefined,
  };
}
export const PreflightLoading = story("loading");
export const PermissionReadFailure = story("read_failure");
export const NoDemand = story("no_demand");
export const SourceBlocked = story("blocked");
export const CreateNeed = story("not_generated");
export const UpdateNeed = story("outdated");
export const LegacyOverlap = story("legacy_overlap");
export const ReleasedCorrectionBlocked = story("correction_blocked");
export const GeneratedIntoConfirmedNeed = story("not_generated", "generate");
export const CurrentConfirmedNeed = story("normal");
export const NeedsReview = story("needs_review");
export const CarriedForward = story("carried");
export const Adjusted = story("adjusted");
export const DirtyValid = story("normal", "dirty");
export const DirtyInvalid = story("normal", "invalid");
export const ReasonRequired = story("normal", "reason");
export const NoteRequired = story("normal", "note");
export const SaveSuccess = story("normal", "save");
export const StaleSave = story("stale", "save");
export const UnknownSave = story("unknown", "save");
export const MissingReadback = story("missing_readback", "save");
export const FailedUnknownRecovery = story("recovery_failed", "recover");
export const ReleasedReadOnly = story("released");
export const HistoricalPrecision = story("historical");
export const ContinueToProcurement = story("normal", "continue");
export const NeedSupportDetail = story("normal", "support");
export const Mobile: Story = {
  ...story("needs_review"),
  globals: { viewport: { value: "mobile1", isRotated: false } },
};
