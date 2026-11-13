import { Button, type ButtonProps } from "@chakra-ui/react";
import { FileArrowUp } from "@phosphor-icons/react";
import { useRef } from "react";

export function AtlasXlsxPicker({
  inputLabel,
  onFile,
  children,
  disabled,
  ...buttonProps
}: Omit<ButtonProps, "onClick"> & {
  inputLabel: string;
  onFile: (file: File) => void;
}) {
  const input = useRef<HTMLInputElement>(null);
  return (
    <>
      <Button
        {...buttonProps}
        type="button"
        disabled={disabled}
        onClick={() => input.current?.click()}
      >
        <FileArrowUp aria-hidden="true" />
        {children}
      </Button>
      <input
        ref={input}
        hidden
        type="file"
        accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        aria-label={inputLabel}
        disabled={disabled}
        onChange={(event) => {
          const file = event.currentTarget.files?.[0];
          event.currentTarget.value = "";
          if (file && !disabled) onFile(file);
        }}
      />
    </>
  );
}
