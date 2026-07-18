import { useCallback, useEffect, useRef, useState } from "react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
import type { AtlasSupabaseClientResult } from "./supabaseClient";

export type AtlasAuthState =
  | { status: "configuration_error"; safeMessage: string }
  | { status: "loading" }
  | { status: "unauthenticated" }
  | {
      status: "authenticated";
      session: Session;
      user: Session["user"];
      authSubject: string;
    }
  | { status: "session_expired"; safeMessage: string };

const SIGN_IN_FAILURE =
  "Sign-in failed. Check the local synthetic account and try again.";
const SESSION_EXPIRED =
  "The local Auth session is expired or invalid. Sign in again and review before submitting a new command.";

function authenticatedState(session: Session): AtlasAuthState {
  return {
    status: "authenticated",
    session,
    user: session.user,
    authSubject: session.user.id,
  };
}

function sessionIsExpired(session: Session): boolean {
  return Boolean(session.expires_at && session.expires_at * 1000 <= Date.now());
}

export function useAtlasAuthSession(
  connection: AtlasSupabaseClientResult,
  onConnectionCleared?: () => void,
) {
  const initialState: AtlasAuthState =
    connection.status === "configuration_error"
      ? connection
      : { status: "loading" };
  const [state, setState] = useState<AtlasAuthState>(initialState);
  const [safeAuthError, setSafeAuthError] = useState<string | null>(null);
  const stateRef = useRef(state);
  const explicitSignOutRef = useRef(false);

  const updateState = useCallback((nextState: AtlasAuthState) => {
    stateRef.current = nextState;
    setState(nextState);
  }, []);

  const clearConnectionState = useCallback(() => {
    setSafeAuthError(null);
    onConnectionCleared?.();
  }, [onConnectionCleared]);

  useEffect(() => {
    if (connection.status === "configuration_error") {
      updateState(connection);
      return;
    }

    let active = true;
    const client = connection.client;

    const applySession = (session: Session | null) => {
      if (!active) return;
      if (!session) {
        updateState({ status: "unauthenticated" });
      } else if (sessionIsExpired(session)) {
        clearConnectionState();
        updateState({
          status: "session_expired",
          safeMessage: SESSION_EXPIRED,
        });
      } else {
        updateState(authenticatedState(session));
      }
    };

    const handleAuthChange = (
      event: AuthChangeEvent,
      session: Session | null,
    ) => {
      if (event === "SIGNED_OUT") {
        const wasAuthenticated = stateRef.current.status === "authenticated";
        clearConnectionState();
        updateState(
          wasAuthenticated && !explicitSignOutRef.current
            ? { status: "session_expired", safeMessage: SESSION_EXPIRED }
            : { status: "unauthenticated" },
        );
        return;
      }
      applySession(session);
    };

    const { data } = client.auth.onAuthStateChange(handleAuthChange);
    void client.auth.getSession().then(({ data: sessionData, error }) => {
      if (!active) return;
      if (error) {
        clearConnectionState();
        updateState({
          status: "session_expired",
          safeMessage: SESSION_EXPIRED,
        });
        return;
      }
      applySession(sessionData.session);
    });

    return () => {
      active = false;
      data.subscription.unsubscribe();
    };
  }, [clearConnectionState, connection, updateState]);

  useEffect(() => {
    if (state.status !== "authenticated" || !state.session.expires_at) return;
    const remaining = state.session.expires_at * 1000 - Date.now();
    if (remaining <= 0) {
      clearConnectionState();
      updateState({ status: "session_expired", safeMessage: SESSION_EXPIRED });
      return;
    }
    const timer = window.setTimeout(() => {
      clearConnectionState();
      updateState({ status: "session_expired", safeMessage: SESSION_EXPIRED });
    }, remaining);
    return () => window.clearTimeout(timer);
  }, [clearConnectionState, state, updateState]);

  const signIn = useCallback(
    async (email: string, password: string) => {
      if (connection.status !== "configured") return false;
      setSafeAuthError(null);
      const { data, error } = await connection.client.auth.signInWithPassword({
        email,
        password,
      });
      if (error || !data.session || sessionIsExpired(data.session)) {
        clearConnectionState();
        setSafeAuthError(SIGN_IN_FAILURE);
        updateState({ status: "unauthenticated" });
        return false;
      }
      updateState(authenticatedState(data.session));
      return true;
    },
    [clearConnectionState, connection, updateState],
  );

  const signOut = useCallback(async () => {
    if (connection.status !== "configured") return false;
    setSafeAuthError(null);
    explicitSignOutRef.current = true;
    const { error } = await connection.client.auth.signOut({ scope: "local" });
    explicitSignOutRef.current = false;
    if (error) {
      setSafeAuthError(
        "Sign-out failed safely. The current session was not replayed.",
      );
      return false;
    }
    clearConnectionState();
    updateState({ status: "unauthenticated" });
    return true;
  }, [clearConnectionState, connection, updateState]);

  return {
    state,
    safeAuthError,
    signIn,
    signOut,
    canSubmitCommands: state.status === "authenticated",
  };
}

export type AtlasAuthSessionController = ReturnType<typeof useAtlasAuthSession>;
