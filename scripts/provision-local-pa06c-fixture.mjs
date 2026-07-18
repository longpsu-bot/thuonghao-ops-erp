import { fileURLToPath } from "node:url";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

function localFile(relativePath) {
  return fileURLToPath(new URL(relativePath, import.meta.url));
}

function provisionFixture() {
  readLocalSupabaseStatus();
  runPinnedSupabase(
    [
      "db",
      "query",
      "--local",
      "--file",
      localFile("../supabase/local/pa_06c_supplier_evidence_fixture.sql"),
    ],
    { stdio: "inherit" },
  );
  runPinnedSupabase(
    [
      "db",
      "query",
      "--local",
      "--file",
      localFile(
        "../supabase/local/pa_06c_supplier_evidence_fixture_assertion.sql",
      ),
    ],
    { stdio: "inherit" },
  );
  console.log("Provisioned and asserted deterministic PA-06C local fixture.");
}

try {
  provisionFixture();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "PA-06C local fixture provisioning failed safely.",
  );
  process.exitCode = 1;
}
