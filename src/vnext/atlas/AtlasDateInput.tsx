import { DateInput, parseDate } from "@chakra-ui/react";

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
  return (
    <DateInput.Root
      disabled={disabled}
      locale="vi-VN"
      shouldForceLeadingZeros
      granularity="day"
      value={[parseDate(value)]}
      onValueChange={({ value: dates }) => {
        if (dates[0]) onValueChange(dates[0].toString());
      }}
    >
      <DateInput.Label>{label}</DateInput.Label>
      <DateInput.Control>
        <DateInput.Segments />
      </DateInput.Control>
      <DateInput.HiddenInput />
    </DateInput.Root>
  );
}
