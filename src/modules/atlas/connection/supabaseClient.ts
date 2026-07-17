import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  readAtlasBrowserEnvironment,
  type AtlasEnvironmentResult,
} from "./environment";

export type AtlasSupabaseClientResult =
  | { status: "configured"; client: SupabaseClient }
  | { status: "configuration_error"; safeMessage: string };

type ClientFactory = (url: string, publishableKey: string) => SupabaseClient;

export function createAtlasSupabaseClient(
  environment: AtlasEnvironmentResult,
  factory: ClientFactory = createClient,
): AtlasSupabaseClientResult {
  if (environment.status === "configuration_error") return environment;

  return {
    status: "configured",
    client: factory(
      environment.config.supabaseUrl,
      environment.config.publishableKey,
    ),
  };
}

let browserClient: AtlasSupabaseClientResult | undefined;

export function getAtlasSupabaseClient(): AtlasSupabaseClientResult {
  browserClient ??= createAtlasSupabaseClient(readAtlasBrowserEnvironment());
  return browserClient;
}
