import { randomBytes, createHash } from "node:crypto";
import { open, readFile, unlink } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline/promises";

const repository = "longpsu-bot/thuonghao-ops-erp";
const environment = "atlas-staging";
const spreadsheetId = "1kSNc69C-Fe7QYjmbwYiCL6Kf01r2dsvonRIC7qn2urI";
export function validWebAppUrl(value) {
  try {
    const u = new URL(value);
    return (
      u.protocol === "https:" &&
      u.hostname === "script.google.com" &&
      !u.port &&
      !u.username &&
      !u.password &&
      !u.search &&
      !u.hash &&
      /^\/macros\/s\/[A-Za-z0-9_-]+\/exec$/.test(u.pathname)
    );
  } catch {
    return false;
  }
}
export async function prepareInstall({
  directory,
  webAppUrl,
  run = spawnSync,
  randomSecret = () => randomBytes(32).toString("hex"),
}) {
  if (!validWebAppUrl(webAppUrl)) throw new Error("WEBAPP_URL_INVALID");
  const options = {
    encoding: "utf8",
    shell: false,
    stdio: ["pipe", "pipe", "pipe"],
  };
  if (
    run("gh", ["auth", "status", "--hostname", "github.com"], options)
      .status !== 0
  )
    throw new Error("GITHUB_AUTH_REQUIRED");
  const list = run(
    "gh",
    [
      "secret",
      "list",
      "--repo",
      repository,
      "--env",
      environment,
      "--json",
      "name",
    ],
    options,
  );
  if (list.status !== 0) throw new Error("GITHUB_ENVIRONMENT_ACCESS_REQUIRED");
  let names;
  try {
    names = JSON.parse(list.stdout || "[]");
  } catch {
    throw new Error("GITHUB_SECRET_METADATA_INVALID");
  }
  if (!Array.isArray(names)) throw new Error("GITHUB_SECRET_METADATA_INVALID");
  const path = join(directory, "AtlasWeeklyMenuConfig.gs");
  try {
    await readFile(path);
    throw new Error("OUTPUT_EXISTS");
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  if (names.some((item) => item.name === "ATLAS_WEEKLY_MENU_WEBAPP_SECRET"))
    throw new Error("READER_SECRET_ALREADY_EXISTS");
  const secret = randomSecret();
  if (!/^[a-f0-9]{64}$/.test(secret))
    throw new Error("INVALID_GENERATED_SECRET");
  const digest = createHash("sha256").update(secret, "utf8").digest("hex");
  const text =
    "// Instance configuration: digest only, no plaintext credential.\n" +
    "function atlasWeeklyMenuDeploymentConfig_() {\n" +
    `  return ${JSON.stringify({ spreadsheetId, secretSha256: digest }, null, 2)};\n}\n`;
  let handle;
  try {
    handle = await open(path, "wx", 0o600);
  } catch {
    throw new Error("OUTPUT_EXISTS");
  }
  let installed = false;
  try {
    // URL first, then credential. No token appears in command arguments or output.
    const set = (name, value) =>
      run(
        "gh",
        ["secret", "set", name, "--repo", repository, "--env", environment],
        { ...options, input: value },
      );
    if (set("ATLAS_WEEKLY_MENU_WEBAPP_URL", webAppUrl).status !== 0)
      throw new Error("WEBAPP_URL_SECRET_INSTALL_FAILED");
    if (set("ATLAS_WEEKLY_MENU_WEBAPP_SECRET", secret).status !== 0)
      throw new Error("READER_SECRET_INSTALL_FAILED");
    installed = true;
    await handle.writeFile(text, "utf8");
    await handle.sync();
  } catch (error) {
    // Keep the digest file if the remote secret was installed: it is the only
    // non-secret counterpart needed to recover without replacing credentials.
    if (installed) {
      try {
        await handle.writeFile(text, "utf8");
      } catch {}
    } else {
      await handle.close();
      handle = null;
      await unlink(path);
    }
    throw error;
  } finally {
    if (handle) await handle.close();
  }
  return { configured: true, configFile: path, repository, environment };
}
async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 0 && !(args.length === 2 && args[0] === "--webapp-url"))
    throw new Error("INVALID_ARGUMENTS");
  const terminal = createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  try {
    const url =
      args[1] ??
      (
        await terminal.question(
          "Paste the EXISTING Weekly Menu Web App URL ending /exec: ",
        )
      ).trim();
    const result = await prepareInstall({
      directory: dirname(fileURLToPath(import.meta.url)),
      webAppUrl: url,
    });
    console.log(
      "Reader credential installed in GitHub atlas-staging. No live application was deployed.",
    );
    console.log(`Generated: ${result.configFile}`);
    console.log(
      "Next: add the reader and generated config to Apps Script, insert the two router lines, then update the SAME Web App deployment to a new version. See START-HERE.md.",
    );
  } finally {
    terminal.close();
  }
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main().catch((error) => {
    console.error(
      error instanceof Error && /^[A-Z_]+$/.test(error.message)
        ? error.message
        : "INSTALL_PREPARATION_FAILED",
    );
    process.exitCode = 1;
  });
