import {
  Button,
  Field,
  Flex,
  Heading,
  Input,
  NativeSelect,
} from "@chakra-ui/react";
import type { DishRecipeController } from "./useDishRecipeWorkbench";
export function DishEditor({ c }: { c: DishRecipeController }) {
  const draft = c.dishDraft;
  if (!draft) return null;
  return (
    <>
      <Heading as="h2" textStyle="section">
        {c.surface === "create" ? "Tạo món mới" : "Sửa thông tin món"}
      </Heading>
      <Field.Root mt="sm" required>
        <Field.Label>Tên món</Field.Label>
        <Input
          value={draft.name}
          disabled={!c.canCommand}
          onChange={(e) => c.setDishDraft({ ...draft, name: e.target.value })}
        />
      </Field.Root>
      <Field.Root mt="sm" required>
        <Field.Label>Loại món của món</Field.Label>
        <NativeSelect.Root disabled={!c.canCommand}>
          <NativeSelect.Field
            value={draft.typeId}
            onChange={(e) =>
              c.setDishDraft({ ...draft, typeId: e.target.value })
            }
          >
            <option value="">Chọn loại món</option>
            {c.catalog.dish_types
              .filter(
                (t) =>
                  t.dish_type_status === "ACTIVE" ||
                  t.dish_type_id === draft.typeId,
              )
              .map((t) => (
                <option
                  key={t.dish_type_id}
                  value={t.dish_type_id}
                  disabled={t.dish_type_status !== "ACTIVE"}
                >
                  {t.dish_type_name}
                  {t.dish_type_status !== "ACTIVE" ? " (ngừng dùng)" : ""}
                </option>
              ))}
          </NativeSelect.Field>
          <NativeSelect.Indicator />
        </NativeSelect.Root>
      </Field.Root>
      <Field.Root mt="sm">
        <Field.Label>Phân loại / nhóm món</Field.Label>
        <Input
          value={draft.category}
          disabled={!c.canCommand}
          onChange={(e) =>
            c.setDishDraft({ ...draft, category: e.target.value })
          }
        />
      </Field.Root>
      <Field.Root mt="sm">
        <Field.Label>Ghi chú vận hành (không bắt buộc)</Field.Label>
        <Input
          value={draft.notes}
          disabled={!c.canCommand}
          onChange={(e) => c.setDishDraft({ ...draft, notes: e.target.value })}
        />
      </Field.Root>
      <Flex mt="md" justify="flex-end">
        <Button
          variant="businessPrimary"
          loading={c.busy}
          disabled={!c.dishValid || !c.canCommand}
          onClick={() => void c.saveDish()}
        >
          {c.surface === "create" ? "Tạo món" : "Lưu thông tin món"}
        </Button>
      </Flex>
    </>
  );
}
