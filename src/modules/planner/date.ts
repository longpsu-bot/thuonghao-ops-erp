const weekdayLabels = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"];

export function formatDateVi(isoDate: string) {
  const [year, month, day] = isoDate.split("-");
  return year && month && day ? `${day}/${month}/${year}` : "—";
}

export function formatDateWithWeekdayVi(isoDate: string) {
  const date = new Date(`${isoDate}T12:00:00`);
  return `${formatDateVi(isoDate)} — ${weekdayLabels[date.getDay()]}`;
}

export function parseDateVi(value: string) {
  const match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(value.trim());
  if (!match) return undefined;
  const [, day, month, year] = match;
  const date = new Date(`${year}-${month}-${day}T12:00:00`);
  if (
    Number.isNaN(date.getTime()) ||
    date.getFullYear() !== Number(year) ||
    date.getMonth() + 1 !== Number(month) ||
    date.getDate() !== Number(day)
  ) {
    return undefined;
  }
  return `${year}-${month}-${day}`;
}
