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

function firstFocusableAfterOnward(
  root: HTMLElement | null,
  onward: HTMLElement | null,
) {
  const direct = focusableElements(onward)[0];
  if (direct) return direct;
  if (!root || !onward) return null;
  return Array.from(
    document.querySelectorAll<HTMLElement>(
      `${focusableSelector}, [data-compact-filter-fallback]`,
    ),
  ).find(
    (candidate) =>
      !root.contains(candidate) &&
      Boolean(
        onward.compareDocumentPosition(candidate) &
        Node.DOCUMENT_POSITION_FOLLOWING,
      ),
  );
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
    const target = firstFocusableAfterOnward(root, onward);
    if (target) {
      event.preventDefault();
      target.focus();
    }
  }
}
