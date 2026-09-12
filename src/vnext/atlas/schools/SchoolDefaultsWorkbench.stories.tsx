import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useMemo } from "react";
import { userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { SchoolDefaultsWorkbench } from "./SchoolDefaultsWorkbench";
import {
  createSchoolDefaultsReviewFixture,
  schoolDefaultsFixtureSchools,
  type SchoolDefaultsScenario,
} from "./schoolDefaultsReviewFixtures";

function SchoolDefaultsReview({
  scenario = "NORMAL",
}: {
  scenario?: SchoolDefaultsScenario;
}) {
  const api = useMemo(
    () => createSchoolDefaultsReviewFixture(scenario),
    [scenario],
  );
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Trường học">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Chế độ xem thử giao diện — dữ liệu không được lưu
        </Text>
        <SchoolDefaultsWorkbench authSubject="review-operator" api={api} />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}

const meta = {
  title: "Atlas/Schools/School Defaults Workbench",
  component: SchoolDefaultsReview,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof SchoolDefaultsReview>;

export default meta;
type Story = StoryObj<typeof meta>;

const firstSchool = schoolDefaultsFixtureSchools[0]!;

async function setInput(
  canvas: ReturnType<typeof within>,
  label: string,
  value: string,
) {
  const input = await canvas.findByLabelText(label);
  await userEvent.clear(input);
  if (value) await userEvent.type(input, value);
}

async function dirtyFirst(canvas: ReturnType<typeof within>) {
  await setInput(
    canvas,
    `Học sinh mặc định — ${firstSchool.school_name}`,
    String(firstSchool.default_student_portions + 12),
  );
}

async function saveFirst(canvas: ReturnType<typeof within>) {
  await dirtyFirst(canvas);
  await userEvent.click(
    await canvas.findByRole("button", { name: "Xem thay đổi" }),
  );
  await userEvent.click(
    await canvas.findByRole("button", { name: "Lưu thay đổi" }),
  );
}

export const Normal: Story = { args: { scenario: "NORMAL" } };
export const MultipleSchoolTypes: Story = {
  args: { scenario: "MULTIPLE_SCHOOL_TYPES" },
};
export const InactiveSchool: Story = {
  args: { scenario: "INACTIVE_SCHOOL" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.type(
      await canvas.findByLabelText("Tìm trường"),
      "Thực nghiệm Khoa học",
    );
  },
};
export const DirtyOne: Story = {
  args: { scenario: "DIRTY_ONE" },
  play: async ({ canvasElement }) => dirtyFirst(within(canvasElement)),
};
export const DirtyMany: Story = {
  args: { scenario: "DIRTY_MANY" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    for (const school of schoolDefaultsFixtureSchools.slice(0, 8)) {
      await setInput(
        canvas,
        `Học sinh mặc định — ${school.school_name}`,
        String(school.default_student_portions + 5),
      );
    }
  },
};
export const DirtyHiddenBySearch: Story = {
  args: { scenario: "DIRTY_HIDDEN_BY_SEARCH" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await dirtyFirst(canvas);
    await userEvent.type(await canvas.findByLabelText("Tìm trường"), "Hoa Sen");
  },
};
export const InvalidBlank: Story = {
  args: { scenario: "INVALID_BLANK" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await setInput(
      canvas,
      `Học sinh mặc định — ${firstSchool.school_name}`,
      "",
    );
  },
};
export const InvalidNegative: Story = {
  args: { scenario: "INVALID_NEGATIVE" },
  play: async ({ canvasElement }) => {
    await setInput(
      within(canvasElement),
      `Học sinh mặc định — ${firstSchool.school_name}`,
      "-1",
    );
  },
};
export const InvalidDecimal: Story = {
  args: { scenario: "INVALID_DECIMAL" },
  play: async ({ canvasElement }) => {
    await setInput(
      within(canvasElement),
      `Học sinh mặc định — ${firstSchool.school_name}`,
      "1.5",
    );
  },
};
export const InvalidOverflow: Story = {
  args: { scenario: "INVALID_OVERFLOW" },
  play: async ({ canvasElement }) => {
    await setInput(
      within(canvasElement),
      `Học sinh mặc định — ${firstSchool.school_name}`,
      "2147483648",
    );
  },
};
export const AttachedReview: Story = {
  args: { scenario: "DIRTY_MANY" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await dirtyFirst(canvas);
    await setInput(
      canvas,
      `Giáo viên mặc định — ${schoolDefaultsFixtureSchools[1]!.school_name}`,
      String(schoolDefaultsFixtureSchools[1]!.default_teacher_portions + 2),
    );
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xem thay đổi" }),
    );
  },
};
export const StaleVersion: Story = {
  args: { scenario: "STALE_VERSION" },
  play: async ({ canvasElement }) => saveFirst(within(canvasElement)),
};
export const UnknownSave: Story = {
  args: { scenario: "UNKNOWN_SAVE" },
  play: async ({ canvasElement }) => saveFirst(within(canvasElement)),
};
export const SuccessThenReadFailure: Story = {
  args: { scenario: "SUCCESS_THEN_READ_FAILURE" },
  play: async ({ canvasElement }) => saveFirst(within(canvasElement)),
};
export const PermissionDenied: Story = {
  args: { scenario: "PERMISSION_DENIED" },
  play: async ({ canvasElement }) => saveFirst(within(canvasElement)),
};
export const ReadFailure: Story = { args: { scenario: "READ_FAILURE" } };
export const Empty: Story = { args: { scenario: "EMPTY" } };
export const AuthChangeDelayedRead: Story = {
  args: { scenario: "AUTH_CHANGE_DELAYED_READ" },
};
