// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import { createGoogleSyncHandler } from "./index";

const sourceId = "a1000000-0000-4000-8000-000000000001";
const correlationId = "a1000000-0000-4000-8000-000000000002";
const authorization = "Bearer test-atlas-jwt";
const source = {
  weekly_menu_google_source_id: sourceId,
  source_code: "synthetic-menu",
  source_name: "Synthetic weekly menu",
  spreadsheet_id: "synthetic-spreadsheet",
  sheet_name_pattern: "Tuần {DD-MM-YYYY}",
  range_a1_template: "'{sheet}'!A3:I500",
  source_status: "ACTIVE",
  display_order: 1,
  version: 1,
};

function request(body: Record<string, unknown> = {}) {
  return new Request(
    "http://localhost/functions/v1/atlas-weekly-menu-google-sync",
    {
      method: "POST",
      headers: {
        Authorization: authorization,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        weekly_menu_google_source_id: sourceId,
        week_start: "2026-07-27",
        correlation_id: correlationId,
        ...body,
      }),
    },
  );
}

function environment(hasCredential = true) {
  const values: Record<string, string> = {
    SUPABASE_URL: "http://supabase.test",
    SUPABASE_ANON_KEY: "test-browser-key",
  };
  values.GOOGLE_APPS_SCRIPT_WEBAPP_URL =
    "https://script.google.com/macros/s/synthetic-deployment/exec";
  if (hasCredential) values.GOOGLE_APPS_SCRIPT_SECRET = "test-webapp-secret";
  return { get: (name: string) => values[name] };
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function successfulFetch(
  googleResponse: Response = json({
    success: true,
    contract_version: "ATLAS-WEEKLY-MENU-READ.v1",
    request_id: correlationId,
    week_start: "2026-07-27",
    spreadsheet_id: source.spreadsheet_id,
    sheet_name: "Tuần 27-07-2026",
    range: "'Tuần 27-07-2026'!A3:I500",
    rows: [
      ["Tên trường", "Ngày", "Món canh"],
      ["school-a", "2026-07-27", "dish-a"],
    ],
  }),
) {
  return vi.fn<typeof fetch>(async (input) => {
    const url = String(input);
    if (url.endsWith("/auth/v1/user")) return json({ id: "user-1" });
    if (url.includes("/rpc/get_planning_inputs_workbench"))
      return json({ success: true, google_connector_source: source });
    if (url.startsWith("https://script.google.com/")) return googleResponse;
    throw new Error(`Unexpected fetch: ${url}`);
  });
}

function handler(fetchMock = successfulFetch(), hasCredential = true) {
  return {
    fetchMock,
    handle: createGoogleSyncHandler({
      fetch: fetchMock,
      env: environment(hasCredential),
      now: () => new Date("2026-07-27T03:00:00.000Z"),
    }),
  };
}

describe("atlas-weekly-menu-google-sync", () => {
  it.each(["auth", "atlas"] as const)(
    "classifies temporary %s outages without inventing session or source failures",
    async (stage) => {
      for (const status of [429, 500, 503]) {
        const fetchMock = vi.fn<typeof fetch>(async (input) =>
          stage === "atlas" && String(input).endsWith("/auth/v1/user")
            ? json({ id: "user-1" })
            : json({ message: "private upstream detail" }, status),
        );
        const response = await handler(fetchMock).handle(request());
        expect(response.status).toBe(503);
        expect(await response.json()).toMatchObject({
          error_code: "CONNECTOR_UNAVAILABLE",
          retryable: true,
          correlation_id: correlationId,
        });
        expect(fetchMock).toHaveBeenCalledTimes(stage === "auth" ? 1 : 2);
      }
    },
  );

  it.each(["auth", "atlas"] as const)(
    "returns a safe correlated envelope when the %s fetch rejects",
    async (stage) => {
      const fetchMock = vi.fn<typeof fetch>(async (input) => {
        if (stage === "atlas" && String(input).endsWith("/auth/v1/user"))
          return json({ id: "user-1" });
        throw new TypeError("private credential: test-webapp-secret");
      });
      const response = await handler(fetchMock).handle(request());
      expect(response.status).toBe(503);
      const body = await response.json();
      expect(body).toMatchObject({
        error_code: "CONNECTOR_UNAVAILABLE",
        retryable: true,
        correlation_id: correlationId,
      });
      expect(JSON.stringify(body)).not.toContain("test-webapp-secret");
      expect(fetchMock).toHaveBeenCalledTimes(stage === "auth" ? 1 : 2);
    },
  );

  it.each([401, 403])(
    "retains actual Auth HTTP %s rejection",
    async (status) => {
      const response = await handler(
        vi.fn<typeof fetch>(async () => json({}, status)),
      ).handle(request());
      expect(response.status).toBe(401);
      expect(await response.json()).toMatchObject({
        error_code: "SESSION_EXPIRED",
        retryable: false,
      });
    },
  );

  it.each(["CAPABILITY_DENIED", "SCOPE_DENIED"])(
    "retains %s without reading Google",
    async (code) => {
      const fetchMock = vi.fn<typeof fetch>(async (input) =>
        String(input).endsWith("/auth/v1/user")
          ? json({ id: "user-1" })
          : json({ success: false, error_code: code }),
      );
      const response = await handler(fetchMock).handle(request());
      expect(response.status).toBe(403);
      expect(await response.json()).toMatchObject({
        error_code: "CAPABILITY_DENIED",
        retryable: false,
      });
      expect(fetchMock).toHaveBeenCalledTimes(2);
    },
  );

  it.each(["auth", "atlas"] as const)(
    "does not turn a malformed %s response into expired session or missing source",
    async (stage) => {
      const response = await handler(
        vi.fn<typeof fetch>(async (input) =>
          stage === "atlas" && String(input).endsWith("/auth/v1/user")
            ? json({ id: "user-1" })
            : new Response("private malformed response"),
        ),
      ).handle(request());
      expect(response.status).toBe(502);
      const body = await response.json();
      expect(body.error_code).toBe("CONNECTOR_UNAVAILABLE");
      expect(JSON.stringify(body)).not.toContain("private malformed");
    },
  );

  it.each(["auth", "atlas"] as const)(
    "classifies a broken %s body stream as a retryable network failure",
    async (stage) => {
      const fetchMock = vi.fn<typeof fetch>(async (input) => {
        if (stage === "atlas" && String(input).endsWith("/auth/v1/user"))
          return json({ id: "user-1" });
        return new Response(
          new ReadableStream({
            start(controller) {
              controller.error(new TypeError("private broken stream detail"));
            },
          }),
        );
      });
      const response = await handler(fetchMock).handle(request());
      expect(response.status).toBe(503);
      const body = await response.json();
      expect(body).toMatchObject({
        error_code: "CONNECTOR_UNAVAILABLE",
        retryable: true,
        correlation_id: correlationId,
      });
      expect(JSON.stringify(body)).not.toContain("private broken");
    },
  );

  it.each([
    { label: "absent", value: undefined },
    { label: "null", value: null },
    { label: "array", value: [] },
    { label: "missing status", value: {} },
    { label: "unknown status", value: { ...source, source_status: "UNKNOWN" } },
  ])(
    "rejects malformed successful Atlas source evidence $label without inventing absence",
    async ({ value: google_connector_source }) => {
      const fetchMock = vi.fn<typeof fetch>(async (input) =>
        String(input).endsWith("/auth/v1/user")
          ? json({ id: "user-1" })
          : json({ success: true, google_connector_source }),
      );
      const response = await handler(fetchMock).handle(request());
      expect(response.status).toBe(502);
      expect(await response.json()).toMatchObject({
        error_code: "MALFORMED_ATLAS_SOURCE",
        retryable: false,
        correlation_id: correlationId,
      });
      expect(fetchMock).toHaveBeenCalledTimes(2);
    },
  );

  it.each(["auth", "atlas"] as const)(
    "bounds a stalled %s read and clears the deadline timer",
    async (stage) => {
      vi.useFakeTimers();
      try {
        let stalledSignal: AbortSignal | null | undefined;
        const fetchMock = vi.fn<typeof fetch>(async (input, init) => {
          if (stage === "atlas" && String(input).endsWith("/auth/v1/user"))
            return json({ id: "user-1" });
          stalledSignal = init?.signal;
          return new Promise<Response>((_resolve, reject) =>
            stalledSignal?.addEventListener(
              "abort",
              () => reject(stalledSignal?.reason),
              { once: true },
            ),
          );
        });
        const pending = handler(fetchMock).handle(request());
        await vi.advanceTimersByTimeAsync(0);
        expect(stalledSignal).toBeInstanceOf(AbortSignal);
        await vi.advanceTimersByTimeAsync(35_000);
        const response = await pending;
        expect(await response.json()).toMatchObject({
          error_code: "CONNECTOR_TIMEOUT",
          retryable: true,
          correlation_id: correlationId,
        });
        expect(stalledSignal?.aborted).toBe(true);
        expect(vi.getTimerCount()).toBe(0);
      } finally {
        vi.useRealTimers();
      }
    },
  );

  it.each(["auth", "atlas"] as const)(
    "bounds a stalled %s response body as well as its headers",
    async (stage) => {
      vi.useFakeTimers();
      try {
        const fetchMock = vi.fn<typeof fetch>(async (input, init) => {
          if (stage === "atlas" && String(input).endsWith("/auth/v1/user"))
            return json({ id: "user-1" });
          return new Response(
            new ReadableStream({
              start(controller) {
                init?.signal?.addEventListener(
                  "abort",
                  () => controller.error(init.signal?.reason),
                  { once: true },
                );
              },
            }),
          );
        });
        const pending = handler(fetchMock).handle(request());
        await vi.advanceTimersByTimeAsync(35_000);
        expect(await (await pending).json()).toMatchObject({
          error_code: "CONNECTOR_TIMEOUT",
          retryable: true,
          correlation_id: correlationId,
        });
        expect(vi.getTimerCount()).toBe(0);
      } finally {
        vi.useRealTimers();
      }
    },
  );

  it("clears the shared deadline after a successful read", async () => {
    vi.useFakeTimers();
    try {
      expect((await handler().handle(request())).status).toBe(200);
      expect(vi.getTimerCount()).toBe(0);
    } finally {
      vi.useRealTimers();
    }
  });

  it("keeps one deadline across Auth, Atlas and Google rather than resetting it", async () => {
    vi.useFakeTimers();
    try {
      let googleSignal: AbortSignal | null | undefined;
      const fetchMock = vi.fn<typeof fetch>(async (input, init) => {
        const url = String(input);
        if (url.endsWith("/auth/v1/user"))
          return new Promise<Response>((resolve) =>
            setTimeout(() => resolve(json({ id: "user-1" })), 10_000),
          );
        if (url.includes("/rpc/"))
          return json({ success: true, google_connector_source: source });
        googleSignal = init?.signal;
        return new Promise<Response>((_resolve, reject) =>
          googleSignal?.addEventListener(
            "abort",
            () => reject(googleSignal?.reason),
            {
              once: true,
            },
          ),
        );
      });
      const pending = handler(fetchMock).handle(request());
      let settled = false;
      void pending.then(() => {
        settled = true;
      });
      await vi.advanceTimersByTimeAsync(10_000);
      expect(googleSignal).toBeInstanceOf(AbortSignal);
      await vi.advanceTimersByTimeAsync(24_999);
      expect(settled).toBe(false);
      await vi.advanceTimersByTimeAsync(1);
      expect(await (await pending).json()).toMatchObject({
        error_code: "CONNECTOR_TIMEOUT",
        retryable: true,
      });
      expect(googleSignal?.aborted).toBe(true);
      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(vi.getTimerCount()).toBe(0);
    } finally {
      vi.useRealTimers();
    }
  });

  it("cancels an in-flight read when the incoming request is aborted", async () => {
    const controller = new AbortController();
    let upstreamSignal: AbortSignal | null | undefined;
    const fetchMock = vi.fn<typeof fetch>(async (_input, init) => {
      upstreamSignal = init?.signal;
      return new Promise<Response>((_resolve, reject) =>
        upstreamSignal?.addEventListener(
          "abort",
          () => reject(upstreamSignal?.reason),
          {
            once: true,
          },
        ),
      );
    });
    const pending = handler(fetchMock).handle(
      new Request(request(), { signal: controller.signal }),
    );
    await Promise.resolve();
    await Promise.resolve();
    // Flush request.json() before checking the first network stage.
    await vi.waitFor(() => expect(upstreamSignal).toBeInstanceOf(AbortSignal));
    controller.abort();
    const response = await pending;
    expect(upstreamSignal?.aborted).toBe(true);
    expect(await response.json()).toMatchObject({
      error_code: "CONNECTOR_UNAVAILABLE",
      retryable: true,
    });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it("rejects a missing bearer token before any external call", async () => {
    const fetchMock = successfulFetch();
    const handle = createGoogleSyncHandler({
      fetch: fetchMock,
      env: environment(),
    });
    const response = await handle(
      new Request("http://localhost/function", {
        method: "POST",
        body: JSON.stringify({}),
      }),
    );
    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({
      success: false,
      error_code: "SESSION_REQUIRED",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects an invalid source identifier", async () => {
    const { handle, fetchMock } = handler();
    const response = await handle(
      request({ weekly_menu_google_source_id: "browser-value" }),
    );
    expect(await response.json()).toMatchObject({
      error_code: "INVALID_GOOGLE_SOURCE",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects a source absent from the authorized active read", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) return json({ id: "user-1" });
      return json({
        success: false,
        error_code: "GOOGLE_SOURCE_UNAVAILABLE",
      });
    });
    const { handle } = handler(fetchMock);
    const response = await handle(request());
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_SOURCE_UNAVAILABLE",
    });
  });

  it("rejects an inactive connector source returned by a malformed mock", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) return json({ id: "user-1" });
      return json({
        success: true,
        google_connector_source: { ...source, source_status: "INACTIVE" },
      });
    });
    const { handle } = handler(fetchMock);
    const response = await handle(request());
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_SOURCE_UNAVAILABLE",
    });
  });

  it("rejects browser-supplied spreadsheet and range authority", async () => {
    const { handle, fetchMock } = handler();
    const response = await handle(
      request({ spreadsheet_id: "attacker-sheet", range: "A1:Z999" }),
    );
    expect(await response.json()).toMatchObject({
      error_code: "BROWSER_SOURCE_AUTHORITY_REJECTED",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("fails safely when the server-side credential is missing", async () => {
    const { handle } = handler(successfulFetch(), false);
    const response = await handle(request());
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_CREDENTIAL_MISSING",
    });
  });

  it("classifies a missing weekly sheet safely", async () => {
    const { handle } = handler(
      successfulFetch(
        json({
          success: false,
          error_code: "WEEKLY_SHEET_MISSING",
          message: "not exposed",
        }),
      ),
    );
    const response = await handle(request());
    expect(await response.json()).toMatchObject({
      error_code: "WEEKLY_SHEET_MISSING",
      retryable: false,
    });
  });

  it("classifies retryable upstream failures", async () => {
    const { handle } = handler(successfulFetch(json({}, 429)));
    const response = await handle(request());
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_UPSTREAM_RETRYABLE",
      retryable: true,
    });
  });

  it("returns safe source metadata and matrix rows without a database write", async () => {
    const { handle, fetchMock } = handler();
    const response = await handle(request());
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      success: true,
      source: {
        source_id: sourceId,
        source_code: "synthetic-menu",
        source_name: "Synthetic weekly menu",
        sheet_name: "Tuần 27-07-2026",
        range: "'Tuần 27-07-2026'!A3:I500",
      },
      fetched_at: "2026-07-27T03:00:00.000Z",
      rows: [
        ["Tên trường", "Ngày", "Món canh"],
        ["school-a", "2026-07-27", "dish-a"],
      ],
      correlation_id: correlationId,
    });
    const calls = fetchMock.mock.calls.map(([input, init]) => ({
      url: String(input),
      method: init?.method ?? "GET",
    }));
    expect(calls).toEqual([
      { url: "http://supabase.test/auth/v1/user", method: "GET" },
      {
        url: "http://supabase.test/rest/v1/rpc/get_planning_inputs_workbench",
        method: "POST",
      },
      {
        url: "https://script.google.com/macros/s/synthetic-deployment/exec",
        method: "POST",
      },
    ]);
  });

  it("never exposes credential values or logs connector secrets", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => undefined);
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const { handle } = handler(successfulFetch(json({}, 500)));
    const responseText = await (await handle(request())).text();
    expect(responseText).not.toContain("test-webapp-secret");
    expect(responseText).not.toContain("fixture@example.test");
    expect(log).not.toHaveBeenCalled();
    expect(error).not.toHaveBeenCalled();
    log.mockRestore();
    error.mockRestore();
  });
});
