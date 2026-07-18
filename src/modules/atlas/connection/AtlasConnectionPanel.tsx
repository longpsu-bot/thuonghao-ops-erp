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
}: {
  auth: AtlasAuthSessionController;
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
    <section
      className="atlas-connection"
      aria-label="Local Supabase connection"
    >
      <div className="atlas-connection-heading">
        <div>
          <strong>Local Supabase connection foundation</strong>
          <small>No operator business workflow is connected.</small>
        </div>
        <mark>Local · non-production</mark>
      </div>

      {auth.state.status === "configuration_error" && (
        <p role="alert">{auth.state.safeMessage}</p>
      )}
      {auth.state.status === "loading" && (
        <p role="status">Loading local Auth session…</p>
      )}
      {auth.state.status === "session_expired" && (
        <div>
          <p role="alert">{auth.state.safeMessage}</p>
          <button type="button" onClick={() => void auth.signOut()}>
            Clear expired session
          </button>
        </div>
      )}
      {auth.state.status === "unauthenticated" && (
        <form onSubmit={submit}>
          <label>
            Local email
            <input
              type="email"
              autoComplete="username"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>
          <label>
            Local password
            <input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>
          <button type="submit">Sign in locally</button>
        </form>
      )}
      {auth.state.status === "authenticated" && (
        <div className="atlas-connection-identity">
          <span>
            Email <b>{auth.state.user.email ?? "Local synthetic user"}</b>
          </span>
          <span>
            Auth subject <code>{auth.state.authSubject}</code>
          </span>
          <button type="button" onClick={() => void auth.signOut()}>
            Sign out
          </button>
        </div>
      )}
      {auth.safeAuthError && <p role="alert">{auth.safeAuthError}</p>}
    </section>
  );
}

export function AtlasConnectionPanel({
  connection = getAtlasSupabaseClient(),
}: {
  connection?: AtlasSupabaseClientResult;
}) {
  const auth = useAtlasAuthSession(connection);
  return <AtlasConnectionPanelView auth={auth} />;
}
