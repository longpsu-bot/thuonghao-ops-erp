const SUPABASE_URL_VARIABLE = "VITE_SUPABASE_URL";
const SUPABASE_KEY_VARIABLE = "VITE_SUPABASE_PUBLISHABLE_KEY";

export type AtlasBrowserEnvironment = {
  supabaseUrl: string;
  publishableKey: string;
  environmentLabel: "Local · non-production";
};

export type AtlasEnvironmentResult =
  | { status: "configured"; config: AtlasBrowserEnvironment }
  | { status: "configuration_error"; safeMessage: string };

type EnvironmentSource = Partial<
  Record<typeof SUPABASE_URL_VARIABLE | typeof SUPABASE_KEY_VARIABLE, unknown>
>;

function textValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function isLocalHost(hostname: string): boolean {
  return hostname === "127.0.0.1" || hostname === "localhost";
}

export function readAtlasBrowserEnvironment(
  source: EnvironmentSource = import.meta.env,
): AtlasEnvironmentResult {
  const supabaseUrl = textValue(source.VITE_SUPABASE_URL);
  const publishableKey = textValue(source.VITE_SUPABASE_PUBLISHABLE_KEY);

  if (!supabaseUrl || !publishableKey) {
    return {
      status: "configuration_error",
      safeMessage:
        "Local Supabase connection settings are missing. Configure the documented browser-safe URL and publishable key.",
    };
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(supabaseUrl);
  } catch {
    return {
      status: "configuration_error",
      safeMessage:
        "The local Supabase URL is invalid. Check the documented local environment settings.",
    };
  }

  if (
    !["http:", "https:"].includes(parsedUrl.protocol) ||
    !isLocalHost(parsedUrl.hostname) ||
    parsedUrl.username ||
    parsedUrl.password
  ) {
    return {
      status: "configuration_error",
      safeMessage:
        "PA-06B accepts only a valid local Supabase HTTP(S) URL. Hosted or credential-bearing URLs are not allowed.",
    };
  }

  return {
    status: "configured",
    config: {
      supabaseUrl: parsedUrl.origin,
      publishableKey,
      environmentLabel: "Local · non-production",
    },
  };
}
