import type { Meta, StoryObj } from "@storybook/react-vite";
import { useState } from "react";
import { Box, Input, Text } from "@chakra-ui/react";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextShell } from "./AtlasVNextShell";
import {
  atlasWorkbenches,
  type AtlasWorkbenchId,
} from "./AtlasWorkbenchRegistry";

// Test-only capacity, never imported by the production composition.
export const capacityDestinations = Array.from({ length: 12 }, (_, index) => ({
  ...atlasWorkbenches[index % atlasWorkbenches.length]!,
  id: `capacity-${index + 1}` as AtlasWorkbenchId,
  label: `${atlasWorkbenches[index % atlasWorkbenches.length]!.label} ${index + 1}`,
}));

export function Capacity() {
  const [ids, setIds] = useState(capacityDestinations.map((w) => w.id));
  const [active, setActive] = useState<AtlasWorkbenchId | null>(ids[0]!);
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell
        prefix="capacity"
        activeModule={active}
        openIds={ids}
        destinations={capacityDestinations}
        statuses={{ [ids[2]!]: { unsaved: true, blocked: false } }}
        onNavigate={(id) => {
          setIds((old) => (old.includes(id) ? old : [...old, id]));
          setActive(id);
        }}
        onClose={(id) => {
          const next = ids.filter((item) => item !== id);
          setIds(next);
          setActive(next[0] ?? null);
        }}
      >
        {ids.map((id) => (
          <Box
            key={id}
            role="tabpanel"
            id={`capacity-panel-${id}`}
            aria-label={capacityDestinations.find((w) => w.id === id)!.label}
            hidden={id !== active}
            inert={id !== active}
            tabIndex={0}
            p="md"
          >
            <Text mb="sm">Kiểm tra sức chứa 12 bàn làm việc</Text>
            <Input aria-label={`Dữ liệu ${id}`} defaultValue={id} />
          </Box>
        ))}
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas vNext/Workspace capacity",
  component: Capacity,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Capacity>;
export default meta;
type Story = StoryObj<typeof meta>;
export const TwelveOpen: Story = {};
