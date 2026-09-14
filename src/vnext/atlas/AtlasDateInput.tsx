import {
  DateInput,
  DatePicker,
  Portal,
  parseDate,
  useDateInput,
} from "@chakra-ui/react";
import { CalendarBlank } from "@phosphor-icons/react";
import { useAtlasPortalContainer } from "./AtlasVNextProvider";

/** Vietnamese presentation; business-facing values remain ISO calendar dates. */
export function AtlasDateInput({
  label,
  value,
  onValueChange,
  disabled,
}: {
  disabled?: boolean;
  label: string;
  value: string;
  onValueChange: (value: string) => void;
}) {
  const dates = [parseDate(value)];
  const change = ({ value: next }: { value: DateInput.DateValue[] }) => {
    if (next[0]) onValueChange(next[0].toString());
  };
  const dateInput = useDateInput({
    disabled,
    locale: "vi-VN",
    shouldForceLeadingZeros: true,
    granularity: "day",
    value: dates,
    onValueChange: change,
  });
  const portalContainer = useAtlasPortalContainer();
  return (
    <DatePicker.Root
      disabled={disabled}
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
      <DateInput.RootProvider value={dateInput}>
        <DateInput.Label>{label}</DateInput.Label>
        <DatePicker.Control>
          <DatePicker.Context>
            {(picker) => (
              <DateInput.Control
                flex="1"
                minW="var(--atlas-layout-zero, 0)"
                // DateInput segments do not consume DatePicker.Input's click handler.
                onClick={() => {
                  if (!disabled) picker.setOpen(true);
                }}
              >
                <DateInput.Segments pe="var(--atlas-layout-calendar-inset, 40px)" />
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
      </DateInput.RootProvider>
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
    </DatePicker.Root>
  );
}
