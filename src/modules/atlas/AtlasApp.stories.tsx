import type { Meta, StoryObj } from "@storybook/react-vite";
import { AtlasAppView as AtlasApp } from "./AtlasApp";

const meta = {
  title: "Atlas/Operational shell proof",
  component: AtlasApp,
  parameters: {
    layout: "fullscreen",
    docs: {
      description: {
        component:
          "Review-oriented Atlas story coverage for shell identity and shared-state visual treatment.",
      },
    },
  },
} satisfies Meta<typeof AtlasApp>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Shell: Story = {
  name: "Shell identity",
  args: {
    initialPage: "customers-schools",
    reviewMode: true,
  },
};

export const ActiveNavigation: Story = {
  name: "Active navigation",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
};

export const PrimaryActionAndStates: Story = {
  name: "Primary action and state treatment",
  args: {
    initialPage: "ingredients-units",
    reviewMode: true,
  },
  parameters: {
    docs: {
      description: {
        story:
          "Open the review scenario selector and capture the following modes: success (menu_replay_success), warning (attendance_negative), blocking (menu_duplicate), and error (access-denied).",
      },
    },
  },
};

export const LongVietnameseText: Story = {
  name: "Dữ liệu đầu vào dài và tiếng Việt",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
  parameters: {
    docs: {
      description: {
        story:
          "Use this scenario to review long Vietnamese labels and compact table rows at different breakpoints.",
      },
    },
  },
};
