/** Staff may use catalogue/document codes. Imported keys and audit identifiers are internal. */
export function staffReference(value: string | null | undefined) {
  const text = value?.trim();
  if (
    !text ||
    /\b[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}\b|\b[\da-f]{32,}\b|^(?:v1[-_:]|atlas[-_:]|unit[-_:])/i.test(
      text,
    )
  )
    return null;
  return text;
}
