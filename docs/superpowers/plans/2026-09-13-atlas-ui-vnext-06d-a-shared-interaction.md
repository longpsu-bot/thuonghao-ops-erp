# Atlas UI vNext 06D-A Shared Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the 06D shared interaction grammar: a Vietnamese popup calendar, visibly button-like command variants, 8px control geometry, and reusable local detail-entry motion for later 06D slices.

**Architecture:** Keep Chakra UI 3.37 as the only presentation framework and preserve `AtlasDateInput`'s public ISO-string interface. Follow Chakra's supported `DateInput` + `DatePicker` composition so typing and calendar selection share one controlled `DateValue[]`. Add one Atlas-owned portal host inside `.atlas-vnext`, because the Chakra system's CSS variables/global selectors are scoped there and an unscoped `body` portal would escape the theme boundary. Put visual meaning in `src/vnext/atlas/system.ts`, not per-workbench CSS.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Chakra's transitive `@internationalized/date` support, Phosphor Icons 2.1.10, Vitest 4.1.10, Testing Library, Storybook 10.5, pnpm 11.7.0.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Frontend-only: no Supabase migration, RLS, RPC, Edge Function, API-contract, Retool, or hosted-data changes.
- Keep Soft Mineral palette and semantic-token authority; do not add raw module-specific colors.
- Normal interactive control radius is exactly **8px**; workbench radius stays 6px unless separately specified.
- Keep control heights 40px and compact controls 36px; routine Refresh stays the deliberate 36×36 circular exception.
- Keep `AtlasDateInput` props exactly `label`, `value`, `onValueChange`, `disabled`; business values remain `YYYY-MM-DD`.
- Date UI is `vi-VN`, `startOfWeek={1}` (Monday), visible `dd/mm/yyyy`, with popup calendar and no browser-native date input.
- Use `openOnClick` so clicking either the segmented field or calendar icon opens the picker.
- Do not add a date library or a generic range-picker abstraction.
- Preserve frozen page motion, Refresh timing, disabled grammar, strictTokens, VNext boundary checks, and reduced-motion behavior.
- Transparent `utility` remains available for genuine navigation/link-like uses; do not globally turn it into the tertiary button.
- Start source implementation from the reviewed 06D docs/main baseline after Product authorizes implementation. PR #286 remains untouched.

---

### Task 1: Lock the button and control recipes with failing tests

**Files:**
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.test.tsx`
- Modify: `src/vnext/atlas/AtlasRefreshButton.test.tsx`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.tsx`
- Modify: `src/vnext/atlas/system.ts`

**Interfaces:**
- Consumes: current Chakra `button` recipe and `radii.control` token.
- Produces: button variants `businessPrimary | secondary | tertiary | utility | destructive`; `radii.control = 8px`; animation style `detailEnter`.

- [ ] **Step 1: Add failing assertions for the sanctioned command hierarchy**

In the design-language reference, expose fixture-only examples for one supporting command and one low-emphasis real command in addition to the existing primary command. In the test, locate buttons by accessible name and inspect the CSS rule generated for each rendered class using the same stylesheet helper pattern already used by the reference tests. Do **not** depend on a synthetic `data-variant` attribute or generated class-name literals.

Required assertions:

```text
Lưu phân bổ      → primary rule has action.primary/default background
Áp dụng bộ lọc   → secondary rule has a non-transparent rest surface + visible border
Đóng chi tiết    → tertiary rule has a non-transparent rest surface + visible border
```

Also assert `utility` remains transparent in the theme contract so shell/navigation semantics are not globally changed.

- [ ] **Step 2: Add failing theme-contract assertions**

In `AtlasRefreshButton.test.tsx`, inspect `atlasSystem._config` and assert:

```ts
expect(atlasSystem._config.theme?.tokens?.radii?.control).toMatchObject({
  value: "8px",
});
expect(atlasSystem._config.theme?.tokens?.radii?.workbench).toMatchObject({
  value: "6px",
});
expect(atlasSystem._config.theme?.animationStyles?.detailEnter).toMatchObject({
  value: { _motionReduce: { animation: "none" } },
});
```

Keep the existing assertion proving Refresh uses `rounded="full"`, so the shared 8px control token does not make Refresh square.

