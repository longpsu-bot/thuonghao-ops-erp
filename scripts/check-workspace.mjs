import { execFileSync } from "node:child_process";
import path from "node:path";
import process from "node:process";

const EXPECTED_REPO = "longpsu-bot/thuonghao-ops-erp";
const EXPECTED_WINDOWS_PATH = "D:/Project/Repo/OPS/thuonghao-ops-erp";

function runGit(args) {
  try {
    return execFileSync("git", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    const message = error.stderr?.toString().trim() || error.message;
    throw new Error(`git ${args.join(" ")} failed: ${message}`);
  }
}

function normalize(value) {
  return value.replaceAll("\\", "/").replace(/\/$/, "").toLowerCase();
}

function remoteMatches(remote) {
  const normalized = normalize(remote).replace(/\.git$/, "");
  return (
    normalized === `https://github.com/${EXPECTED_REPO}` ||
    normalized === `git@github.com:${EXPECTED_REPO}` ||
    normalized.endsWith(`/github.com/${EXPECTED_REPO}`)
  );
}

const gitRoot = runGit(["rev-parse", "--show-toplevel"]);
const origin = runGit(["config", "--get", "remote.origin.url"]);
const branch = runGit(["branch", "--show-current"]);
const status = runGit(["status", "--short"]);

const normalizedRoot = normalize(gitRoot);
const normalizedExpectedPath = normalize(EXPECTED_WINDOWS_PATH);
const errors = [];
const warnings = [];

if (path.basename(gitRoot) !== "thuonghao-ops-erp") {
  errors.push(`Git root folder should be thuonghao-ops-erp, got: ${gitRoot}`);
}

if (!remoteMatches(origin)) {
  errors.push(`remote.origin.url should point to ${EXPECTED_REPO}, got: ${origin}`);
}

if (normalizedRoot.includes("/onedrive/")) {
  warnings.push(
    "Git root is inside OneDrive. Use the canonical project repo folder unless this is intentional.",
  );
}

if (process.platform === "win32" && normalizedRoot !== normalizedExpectedPath) {
  warnings.push(`Canonical user repo path is ${EXPECTED_WINDOWS_PATH}; current root is ${gitRoot}.`);
}

console.log("OPS workspace check");
console.log(`- git root: ${gitRoot}`);
console.log(`- origin: ${origin}`);
console.log(`- branch: ${branch || "(detached HEAD)"}`);
console.log(`- working tree: ${status ? "has changes" : "clean"}`);

for (const warning of warnings) {
  console.warn(`warning: ${warning}`);
}

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`error: ${error}`);
  }
  process.exit(1);
}
