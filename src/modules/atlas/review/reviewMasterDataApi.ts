import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type {
  MasterDataApi,
  MasterDataBulkCommandRequest,
} from "../master-data/masterDataApi";
import type {
  IngredientMasterData,
  IngredientOrderGroupMasterData,
  IngredientTypeMasterData,
  SchoolMasterData,
  SupplierMasterData,
  UnitMasterData,
} from "../master-data/masterDataModel";
import type { AtlasReviewScenario } from "./reviewMode";

const SCHOOL_NAMES = [
  "Trường Tiểu học Nguyễn Du",
  "Trường Tiểu học Trần Quốc Toản",
  "Trường Tiểu học Lê Văn Tám",
  "Trường Tiểu học Bùi Thị Xuân",
  "Trường Tiểu học Võ Thị Sáu",
  "Trường Tiểu học Đinh Tiên Hoàng",
  "Trường Tiểu học Phan Đình Phùng",
  "Trường Tiểu học Lương Thế Vinh",
  "Trường Tiểu học Nguyễn Bỉnh Khiêm",
  "Trường Tiểu học Nguyễn Thái Học",
  "Trường THCS Chu Văn An",
  "Trường THCS Trưng Vương",
  "Trường THCS Lê Quý Đôn",
  "Trường THCS Nguyễn Gia Thiều",
  "Trường THCS Nguyễn Trãi",
  "Trường THCS Ngô Sĩ Liên",
  "Trường THCS Phan Chu Trinh",
  "Trường THCS Đoàn Thị Điểm",
  "Trường Mầm non Hoa Hồng",
  "Trường Mầm non Hoa Mai",
  "Trường Mầm non Ánh Dương",
  "Trường Mầm non Tuổi Thơ",
  "Trường Mầm non Măng Non",
  "Trường Mầm non Sơn Ca",
  "Trường Mầm non Họa Mi",
  "Trường Liên cấp Nguyễn Siêu",
  "Trường Liên cấp Marie Curie",
  "Trường Liên cấp Vinschool",
  "Trường Tiểu học Kim Đồng",
  "Trường Tiểu học Nam Thành Công",
  "Trường THCS Giảng Võ",
  "Trường Mầm non Bông Sen",
  "Trường Tiểu học Thăng Long",
] as const;

const INGREDIENT_NAMES = [
  "Gạo Jasmine",
  "Gạo tẻ thơm",
  "Gạo nếp cái hoa vàng",
  "Thịt lợn nạc vai",
  "Thịt lợn ba chỉ",
  "Thịt bò thăn",
  "Thịt bò bắp",
  "Thịt gà đùi",
  "Thịt gà ức",
  "Cá rô phi",
  "Cá basa phi lê",
  "Tôm nõn",
  "Trứng gà",
  "Đậu phụ",
  "Cà rốt",
  "Khoai tây",
  "Khoai lang",
  "Bí đỏ",
  "Bí xanh",
  "Su su",
  "Cải ngọt",
  "Cải thìa",
  "Rau muống",
  "Bắp cải",
  "Súp lơ xanh",
  "Cà chua",
  "Hành tây",
  "Hành lá",
  "Rau mùi",
  "Nấm hương",
  "Mộc nhĩ",
  "Đậu xanh",
  "Đậu đỏ",
  "Lạc nhân",
  "Bún khô",
  "Miến dong",
  "Mì trứng",
  "Sữa tươi không đường",
  "Dầu ăn",
  "Nước mắm",
  "Nước tương",
  "Đường kính",
  "Muối tinh",
  "Hạt nêm",
  "Bột năng",
] as const;

const SUPPLIER_NAMES = [
  "Công ty Thực phẩm Minh Tâm",
  "Công ty Nông sản An Phú",
  "Hợp tác xã Rau sạch Đông Anh",
  "Công ty Gạo Việt Hương",
  "Công ty Thực phẩm Hà Thành",
  "Hợp tác xã Chăn nuôi Ba Vì",
  "Công ty Hải sản Biển Đông",
  "Công ty Rau củ Mộc Châu",
  "Công ty Thực phẩm Tân Việt",
  "Nhà cung ứng Phúc Lâm",
  "Nhà cung ứng Hoàng Gia",
  "Nhà cung ứng Đức Anh",
  "Công ty Nông nghiệp Xanh",
  "Công ty Thực phẩm Đại Việt",
  "Hợp tác xã Đồng Tâm",
  "Công ty Sữa An Lành",
  "Công ty Gia vị Việt",
  "Công ty Thực phẩm Phương Nam",
  "Nhà cung ứng Thành Công",
  "Nhà cung ứng Hưng Thịnh",
  "Công ty Nông sản Việt",
  "Công ty Thực phẩm Bách Khoa",
  "Hợp tác xã Phú Cường",
  "Công ty Phân phối Ánh Dương",
] as const;

