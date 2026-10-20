import { Box, Text } from "@chakra-ui/react";

/** Repeats existing row facts beside a narrow-screen quantity; never derives quantities. */
export function AtlasQuantityContext({
  id,
  recipient,
  location,
  ingredient,
  unit,
  date,
  source,
}: {
  id?: string;
  recipient?: string;
  location?: string;
  ingredient?: string;
  unit?: string;
  date?: string;
  source?: string;
}) {
  return (
    <Box
      id={id}
      hideFrom="md"
      mb="xs"
      data-quantity-context=""
      textAlign="start"
      whiteSpace="normal"
      overflowWrap="anywhere"
    >
      <Text fontWeight="semibold">
        {[recipient, ingredient].filter(Boolean).join(" · ")}
      </Text>
      <Text textStyle="helper" color="fg.muted">
        {[location, date?.split("-").reverse().join("/"), source, unit]
          .filter(Boolean)
          .join(" · ")}
      </Text>
    </Box>
  );
}