- [ ] **Step 3: Run the focused tests and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx
```

Expected: FAIL because `tertiary`, `8px`, and `detailEnter` do not yet exist.

- [ ] **Step 4: Implement the minimal system recipe changes**

Keep `utility` transparent. Add explicit pressed states to surfaced command variants:

```ts
const pressed = {
  transform: "translateY(var(--atlas-layout-button-press, 1px))",
} as const;

businessPrimary: {
  bg: "action.primary.default",
  color: "fg.inverse",
  _hover: { bg: "action.primary.hover" },
  _active: { bg: "action.primary.hover", ...pressed },
},
secondary: {
  bg: "bg.toolbar",
  color: "fg.primary",
  borderWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "border.default",
  _hover: { bg: "bg.selected" },
  _active: { bg: "bg.selected", ...pressed },
},
tertiary: {
  bg: "bg.subtle",
  color: "fg.default",
  borderWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "border.subtle",
  _hover: { bg: "bg.selected", color: "fg.primary" },
  _active: { bg: "bg.selected", ...pressed },
},
utility: {
  bg: "transparent",
  color: "fg.muted",
  _hover: { bg: "bg.selected", color: "fg.primary" },
},
```

Set:

```ts
radii: {
  control: { value: "8px" },
  workbench: { value: "6px" },
}
```

Add:

```ts
atlasDetailEnter: {
  from: { opacity: 0, transform: "translateY(6px)" },
  to: { opacity: 1, transform: "translateY(0)" },
}
```

and:

```ts
detailEnter: {
  value: {
    animation: "atlasDetailEnter 160ms ease-out",
    _motionReduce: { animation: "none" },
  },
}
```

Do not change the frozen primary page transition timings.

- [ ] **Step 5: Make the design-language reference expose roles without business side effects**

Preserve the existing primary `Lưu phân bổ`. Add fixture-only `Áp dụng bộ lọc` and `Đóng chi tiết` examples whose handlers change only local fixture state or are inert in the reference. Do not call APIs.

- [ ] **Step 6: Run focused tests and type generation**

```bash
pnpm ui:vnext:typegen
pnpm exec vitest run src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx
pnpm typecheck
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/vnext/atlas/system.ts src/vnext/atlas/AtlasDesignLanguageReference.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx
git commit -m "feat(atlas): strengthen shared interaction affordance"
```

---

### Task 2: Add a scoped Atlas portal host before adding the calendar popup

**Files:**
- Modify: `src/vnext/atlas/AtlasVNextProvider.tsx`
- Modify: `src/vnext/atlas/AtlasConvergence.test.tsx`

**Interfaces:**
- Produces hook:

```ts
export function useAtlasPortalContainer(): RefObject<HTMLDivElement | null>;
```

and exactly one portal host under `.atlas-vnext`:

```html
<div data-atlas-portal-root></div>
```

- [ ] **Step 1: Write the provider-boundary test**

Render `AtlasVNextProvider` with a probe component that calls `useAtlasPortalContainer()`. Assert the returned ref resolves to an element matching `[data-atlas-portal-root]` and that:

```ts
expect(root.closest(".atlas-vnext")).not.toBeNull();
```

Assert the provider renders exactly one portal root.

- [ ] **Step 2: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: FAIL because no Atlas portal context/root exists.

- [ ] **Step 3: Implement the scoped portal context**

In `AtlasVNextProvider.tsx`:

```tsx
import {
  createContext,
  useContext,
  useRef,
  type ReactNode,
  type RefObject,
} from "react";

const AtlasPortalContainerContext =
  createContext<RefObject<HTMLDivElement | null> | null>(null);

export function useAtlasPortalContainer() {
  const ref = useContext(AtlasPortalContainerContext);
  if (!ref) throw new Error("Atlas portal container requires AtlasVNextProvider");
  return ref;
}
```

Inside the existing `.atlas-vnext` Box, wrap children in the context provider and add:

```tsx
<Box ref={portalRef} data-atlas-portal-root />
```

The host must remain inside `.atlas-vnext` so scoped Chakra CSS variables/selectors apply to portalled content.

- [ ] **Step 4: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx
pnpm typecheck
git add src/vnext/atlas/AtlasVNextProvider.tsx src/vnext/atlas/AtlasConvergence.test.tsx
git commit -m "feat(atlas): add scoped overlay portal host"
```

---

