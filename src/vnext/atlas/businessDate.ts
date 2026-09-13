const timeZone = "Asia/Ho_Chi_Minh";

export function vietnamServiceDate(now: Date): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((p) => p.type === type)!.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export function formatVietnamBusinessDate(now: Date): string {
  const weekday = new Intl.DateTimeFormat("vi-VN", {
    timeZone,
    weekday: "long",
  })
    .format(now)
    .toLocaleLowerCase("vi-VN");
  return `${weekday[0]!.toLocaleUpperCase("vi-VN")}${weekday.slice(1)}, ${vietnamServiceDate(now).split("-").reverse().join("/")}`;
}
