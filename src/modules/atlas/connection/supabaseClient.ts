import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  readAtlasBrowserEnvironment,
  type AtlasEnvironmentResult,
} from "./environment";

export type AtlasSupabaseClientResult =
  | { status: "configured"; client: SupabaseClient }
  | { status: "configuration_error"; safeMessage: string };

export const ATLAS_SUPABASE_CLIENT_OPTIONS = {
  db: { retry: false },
} as const;

type ClientFactory = (
  url: string,
  publishableKey: string,
  options: typeof ATLAS_SUPABASE_CLIENT_OPTIONS,
) => SupabaseClient;

const defaultClientFactory: ClientFactory = (url, publishableKey, options) =>
  createClient(url, publishableKey, options as never);

export function createAtlasSupabaseClient(
  environment: AtlasEnvironmentResult,
  factory: ClientFactory = defaultClientFactory,
): AtlasSupabaseClientResult {
  if (environment.status === "configuration_error") return environment;

  return {
    status: "configured",
    client: factory(
      environment.config.supabaseUrl,
      environment.config.publishableKey,
      ATLAS_SUPABASE_CLIENT_OPTIONS,
    ),
  };
}

let browserClient: AtlasSupabaseClientResult | undefined;

export function getAtlasSupabaseClient(): AtlasSupabaseClientResult {
  browserClient ??= createAtlasSupabaseClient(readAtlasBrowserEnvironment());
  return browserClient;
}
