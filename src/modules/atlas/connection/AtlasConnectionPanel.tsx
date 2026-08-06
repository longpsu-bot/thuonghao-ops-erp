import { useEffect, useState, type FormEvent } from "react";
import {
  useAtlasAuthSession,
  type AtlasAuthSessionController,
} from "./authSession";
import {
  getAtlasSupabaseClient,
  type AtlasSupabaseClientResult,
} from "./supabaseClient";

export function AtlasConnectionPanelView({
  auth,
  environmentLabel,
}: {
  auth: AtlasAuthSessionController;
  environmentLabel: string;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  useEffect(() => {
    if (auth.state.status !== "unauthenticated") setPassword("");
  }, [auth.state.status]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    await auth.signIn(email, password);
    setPassword("");
  };

  return (
    <section className="atlas-session" aria-label="Phiên làm việc Atlas">
      <div className="atlas-environment-label" aria-label="Môi trường Atlas">
        <strong>{environmentLabel}</strong>
      </div>
      {auth.state.status === "configuration_error" && (
        <div className="atlas-session-message" role="alert">
          <div>
            <strong>Chưa thể kết nối dữ liệu Atlas</strong>
            <small>Vui lòng liên hệ bộ phận hỗ trợ trước khi tiếp tục.</small>
          </div>
        </div>
      )}

      {auth.state.status === "loading" && (
        <p role="status">Đang kiểm tra phiên làm việc…</p>
      )}

      {auth.state.status === "session_expired" && (
        <div className="atlas-session-message">
          <p role="alert">
            Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục.
          </p>
          <button type="button" onClick={() => void auth.signOut()}>
            Đăng nhập lại
          </button>
        </div>
      )}

      {auth.state.status === "unauthenticated" && (
        <form onSubmit={submit}>
          <div>
            <strong>Đăng nhập Atlas</strong>
            <small>Dùng tài khoản vận hành đã được cấp quyền.</small>
          </div>
          <label>
            Email
            <input
              type="email"
              autoComplete="username"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>
          <label>
            Mật khẩu
            <input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>
          <button type="submit">Đăng nhập</button>
        </form>
      )}

      {auth.state.status === "authenticated" && (
        <div className="atlas-session-identity">
          <span>
            Đang đăng nhập: <b>{auth.state.user.email ?? "Người dùng Atlas"}</b>
          </span>
          <button type="button" onClick={() => void auth.signOut()}>
            Đăng xuất
          </button>
        </div>
      )}

      {auth.safeAuthError && (
        <p role="alert">Không thể đăng nhập. Vui lòng kiểm tra và thử lại.</p>
      )}
    </section>
  );
}

export function AtlasConnectionPanel({
  connection = getAtlasSupabaseClient(),
}: {
  connection?: AtlasSupabaseClientResult;
}) {
  const auth = useAtlasAuthSession(connection);
  return (
    <AtlasConnectionPanelView
      auth={auth}
      environmentLabel={
        connection.status === "configured"
          ? connection.environmentLabel
          : "Atlas · lỗi cấu hình · non-production"
      }
    />
  );
}
