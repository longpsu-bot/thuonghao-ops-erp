import type { MenuLine } from "../bridges/planning";

export type WeeklyMenuSyncDelta = {
  unchanged: number;
  added: number;
  replaced: number;
  removed: number;
};

const assignmentKey = (line: MenuLine) =>
  `${line.school_id}\u0000${line.service_date}\u0000${line.menu_slot_code}`;

export function classifyWeeklyMenuSync(
  before: MenuLine[],
  after: MenuLine[],
): WeeklyMenuSyncDelta {
  const previous = new Map(before.map((line) => [assignmentKey(line), line]));
  const incoming = new Map(after.map((line) => [assignmentKey(line), line]));
  const keys = new Set([...previous.keys(), ...incoming.keys()]);
  const delta: WeeklyMenuSyncDelta = {
    unchanged: 0,
    added: 0,
    replaced: 0,
    removed: 0,
  };

  for (const key of keys) {
    const oldLine = previous.get(key);
    const newLine = incoming.get(key);
    if (!oldLine && newLine) delta.added += 1;
    else if (oldLine && !newLine) delta.removed += 1;
    else if (oldLine?.dish_id === newLine?.dish_id) delta.unchanged += 1;
    else delta.replaced += 1;
  }
  return delta;
}

export function sameWeeklyMenuAssignments(left: MenuLine[], right: MenuLine[]) {
  const delta = classifyWeeklyMenuSync(left, right);
  return delta.added === 0 && delta.replaced === 0 && delta.removed === 0;
}

export function weeklyMenuSyncDescription(delta: WeeklyMenuSyncDelta) {
  const parts = [
    delta.replaced > 0 ? `${delta.replaced} món đã được thay đổi` : "",
    delta.removed > 0 ? `${delta.removed} món đã được bỏ` : "",
  ].filter(Boolean);
  return parts.length ? `${parts.join(" · ")}.` : null;
}
