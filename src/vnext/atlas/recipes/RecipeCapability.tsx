import type { AtlasModuleExitProps } from "../AtlasModuleExit";
import { Box, Heading, Tabs, Text } from "@chakra-ui/react";
import { useRef, useState, useImperativeHandle } from "react";
import type { DishRecipeApi } from "../bridges/dishRecipe";
import type { RecipeAdjustmentApi } from "../bridges/recipeAdjustment";
import { DishRecipeWorkbench } from "./DishRecipeWorkbench";
import { ChangeOrderWorkbench } from "./ChangeOrderWorkbench";
import type { RecipeJobHandle } from "./useChangeOrderWorkbench";

export function RecipeCapability(
  props: AtlasModuleExitProps & {
    authSubject: string | null;
    recipeApi: DishRecipeApi;
    adjustmentApi: RecipeAdjustmentApi;
    initialDate?: string;
    initialJob?: "recipes" | "changes";
  },
) {
  const [job, setJob] = useState(props.initialJob ?? "recipes");
  const active = useRef<RecipeJobHandle>(null);
  useImperativeHandle(props.exitRef, () => ({
    requestExit: (next) => active.current?.requestExit(next),
  }));
  const switchJob = (next: "recipes" | "changes") => {
    if (next !== job) active.current?.requestExit(() => setJob(next));
  };
  return (
    <Box
      as="section"
      aria-label="Công thức"
      bg="bg.workbench"
      borderRadius="workbench"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Tabs.Root
        value={job}
        variant="line"
        activationMode="manual"
        onValueChange={({ value }) => {
          if (value !== job && (value === "recipes" || value === "changes"))
            switchJob(value);
        }}
      >
        <Box px="md" pt="md" pb="sm">
          <Text textStyle="helper" color="fg.muted">
            Công thức
          </Text>
          <Heading as="h1" textStyle="workbenchTitle" mt="xs">
            {job === "recipes" ? "Danh mục công thức" : "Lệnh điều chỉnh"}
          </Heading>
          <Tabs.List mt="sm" aria-label="Công việc công thức">
            <Tabs.Trigger value="recipes">Công thức</Tabs.Trigger>
            <Tabs.Trigger value="changes">Lệnh điều chỉnh</Tabs.Trigger>
          </Tabs.List>
        </Box>
        <Tabs.Content value="recipes" p="var(--atlas-layout-zero, 0)">
          {job === "recipes" && (
            <DishRecipeWorkbench
              embedded
              exitRef={active}
              authSubject={props.authSubject}
              api={props.recipeApi}
              initialDate={props.initialDate}
              onOpenChangeOrders={() => switchJob("changes")}
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
