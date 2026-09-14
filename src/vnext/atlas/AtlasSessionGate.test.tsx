import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasSessionGate } from "./AtlasSessionGate";
afterEach(cleanup);
it("shows Thượng Hảo branding without replacing the Atlas sign-in workflow", () => {
  render(
    <AtlasVNextProvider>
      <AtlasSessionGate
        session={{ status: "unauthenticated" }}
        onSignIn={vi.fn()}
      >
        <h1>Private module</h1>
      </AtlasSessionGate>
    </AtlasVNextProvider>,
  );
  expect(screen.getByRole("heading", { name: "Atlas" })).toBeVisible();
  expect(screen.getByText("CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO")).toBeVisible();
  expect(screen.getByRole("img", { name: "Thượng Hảo" })).toBeVisible();
  expect(screen.queryByText("Vận hành trường học")).not.toBeInTheDocument();
  expect(screen.getByLabelText("Email")).toBeEnabled();
  expect(screen.getByLabelText("Mật khẩu")).toBeEnabled();
  expect(screen.getByRole("button", { name: "Đăng nhập" })).toBeEnabled();
});
it.each(["unauthenticated", "session_expired"] as const)(
  "%s signs in with labeled fields without mounting stale data",
  async (status) => {
    const signIn = vi.fn().mockResolvedValue(true);
    render(
      <AtlasVNextProvider>
        <AtlasSessionGate
          session={{ status, safeMessage: "Phiên làm việc đã hết." }}
          onSignIn={signIn}
        >
          <h1>Private module</h1>
        </AtlasSessionGate>
      </AtlasVNextProvider>,
    );
    expect(screen.queryByText("Private module")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "operator@example.test" },
    });
    fireEvent.change(screen.getByLabelText("Mật khẩu"), {
      target: { value: "test-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Đăng nhập" }));
    await waitFor(() =>
      expect(signIn).toHaveBeenCalledExactlyOnceWith(
        "operator@example.test",
        "test-password",
      ),
    );
  },
);
it.each(["loading", "configuration_error"] as const)(
  "%s has safe copy without a sign-in form or module",
  (status) => {
    render(
      <AtlasVNextProvider>
        <AtlasSessionGate session={{ status }} onSignIn={vi.fn()}>
          <h1>Private module</h1>
        </AtlasSessionGate>
      </AtlasVNextProvider>,
    );
    expect(screen.queryByText("Private module")).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Mật khẩu")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).not.toBeEmptyDOMElement();
  },
);
it("authenticated renders the application and auth loss unmounts it", () => {
  const view = (status: "authenticated" | "session_expired") => (
    <AtlasVNextProvider>
      <AtlasSessionGate session={{ status }} onSignIn={vi.fn()}>
        <h1>Private module</h1>
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
  const { rerender } = render(view("authenticated"));
  expect(screen.getByText("Private module")).toBeInTheDocument();
  rerender(view("session_expired"));
  expect(screen.queryByText("Private module")).not.toBeInTheDocument();
});
