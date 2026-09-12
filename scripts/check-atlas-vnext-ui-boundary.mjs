import { readdirSync, readFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// No exceptions currently. New exceptions require an explicit Product decision.
const chakraSupportFiles = new Set();
// Exact extensionless modules, reviewed for business-only dependencies before
// adding a bridge. Master-data vNext imports only request builders, models, types,
// and safe copy; legacy Admin presentation remains forbidden.
const approvedLegacyBusinessModules = [
  "src/modules/atlas/master-data/masterDataApi",
  "src/modules/atlas/master-data/masterDataModel",
  "src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi",
  "src/modules/atlas/dispatch/schoolFulfilmentReconciliationModel",
  "src/modules/atlas/dispatch/schoolDispatchReleaseApi",
  "src/modules/atlas/dispatch/schoolDispatchReleaseModel",
  "src/modules/atlas/planning-inputs/readiness/planningInputReadinessApi",
  "src/modules/atlas/planning-inputs/readiness/planningInputReadinessModel",
  "src/modules/atlas/planning-inputs/need-generation/needGenerationApi",
  "src/modules/atlas/planning-inputs/need-generation/needGenerationModel",
  "src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi",
  "src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel",
  "src/modules/atlas/planning-inputs/planningInputsApi",
  "src/modules/atlas/planning-inputs/planningInputsModel",
  "src/modules/atlas/planning-inputs/planningInputsWorkbook",
  "src/modules/atlas/planning-inputs/planningCorrectionApi",
  "src/modules/atlas/planning-inputs/planningSchoolScope",
  "src/modules/atlas/planning-inputs/pantry/pantryApi",
  "src/modules/atlas/planning-inputs/pantry/pantryModel",
  "src/modules/atlas/procurement/purchaseReviewApi",
  "src/modules/atlas/procurement/schoolCateringProcurementApi",
  "src/modules/atlas/procurement/schoolCateringProcurementModel",
  "src/modules/atlas/procurement/procurementOperatorCopy",
  "src/modules/atlas/connection/atlasRpc",
];
const sourceExtension = /\.[cm]?[jt]sx?$/;

function imports(source) {
  // Preserve quoted strings while removing comments, including comment examples.
  const clean = source.replace(
    /("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|(\/\*[\s\S]*?\*\/|\/\/[^\r\n]*)/g,
    (match, quoted) => quoted ?? " ".repeat(match.length),
  );
  return Array.from(
    clean.matchAll(
      /(?:\bfrom\s*|\bimport\s*(?:\(\s*)?|\brequire\s*\(\s*)["']([^"']+)["']/g,
    ),
    (match) => match[1],
  );
}

export function checkSources(
  sources,
  approvedBusinessModules = approvedLegacyBusinessModules,
) {
  const errors = [];
  for (const file of Object.keys(sources).sort()) {
    const vnext = file.startsWith("src/vnext/");
    for (const specifier of imports(sources[file])) {
      if (vnext && specifier.startsWith("@mantine/"))
        errors.push(`${file}: vNext cannot import ${specifier}`);
      if (
        (specifier === "@chakra-ui/react" ||
          specifier.startsWith("@chakra-ui/react/")) &&
        !vnext &&
        !chakraSupportFiles.has(file)
      )
        errors.push(`${file}: Chakra belongs under src/vnext/`);
      const clean = specifier.split(/[?#]/)[0];
      const target = clean.startsWith(".")
        ? posix.normalize(posix.join(posix.dirname(file), clean))
        : clean.replace(/^@\//, "src/").replace(/^\//, "");
      if (
        vnext &&
        /^(?:src\/theme(?:\.[cm]?[jt]sx?)?|src\/styles\.css)$/.test(target)
      )
        errors.push(
          `${file}: legacy presentation authority ${specifier} is forbidden`,
        );
      else if (
        vnext &&
        target.startsWith("src/") &&
        !target.startsWith("src/vnext/") &&
        !(
          file.startsWith("src/vnext/atlas/bridges/") &&
          approvedBusinessModules.includes(target.replace(sourceExtension, ""))
        )
      )
        errors.push(
          `${file}: legacy import ${specifier} requires an approved business-only bridge`,
        );
    }
  }
  return errors;
}

export function checkRepository(root = process.cwd()) {
  const sources = {};
  function visit(directory) {
    for (const entry of readdirSync(resolve(root, directory), {
      withFileTypes: true,
    })) {
      const file = `${directory}/${entry.name}`;
      if (entry.isDirectory()) visit(file);
      else if (sourceExtension.test(file))
        sources[file] = readFileSync(resolve(root, file), "utf8");
    }
  }
  visit("src");
  visit(".storybook");
  return checkSources(sources);
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const errors = checkRepository();
  if (errors.length) {
    console.error(errors.join("\n"));
    process.exitCode = 1;
  } else console.log("Atlas vNext UI boundary passed.");
}
