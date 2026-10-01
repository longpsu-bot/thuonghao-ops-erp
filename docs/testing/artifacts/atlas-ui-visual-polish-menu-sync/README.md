# Atlas UI visual polish and Menu sync evidence

These captures use local Storybook fixture data only. No hosted Supabase business
write was made. `after/` contains viewport screenshots for the connected shell,
School, Ingredient, selected Ingredient, Menu, editable Attendance, Confirmed
Need, Procurement and blocked Procurement stories at 1440×900, 1280×800,
768×1024 and 390×844. The additions-only, replacement and correction-blocked
Menu stories were also captured at desktop and mobile sizes. The four
`contact-sheet-*.jpg` files place the director's pre-change capture beside each
post-change capture for those nine representative screens.

`browser-measurements.json` records story IDs, viewport sizes, document overflow,
Atlas notification counts and browser page errors. All 42 captures had zero
document-wide horizontal overflow. The expected replacement notification was
present once at both tested sizes; additions-only and correction-blocked states
had none. The replacement capture taken after its enter animation settled is
`after/menu-replacement-settled-390x844.png`.

The finish review measured the selected Ingredient layout at 817/501px
(1440×900) and 718/440px (1280×800), matching the approved 62/38 desktop
split; it stacks at 768×1024 and 390×844. A local browser interaction check
scrolled the mobile Menu table 300px in both axes: its header top and frozen
first-cell left position remained fixed. The School table header likewise
remained fixed after a 300px local vertical scroll. The final UI finish review
reported no BLOCK, MAJOR or MINOR product findings.

The capture run recorded 172 `Illegal invocation` errors across 23 Storybook
story loads. The stack begins in Storybook 10.5's instrumented
`HTMLElement.focus` getter, called by Chakra's `setupGlobalFocusEvents`; no
Atlas application frame is in that stack. This is a Storybook focus-instrumentation
compatibility issue in the local visual harness. Keyboard focus on the Atlas
table viewport was separately observed with its semantic outline. The browser
screenshots and targeted interaction tests remain usable, while a clean
Storybook console is not claimed.
