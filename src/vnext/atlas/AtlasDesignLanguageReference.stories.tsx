import type { Meta, StoryObj } from "@storybook/react-vite";
import { AtlasDesignLanguageReference } from "./AtlasDesignLanguageReference";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextShell } from "./AtlasVNextShell";

const meta = {
  title: "Atlas vNext/Design language",
  component: AtlasDesignLanguageReference,
  decorators: [
    (Story) => (
      <AtlasVNextProvider>
        <AtlasVNextShell>
          <Story />
        </AtlasVNextShell>
      </AtlasVNextProvider>
    ),
  ],
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof AtlasDesignLanguageReference>;
export default meta;
type Story = StoryObj<typeof meta>;
export const OperationalReference: Story = {};
export const Blocker: Story = { args: { scenario: "blocker" } };
export const UnknownOutcome: Story = { args: { scenario: "unknown" } };
export const Empty: Story = { args: { scenario: "empty" } };
export const Loading: Story = { args: { scenario: "loading" } };
