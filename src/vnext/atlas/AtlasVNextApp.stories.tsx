import type { Meta, StoryObj } from "@storybook/react-vite";
import { useMemo } from "react";
import { AtlasVNextApp } from "./AtlasVNextApp";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasSessionGate, type AtlasSessionModel } from "./AtlasSessionGate";
import {
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";
function Review({
  status = "authenticated",
}: {
  status?: AtlasSessionModel["status"];
}) {
  const apis = useMemo(() => createAtlasApplicationFixture(), []);
  return (
    <AtlasVNextProvider>
      <AtlasSessionGate session={{ status }} onSignIn={async () => false}>
        <AtlasVNextApp
          apis={apis}
          authSubject="fixture-operator"
          now={applicationReviewNow}
          userLabel="vanhanh@example.test"
          environmentLabel="Local"
          onSignOut={() => {}}
          exporters={{
            procurementXlsx: () => {},
            procurementPdf: () => {},
            pxkXlsx: () => {},
            pxkPdf: () => {},
          }}
        />
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/Connected application",
  component: Review,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Review>;
export default meta;
type Story = StoryObj<typeof meta>;
export const Connected: Story = {};
export const SignIn: Story = { args: { status: "unauthenticated" } };
export const Expired: Story = { args: { status: "session_expired" } };
export const Loading: Story = { args: { status: "loading" } };
export const ConfigurationError: Story = {
  args: { status: "configuration_error" },
};
