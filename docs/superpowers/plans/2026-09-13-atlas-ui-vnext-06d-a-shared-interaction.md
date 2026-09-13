# Atlas UI vNext 06D-A Shared Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the 06D shared interaction grammar: a Vietnamese popup calendar, visibly button-like command variants, 8px control geometry, and the reusable detail-entry motion used by later 06D slices.

**Architecture:** Keep Chakra UI 3.37 as the only presentation framework and preserve `AtlasDateInput`'s public ISO-string interface. Compose Chakra `DateInput` with `DatePicker` so typing and calendar selection share one controlled `DateValue[]`; keep the popup inside `.atlas-vnext` rather than portalling to unscoped `body`. Put visual meaning in `src/vnext/atlas/system.ts`, not per-workbench CSS.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, @internationalized/date 3.12.3 transitive through Chakra, Phosphor Icons 2.1.10, Vitest 4.1.10, Testing Library, Storybook 10.5, pnpm 11.7.0.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Frontend-only: no Supabase migration, RLS, RPC, Edge Function, API-contract, Retool, or hosted-data changes.
- Keep Soft Mineral palette and semantic-token authority; do not add raw module-specific colors.
- Normal interactive control radius is exactly **8px**; workbench radius remains 6px unless the spec separately changes it.
- Keep control heights 40px and compact controls 36px; routine Refresh stays the deliberate 36×36 circular exception.
- Keep `AtlasDateInput` props exactly `label`, `value`, `onValueChange`, `disabled`; business values remain `YYYY-MM-DD`.
- Date UI is `vi-VN`, Monday-first, `dd/mm/yyyy`, with a popup calendar and no browser-native date input.
- Do not add a date library or generic range-picker abstraction.
- Preserve frozen page motion, Refresh timing, disabled grammar, strictTokens, VNext boundary checks, and reduced-motion behavior.
- Transparent `utility` remains available for genuine navigation/link-like uses; do not globally turn it into the tertiary button.
- Start source implementation from exact `main` baseline `197e9003ac9aebabfdf8ab08f46b5571881085ae` or the subsequently merged 06D-docs commit only after Product authorizes implementation. PR #286 remains untouched.

---

### Task 1: Lock the button and control recipes with failing tests

**Files:**
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.test.tsx`
- Modify: `src/vnext/atlas/AtlasRefreshButton.test.tsx`
- Modify: `src/vnext/atlas/system.ts`

**Interfaces:**
- Consumes: existing Chakra `button` recipe and `radii.control` token.
- Produces: button variants `businessPrimary | secondary | tertiary | utility | destructive`; `radii.control = 8px`; animation style `detailEnter`.

- [ ] **Step 1: Add failing assertions for the sanctioned command hierarchy**

Extend `AtlasDesignLanguageReference.test.tsx` so it can inspect emitted CSS rules and assert that the reference renders one button for each command role. Add assertions equivalent to:

```tsx
const primary = screen.getByRole("button", { name: "Lưu phân bổ" });
const secondary = screen.getByRole("button", { name: "Áp dụng bộ lọc" });
const tertiary = screen.getByRole("button", { name: "Đóng chi tiết" });
expect(primary).toHaveAttribute("data-variant", "businessPrimary");
expect(secondary).toHaveAttribute("data-variant", "secondary");
expect(tertiary).toHaveAttribute("data-variant", "tertiary");
```

Do not assert raw generated class names. Inspect either `data-variant` or the emitted recipe rule in the same style as the current primary-action helper.

- [ ] **Step 2: Add failing theme-contract assertions**

In `AtlasRefreshButton.test.tsx`, add direct configuration checks:

```ts
expect(atlasSystem._config.theme?.tokens?.radii?.control).toMatchObject({
  value: "8px",
});
expect(atlasSystem._config.theme?.animationStyles?.detailEnter).toMatchObject({
  value: { _motionReduce: { animation: "none" } },
});
```

Also assert that the existing refresh `rounded="full"` behavior still wins for the refresh control.

- [ ] **Step 3: Run the focused tests and confirm red**

Run:

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx
```

Expected: FAIL because `tertiary`, `8px`, and `detailEnter` do not yet exist.

- [ ] **Step 4: Implement the minimal system recipe changes**

