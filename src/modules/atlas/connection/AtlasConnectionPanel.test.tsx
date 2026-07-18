import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import type {
  AuthChangeEvent,
  Session,
  SupabaseClient,
} from "@supabase/supabase-js";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasConnectionPanel } from "./AtlasConnectionPanel";

type AuthCallback = (event: AuthChangeEvent, session: Session | null) => void;

const authSubject = "10000000-0000-0000-0000-000000000101";

function session(expiresAt = Math.floor(Date.now() / 1000) + 3600): Session {
  return {
    access_token: "local-access-token",
    refresh_token: "local-refresh-token",
    expires_in: 3600,
    expires_at: expiresAt,
    token_type: "bearer",
    user: {
      id: authSubject,
      aud: "authenticated",
      role: "authenticated",
      email: "atlas.operator@local.test",
      created_at: "2026-07-17T00:00:00.000Z",
      app_metadata: {},
      user_metadata: {},
    },
  };
}

function fakeConnection({
  initialSession = null as Session | null,
  initialPromise,
  signInSession = session(),
  signInError = null as unknown,
}: {
  initialSession?: Session | null;
  initialPromise?: Promise<{
    data: { session: Session | null };
    error: unknown;
  }>;
  signInSession?: Session | null;
  signInError?: unknown;
} = {}) {
  let callback: AuthCallback | undefined;
  const unsubscribe = vi.fn();
  const rpc = vi.fn();
  const getSession = vi.fn(() =>
    initialPromise
      ? initialPromise
      : Promise.resolve({ data: { session: initialSession }, error: null }),
  );
  const signInWithPassword = vi.fn().mockResolvedValue({
    data: { session: signInSession, user: signInSession?.user ?? null },
    error: signInError,
  });
  const signOut = vi.fn().mockResolvedValue({ error: null });
  const client = {
    auth: {
      getSession,
      signInWithPassword,
      signOut,
      onAuthStateChange: vi.fn((nextCallback: AuthCallback) => {
        callback = nextCallback;
        return { data: { subscription: { unsubscribe } } };
      }),
    },
    schema: vi.fn(() => ({ rpc })),
  } as unknown as SupabaseClient;
  return {
    connection: { status: "configured" as const, client },
    emit(event: AuthChangeEvent, nextSession: Session | null) {
      callback?.(event, nextSession);
    },
    unsubscribe,
    signInWithPassword,
    signOut,
    rpc,
  };
}

afterEach(cleanup);

