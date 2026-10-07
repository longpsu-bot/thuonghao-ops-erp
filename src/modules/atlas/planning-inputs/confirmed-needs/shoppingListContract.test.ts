import { expect, it } from "vitest";
import schema from "../../../../../docs/xlsx/atlas-shopping-list-xlsx-v1.schema.json";
import { shoppingListContract as c } from "./shoppingListContract";
it("production V2 constants conform to the Owner-approved structural amendment", () => {
  const layout = schema["x-atlas-layout"];
  for (const key of [
    "visibleHeaders",
    "hiddenHeaders",
    "metadataSheet",
    "metadataState",
    "headerRow",
    "firstDataRow",
    "lastColumn",
    "editableColumns",
    "paper",
    "orientation",
    "printAreaColumns",
    "printTitleRows",
    "font",
    "bodyHeightClasses",
    "maxServiceDates",
    "partialImport",
    "importWrites",
    "legacyAccepted",
    "protectedSort",
    "protectionPassword",
    "print",
  ] as const)
    expect(c[key]).toEqual(layout[key]);
  expect(c.metadataKeys).toEqual(schema.properties.metadata.required);
  expect(c.dailyKeys).toEqual(schema.properties.daily_batches.items.required);
  expect(c.contractName).toBe(
    schema.properties.metadata.properties.contract_name.const,
  );
  expect(c.contractVersion).toBe(
    schema.properties.metadata.properties.contract_version.const,
  );
  expect(c.resourceLimits).toEqual(schema["x-atlas-resource-limits"]);
  expect(c.geometryVariant).toBe(
    schema.properties.metadata.properties.geometry_variant.const,
  );
});
