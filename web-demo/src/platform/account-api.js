export function createAccountApi({ fetchImpl, now = Date.now }) {
  async function readJson(url, options) {
    const response = await fetchImpl(url, options);
    return response.json();
  }

  return Object.freeze({
    post(route, body) {
      return readJson(route, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body || {}),
      });
    },
    getVersion() {
      return readJson(`/api/version?t=${now()}`);
    },
    getBoard() {
      return readJson("/api/board");
    },
  });
}
