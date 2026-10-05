import { DatePicker, Field, Input, Portal, parseDate } from "@chakra-ui/react";
import { CalendarBlank } from "@phosphor-icons/react";
import { useId } from "react";
import {
  useAtlasPortalContainer,
  useAtlasWorkbenchActive,
} from "./AtlasVNextProvider";
import {
  AtlasDateEnvironment,
  AtlasDismissInactiveCalendar,
} from "./AtlasDateEnvironment";

function shiftIsoDate(value: string, days: number) {
  const date = new Date(`${value}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function normalizeIsoWeekStart(value: string) {
  const date = new Date(`${value}T12:00:00Z`);
  return shiftIsoDate(value, -((date.getUTCDay() + 6) % 7));
}

function viDate(value: string) {
  return value.split("-").reverse().join("/");
}

export function formatAtlasWeekRange(value: string) {
  const monday = normalizeIsoWeekStart(value);
  return `${viDate(monday)} – ${viDate(shiftIsoDate(monday, 6))}`;
}

type AtlasWeekRangeInputProps = {
  disabled?: boolean;
  label: string;
  value: string;
  onValueChange: (weekStart: string) => void;
};

export function AtlasWeekRangeInput(props: AtlasWeekRangeInputProps) {
  return (
    <AtlasDateEnvironment>
      <AtlasWeekRangeInputControl {...props} />
    </AtlasDateEnvironment>
  );
}

function AtlasWeekRangeInputControl({
  label,
  value,
  onValueChange,
  disabled,
}: AtlasWeekRangeInputProps) {
  const active = useAtlasWorkbenchActive();
  const unavailable = disabled || !active;
  const inputId = useId();
  const monday = normalizeIsoWeekStart(value);
  const dates = [parseDate(monday)];
  const portalContainer = useAtlasPortalContainer();
  const change = ({ value: next }: { value: DatePicker.DateValue[] }) => {
    if (next[0]) onValueChange(normalizeIsoWeekStart(next[0].toString()));
  };
  return (
    <Field.Root disabled={unavailable}>
      <Field.Label htmlFor={inputId}>{label}</Field.Label>
      <DatePicker.Root
        disabled={unavailable}
        locale="vi-VN"
        startOfWeek={1}
        openOnClick
        closeOnSelect
        lazyMount
        unmountOnExit
        value={dates}
        onValueChange={change}
        positioning={{
          placement: "bottom-start",
          gutter: 6,
          overflowPadding: 10,
        }}
        translations={{
          content: `Lịch — ${label}`,
          prevTrigger: (view) =>
            view === "day"
              ? "Tháng trước"
              : view === "month"
                ? "Năm trước"
                : "Nhóm năm trước",
          nextTrigger: (view) =>
            view === "day"
              ? "Tháng sau"
              : view === "month"
                ? "Năm sau"
                : "Nhóm năm sau",
          viewTrigger: (view) => (view === "day" ? "Chọn tháng" : "Chọn năm"),
        }}
      >
        <AtlasDismissInactiveCalendar />
        <DatePicker.Control>
          <DatePicker.Context>
            {(picker) => (
              <Input
                id={inputId}
                aria-label={label}
                value={formatAtlasWeekRange(monday)}
                readOnly
                disabled={unavailable}
                cursor={
                  unavailable
                    ? "disabled"
                    : "var(--atlas-layout-cursor, pointer)"
                }
                pe="var(--atlas-layout-calendar-inset, 40px)"
                onClick={() => {
                  if (!unavailable) picker.setOpen(true);
                }}
                onKeyDown={(event) => {
                  if (
                    !unavailable &&
                    ["ArrowDown", "Enter", " "].includes(event.key)
                  ) {
                    event.preventDefault();
                    picker.setOpen(true);
                  }
                }}
              />
            )}
          </DatePicker.Context>
          <DatePicker.IndicatorGroup>
            <DatePicker.Trigger aria-label={`Mở lịch — ${label}`}>
              <CalendarBlank aria-hidden="true" />
            </DatePicker.Trigger>
          </DatePicker.IndicatorGroup>
        </DatePicker.Control>
        {active && (
          <Portal container={portalContainer}>
            <DatePicker.Positioner>
              <DatePicker.Content>
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
        )}
      </DatePicker.Root>
    </Field.Root>
  );
}
