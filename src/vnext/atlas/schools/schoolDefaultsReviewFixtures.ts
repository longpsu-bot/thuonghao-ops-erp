import type {
  AtlasRpcResult,
  SchoolMasterData,
  SchoolMasterDataApi,
} from "../bridges/schoolMasterData";

export type SchoolDefaultsScenario =
  | "NORMAL"
  | "MULTIPLE_SCHOOL_TYPES"
  | "INACTIVE_SCHOOL"
  | "DIRTY_ONE"
  | "DIRTY_MANY"
  | "DIRTY_HIDDEN_BY_SEARCH"
  | "INVALID_BLANK"
  | "INVALID_NEGATIVE"
  | "INVALID_DECIMAL"
  | "INVALID_OVERFLOW"
  | "STALE_VERSION"
  | "UNKNOWN_SAVE"
  | "SUCCESS_THEN_READ_FAILURE"
  | "PERMISSION_DENIED"
  | "READ_FAILURE"
  | "EMPTY"
  | "AUTH_CHANGE_DELAYED_READ";

const SCHOOL_NAMES = [
  "Trường Mầm non Ánh Dương",
  "Trường Mầm non Hoa Sen",
  "Trường Mầm non Bình Minh",
  "Trường Tiểu học Nguyễn Du",
  "Trường Tiểu học Nguyễn Trãi",
  "Trường Tiểu học Lê Quý Đôn",
  "Trường Tiểu học Trần Quốc Toản",
  "Trường Tiểu học Đoàn Thị Điểm",
  "Trường Tiểu học Chu Văn An",
  "Trường Tiểu học Thăng Long",
  "Trường Tiểu học Thành Công",
  "Trường Tiểu học Kim Liên",
  "Trường Tiểu học Dịch Vọng",
  "Trường Tiểu học Nghĩa Tân",
  "Trường Tiểu học Lý Thái Tổ",
  "Trường Tiểu học Nguyễn Siêu",
  "Trường Tiểu học Đặng Trần Côn",
  "Trường Tiểu học Phan Đình Giót",
  "Trường Tiểu học Hoàng Diệu",
  "Trường Tiểu học Võ Thị Sáu",
  "Trường THCS Nguyễn Trường Tộ",
  "Trường THCS Giảng Võ",
  "Trường THCS Cầu Giấy",
  "Trường THCS Lương Thế Vinh",
  "Trường THCS Marie Curie",
  "Trường THCS Đống Đa",
  "Trường THCS Ngô Sĩ Liên",
  "Trường THCS Trưng Vương",
  "Trường Liên cấp Olympia",
  "Trường Liên cấp Nguyễn Bỉnh Khiêm",
  "Trường Liên cấp Ngôi Sao Hà Nội",
  "Trường Tiểu học Thực nghiệm Khoa học Giáo dục",
  "Trường THCS Thực nghiệm Khoa học Giáo dục",
  "Trường Liên cấp Song ngữ Quốc tế Horizon",
] as const;

function schoolType(name: string) {
  if (name.includes("Mầm non")) return "Mầm non";
  if (name.includes("THCS")) return "Trung học cơ sở";
  if (name.includes("Liên cấp")) return "Liên cấp";
  return "Tiểu học";
}

export const schoolDefaultsFixtureSchools: SchoolMasterData[] =
  SCHOOL_NAMES.map((school_name, index) => {
    const number = index + 1;
    const type = schoolType(school_name);
    return {
      school_id: `review-school-${String(number).padStart(2, "0")}`,
      school_code: `TH${String(number).padStart(3, "0")}`,
      school_name,
      school_status: index === 31 || index === 32 ? "INACTIVE" : "ACTIVE",
      version: 1 + (index % 4),
      display_order: number,
      default_student_portions: 280 + ((index * 37) % 520),
      default_teacher_portions: 18 + ((index * 5) % 42),
      school_type_id: `review-school-type-${type.toLowerCase().replaceAll(" ", "-")}`,
      school_type_name: type,
      customer_id: `review-customer-${Math.floor(index / 4) + 1}`,
      customer_code: `KH${String(Math.floor(index / 4) + 1).padStart(2, "0")}`,
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

function success(schools: SchoolMasterData[]): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, schools: structuredClone(schools) },
  };
}

function backendError(error_code: string): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code,
      safe_message: "Yêu cầu xem thử không thể hoàn tất.",
    },
  };
}

const readFailure: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: {
    code: "NETWORK_FAILURE",
    safeMessage: "Không thể tải dữ liệu xem thử.",
  },
};

export function createSchoolDefaultsReviewFixture(
  scenario: SchoolDefaultsScenario = "NORMAL",
): SchoolMasterDataApi {
  let readCount = 0;
  return {
    getSchools() {
      readCount += 1;
      if (scenario === "AUTH_CHANGE_DELAYED_READ")
        return new Promise<AtlasRpcResult>(() => undefined);
      if (scenario === "READ_FAILURE") return Promise.resolve(readFailure);
      if (scenario === "SUCCESS_THEN_READ_FAILURE" && readCount > 1)
        return Promise.resolve(readFailure);
      return Promise.resolve(
        success(scenario === "EMPTY" ? [] : schoolDefaultsFixtureSchools),
      );
    },
    updateSchoolDefaultsBulk() {
      if (scenario === "STALE_VERSION")
        return Promise.resolve(backendError("STALE_VERSION"));
      if (scenario === "UNKNOWN_SAVE") return Promise.resolve(readFailure);
      if (scenario === "PERMISSION_DENIED")
        return Promise.resolve(backendError("CAPABILITY_DENIED"));
      return Promise.resolve({
        kind: "success",
        response: {
          success: true,
          safe_operator_message: "Đã nhận lệnh xem thử.",
        },
      });
    },
  };
}