describe("Atlas local connection panel", () => {
  it("always labels the environment local and non-production", () => {
    render(
      <AtlasConnectionPanel
        connection={{
          status: "configuration_error",
          safeMessage: "Safe configuration failure.",
        }}
      />,
    );
    expect(screen.getByText("Local · non-production")).toBeInTheDocument();
    expect(
      screen.getByText("No operator business workflow is connected."),
    ).toBeInTheDocument();
  });

  it("renders a safe configuration-error state", () => {
    const secret = "private-value-that-must-not-render";
    render(
      <AtlasConnectionPanel
        connection={{
          status: "configuration_error",
          safeMessage: "Local Supabase connection settings are missing.",
        }}
      />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent(
      "Local Supabase connection settings are missing.",
    );
    expect(document.body.textContent).not.toContain(secret);
  });

  it("shows loading while the initial session is unresolved", () => {
    const initialPromise = new Promise<{
      data: { session: Session | null };
      error: unknown;
    }>(() => undefined);
    const fake = fakeConnection({ initialPromise });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    expect(screen.getByRole("status")).toHaveTextContent(
      "Loading local Auth session",
    );
  });

  it("shows the unauthenticated local sign-in surface", async () => {
    const fake = fakeConnection();
    render(<AtlasConnectionPanel connection={fake.connection} />);
    expect(
      await screen.findByRole("button", { name: "Sign in locally" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Local email")).toBeInTheDocument();
    expect(screen.getByLabelText("Local password")).toBeInTheDocument();
  });

  it("propagates authenticated email and subject from the session", async () => {
    const fake = fakeConnection({ initialSession: session() });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    expect(
      await screen.findByText("atlas.operator@local.test"),
    ).toBeInTheDocument();
    expect(screen.getByText(authSubject)).toBeInTheDocument();
    expect(screen.queryByText("local-access-token")).not.toBeInTheDocument();
    expect(screen.queryByText("local-refresh-token")).not.toBeInTheDocument();
  });

  it("displays a safe sign-in failure instead of the provider error", async () => {
    const fake = fakeConnection({
      signInSession: null,
      signInError: { message: "raw provider failure with private detail" },
    });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    await screen.findByRole("button", { name: "Sign in locally" });
    fireEvent.change(screen.getByLabelText("Local email"), {
      target: { value: "atlas.operator@local.test" },
    });
    fireEvent.change(screen.getByLabelText("Local password"), {
      target: { value: "synthetic-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in locally" }));
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Sign-in failed. Check the local synthetic account",
    );
    expect(document.body.textContent).not.toContain("raw provider failure");
  });

  it("signs out locally and clears the authenticated identity", async () => {
    const fake = fakeConnection({ initialSession: session() });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    fireEvent.click(await screen.findByRole("button", { name: "Sign out" }));
    expect(
      await screen.findByRole("button", { name: "Sign in locally" }),
    ).toBeInTheDocument();
    expect(screen.queryByText(authSubject)).not.toBeInTheDocument();
    expect(fake.signOut).toHaveBeenCalledWith({ scope: "local" });
  });

  it("clears the password after successful sign-in while retaining the email", async () => {
    const fake = fakeConnection();
    render(<AtlasConnectionPanel connection={fake.connection} />);
    const emailInput = await screen.findByLabelText("Local email");
    const passwordInput = screen.getByLabelText("Local password");

    fireEvent.change(emailInput, {
      target: { value: "atlas.operator@local.test" },
    });
    fireEvent.change(passwordInput, {
      target: { value: "synthetic-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in locally" }));

    await screen.findByRole("button", { name: "Sign out" });
    act(() => fake.emit("INITIAL_SESSION", null));
    expect(
      await screen.findByRole("button", { name: "Sign in locally" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Local email")).toHaveValue(
      "atlas.operator@local.test",
    );
    expect(screen.getByLabelText("Local password")).toHaveValue("");
  });

  it("renders an expired session and disables the sign-in form", async () => {
    const expired = session(Math.floor(Date.now() / 1000) - 1);
    const fake = fakeConnection({ initialSession: expired });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "session is expired or invalid",
    );
    expect(
      screen.queryByRole("button", { name: "Sign in locally" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Clear expired session" }),
    ).toBeInTheDocument();
  });

  it("treats an unexpected signed-out event as session expiry", async () => {
    const fake = fakeConnection({ initialSession: session() });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    await screen.findByText(authSubject);
    act(() => fake.emit("SIGNED_OUT", null));
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "session is expired or invalid",
    );
  });

  it("cleans up the Auth subscription on unmount", () => {
    const fake = fakeConnection();
    const { unmount } = render(
      <AtlasConnectionPanel connection={fake.connection} />,
    );
    unmount();
    expect(fake.unsubscribe).toHaveBeenCalledOnce();
  });

  it("does not replay an RPC after clearing expiry and reauthenticating", async () => {
    const fake = fakeConnection({ initialSession: session() });
    render(<AtlasConnectionPanel connection={fake.connection} />);
    await screen.findByText(authSubject);
    act(() => fake.emit("SIGNED_OUT", null));
    fireEvent.click(
      await screen.findByRole("button", { name: "Clear expired session" }),
    );
    await screen.findByRole("button", { name: "Sign in locally" });
    fireEvent.change(screen.getByLabelText("Local email"), {
      target: { value: "atlas.operator@local.test" },
    });
    fireEvent.change(screen.getByLabelText("Local password"), {
      target: { value: "synthetic-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in locally" }));
    await waitFor(() => expect(fake.signInWithPassword).toHaveBeenCalledOnce());
    expect(fake.rpc).not.toHaveBeenCalled();
  });
});
