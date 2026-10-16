import type { ReactNode } from "react";
import { Flex, Field, NativeSelect } from "@chakra-ui/react";
import { atlasDefaultSort, type AtlasSortState } from "./atlasTableSort";

export function AtlasSortControl<Key extends string>({
  label,
  axes,
  value,
  onChange,
  tools,
}: {
  label: string;
  axes: readonly (readonly [Key, string])[];
  value: AtlasSortState<Key>;
  onChange: (value: AtlasSortState<Key>) => void;
  tools?: ReactNode;
}) {
  return (
    <Flex
      px="md"
      py="xs"
      gap="sm"
      align="center"
      wrap="wrap"
      justify="space-between"
      bg="bg.toolbar"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Field.Root
        flexDirection="row"
        alignItems="center"
        gap="sm"
        maxW="var(--atlas-sort-control-width, 380px)"
        flex={{ base: "1 1 100%", md: "0 1 380px" }}
      >
        <Field.Label flexShrink={0}>Sắp xếp</Field.Label>
        <NativeSelect.Root
          size="sm"
          minW="var(--atlas-layout-zero, 0)"
          flex="1"
        >
          <NativeSelect.Field
            aria-label={label}
            value={
              value.key === null || value.direction === "default"
                ? "default"
                : `${value.key}:${value.direction}`
            }
            onChange={(event) => {
              if (event.target.value === "default") {
                onChange(atlasDefaultSort);
                return;
              }
              for (const [key] of axes)
                for (const direction of ["ascending", "descending"] as const) {
                  if (event.target.value === `${key}:${direction}`) {
                    onChange({ key, direction });
                    return;
                  }
                }
            }}
          >
            <option value="default">Thứ tự gốc</option>
            {axes.flatMap(([key, name]) =>
              (["ascending", "descending"] as const).map((direction) => (
                <option
                  key={`${key}:${direction}`}
                  value={`${key}:${direction}`}
                >
                  {name} · {direction === "ascending" ? "Tăng dần" : "Giảm dần"}
                </option>
              )),
            )}
          </NativeSelect.Field>
          <NativeSelect.Indicator />
        </NativeSelect.Root>
      </Field.Root>
      {tools}
    </Flex>
  );
}