const UNITS: UnitMasterData[] = [
  {
    unit_id: "unit-kg",
    unit_code: "kg",
    unit_name: "Kilôgam",
    unit_status: "ACTIVE",
  },
  {
    unit_id: "unit-l",
    unit_code: "l",
    unit_name: "Lít",
    unit_status: "ACTIVE",
  },
  {
    unit_id: "unit-pack",
    unit_code: "gói",
    unit_name: "Gói",
    unit_status: "ACTIVE",
  },
  {
    unit_id: "unit-tray",
    unit_code: "khay",
    unit_name: "Khay",
    unit_status: "ACTIVE",
  },
];

const INGREDIENT_TYPES: IngredientTypeMasterData[] = [
  ["banh_keo", "Bánh kẹo"],
  ["banh_nuoc", "Bánh nước"],
  ["bo", "Bò"],
  ["bo_sua", "Bơ sữa"],
  ["bun_nui_mi_kho", "Bún, nui, mì khô"],
  ["cha", "Chả"],
  ["dau_hu", "Đậu hủ"],
  ["gia_cam", "Gia cầm"],
  ["heo", "Heo"],
  ["khac", "Khác"],
  ["lap_xuong_tom_kho", "Lạp xưởng - tôm khô"],
  ["rau_cu_qua", "Rau củ quả"],
  ["sua_tuoi", "Sữa tươi"],
  ["tan_tuoi", "Tần tươi"],
  ["thuc_pham_kho_gia_vi", "Thực phẩm khô - gia vị"],
  ["thuy_hai_san", "Thuỷ hải sản"],
  ["trung", "Trứng"],
].map(([code, name], index) => ({
  ingredient_type_id: `review-ingredient-type-${code}`,
  ingredient_type_code: code,
  ingredient_type_name: name,
  display_order: index + 1,
  ingredient_type_status: "ACTIVE",
}));

const INGREDIENT_ORDER_GROUPS: IngredientOrderGroupMasterData[] = [
  ["pantry", "Hàng đặt riêng"],
  ["daily_vegetable", "Rau củ"],
  ["daily_other", "Còn lại"],
].map(([code, name], index) => ({
  ingredient_order_group_id: `review-ingredient-order-group-${code}`,
  ingredient_order_group_code: code,
  ingredient_order_group_name: name,
  display_order: index + 1,
  ingredient_order_group_status: "ACTIVE",
}));

function createSchools(): SchoolMasterData[] {
  return SCHOOL_NAMES.map((name, index) => {
    const number = index + 1;
    const type = name.includes("Mầm non")
      ? "Mầm non"
      : name.includes("THCS")
        ? "Trung học cơ sở"
        : name.includes("Liên cấp")
          ? "Liên cấp"
          : "Tiểu học";
    return {
      school_id: `review-school-${number.toString().padStart(2, "0")}`,
      school_code: `TH${number.toString().padStart(3, "0")}`,
      school_name: name,
      school_status: index === 31 ? "INACTIVE" : "ACTIVE",
      version: 1,
      display_order: number,
      default_student_portions: 280 + ((index * 37) % 520),
      default_teacher_portions: 18 + ((index * 5) % 42),
      school_type_id: `review-school-type-${type.toLowerCase().replaceAll(" ", "-")}`,
      school_type_name: type,
      customer_id: `review-customer-${Math.floor(index / 4) + 1}`,
      customer_code: `KH${(Math.floor(index / 4) + 1).toString().padStart(2, "0")}`,
      customer_name: `Cụm trường khu vực ${Math.floor(index / 4) + 1}`,
      delivery_location_id: `review-delivery-${number}`,
      delivery_location_name:
        index % 3 === 0 ? "Cổng bếp bán trú" : "Khu tiếp nhận thực phẩm",
      delivery_address: `${12 + index} phố Nguyễn Trãi, Hà Nội`,
      delivery_instructions:
        index % 4 === 0
          ? "Giao trước 05:45, liên hệ bảo vệ trước khi vào."
          : "Giao tại cửa kho thực phẩm trước 06:15.",
      contract_context: `Hợp đồng suất ăn năm học 2026–2027 · Đợt ${1 + (index % 3)}`,
    };
  });
}

