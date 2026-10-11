import { fileURLToPath } from "node:url";
import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";

export const FRONTEND_CERTIFICATION_COMMANDS = Object.freeze([
  Object.freeze(["install", "--frozen-lockfile"]),
  Object.freeze(["ui:vnext:check"]),
  Object.freeze(["ui:vnext:typegen"]),
  Object.freeze(["format"]),
  Object.freeze(["typecheck"]),
  Object.freeze(["test"]),
  Object.freeze(["build"]),
]);

export function certifyFrontend({
  cwd = process.cwd(),
  environment = process.env,
  runCommand = defaultCommandRunner,
} = {}) {
  for (const args of FRONTEND_CERTIFICATION_COMMANDS) {
    console.log(`Frontend certification: pnpm ${args.join(" ")}`);
    const result = runCommand("pnpm", args, {
      cwd,
      env: environment,
      maxBuffer: 32 * 1024 * 1024,
    });
    if (result.status !== 0) {
      const lines = redactAtlasStagingDiagnostic(
        `${result.errorCode || result.signal ? `Subprocess: ${result.errorCode ?? "no error code"}; signal: ${result.signal ?? "none"}\n` : ""}${result.stdout ?? ""}\n${result.stderr ?? ""}`,
      )
        .replace(/\u001b\[[0-9;]*m/g, "")
        .split(/\r?\n/);
      const failureSummary = lines.filter((line) =>
        /\bFAIL\s|\bTest Files\b|\bTests\s+\d|\bErrors\s+\d|^Subprocess:|^\s*(?:[A-Za-z]*Error:|Expected\b|Received\b|[+-] (?:Expected|Received)\b)/.test(
          line,
        ),
      );
      const diagnostic = [...failureSummary, ...lines.slice(-120)]
        .join("\n")
        .trim();
      throw new Error(
        `Frontend certification failed at pnpm ${args.join(" ")}.${diagnostic ? `\n${diagnostic}` : ""}`,
      );
    }
  }
  return { status: "certified", commands: FRONTEND_CERTIFICATION_COMMANDS };
}

function main() {
  certifyFrontend();
  console.log("Frontend certification passed.");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    main();
  } catch (error) {
    console.error(
      error instanceof Error
        ? error.message
        : "Frontend certification failed safely.",
    );
    process.exitCode = 1;
  }
}
