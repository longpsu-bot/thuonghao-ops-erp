import {
  Box,
  Button,
  Field,
  Flex,
  Heading,
  Input,
  NativeSelect,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useMemo, useState } from "react";
import { AtlasQuantityContext } from "../AtlasQuantityContext";
import { PantryIngredientChooser } from "./PantryIngredientChooser";
import {
  createPlanningReviewFixture,
  reviewWeek,
} from "./planningReviewFixtures";

const categories = [
  { id: "planning_identified_supplement", name: "Bổ sung" },
  { id: "school_requested_supplement", name: "Hàng đặt riêng" },
] as const;
type ExampleLine = {
  id: string;
  schoolId: string;
  category: (typeof categories)[number]["id"];
  ingredientId: string;
  quantity: string;
  note: string;
};

/** Explicit opt-in design fixture. No Pantry API is called and Save is unavailable. */
export function PantryCategoryDesignReview() {
  const catalog = useMemo(() => {
    const base = createPlanningReviewFixture().pantry;
    return {
      schools: base.schools,
      ingredients: Array.from({ length: 403 }, (_, index) => ({
        ...base.ingredients[0],
        ingredient_id: `design-ingredient-${index}`,
        ingredient_code: `MH-${index + 1}`,
        ingredient_name:
          index === 0
            ? "Gạo thơm"
            : index >= 400
              ? "Rau muống"
              : `Nguyên liệu minh họa ${index}`,
        ingredient_status: index === 402 ? "INACTIVE" : "ACTIVE",
      })),
    };
  }, []);
  const [schoolId, setSchoolId] = useState(catalog.schools[0]!.school_id);
  const [category, setCategory] = useState<ExampleLine["category"]>(
    categories[0].id,
  );
  const [review, setReview] = useState(false);
  const [lines, setLines] = useState<ExampleLine[]>([
    {
      id: "design-planning-line",
      schoolId: catalog.schools[0]!.school_id,
      category: categories[0].id,
      ingredientId: "design-ingredient-0",
      quantity: "5",
      note: "",
    },
    {
      id: "design-school-line",
      schoolId: catalog.schools[0]!.school_id,
      category: categories[1].id,
      ingredientId: "design-ingredient-0",
      quantity: "3",
      note: "",
    },
  ]);
  const edit = (id: string, patch: Partial<ExampleLine>) => {
    setReview(false);
    setLines((rows) =>
      rows.map((row) => (row.id === id ? { ...row, ...patch } : row)),
    );
  };
  return (
    <Box
      p="md"
      bg="bg.workbench"
      minH="var(--atlas-layout-design-height, 100dvh)"
    >
      <Box role="note" p="sm" bg="bg.subtle" mb="md">
        <Text fontWeight="semibold">
          Minh họa giao diện · Dữ liệu ví dụ · Không lưu
        </Text>
        <Text textStyle="helper">
          Hai nguồn được trình bày riêng. Lưu phân loại riêng chưa khả dụng;
          không tạo nhu cầu hoặc đơn mua từ ví dụ này.
        </Text>
      </Box>
      <Heading as="h1" textStyle="workbenchTitle">
        Hàng đặt riêng · Hai nguồn
      </Heading>
      <Flex gap="sm" wrap="wrap" my="md" align="end">
        <Field.Root
          w={{ base: "full", md: "var(--atlas-design-school-width, 280px)" }}
        >
          <Field.Label>Trường thêm hàng</Field.Label>
          <NativeSelect.Root disabled={review}>
            <NativeSelect.Field
              value={schoolId}
              onChange={(e) => setSchoolId(e.target.value)}
            >
              {catalog.schools.map((s) => (
                <option key={s.school_id} value={s.school_id}>
                  {s.school_name}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Field.Root
          w={{ base: "full", md: "var(--atlas-design-category-width, 290px)" }}
        >
          <Field.Label>Nguồn của dòng mới</Field.Label>
          <NativeSelect.Root disabled={review}>
            <NativeSelect.Field
              value={category}
              onChange={(e) =>
                setCategory(e.target.value as ExampleLine["category"])
              }
            >
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Button
          disabled={review}
          onClick={() =>
            setLines((rows) => [
              ...rows,
              {
                id: `design:${crypto.randomUUID()}`,
                schoolId,
                category,
                ingredientId: "",
                quantity: "",
                note: "",
              },
            ])
          }
        >
          + Thêm dòng minh họa
        </Button>
      </Flex>
      <Text textStyle="helper" color="fg.muted">
        Nguồn được chọn một lần cho các dòng thêm mới; đổi lựa chọn không chuyển
        các dòng đã có sang trường hoặc nguồn khác.
      </Text>
      {categories.map((source) => (
        <Box
          as="section"
          aria-label={source.name}
          key={source.id}
          mt="md"
          borderTopWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.default"
        >
          <Heading as="h2" textStyle="section" py="sm">
            {source.name}
          </Heading>
          <Stack gap="sm">
            {lines
              .filter((row) => row.category === source.id)
              .map((row) => {
                const school = catalog.schools.find(
                  (s) => s.school_id === row.schoolId,
                )!;
                const ingredient = catalog.ingredients.find(
                  (i) => i.ingredient_id === row.ingredientId,
                );
                return (
                  <Box
                    key={row.id}
                    data-design-source={row.category}
                    data-design-line={row.id}
                  >
                    <Text fontWeight="semibold">
                      {school.school_name} ·{" "}
                      {school.default_delivery_location.location_name} ·
                      07/09/2026
                    </Text>
                    <Flex gap="sm" wrap="wrap" align="start" py="xs">
                      <Box
                        w={{
                          base: "full",
                          md: "var(--atlas-design-ingredient-width, 310px)",
                        }}
                      >
                        <PantryIngredientChooser
                          label={`Nguyên liệu minh họa ${row.id}`}
                          ingredients={catalog.ingredients}
                          value={row.ingredientId}
                          disabled={review}
                          onChange={(ingredientId) =>
                            edit(row.id, { ingredientId })
                          }
                        />
                      </Box>
                      <Field.Root
                        w={{
                          base: "full",
                          md: "var(--atlas-design-quantity-width, 190px)",
                        }}
                      >
                        <Field.Label>Số lượng</Field.Label>
                        <AtlasQuantityContext
                          recipient={school.school_name}
                          location={
                            school.default_delivery_location.location_name
                          }
                          ingredient={ingredient?.ingredient_name}
                          unit={ingredient?.purchase_unit.unit_code}
                          date={reviewWeek}
                          source={source.name}
                        />
                        <Flex gap="xs" align="center">
                          <Input
                            aria-label={`Số lượng minh họa ${row.id}`}
                            value={row.quantity}
                            disabled={review}
                            inputMode="decimal"
                            onChange={(e) =>
                              edit(row.id, { quantity: e.target.value })
                            }
                          />
                          <Text>{ingredient?.purchase_unit.unit_code}</Text>
                        </Flex>
                      </Field.Root>
                      <Field.Root
                        flex="1"
                        minW="var(--atlas-design-note-width, 180px)"
                      >
                        <Field.Label>Ghi chú (không bắt buộc)</Field.Label>
                        <Input
                          value={row.note}
                          disabled={review}
                          onChange={(e) =>
                            edit(row.id, { note: e.target.value })
                          }
                        />
                      </Field.Root>
                    </Flex>
                  </Box>
                );
              })}
          </Stack>
        </Box>
      ))}
      <Flex mt="md" gap="sm" wrap="wrap">
        <Button variant="secondary" onClick={() => setReview(!review)}>
          {review ? "Tiếp tục chỉnh sửa ví dụ" : "Xem thay đổi minh họa"}
        </Button>
        <Button variant="businessPrimary" disabled>
          Lưu hai nguồn · chưa khả dụng
        </Button>
      </Flex>
      {review && (
        <Box aria-label="Xem thay đổi minh họa" mt="sm" p="sm" bg="bg.subtle">
          <Text fontWeight="semibold">
            Các dòng ví dụ được giữ riêng theo nguồn
          </Text>
          {lines.map((row) => (
            <Text key={row.id}>
              {categories.find((c) => c.id === row.category)!.name} ·{" "}
              {
                catalog.schools.find((s) => s.school_id === row.schoolId)!
                  .school_name
              }{" "}
              ·{" "}
              {catalog.ingredients.find(
                (i) => i.ingredient_id === row.ingredientId,
              )?.ingredient_name ?? "Chưa chọn"}{" "}
              · {row.quantity || "Chưa nhập"}
            </Text>
          ))}
          <Text textStyle="helper">
            Đây là xem trước giao diện, chưa phải kết quả lưu hay bằng chứng
            tổng hợp nhu cầu.
          </Text>
        </Box>
      )}
    </Box>
  );
}
