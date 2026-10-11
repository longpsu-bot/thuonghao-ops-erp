import { DatePicker, Portal, Text, parseDate } from "@chakra-ui/react";
import { useEffect, useId, useState } from "react";
import { type AtlasOperatorDateRange } from "./atlasOperatorDateRange";
import { CalendarBlank } from "@phosphor-icons/react";
import { AtlasDismissInactiveCalendar } from "./AtlasDateOwnership";
import { atlasWorkbarControlHeight } from "./AtlasWorkbar";
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
  const valueId = useId();
  const errorId = errorMessageId ?? localErrorId;
  const dates = [parseDate(value.start), parseDate(value.end)];
  const [calendarDates, setCalendarDates] = useState(dates);
  useEffect(() => {
    setCalendarDates([parseDate(value.start), parseDate(value.end)]);
  }, [value.start, value.end, active]);
  const rangeText = `${value.start.split("-").reverse().join("/")} — ${value.end.split("-").reverse().join("/")}`;
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
        if (!disabled && active && next[0] && next[1])
          onValueChange({ start: next[0].toString(), end: next[1].toString() });
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
      <DatePicker.Context>
        {(picker) => (
          <DatePicker.Label
            htmlFor={picker.getTriggerProps().id}
            textStyle="label"
            color="fg.default"
          >
            {label}
          </DatePicker.Label>
        )}
      </DatePicker.Context>
      <DatePicker.Control>
        <DatePicker.Trigger
          aria-label={`Mở lịch — ${label}`}
          aria-invalid={Boolean(error)}
          aria-describedby={`${valueId}${error ? ` ${errorId}` : ""}`}
          // The Atlas calendar trigger recipe is an icon target for day inputs.
          // This complete range is the field, so it fills the control at all widths.
          css={{ "&[data-part=trigger]": { width: "full" } }}
          h={atlasWorkbarControlHeight}
          minH={atlasWorkbarControlHeight}
          justifyContent="space-between"
          gap="sm"
          px="sm"
          bg="bg.workbench"
          textStyle="body"
          fontWeight="normal"
          _hover={{ bg: "bg.workbench", borderColor: "border.interactive" }}
        >
          <Text as="span" id={valueId} whiteSpace="nowrap">
            {rangeText}
          </Text>
          <CalendarBlank aria-hidden="true" />
        </DatePicker.Trigger>
      </DatePicker.Control>
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
