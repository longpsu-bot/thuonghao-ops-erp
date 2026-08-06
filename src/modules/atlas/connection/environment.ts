const ATLAS_ENVIRONMENT_VARIABLE = "VITE_ATLAS_ENVIRONMENT";
const SUPABASE_URL_VARIABLE = "VITE_SUPABASE_URL";
const SUPABASE_KEY_VARIABLE = "VITE_SUPABASE_PUBLISHABLE_KEY";
const LIVE_OPS_PROJECT_REF = "qnthofvccilhnefdcxnz";

const SAFE_CONFIGURATION_MESSAGE =
  "Cấu hình kết nối Atlas chưa hợp lệ. Vui lòng liên hệ bộ phận hỗ trợ trước khi tiếp tục.";

export type AtlasEnvironmentName = "local" | "staging";

export type AtlasBrowserEnvironment = {
  environment: AtlasEnvironmentName;
  supabaseUrl: string;
  publishableKey: string;
  projectRef?: string;
  environmentLabel: "Local · non-production" | "Atlas staging · non-production";
};

export type AtlasEnvironmentResult =
  | { status: "configured"; config: AtlasBrowserEnvironment }
  | { status: "configuration_error"; safeMessage: string };

type EnvironmentSource = Partial<Record<string, unknown>>;

function configurationError(): AtlasEnvironmentResult {
  return {
    status: "configuration_error",
    safeMessage: SAFE_CONFIGURATION_MESSAGE,
  };
}

function textValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function isLocalHost(hostname: string): boolean {
  return hostname === "127.0.0.1" || hostname === "localhost";
}

function decodeJwtPayload(value: string): Record<string, unknown> | null {
  const parts = value.split(".");
  if (parts.length !== 3) return null;
  try {
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const binary = atob(padded);
    const bytes = new Uint8Array(
      binary.split("").map((character) => character.charCodeAt(0)),
    );
    const payload: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return payload && typeof payload === "object"
      ? (payload as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

function isBrowserSafeKey(
  value: string,
  environment: AtlasEnvironmentName,
): boolean {
  if (/\s/.test(value) || value.startsWith("sb_secret_")) return false;
  if (value.startsWith("sb_publishable_") && value.length > 20) return true;

  const payload = decodeJwtPayload(value);
  if (payload) return payload.role === "anon";

  // Preserve existing disposable local aliases only in local mode.
  return environment === "local" && /^[A-Za-z0-9_-]{8,}$/.test(value);
}

function hasUnrelatedBrowserCredential(source: EnvironmentSource): boolean {
  return Object.entries(source).some(
    ([name, value]) =>
      name.startsWith("VITE_") &&
      name !== ATLAS_ENVIRONMENT_VARIABLE &&
      name !== SUPABASE_URL_VARIABLE &&
      name !== SUPABASE_KEY_VARIABLE &&
      /(SERVICE_ROLE|SECRET|ACCESS_TOKEN|DB_PASSWORD|TEST_PASSWORD)/i.test(
        name,
      ) &&
      textValue(value),
  );
}

function stagingProjectRef(hostname: string): string | null {
  const match = /^([a-z0-9]{20})\.supabase\.co$/i.exec(hostname);
  return match?.[1].toLowerCase() ?? null;
}

export function readAtlasBrowserEnvironment(
  source: EnvironmentSource = import.meta.env,
): AtlasEnvironmentResult {
  const environment = textValue(source.VITE_ATLAS_ENVIRONMENT);
  const supabaseUrl = textValue(source.VITE_SUPABASE_URL);
  const publishableKey = textValue(source.VITE_SUPABASE_PUBLISHABLE_KEY);

  if (
    (environment !== "local" && environment !== "staging") ||
    !supabaseUrl ||
    !publishableKey ||
    hasUnrelatedBrowserCredential(source) ||
    !isBrowserSafeKey(publishableKey, environment)
  ) {
    return configurationError();
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(supabaseUrl);
  } catch {
    return configurationError();
  }

  if (parsedUrl.username || parsedUrl.password) return configurationError();

  if (environment === "local") {
    if (
      !["http:", "https:"].includes(parsedUrl.protocol) ||
      !isLocalHost(parsedUrl.hostname)
    ) {
      return configurationError();
    }
    return {
      status: "configured",
      config: {
        environment,
        supabaseUrl: parsedUrl.origin,
        publishableKey,
        environmentLabel: "Local · non-production",
      },
    };
  }

  const projectRef = stagingProjectRef(parsedUrl.hostname);
  if (
    parsedUrl.protocol !== "https:" ||
    isLocalHost(parsedUrl.hostname) ||
    !projectRef ||
    projectRef === LIVE_OPS_PROJECT_REF
  ) {
    return configurationError();
  }

  return {
    status: "configured",
    config: {
      environment,
      supabaseUrl: parsedUrl.origin,
      publishableKey,
      projectRef,
      environmentLabel: "Atlas staging · non-production",
    },
  };
}