### Task 3: Add the Vietnamese popup calendar without changing the ISO interface

**Files:**
- Modify: `src/vnext/atlas/AtlasDateInput.test.tsx`
- Modify: `src/vnext/atlas/AtlasDateInput.tsx`
- Modify: `src/vnext/atlas/system.ts` only for DatePicker slot styling needed to meet the design contract.

**Interfaces:**
- Consumes: Chakra `DateInput`, `DatePicker`, `Portal`, `useDateInput`, `parseDate`; `useAtlasPortalContainer`; Phosphor calendar icon.
- Produces: unchanged `AtlasDateInput({ label, value, onValueChange, disabled })` interface with typed segments plus popup calendar.

- [ ] **Step 1: Extend the date test for popup behavior**

Keep existing segment tests and add:

```tsx
const trigger = screen.getByRole("button", {
  name: "Mở lịch — Ngày phục vụ",
});
fireEvent.click(trigger);
expect(screen.getByRole("grid")).toBeVisible();
```

Read calendar column headers and assert Monday is first and Sunday last. Assert there is still no `input[type="date"]`.

- [ ] **Step 2: Assert field-click opening, scoped portal placement, selection and disabled behavior**

Use `userEvent.click` on the segmented field and assert the calendar opens because `openOnClick` is enabled. After opening, assert the calendar grid is a descendant of `[data-atlas-portal-root]`, not a direct `document.body` portal.

Select 13 September 2026 and assert:

```tsx
await waitFor(() =>
  expect(onValueChange).toHaveBeenCalledWith("2026-09-13"),
);
```

Rerender with `value="2026-09-13"` and assert segments display `13 / 09 / 2026`. In disabled state, both segmented editing and the calendar trigger are unavailable.

- [ ] **Step 3: Add focus-return and current-day styling tests**

Open with trigger focus, choose a date, and assert focus returns to the trigger/date control after close rather than `body`. Add semantic assertions that the selected day has the selected state and today has a distinct current-day marker/state; do not assert raw color values in component tests.

- [ ] **Step 4: Run the date test and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDateInput.test.tsx
```

Expected: FAIL because there is no trigger/popup.

- [ ] **Step 5: Compose Chakra DateInput and DatePicker using the supported pattern**

Use Chakra's official DateInput-with-DatePicker composition and the confirmed DatePicker Root props `startOfWeek={1}` and `openOnClick`:

```tsx
const dates = [parseDate(value)];
const dateInput = useDateInput({
  locale: "vi-VN",
  shouldForceLeadingZeros: true,
  granularity: "day",
  disabled,
  value: dates,
  onValueChange: ({ value: next }) => {
    if (next[0]) onValueChange(next[0].toString());
  },
});
const portalContainer = useAtlasPortalContainer();

return (
  <DatePicker.Root
    locale="vi-VN"
    startOfWeek={1}
    openOnClick
    closeOnSelect
    disabled={disabled}
    value={dates}
    onValueChange={({ value: next }) => {
      if (next[0]) onValueChange(next[0].toString());
    }}
  >
    <DateInput.RootProvider value={dateInput}>
      <DateInput.Label>{label}</DateInput.Label>
      <DatePicker.Control>
        <DateInput.Control flex="1">
          <DateInput.Segments />
        </DateInput.Control>
        <DatePicker.IndicatorGroup>
          <DatePicker.Trigger aria-label={`Mở lịch — ${label}`}>
            <CalendarBlank />
          </DatePicker.Trigger>
        </DatePicker.IndicatorGroup>
      </DatePicker.Control>
      <DateInput.HiddenInput />
    </DateInput.RootProvider>

    <Portal container={portalContainer}>
      <DatePicker.Positioner>
        <DatePicker.Content maxW="calc(100vw - 20px)">
          <DatePicker.View view="day">
            <DatePicker.Header />
            <DatePicker.DayTable />
          </DatePicker.View>
          <DatePicker.View view="month">
            <DatePicker.Header />
            <DatePicker.MonthTable />
          </DatePicker.View>
          <DatePicker.View view="year">
            <DatePicker.Header />
            <DatePicker.YearTable />
          </DatePicker.View>
        </DatePicker.Content>
      </DatePicker.Positioner>
    </Portal>
  </DatePicker.Root>
);
```

Do not add an external date framework. `DatePicker` locale supplies Vietnamese calendar labels; `startOfWeek={1}` fixes Monday-first presentation.

- [ ] **Step 6: Apply shared DatePicker styling only where Chakra defaults do not meet 06D**

Use `system.ts` slot recipes/semantic tokens to ensure:

```text
8px control/popup interaction geometry
selected date visibly stronger than ordinary days
today distinct but subtler than selected date
visible hover/focus states
mobile popup max-width/positioning does not overflow viewport
```

Do not add raw module colors.

- [ ] **Step 7: Run focused tests and typecheck**

```bash
pnpm ui:vnext:typegen
pnpm exec vitest run src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
pnpm typecheck
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/vnext/atlas/AtlasDateInput.tsx src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/system.ts
git commit -m "feat(atlas): add Vietnamese popup calendar"
```

---

### Task 4: Update the design-language contract and executable reference

**Files:**
- Modify: `docs/ui/atlas-vnext-design-language-v1.md`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.tsx`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.test.tsx`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.stories.tsx` only if a dedicated open-calendar review story materially improves review.

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: written presentation contract matching executable Chakra recipes.

