import {
  DateInput,
  DatePicker,
  Portal,
  Text,
  parseDate,
  useDateInput,
} from "@chakra-ui/react";
import { useEffect, useId, useState } from "react";
import { type AtlasOperatorDateRange } from "./atlasOperatorDateRange";
import { CalendarBlank } from "@phosphor-icons/react";
import { AtlasDismissInactiveCalendar } from "./AtlasDateOwnership";
import {
  useAtlasPortalContainer,
  useAtlasWorkbenchActive,
} from "./AtlasVNextProvider";

/** Vietnamese presentation; business-facing values remain ISO calendar dates. */

type AtlasDateRangeInputProps = {
  disabled?: boolean;
  label: string;
  value: AtlasOperatorDateRange;
  error?: string | null;
  /** When supplied, the workbar renders the message in its own full-width row. */
  errorMessageId?: string;
  onValueChange: (value: AtlasOperatorDateRange) => void;
};

export function AtlasDateRangeInput({
  label,
  value,
  onValueChange,
  disabled,
  error,
  errorMessageId,
}: AtlasDateRangeInputProps) {
  const active = useAtlasWorkbenchActive();
  const localErrorId = useId();
  const errorId = errorMessageId ?? localErrorId;
  const dates = [parseDate(value.start), parseDate(value.end)];
  const [calendarDates, setCalendarDates] = useState(dates);
  useEffect(() => {
    setCalendarDates([parseDate(value.start), parseDate(value.end)]);
  }, [value.start, value.end, active]);
  const change = ({ value: next }: { value: DateInput.DateValue[] }) => {
    if (disabled || !active) return;
    if (next[0] && next[1])
      onValueChange({ start: next[0].toString(), end: next[1].toString() });
  };
  const dateInput = useDateInput({
    invalid: Boolean(error),
    disabled: disabled || !active,
    locale: "vi-VN",
    selectionMode: "range",
    shouldForceLeadingZeros: true,
    granularity: "day",
    value: dates,
    onValueChange: change,
  });
  const portalContainer = useAtlasPortalContainer();
  return (
    <DatePicker.Root
      disabled={disabled || !active}
      locale="vi-VN"
      selectionMode="range"
      startOfWeek={1}
      openOnClick
      closeOnSelect
      lazyMount
      unmountOnExit
      value={calendarDates}
      onOpenChange={({ open }) => {
        if (!open)
          setCalendarDates([parseDate(value.start), parseDate(value.end)]);
      }}
      onValueChange={({ value: next }) => {
        setCalendarDates(next);
        change({ value: next });
      }}
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
      <DateInput.RootProvider value={dateInput}>
        <DateInput.Label>{label}</DateInput.Label>
        <DatePicker.Control>
          <DatePicker.Context>
            {(picker) => (
              <DateInput.Control
                aria-invalid={Boolean(error)}
                aria-describedby={error ? errorId : undefined}
                gap="xs"
                flex="1"
                minW="var(--atlas-layout-zero, 0)"
                // DateInput segments do not consume DatePicker.Input's click handler.
                onClick={() => {
                  if (!disabled && active) picker.setOpen(true);
                }}
              >
                <DateInput.Segments
                  index={0}
                  aria-describedby={error ? errorId : undefined}
                  gap="var(--atlas-layout-zero, 0)"
                  aria-label="Từ ngày"
                  aria-labelledby=""
                />
                <Text as="span" color="fg.muted" aria-hidden="true">
                  —
                </Text>
                <DateInput.Segments
                  index={1}
                  aria-describedby={error ? errorId : undefined}
                  gap="var(--atlas-layout-zero, 0)"
                  aria-label="Đến ngày"
                  aria-labelledby=""
                  pe={{
                    base: "var(--atlas-layout-mobile-target, 44px)",
                    lg: "var(--atlas-layout-calendar-inset, 40px)",
                  }}
                />
              </DateInput.Control>
            )}
          </DatePicker.Context>
          <DatePicker.IndicatorGroup>
            <DatePicker.Trigger aria-label={`Mở lịch — ${label}`}>
              <CalendarBlank aria-hidden="true" />
            </DatePicker.Trigger>
          </DatePicker.IndicatorGroup>
        </DatePicker.Control>
        <DateInput.HiddenInput />
        <DateInput.HiddenInput index={1} />
        {error && !errorMessageId && (
          <Text
            id={errorId}
            role="alert"
            textStyle="helper"
            color="status.danger"
          >
            {error}
          </Text>
        )}
      </DateInput.RootProvider>
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
  );
}
