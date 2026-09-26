// Approved candidate remains PR286. Protected variables pin its freshly built
// immutable deployment; its head must contain the certified backend commit.
export function assertPlanningPreview({
  url,
  sha,
  requiredSha,
  prHead,
  comparison,
  manifest,
}) {
  if (
    !/^https:\/\/[a-f0-9]{8}\.thuonghao-ops-erp\.pages\.dev\/$/.test(
      url ?? "",
    ) ||
    !/^[a-f0-9]{40}$/.test(sha ?? "") ||
    !/^[a-f0-9]{40}$/.test(requiredSha ?? "") ||
    prHead !== sha ||
    !["ahead", "identical"].includes(comparison?.status) ||
    comparison?.merge_base_commit?.sha !== requiredSha ||
    manifest?.schema !== "atlas-planning-preview.v1" ||
    manifest.commit !== sha ||
    manifest.dirty !== false ||
    manifest.entrypoint !== "AtlasVNextConnectedApp" ||
    manifest.supabaseOrigin !== "https://rnzxmxiiqgtdevzregff.supabase.co"
  )
    throw new Error("PLANNING_PREVIEW_PROVENANCE_REJECTED");
  return {
    url,
    commit: sha,
    requiredMainCommit: requiredSha,
    approvedCandidate: 286,
  };
}

export async function verifyPlanningPreview({
  environment = process.env,
  requiredSha,
  fetchImpl = fetch,
}) {
  const url = environment.ATLAS_PLANNING_PREVIEW_URL;
  const sha = environment.ATLAS_PLANNING_PREVIEW_SHA;
  if (
    !/^https:\/\/[a-f0-9]{8}\.thuonghao-ops-erp\.pages\.dev\/$/.test(
      url ?? "",
    ) ||
    !/^[a-f0-9]{40}$/.test(sha ?? "") ||
    !/^[a-f0-9]{40}$/.test(requiredSha ?? "") ||
    !environment.GITHUB_TOKEN
  )
    throw new Error("PLANNING_PREVIEW_PROVENANCE_CONFIGURATION_REQUIRED");
  const get = async (address, headers = {}) => {
    const result = await fetchImpl(address, {
      headers,
      redirect: "error",
      signal: AbortSignal.timeout(15000),
    });
    if (!result.ok) throw new Error("PLANNING_PREVIEW_PROVENANCE_FETCH_FAILED");
    return result.json();
  };
  const headers = {
    Authorization: `Bearer ${environment.GITHUB_TOKEN}`,
    Accept: "application/vnd.github+json",
  };
  const api = "https://api.github.com/repos/longpsu-bot/thuonghao-ops-erp";
  const [pr, comparison, manifest] = await Promise.all([
    get(`${api}/pulls/286`, headers),
    get(`${api}/compare/${requiredSha}...${sha}`, headers),
    get(`${url}_atlas-build.json`),
  ]);
  return assertPlanningPreview({
    url,
    sha,
    requiredSha,
    prHead: pr.head?.sha,
    comparison,
    manifest,
  });
}
