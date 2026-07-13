import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { gzipSync } from "node:zlib";

const [outputDirectory, launcherName, portValue] = process.argv.slice(2);
const port = Number(portValue);

if (!outputDirectory || !launcherName || !Number.isInteger(port)) {
  throw new Error(
    "Usage: node scripts/create-review-launcher.mjs <directory> <launcher-name> <port>",
  );
}

const serverScript = `
$ErrorActionPreference = 'Stop'
$port = ${port}
$rootPath = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\\') + '\\'
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$port/"
$listener.Prefixes.Add($prefix)

try {
  $listener.Start()
} catch {
  Write-Host "Port $port is already in use. Close the previous preview window and try again." -ForegroundColor Yellow
  exit 1
}

Start-Process $prefix
Write-Host "Preview opened at $prefix"
Write-Host "Keep this window open while reviewing. Close it to stop the preview."

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/')).Replace('/', '\\')
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
      $relativePath = 'index.html'
    }

    $filePath = [IO.Path]::GetFullPath((Join-Path $rootPath $relativePath))
    if (-not $filePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
      $context.Response.StatusCode = 404
      $context.Response.Close()
      continue
    }

    $contentType = switch ([IO.Path]::GetExtension($filePath).ToLowerInvariant()) {
      '.css' { 'text/css; charset=utf-8' }
      '.gif' { 'image/gif' }
      '.html' { 'text/html; charset=utf-8' }
      '.ico' { 'image/x-icon' }
      '.jpg' { 'image/jpeg' }
      '.jpeg' { 'image/jpeg' }
      '.js' { 'text/javascript; charset=utf-8' }
      '.json' { 'application/json; charset=utf-8' }
      '.map' { 'application/json; charset=utf-8' }
      '.mjs' { 'text/javascript; charset=utf-8' }
      '.png' { 'image/png' }
      '.svg' { 'image/svg+xml' }
      '.ttf' { 'font/ttf' }
      '.webp' { 'image/webp' }
      '.woff' { 'font/woff' }
      '.woff2' { 'font/woff2' }
      default { 'application/octet-stream' }
    }

    $bytes = [IO.File]::ReadAllBytes($filePath)
    $context.Response.ContentType = $contentType
    $context.Response.ContentLength64 = $bytes.Length
    if ($context.Request.HttpMethod -ne 'HEAD') {
      $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    $context.Response.Close()
  }
} finally {
  if ($listener.IsListening) {
    $listener.Stop()
  }
  $listener.Close()
}
`.trim();

const compressedServerScript = gzipSync(
  Buffer.from(serverScript, "utf8"),
).toString("base64");
const launcher = `@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$bytes = [Convert]::FromBase64String('${compressedServerScript}'); $inputStream = [IO.MemoryStream]::new($bytes); $gzipStream = [IO.Compression.GzipStream]::new($inputStream, [IO.Compression.CompressionMode]::Decompress); $reader = [IO.StreamReader]::new($gzipStream); Invoke-Expression $reader.ReadToEnd()"\r\nif errorlevel 1 pause\r\n`;
const launcherPath = resolve(outputDirectory, launcherName);

await mkdir(dirname(launcherPath), { recursive: true });
await writeFile(launcherPath, launcher, "utf8");