In `system.ts`, keep `utility` transparent and add/adjust variants like:

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
```

Set:

```ts
radii: {
  control: { value: "8px" },
  workbench: { value: "6px" },
}
```

Add a local detail animation:

```ts
keyframes: {
  // existing refresh keyframes retained
  atlasDetailEnter: {
    from: { opacity: 0, transform: "translateY(6px)" },
    to: { opacity: 1, transform: "translateY(0)" },
  },
},
animationStyles: {
  // existing refresh styles retained
  detailEnter: {
    value: {
      animation: "atlasDetailEnter 160ms ease-out",
      _motionReduce: { animation: "none" },
    },
  },
},
```

- [ ] **Step 5: Make the design-language reference expose the roles without changing business semantics**

In `AtlasDesignLanguageReference.tsx`, use the new variants on fixture-only controls. Preserve the existing primary `Lưu phân bổ`; add fixture-only secondary/tertiary examples where they do not call business APIs. Ensure the existing row action remains semantically actionable rather than a hidden text link.

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

### Task 2: Add the Vietnamese popup calendar without changing the ISO interface

**Files:**
- Modify: `src/vnext/atlas/AtlasDateInput.test.tsx`
- Modify: `src/vnext/atlas/AtlasDateInput.tsx`

**Interfaces:**
- Consumes: Chakra `DateInput`, `DatePicker`, `useDateInput`, `parseDate`; Phosphor calendar icon.
- Produces: unchanged `AtlasDateInput({ label, value, onValueChange, disabled })` interface with typed segments plus popup calendar.

- [ ] **Step 1: Extend the date test for popup behavior**

Add tests that keep the existing segment assertions and verify:

```tsx
const trigger = screen.getByRole("button", { name: "Mở lịch — Ngày phục vụ" });
fireEvent.click(trigger);
expect(screen.getByText(/Tháng 9.*2026/i)).toBeVisible();
expect(screen.getByRole("grid")).toBeVisible();
```

Verify the weekday header starts Monday and ends Sunday by reading the calendar column headers after opening. Also assert there is still no `input[type="date"]`.

- [ ] **Step 2: Add a controlled calendar-selection test**

Open September 2026 and select day 13. Assert:

```tsx
await waitFor(() =>
  expect(onValueChange).toHaveBeenCalledWith("2026-09-13"),
);
```

Then rerender with `value="2026-09-13"` and assert the segments read `13 / 09 / 2026`. Add a disabled test asserting both segments and calendar trigger are unavailable.

- [ ] **Step 3: Add a focus-return test**

Focus the trigger, open the calendar, select a date, and assert focus returns to the trigger or date control after the popup closes. Do not accept focus landing on `body`.

- [ ] **Step 4: Run the date test and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDateInput.test.tsx
```

Expected: FAIL because there is no calendar trigger or popup.

- [ ] **Step 5: Compose Chakra DateInput and DatePicker**

Use Chakra's supported composition pattern while keeping the popup inside the `.atlas-vnext` subtree. The implementation shape should be:

```tsx
import {
  DateInput,
  DatePicker,
  Icon,
  parseDate,
  useDateInput,
} from "@chakra-ui/react";
import { CalendarBlank } from "@phosphor-icons/react";

const dates = [parseDate(value)];
const dateInput = useDateInput({
  locale: "vi-VN",
  shouldForceLeadingZeros: true,
  granularity: "day",
  value: dates,
  onValueChange: ({ value: next }) => {
    if (next[0]) onValueChange(next[0].toString());
  },
});

return (
  <DatePicker.Root
    locale="vi-VN"
    startOfWeek={1}
    value={dates}
    disabled={disabled}
    closeOnSelect
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
            <Icon asChild><CalendarBlank /></Icon>
          </DatePicker.Trigger>
        </DatePicker.IndicatorGroup>
      </DatePicker.Control>
      <DateInput.HiddenInput />
    </DateInput.RootProvider>
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
  </DatePicker.Root>
);
```

Use the exact Chakra 3.37 prop name accepted by typecheck for Monday-first week. If Chakra's prop is not `startOfWeek`, use the documented equivalent exposed by the installed types; do not implement a custom calendar to force the prop name.

Do **not** wrap the popup in Chakra `Portal` unless it is explicitly targeted at an element inside `.atlas-vnext`; the provider scopes CSS variables to that root.

- [ ] **Step 6: Add calendar slot styling in the system only where needed**

If default DatePicker tokens do not satisfy the 8px/Soft Mineral contract, extend the Chakra slot recipe in `system.ts` rather than styling every date field. Keep selected day visually stronger than today; use semantic tokens only.

- [ ] **Step 7: Run focused tests and typecheck**

