import { Box, Field, NativeSelect } from "@chakra-ui/react";
import { atlasDefaultSort, type AtlasSortState } from "./atlasTableSort";

export function AtlasSortControl<Key extends string>({
  label,
  axes,
  value,
  onChange,
}: {
  label: string;
  axes: readonly (readonly [Key, string])[];
  value: AtlasSortState<Key>;
  onChange: (value: AtlasSortState<Key>) => void;
}) {
  return (
    <Box px="md" py="xs" minW="var(--atlas-layout-zero, 0)">
      <Field.Root maxW="var(--atlas-sort-control-width, 360px)">
        <Field.Label>{label}</Field.Label>
        <NativeSelect.Root size="sm">
          <NativeSelect.Field
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
    </Box>
  );
}
