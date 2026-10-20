// Readiness for a newly reset disposable PostgREST instance. Never wrap writes
// or ongoing journey reads: business failures must retain normal handling.
export function readAfterSchemaCacheStarts(read, until) {
  return until(async () => {
    const response = await read();
    return response.status === 503 && response.error?.code === "PGRST002"
      ? null
      : response;
  }, "INITIAL_SCHEMA_CACHE_READY");
}