function createSuppliers(): SupplierMasterData[] {
  return SUPPLIER_NAMES.map((name, index) => {
    const number = index + 1;
    return {
      supplier_id: `review-supplier-${number.toString().padStart(2, "0")}`,
      supplier_code: `NCC${number.toString().padStart(3, "0")}`,
      supplier_name: name,
      supplier_status:
        index === 21 ? "SUSPENDED" : index === 22 ? "INACTIVE" : "ACTIVE",
      contact_name: `Nguyễn Minh ${String.fromCharCode(65 + (index % 24))}`,
      contact_phone: `09${(10000000 + index * 137).toString().slice(-8)}`,
      contact_email: `lienhe${number}@example.invalid`,
      version: 1,
    };
  });
}

function ingredientType(name: string) {
  const code = /Thịt bò/.test(name)
    ? "bo"
    : /Thịt lợn/.test(name)
      ? "heo"
      : /Thịt gà/.test(name)
        ? "gia_cam"
        : /Cá|Tôm/.test(name)
          ? "thuy_hai_san"
          : /Trứng/.test(name)
            ? "trung"
            : /Đậu phụ/.test(name)
              ? "dau_hu"
              : /Sữa/.test(name)
                ? "sua_tuoi"
                : /Bún|Miến|Mì/.test(name)
                  ? "bun_nui_mi_kho"
                  : /Cà|Khoai|Bí|Su |Cải|Rau|Bắp|Súp|Hành|Nấm/.test(name)
                    ? "rau_cu_qua"
                    : "thuc_pham_kho_gia_vi";
  return INGREDIENT_TYPES.find((item) => item.ingredient_type_code === code)!;
}

function ingredientOrderGroup(name: string) {
  const code = /Gạo/.test(name)
    ? "pantry"
    : /Cà|Khoai|Bí|Su |Cải|Rau|Bắp|Súp|Hành|Nấm/.test(name)
      ? "daily_vegetable"
      : "daily_other";
  return INGREDIENT_ORDER_GROUPS.find(
    (item) => item.ingredient_order_group_code === code,
  )!;
}

function createIngredients(
  suppliers: SupplierMasterData[],
): IngredientMasterData[] {
  return Array.from({ length: 180 }, (_, index) => {
    const baseName = INGREDIENT_NAMES[index % INGREDIENT_NAMES.length];
    const cycle = Math.floor(index / INGREDIENT_NAMES.length);
    const name = cycle === 0 ? baseName : `${baseName} · quy cách ${cycle + 1}`;
    const number = index + 1;
    const unit = /Sữa|Dầu|Nước/.test(baseName) ? UNITS[1] : UNITS[0];
    const type = ingredientType(baseName);
    const orderGroup = ingredientOrderGroup(baseName);
    const priorityCount = index < 12 ? 3 : index % 5 === 0 ? 2 : 1;
    const supplier_priorities = Array.from(
      { length: priorityCount },
      (_, priorityIndex) => {
        const supplier =
          suppliers[(index + priorityIndex * 3) % suppliers.length];
        return {
          supplier_eligibility_id: `review-eligibility-${number}-${priorityIndex + 1}`,
          supplier_id: supplier.supplier_id,
          supplier_name: supplier.supplier_name,
          priority: priorityIndex + 1,
        };
      },
    );
    return {
      ingredient_id: `review-ingredient-${number.toString().padStart(3, "0")}`,
      ingredient_code: `NL${number.toString().padStart(4, "0")}`,
      ingredient_name: name,
      ingredient_status:
        index % 29 === 0 && index > 0
          ? "ARCHIVED"
          : index % 11 === 0 && index > 0
            ? "INACTIVE"
            : "ACTIVE",
      ingredient_type_id: type.ingredient_type_id,
      ingredient_type_name: type.ingredient_type_name,
      ingredient_order_group_id: orderGroup.ingredient_order_group_id,
      ingredient_order_group_name: orderGroup.ingredient_order_group_name,
      ingredient_type: type.ingredient_type_name,
      shopping_type: orderGroup.ingredient_order_group_name,
      purchase_unit_id: unit.unit_id,
      purchase_unit_code: unit.unit_code,
      purchase_unit_name: unit.unit_name,
      order_step: /Gạo/.test(baseName) ? 0.1 : 1,
      version: 1,
      supplier_priorities,
    };
  });
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function success(
  response: Omit<AtlasSuccessEnvelope, "success">,
): AtlasRpcResult {
  return { kind: "success", response: { success: true, ...response } };
}

function backendError(
  errorCode: "CAPABILITY_DENIED" | "STALE_VERSION" | "VALIDATION_FAILED",
): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: errorCode,
      safe_message: "Yêu cầu xem thử không thể hoàn tất.",
    },
  };
}

