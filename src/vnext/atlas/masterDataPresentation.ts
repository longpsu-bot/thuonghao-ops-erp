export function operatorMasterReference(code: string) {
  const reference = code.trim();
  return /^v1-/i.test(reference) ? null : reference || null;
}

export function operatorUnitLabel(unit: {
  unit_code: string;
  unit_name: string;
}) {
  return operatorMasterReference(unit.unit_code) ?? unit.unit_name;
}
