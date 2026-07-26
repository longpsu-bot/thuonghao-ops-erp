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
  | "stale";

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
  if (scenario === "session_lost") {
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