function scenarioReadResult(
  scenario: AtlasReviewScenario,
): AtlasRpcResult | null {
  if (scenario === "permission_denied")
    return backendError("CAPABILITY_DENIED");
  if (scenario === "server_error") {
    return {
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage:
          "Không thể tải dữ liệu lúc này. Vui lòng thử lại sau ít phút.",
      },
    };
  }
  return null;
}

function pendingResult(): Promise<AtlasRpcResult> {
  return new Promise(() => undefined);
}

function payloadString(
  request: { payload: Record<string, JsonValue> },
  key: string,
): string {
  const value = request.payload[key];
  return typeof value === "string" ? value : "";
}

function payloadNumber(
  request: { payload: Record<string, JsonValue> },
  key: string,
): number {
  const value = request.payload[key];
  return typeof value === "number" ? value : Number.NaN;
}

function payloadArray(
  request: { payload: Record<string, JsonValue> },
  key: string,
): JsonValue[] {
  const value = request.payload[key];
  return Array.isArray(value) ? value : [];
}

export function createReviewMasterDataApi(
  scenario: AtlasReviewScenario = "ready",
): MasterDataApi {
  let schools = createSchools();
  let suppliers = createSuppliers();
  let ingredients = createIngredients(suppliers);
  let nextIngredient = ingredients.length + 1;
  let nextSupplier = suppliers.length + 1;

  const readBlock = () => scenarioReadResult(scenario);
  const writeBlock = () =>
    scenario === "stale" ? backendError("STALE_VERSION") : null;
  const saved = () =>
    success({
      safe_operator_message:
        "Đã cập nhật dữ liệu xem thử. Thay đổi sẽ mất khi tải lại trang.",
    });

  return {
    getSchools() {
      if (scenario === "loading") return pendingResult();
      const blocked = readBlock();
      if (blocked) return Promise.resolve(blocked);
      return Promise.resolve(
        success({ schools: scenario === "empty" ? [] : clone(schools) }),
      );
    },

    getIngredientsAndSuppliers() {
      if (scenario === "loading") return pendingResult();
      const blocked = readBlock();
      if (blocked) return Promise.resolve(blocked);
      return Promise.resolve(
        success({
          ingredients: scenario === "empty" ? [] : clone(ingredients),
          suppliers: scenario === "empty" ? [] : clone(suppliers),
          units: clone(UNITS),
          ingredient_types: clone(INGREDIENT_TYPES),
          ingredient_order_groups: clone(INGREDIENT_ORDER_GROUPS),
        }),
      );
    },

    updateSchoolDefaults(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const id = payloadString(request, "school_id");
      const index = schools.findIndex((school) => school.school_id === id);
      if (index < 0) return Promise.resolve(backendError("VALIDATION_FAILED"));
      if (schools[index].version !== request.expected_version)
        return Promise.resolve(backendError("STALE_VERSION"));
      schools[index] = {
        ...schools[index],
        default_student_portions: payloadNumber(
          request,
          "default_student_portions",
        ),
        default_teacher_portions: payloadNumber(
          request,
          "default_teacher_portions",
        ),
        version: schools[index].version + 1,
      };
      return Promise.resolve(saved());
    },

    updateSchoolDefaultsBulk(request: MasterDataBulkCommandRequest) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const changes = payloadArray(request, "changes");
      const prepared = changes.flatMap((value) => {
        if (!value || typeof value !== "object" || Array.isArray(value))
          return [];
        const schoolId =
          typeof value.school_id === "string" ? value.school_id : "";
        const expectedVersion =
          typeof value.expected_version === "number"
            ? value.expected_version
            : Number.NaN;
        const student =
          typeof value.default_student_portions === "number"
            ? value.default_student_portions
            : Number.NaN;
        const teacher =
          typeof value.default_teacher_portions === "number"
            ? value.default_teacher_portions
            : Number.NaN;
        const index = schools.findIndex(
          (school) => school.school_id === schoolId,
        );
        return [{ index, expectedVersion, student, teacher }];
      });
      if (
        prepared.length !== changes.length ||
        prepared.length === 0 ||
        prepared.some(
          ({ index, expectedVersion, student, teacher }) =>
            index < 0 ||
            schools[index]?.version !== expectedVersion ||
            !Number.isInteger(student) ||
            !Number.isInteger(teacher) ||
            student < 0 ||
            teacher < 0,
        )
      )
        return Promise.resolve(backendError("VALIDATION_FAILED"));

      const updatedSchools = prepared.map(({ index, student, teacher }) => ({
        school_id: schools[index]!.school_id,
        version: schools[index]!.version + 1,
        default_student_portions: student,
        default_teacher_portions: teacher,
      }));
      const nextSchools = [...schools];
      prepared.forEach(({ index, student, teacher }) => {
        nextSchools[index] = {
          ...nextSchools[index]!,
          default_student_portions: student,
          default_teacher_portions: teacher,
          version: nextSchools[index]!.version + 1,
        };
      });
      schools = nextSchools;
      return Promise.resolve(
        success({
          safe_operator_message: `${prepared.length} trường đã được cập nhật.`,
          updated_schools: updatedSchools,
        }),
      );
    },

    createIngredient(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const code =
        request.payload.ingredient_code === undefined
          ? `ingredient-${crypto.randomUUID()}`
          : payloadString(request, "ingredient_code").trim();
      if (
        !code ||
        ingredients.some(
          (ingredient) =>
            ingredient.ingredient_code.toLocaleLowerCase("vi") ===
            code.toLocaleLowerCase("vi"),
        )
      )
        return Promise.resolve(backendError("VALIDATION_FAILED"));
      const unit = UNITS.find(
        (item) => item.unit_id === payloadString(request, "purchase_unit_id"),
      );
      const type = INGREDIENT_TYPES.find(
        (item) =>
          item.ingredient_type_id ===
          payloadString(request, "ingredient_type_id"),
      );
      const orderGroup = INGREDIENT_ORDER_GROUPS.find(
        (item) =>
          item.ingredient_order_group_id ===
          payloadString(request, "ingredient_order_group_id"),
      );
      if (!unit || !type || !orderGroup)
        return Promise.resolve(backendError("VALIDATION_FAILED"));
      const id = `review-ingredient-${nextIngredient.toString().padStart(3, "0")}`;
      nextIngredient += 1;
      ingredients = [
        {
          ingredient_id: id,
          ingredient_code: code,
          ingredient_name: payloadString(request, "ingredient_name"),
          ingredient_status: "ACTIVE",
          ingredient_type_id: type.ingredient_type_id,
          ingredient_type_name: type.ingredient_type_name,
          ingredient_order_group_id: orderGroup.ingredient_order_group_id,
          ingredient_order_group_name: orderGroup.ingredient_order_group_name,
          ingredient_type: type.ingredient_type_name,
          shopping_type: orderGroup.ingredient_order_group_name,
          purchase_unit_id: unit?.unit_id ?? null,
          purchase_unit_code: unit?.unit_code ?? null,
          purchase_unit_name: unit?.unit_name ?? null,
          order_step: payloadNumber(request, "order_step"),
          version: 1,
          supplier_priorities: [],
        },
        ...ingredients,
      ];
      return Promise.resolve(saved());
    },

    updateIngredient(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const id = payloadString(request, "ingredient_id");
      const index = ingredients.findIndex(
        (ingredient) => ingredient.ingredient_id === id,
      );
      if (index < 0) return Promise.resolve(backendError("VALIDATION_FAILED"));
      if (ingredients[index].version !== request.expected_version)
        return Promise.resolve(backendError("STALE_VERSION"));
      const unit = UNITS.find(
        (item) => item.unit_id === payloadString(request, "purchase_unit_id"),
      );
      const type = INGREDIENT_TYPES.find(
        (item) =>
          item.ingredient_type_id ===
          payloadString(request, "ingredient_type_id"),
      );
      const orderGroup = INGREDIENT_ORDER_GROUPS.find(
        (item) =>
          item.ingredient_order_group_id ===
          payloadString(request, "ingredient_order_group_id"),
      );
      if (!unit || !type || !orderGroup)
        return Promise.resolve(backendError("VALIDATION_FAILED"));
      ingredients[index] = {
        ...ingredients[index],
        ingredient_name: payloadString(request, "ingredient_name"),
        ingredient_type_id: type.ingredient_type_id,
        ingredient_type_name: type.ingredient_type_name,
        ingredient_order_group_id: orderGroup.ingredient_order_group_id,
        ingredient_order_group_name: orderGroup.ingredient_order_group_name,
        ingredient_type: type.ingredient_type_name,
        shopping_type: orderGroup.ingredient_order_group_name,
        purchase_unit_id: unit?.unit_id ?? null,
        purchase_unit_code: unit?.unit_code ?? null,
        purchase_unit_name: unit?.unit_name ?? null,
        order_step: payloadNumber(request, "order_step"),
        version: ingredients[index].version + 1,
      };
      return Promise.resolve(saved());
    },

    setIngredientLifecycle(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const id = payloadString(request, "ingredient_id");
      const index = ingredients.findIndex(
        (ingredient) => ingredient.ingredient_id === id,
      );
      if (index < 0) return Promise.resolve(backendError("VALIDATION_FAILED"));
      if (ingredients[index].version !== request.expected_version)
        return Promise.resolve(backendError("STALE_VERSION"));
      const status = payloadString(
        request,
        "ingredient_status",
      ) as IngredientMasterData["ingredient_status"];
      ingredients[index] = {
        ...ingredients[index],
        ingredient_status: status,
        supplier_priorities:
          status === "ACTIVE" ? ingredients[index].supplier_priorities : [],
        version: ingredients[index].version + 1,
      };
      return Promise.resolve(saved());
    },

    createSupplier(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const code =
        request.payload.supplier_code === undefined
          ? `supplier-${crypto.randomUUID()}`
          : payloadString(request, "supplier_code").trim();
      if (
        !code ||
        suppliers.some(
          (supplier) =>
            supplier.supplier_code.toLocaleLowerCase("vi") ===
            code.toLocaleLowerCase("vi"),
        )
      )
        return Promise.resolve(backendError("VALIDATION_FAILED"));
      const number = nextSupplier;
      nextSupplier += 1;
      suppliers = [
        {
          supplier_id: `review-supplier-${number.toString().padStart(2, "0")}`,
          supplier_code: code,
          supplier_name: payloadString(request, "supplier_name"),
          supplier_status: "ACTIVE",
          contact_name: payloadString(request, "contact_name") || null,
          contact_phone: payloadString(request, "contact_phone") || null,
          contact_email: payloadString(request, "contact_email") || null,
          version: 1,
        },
        ...suppliers,
      ];
      return Promise.resolve(saved());
    },

    updateSupplier(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const id = payloadString(request, "supplier_id");
      const index = suppliers.findIndex(
        (supplier) => supplier.supplier_id === id,
      );
      if (index < 0) return Promise.resolve(backendError("VALIDATION_FAILED"));
      if (suppliers[index].version !== request.expected_version)
        return Promise.resolve(backendError("STALE_VERSION"));
      suppliers[index] = {
        ...suppliers[index],
        supplier_name: payloadString(request, "supplier_name"),
        contact_name: payloadString(request, "contact_name") || null,
        contact_phone: payloadString(request, "contact_phone") || null,
        contact_email: payloadString(request, "contact_email") || null,
        version: suppliers[index].version + 1,
      };
      return Promise.resolve(saved());
    },

    replacePriorities(request) {
      const blocked = writeBlock();
      if (blocked) return Promise.resolve(blocked);
      const id = payloadString(request, "ingredient_id");
      const index = ingredients.findIndex(
        (ingredient) => ingredient.ingredient_id === id,
      );
      if (index < 0) return Promise.resolve(backendError("VALIDATION_FAILED"));
      if (ingredients[index].version !== request.expected_version)
        return Promise.resolve(backendError("STALE_VERSION"));
      const priorities = payloadArray(request, "priorities").flatMap(
        (value, priorityIndex) => {
          if (!value || typeof value !== "object" || Array.isArray(value))
            return [];
          const supplierId =
            typeof value.supplier_id === "string" ? value.supplier_id : "";
          const priority =
            typeof value.priority === "number"
              ? value.priority
              : priorityIndex + 1;
          const supplier = suppliers.find(
            (item) => item.supplier_id === supplierId,
          );
          if (!supplier) return [];
          return [
            {
              supplier_eligibility_id: `review-eligibility-${id}-${priority}`,
              supplier_id: supplier.supplier_id,
              supplier_name: supplier.supplier_name,
              priority,
            },
          ];
        },
      );
      ingredients[index] = {
        ...ingredients[index],
        supplier_priorities: priorities,
        version: ingredients[index].version + 1,
      };
      return Promise.resolve(saved());
    },
  };
}
