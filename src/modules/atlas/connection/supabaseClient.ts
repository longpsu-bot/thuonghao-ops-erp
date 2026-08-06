import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  readAtlasBrowserEnvironment,
  type AtlasBrowserEnvironment,
  type AtlasEnvironmentResult,
} from "./environment";

export type AtlasSupabaseClientResult =
  | {
      status: "configured";
      client: SupabaseClient;
      environmentLabel: AtlasBrowserEnvironment["environmentLabel"];
    }
  | { status: "configuration_error"; safeMessage: string };

type SupabaseCreateClientOptions = NonNullable<
  Parameters<typeof createClient>[2]
>;
type SupabaseCreateClientDbOptions = NonNullable<
  SupabaseCreateClientOptions["db"]
>;
type AtlasSupabaseClientOptions = Omit<SupabaseCreateClientOptions, "db"> & {
  db: Omit<SupabaseCreateClientDbOptions, "schema"> & {
    schema?: "public";
    retry: false;
  };
};

export const ATLAS_SUPABASE_CLIENT_OPTIONS = {
  db: { retry: false },
} satisfies AtlasSupabaseClientOptions;

type ClientFactory = (
  url: string,
  publishableKey: string,
  options: AtlasSupabaseClientOptions,
) => SupabaseClient;

const defaultClientFactory: ClientFactory = (url, publishableKey, options) =>
  createClient(url, publishableKey, options);

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
    environmentLabel: environment.config.environmentLabel,
  };
}

let browserClient: AtlasSupabaseClientResult | undefined;

export function getAtlasSupabaseClient(): AtlasSupabaseClientResult {
  browserClient ??= createAtlasSupabaseClient(readAtlasBrowserEnvironment());
  return browserClient;
}
