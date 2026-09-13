import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextApp } from "./AtlasVNextApp";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import {
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";

// jsdom has no animation timeline. Complete the browser boundary explicitly;
// the application, domain guards, fixtures, and mounted workbenches stay real.
const animations: {
  target: Element;
  frames: Keyframe[];
  options: KeyframeAnimationOptions;
  onfinish: (() => void) | null;
  cancel: ReturnType<typeof vi.fn>;
}[] = [];
let reduced = false;
beforeEach(() => {
  reduced = false;
  animations.length = 0;
  vi.stubGlobal(
    "matchMedia",
    vi.fn((media: string) => ({
      media,
      matches: media.includes("prefers-reduced-motion")
        ? reduced
        : media.includes("min-width"),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
  Object.defineProperty(Element.prototype, "animate", {
    configurable: true,
    value: function (
      this: Element,
      frames: Keyframe[],
      options: KeyframeAnimationOptions,
    ) {
      const animation = {
        target: this,
        frames,
        options,
        onfinish: null as (() => void) | null,
        cancel: vi.fn(),
      };
      animations.push(animation);
      return animation;
    },
  });
});
afterEach(() => {
  cleanup();
  Reflect.deleteProperty(Element.prototype, "animate");
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});
async function show(unknown = false) {
  const apis = createAtlasApplicationFixture();
  if (unknown) apis.recipe = createRecipeReviewFixture("SAVE_UNKNOWN").api;
  const result = render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        userLabel="operator@example.test"
        environmentLabel="Local review"
        now={applicationReviewNow}
        onSignOut={vi.fn()}
      />
    </AtlasVNextProvider>,
  );
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  return { apis, ...result };
}
function nav(name: string) {
  fireEvent.click(screen.getByRole("button", { name, hidden: true }));
}
function complete() {
  const animation = animations.at(-1)!;
  expect(animation.onfinish).toBeTypeOf("function");
  act(() => animation.onfinish!());
}
function heading(name: string) {
  return screen.getByRole("heading", {
    level: 1,
    name,

    hidden: true,
  });
}
async function settle(name: string) {
  complete();
  await screen.findByRole("heading", {
    level: 1,
    name,

    hidden: true,
  });
  complete();
  expect(heading(name)).toHaveFocus();
}

it("keeps Schools through exit, mounts only Recipe during entry, then focuses its heading", async () => {
  await show();
  const old = heading("Sĩ số mặc định");
  nav("Công thức");
  expect(old).toBeInTheDocument();
  expect(
    screen.queryByRole("heading", { level: 1, name: "Công thức" }),
  ).not.toBeInTheDocument();
  expect(animations).toHaveLength(1);
  expect(animations[0]!.options.duration).toBe(60);
  expect(animations[0]!.frames).toEqual([{ opacity: 1 }, { opacity: 0.15 }]);
  complete();
  expect(old).not.toBeInTheDocument();
  expect(heading("Công thức")).not.toHaveFocus();
  expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  expect(animations).toHaveLength(2);
  expect(animations[1]!.options).toMatchObject({
    duration: 180,
    easing: "ease-out",
  });
  expect(animations[1]!.frames).toEqual([
    { opacity: 0.15, transform: "translateY(6px)" },
    { opacity: 1, transform: "translateY(0)" },
  ]);
  expect(animations[1]!.target).toBe(animations[0]!.target);
  for (const animation of animations) {
    for (const frame of animation.frames) {
      expect(Number(frame.opacity)).toBeGreaterThanOrEqual(0.15);
    }
  }
  complete();
  expect(heading("Công thức")).toHaveFocus();
  expect(animations[1]!.target).not.toHaveAttribute("inert");
});

it("does not move or activate the destination until the dirty domain authorizes discard", async () => {
  await show();
  fireEvent.change(
    screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0]!,
    { target: { value: "123" } },
  );
  nav("Công thức");
  await screen.findByRole("button", { name: "Tiếp tục chỉnh sửa" });
  expect(animations).toHaveLength(0);
  expect(heading("Sĩ số mặc định")).toBeInTheDocument();
  expect(
    screen.getByRole("button", {
      name: "Trường học",

      hidden: true,
    }),
  ).toHaveAttribute("aria-current", "page");
  expect(
    screen.queryByRole("heading", { level: 1, name: "Công thức" }),
  ).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
  await waitFor(() =>
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
  );
  expect(animations).toHaveLength(0);
  nav("Công thức");
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  expect(animations).toHaveLength(1);
  expect(heading("Sĩ số mặc định")).toBeInTheDocument();
  await settle("Công thức");
}, 15000);

it("keeps UNKNOWN recovery intact with zero outgoing animation", async () => {
  await show(true);
  nav("Công thức");
  await settle("Công thức");
  fireEvent.click(
    await screen.findByRole("button", {
      name: "Xem công thức Canh bí đỏ thịt bằm",
    }),
  );
  fireEvent.change(await screen.findByLabelText("Định lượng Bí đỏ"), {
    target: { value: "2,25" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  fireEvent.click(screen.getByRole("button", { name: "Lưu công thức" }));
  await screen.findByRole("button", { name: "Tải lại để xác nhận" });
  nav("Trường học");
  expect(animations).toHaveLength(2);
  expect(heading("Công thức")).toBeInTheDocument();
  expect(
    screen.getByRole("button", { name: "Tải lại để xác nhận" }),
  ).toBeInTheDocument();
  expect(
    screen.queryByRole("heading", { level: 1, name: "Sĩ số mặc định" }),
  ).not.toBeInTheDocument();
}, 15000);

it("ignores rapid requests during both phases without queueing a stale destination", async () => {
  await show();
  nav("Công thức");
  nav("Lập nhu cầu");
  expect(animations).toHaveLength(1);
  complete();
  nav("Phiếu xuất kho");
  expect(animations).toHaveLength(2);
  complete();
  expect(heading("Công thức")).toHaveFocus();
  expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  expect(
    screen.queryByRole("heading", { level: 1, name: "Thực đơn" }),
  ).not.toBeInTheDocument();
  expect(
    screen.getByRole("button", {
      name: "Công thức",

      hidden: true,
    }),
  ).toHaveAttribute("aria-current", "page");
});

it("reduced motion still guards dirty exit then mounts and focuses immediately with no animation", async () => {
  reduced = true;
  await show();
  fireEvent.change(
    screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0]!,
    { target: { value: "123" } },
  );
  nav("Công thức");
  await screen.findByRole("button", { name: "Bỏ thay đổi" });
  expect(heading("Sĩ số mặc định")).toBeInTheDocument();
  expect(animations).toHaveLength(0);
  fireEvent.click(screen.getByRole("button", { name: "Bỏ thay đổi" }));
  expect(heading("Công thức")).toHaveFocus();
  expect(animations).toHaveLength(0);
  expect(
    screen.queryByRole("heading", { level: 1, name: "Sĩ số mặc định" }),
  ).not.toBeInTheDocument();
});

it("uses the same two phases for Confirmed Need handoff, retaining date and allocation without a command", async () => {
  const { apis } = await show();
  const save = vi.spyOn(apis.confirmedNeed, "save");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  nav("Lập nhu cầu");
  await settle("Thực đơn");
  fireEvent.change(
    await screen.findByRole("combobox", { name: "Ngày phục vụ" }),
    { target: { value: "2026-09-09" } },
  );
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  expect(animations).toHaveLength(2);
  fireEvent.click(proceed);
  expect(animations).toHaveLength(3);
  expect(allocation).not.toHaveBeenCalled();
  await settle("Phân bổ nhà cung ứng");
  expect(animations).toHaveLength(4);
  await waitFor(() =>
    expect(allocation).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-09",
          date_end: "2026-09-09",
        }),
      }),
    ),
  );
  expect(screen.getByRole("tab", { name: /Phân bổ/ })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(save).not.toHaveBeenCalled();
  expect(prepare).not.toHaveBeenCalled();
});

it("keeps shell and session context DOM stationary while only one content surface animates", async () => {
  const { container } = await show();
  const shell = [
    screen.getByRole("navigation", { hidden: true }),
    container.querySelector("header"),
    screen.getByText("operator@example.test"),
    screen.getByText("Môi trường · Local review"),
  ];
  nav("Công thức");
  await settle("Công thức");
  for (const node of shell) {
    expect(node).toBeInTheDocument();
    expect(animations.every(({ target }) => !target.contains(node))).toBe(true);
  }
  expect(animations[0]!.target).toBe(animations[1]!.target);
});
