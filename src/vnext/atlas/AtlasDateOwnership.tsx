import { useDatePickerContext } from "@chakra-ui/react";
import { useLayoutEffect } from "react";
import { useAtlasWorkbenchActive } from "./AtlasVNextProvider";

export function AtlasDismissInactiveCalendar() {
  const active = useAtlasWorkbenchActive();
  const picker = useDatePickerContext();
  useLayoutEffect(() => {
    if (!active && picker.open) picker.setOpen(false);
  }, [active, picker]);
  return null;
}
