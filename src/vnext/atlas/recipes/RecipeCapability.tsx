import { Box, Heading, Tabs } from "@chakra-ui/react";
import { useRef, useState } from "react";
import type { DishRecipeApi } from "../bridges/dishRecipe";
import type { RecipeAdjustmentApi } from "../bridges/recipeAdjustment";
import { DishRecipeWorkbench } from "./DishRecipeWorkbench";
import { ChangeOrderWorkbench } from "./ChangeOrderWorkbench";
import type { RecipeJobHandle } from "./useChangeOrderWorkbench";

export function RecipeCapability(props: {
  authSubject: string | null;
  recipeApi: DishRecipeApi;
  adjustmentApi: RecipeAdjustmentApi;
  initialDate?: string;
  initialJob?: "recipes" | "changes";
}) {
  const [job, setJob] = useState(props.initialJob ?? "recipes");
  const active = useRef<RecipeJobHandle>(null);
  return (
    <Box
      as="section"
      aria-label="Công thức"
      bg="bg.workbench"
      borderRadius="workbench"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Heading as="h1" textStyle="workbenchTitle" px="md" pt="md" pb="sm">
        Công thức
      </Heading>
      <Tabs.Root
        value={job}
        variant="line"
        activationMode="manual"
        onValueChange={({ value }) => {
          if (value !== job && (value === "recipes" || value === "changes"))
            active.current?.requestExit(() => setJob(value));
        }}
      >
        <Tabs.List px="md" aria-label="Công việc công thức">
          <Tabs.Trigger value="recipes">Công thức</Tabs.Trigger>
          <Tabs.Trigger value="changes">Lệnh điều chỉnh</Tabs.Trigger>
        </Tabs.List>
        <Tabs.Content value="recipes" p="var(--atlas-layout-zero, 0)">
          {job === "recipes" && (
            <DishRecipeWorkbench
              embedded
              exitRef={active}
              authSubject={props.authSubject}
              api={props.recipeApi}
              initialDate={props.initialDate}
            />
          )}
        </Tabs.Content>
        <Tabs.Content value="changes" p="var(--atlas-layout-zero, 0)">
          {job === "changes" && (
            <ChangeOrderWorkbench
              exitRef={active}
              authSubject={props.authSubject}
              api={props.adjustmentApi}
              initialDate={props.initialDate}
            />
          )}
        </Tabs.Content>
      </Tabs.Root>
    </Box>
  );
}
