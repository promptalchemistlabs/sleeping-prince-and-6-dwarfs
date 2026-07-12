import assert from "node:assert/strict";
import { after, before, test } from "node:test";

import { startServer } from "./hello-world.mjs";

let baseUrl;
let server;

before(async () => {
  server = await startServer({
    host: "127.0.0.1",
    port: 0,
    environment: "test",
    log: false,
  });

  const address = server.address();
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  if (server) {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
});

test("reports kingdom health", async () => {
  const response = await fetch(`${baseUrl}/health`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(body, {
    status: "ok",
    service: "kingdom-of-pal",
    environment: "test",
    agents: 4,
  });
});

test("assembles the four agents in the hello workflow", async () => {
  const response = await fetch(`${baseUrl}/hello`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(
    body.message,
    "Hello, Founder. The essential kingdom is assembled.",
  );
  assert.deepEqual(
    body.workflow.map(({ agent }) => agent),
    ["orin", "scribe", "rick", "bastion"],
  );
});

test("reports each agent health", async () => {
  for (const agent of ["orin", "scribe", "rick", "bastion"]) {
    const response = await fetch(`${baseUrl}/agents/${agent}/health`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.status, "ok");
    assert.equal(body.agent, agent);
  }
});

test("rejects unsupported routes and methods", async () => {
  const missingResponse = await fetch(`${baseUrl}/missing`);
  assert.equal(missingResponse.status, 404);

  const postResponse = await fetch(`${baseUrl}/hello`, { method: "POST" });
  assert.equal(postResponse.status, 405);
});