- [ ] **Step 1: Add reference-level interaction assertions**

Verify the calendar trigger is present and that fixture real commands resolve to surfaced primary/secondary/tertiary CSS rules. Use accessible roles/names and stylesheet rule inspection, not snapshots.

- [ ] **Step 2: Update the design-language document exactly**

Replace obsolete statements `controls remain 40px/6px`, `Control radius 6px`, segmented-only date language, and the old four-role button list. Document:

```text
Controls: 40px; compact 36px; normal control radius 8px; workbench radius 6px.
Buttons: businessPrimary, secondary, tertiary, utility, destructive.
AtlasDateInput: vi-VN segmented keyboard input + popup DatePicker, Monday-first, dd/mm/yyyy, ISO YYYY-MM-DD value.
DatePicker overlays portal only to the Atlas-scoped portal root.
Transparent utility is reserved for navigation/link-like or icon-utility semantics; business commands use a surfaced variant.
```

Keep the 36×36 circular Refresh exception and frozen Review/page-motion text unchanged.

- [ ] **Step 3: Run docs/UI checks**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build-storybook
pnpm exec prettier --check docs/ui/atlas-vnext-design-language-v1.md src/vnext/atlas/system.ts src/vnext/atlas/AtlasVNextProvider.tsx src/vnext/atlas/AtlasDateInput.tsx src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasDesignLanguageReference.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx
git diff --check
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/ui/atlas-vnext-design-language-v1.md src/vnext/atlas/AtlasDesignLanguageReference.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasDesignLanguageReference.stories.tsx
git commit -m "docs(atlas): align design language with 06D interaction grammar"
```

---

### Task 5: Certify 06D-A as a reusable foundation

**Files:**
- No new product files unless a failing certification proves a regression in Tasks 1–4.

- [ ] **Step 1: Run the shared VNext regression set**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: PASS except School-specific assertions deliberately superseded by 06D-B must not be weakened in 06D-A; if such a pre-existing assertion blocks this slice, document the exact dependency and leave its behavioral change to 06D-B.

- [ ] **Step 2: Run structural certification**

```bash
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build
pnpm build-storybook
git diff --check
```

Expected: PASS.

- [ ] **Step 3: Browser-review the reference at four standard viewports**

Use the local Storybook/review harness at:

```text
1366×768
1440×900
1920×1080
360×800
```

Acceptance:

```text
calendar opens by field and icon
popup is not clipped by reference/workbench overflow
popup stays in viewport
Vietnamese month/day labels and Monday-first header render correctly
selected date and today are distinct
primary/secondary/tertiary commands read as buttons at rest
Refresh stays circular 36×36
no document-wide horizontal overflow
reduced motion suppresses detailEnter
```

- [ ] **Step 4: Commit fixture-only review support only if needed**

If Storybook needs an open-calendar fixture state, add it without product API behavior and commit it. Do not create an empty commit when no file changed.

## 06D-A Exit Gate

```text
Shared interaction tests     PASS
ui:vnext:typegen             PASS
ui:vnext:check               PASS
typecheck/build/storybook    PASS
Calendar visual review       PASS
Backend/API/schema changes   ZERO
```
