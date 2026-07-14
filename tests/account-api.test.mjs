import assert from "node:assert/strict";
import test from "node:test";
import { createAccountApi } from "../web-demo/src/platform/account-api.js";

function recordingFetch(result = { ok: true }) {
  const calls = [];
  return {
    calls,
    fetchImpl: async (...args) => {
      calls.push(args);
      return { json: async () => result };
    },
  };
}

test("post sends a JSON request to the supplied route", async () => {
  const transport = recordingFetch({ ok: true, token: "test" });
  const client = createAccountApi({ fetchImpl: transport.fetchImpl, now: () => 123 });

  const result = await client.post("/api/login", { name: "tester", pw: "secret" });

  assert.deepEqual(result, { ok: true, token: "test" });
  assert.deepEqual(transport.calls, [[
    "/api/login",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "tester", pw: "secret" }),
    },
  ]]);
});

test("getVersion adds a cache-busting timestamp", async () => {
  const transport = recordingFetch({ ok: true, ver: "7.18.8" });
  const client = createAccountApi({ fetchImpl: transport.fetchImpl, now: () => 123 });

  await client.getVersion();

  assert.deepEqual(transport.calls, [["/api/version?t=123", undefined]]);
});

test("getBoard reads the current leaderboard", async () => {
  const transport = recordingFetch({ ok: true, rows: [] });
  const client = createAccountApi({ fetchImpl: transport.fetchImpl, now: () => 123 });

  await client.getBoard();

  assert.deepEqual(transport.calls, [["/api/board", undefined]]);
});