```bash
pnpm ui:vnext:typegen
pnpm exec vitest run src/vnext/atlas/AtlasDateInput.test.tsx
pnpm typecheck
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/vnext/atlas/AtlasDateInput.tsx src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/system.ts
git commit -m "feat(atlas): add Vietnamese popup calendar"
```

---

### Task 3: Update the design-language contract and reference evidence

**Files:**
- Modify: `docs/ui/atlas-vnext-design-language-v1.md`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.tsx`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.test.tsx`
- Modify: `src/vnext/atlas/AtlasDesignLanguageReference.stories.tsx` only if a dedicated interaction story materially improves review.

**Interfaces:**
- Consumes: Task 1 button variants and Task 2 date picker.
- Produces: current written presentation contract matching executable Chakra recipes.

- [ ] **Step 1: Write the documentation assertions as test-visible behavior first**

Extend the reference test to verify the calendar trigger is visible and that the fixture's real commands are no longer indistinguishable from plain text. Use accessible roles/names, not snapshots.

- [ ] **Step 2: Run the reference test**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDesignLanguageReference.test.tsx
```

Expected: FAIL until the reference markup uses the final variants.

- [ ] **Step 3: Update the design-language document exactly**

Replace the obsolete statements `controls remain 40px/6px`, `Control radius 6px`, segmented-only date language, and four-variant button list. Document:

```text
Controls: 40px; compact 36px; normal control radius 8px; workbench radius 6px.
Buttons: businessPrimary, secondary, tertiary, utility, destructive.
AtlasDateInput: vi-VN segmented keyboard input + popup DatePicker, Monday-first, dd/mm/yyyy, ISO YYYY-MM-DD value.
Transparent utility is reserved for navigation/link-like or icon utility semantics; business commands use a surfaced variant.
```

Keep the 36×36 circular Refresh exception and all frozen Review/page-motion text unchanged.

- [ ] **Step 4: Bring the reference component into conformance**

Use surfaced `secondary`/`tertiary` controls for fixture business actions. Keep shell/navigation treatment outside this reference unchanged.

- [ ] **Step 5: Run docs/UI checks**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx
pnpm ui:vnext:check
pnpm typecheck
pnpm build-storybook
pnpm exec prettier --check docs/ui/atlas-vnext-design-language-v1.md src/vnext/atlas/system.ts src/vnext/atlas/AtlasDateInput.tsx src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasDesignLanguageReference.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add docs/ui/atlas-vnext-design-language-v1.md src/vnext/atlas/AtlasDesignLanguageReference.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasDesignLanguageReference.stories.tsx
git commit -m "docs(atlas): align design language with 06D interaction grammar"
```

---

### Task 4: Certify 06D-A as a reusable foundation

**Files:**
- No new product files unless a failing certification proves a regression in Task 1–3 code.

**Interfaces:**
- Produces the exact shared primitives consumed by 06D-B/C/D: `tertiary` button variant, 8px control token, `detailEnter`, and popup-enabled `AtlasDateInput`.

- [ ] **Step 1: Run the complete shared VNext regression set**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasDateInput.test.tsx src/vnext/atlas/AtlasRefreshButton.test.tsx src/vnext/atlas/AtlasDesignLanguageReference.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: PASS. If `AtlasConvergence.test.tsx` fails only because School Defaults still expects the old Review flow, leave that assertion for 06D-B and document the expected dependency; do not weaken unrelated safety checks.

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

Use the local Storybook or review harness and inspect the operational reference at:

```text
1366×768
1440×900
1920×1080
360×800
```

Acceptance:
- date popup remains inside the viewport;
- Vietnamese labels render correctly;
- selected date and today are distinguishable;
- primary/secondary/tertiary controls read as buttons at rest;
- Refresh stays circular 36×36;
- no document-wide horizontal overflow;
- reduced motion removes `detailEnter` animation.

- [ ] **Step 4: Commit any test-only evidence adjustment needed for deterministic review**

If Storybook needs a fixture-only story to expose the open calendar, add it without product behavior and commit:

```bash
git add src/vnext/atlas/AtlasDesignLanguageReference.stories.tsx
git commit -m "test(atlas): expose 06D interaction review state"
```

If no file changed, do not create an empty commit.

## 06D-A Exit Gate

Do not start 06D-B until:

```text
Shared interaction tests     PASS
ui:vnext:typegen             PASS
ui:vnext:check               PASS
typecheck/build/storybook    PASS
Calendar visual review       PASS
Backend/API/schema changes   ZERO
```
