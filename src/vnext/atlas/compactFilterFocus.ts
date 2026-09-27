import type { KeyboardEvent as ReactKeyboardEvent } from "react";

const focusableSelector = [
  'input:not([type="hidden"]):not([disabled])',
  "select:not([disabled])",
  "button:not([disabled])",
  '[tabindex]:not([tabindex="-1"])',
].join(",");

function focusableElements(root: HTMLElement | null) {
  if (!root) return [];
  const elements = Array.from(
    root.querySelectorAll<HTMLElement>(focusableSelector),
  );
  return root.matches(focusableSelector) ? [root, ...elements] : elements;
}

export function focusFirstCompactFilter(root: HTMLElement | null) {
  focusableElements(root)[0]?.focus();
}

export function preserveCompactFilterFocusOrder(
  event: ReactKeyboardEvent,
  root: HTMLElement | null,
  trigger: HTMLElement | null,
  onward: HTMLElement | null,
) {
  if (event.key !== "Tab") return;
  const controls = focusableElements(root);
  const current = event.target;
  if (event.shiftKey && current === controls[0]) {
    event.preventDefault();
    trigger?.focus();
  } else if (!event.shiftKey && current === controls.at(-1)) {
    event.preventDefault();
    focusableElements(onward)[0]?.focus();
  }
}
