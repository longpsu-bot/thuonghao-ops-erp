import type { Session } from "@supabase/supabase-js";
import type { AtlasAuthState } from "../connection/authSession";

export const ATLAS_REVIEW_NOTICE =
  "Chế độ xem thử giao diện — dữ liệu không được lưu";

export type AtlasReviewScenario =
  | "ready"
  | "loading"
  | "empty"
  | "permission_denied"
  | "session_lost"
  | "server_error"
  | "stale"
  | "menu_draft"
  | "menu_empty"
  | "menu_validated"
  | "menu_approved"
  | "menu_reopened"
  | "menu_recipe_warning"
  | "menu_diff_approved"
  | "menu_replay_success"
  | "menu_invalid_dates"
  | "menu_duplicate"
  | "menu_inactive_refs"
  | "menu_zero_valid"
  | "menu_permission_denied"
  | "menu_retryable"
  | "menu_stale"
  | "menu_session_lost"
  | "dish_types_renamed"
  | "dish_types_reordered"
  | "dish_types_added"
  | "dish_types_inactive"
  | "menu_type_match"
  | "menu_type_mismatch"
  | "google_source_configured"
  | "google_source_missing"
  | "google_source_unavailable"
  | "google_fetch_success"
  | "google_empty_sheet"
  | "google_sheet_missing"
  | "google_connector_unavailable"
  | "google_permission_denied"
  | "google_retryable"
  | "google_session_lost"
  | "google_preview_blockers"
  | "google_save_success"
  | "attendance_draft"
  | "attendance_imported"
  | "attendance_validated"
  | "attendance_approved"
  | "attendance_reopened"
  | "attendance_zero"
  | "attendance_diff_defaults"
  | "attendance_diff_approved"
  | "attendance_missing_menu"
  | "attendance_negative"
  | "attendance_replay_success"
  | "attendance_permission_denied"
  | "attendance_retryable"
  | "attendance_stale"
  | "attendance_session_lost"
  | "procurement_default"
  | "procurement_manual_split"
  | "procurement_rebalance"
  | "procurement_needs_reallocation"
  | "procurement_po_draft"
  | "procurement_stale_po"
  | "procurement_released_po"
  | "procurement_permission_denied"
  | "procurement_retryable_failure"
  | "procurement_empty";

type ReviewEnvironment = {
  VITE_ATLAS_REVIEW_MODE?: string;
};

export function isAtlasReviewMode(
  environment: ReviewEnvironment = import.meta.env as ReviewEnvironment,
): boolean {
  return environment.VITE_ATLAS_REVIEW_MODE === "true";
}

export function createReviewAuthState(
  scenario: AtlasReviewScenario,
): AtlasAuthState {
  if (
    scenario === "session_lost" ||
    scenario === "menu_session_lost" ||
    scenario === "google_session_lost" ||
    scenario === "attendance_session_lost"
  ) {
    return {
      status: "session_expired",
      safeMessage:
        "Phiên làm việc đã hết. Vui lòng đăng nhập lại trước khi tiếp tục.",
    };
  }

  const authSubject = "review-only-atlas-operator";
  const session = {
    access_token: "review-only",
    refresh_token: "review-only",
    expires_in: 3600,
    token_type: "bearer",
    user: {
      id: authSubject,
      email: "nguoi.duyet@example.invalid",
    },
  } as unknown as Session;

  return {
    status: "authenticated",
    session,
    user: session.user,
    authSubject,
  };
}
