import { createServer } from "node:http";
import { pathToFileURL } from "node:url";

export const agents = Object.freeze([
  Object.freeze({
    id: "orin",
    name: "Orin",
    role: "community-coordinator",
    greeting: "I will understand the request and coordinate the kingdom.",
  }),
  Object.freeze({
    id: "scribe",
    name: "Scribe",
    role: "content-producer",
    greeting: "I will turn approved insight into useful content.",
  }),
  Object.freeze({
    id: "rick",
    name: "Rick",
    role: "security-governor",
    greeting: "I will check whether consequential actions are permitted.",
  }),
  Object.freeze({
    id: "bastion",
    name: "Bastion",
    role: "system-doctor",
    greeting: "I will diagnose whether the system is healthy.",
  }),
]);

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  response.end(`${JSON.stringify(body, null, 2)}\n`);
}

export function createRequestHandler({ environment = "development" } = {}) {
  return function handleRequest(request, response) {
    const url = new URL(request.url ?? "/", "http://localhost");

    if (request.method !== "GET") {
      sendJson(response, 405, {
        error: "method_not_allowed",
        message:
          "The hello-world runtime currently supports GET requests only.",
      });
      return;
    }

    if (url.pathname === "/health") {
      sendJson(response, 200, {
        status: "ok",
        service: "kingdom-of-pal",
        environment,
        agents: agents.length,
      });
      return;
    }

    if (url.pathname === "/hello") {
      sendJson(response, 200, {
        message: "Hello, Founder. The essential kingdom is assembled.",
        workflow: agents.map(({ id, name, role, greeting }) => ({
          agent: id,
          name,
          role,
          greeting,
        })),
      });
      return;
    }

    if (url.pathname === "/agents") {
      sendJson(
        response,
        200,
        agents.map(({ id, name, role }) => ({ id, name, role })),
      );
      return;
    }

    const agentHealthMatch = url.pathname.match(
      /^\/agents\/(orin|scribe|rick|bastion)\/health$/,
    );
    if (agentHealthMatch) {
      const agent = agents.find(({ id }) => id === agentHealthMatch[1]);
      sendJson(response, 200, {
        status: "ok",
        agent: agent.id,
        role: agent.role,
        runtime: "hello-world",
      });
      return;
    }

    sendJson(response, 404, {
      error: "not_found",
      message: "Try GET /health, /hello, /agents, or /agents/:id/health.",
    });
  };
}

export async function startServer({
  host = "127.0.0.1",
  port = Number.parseInt(process.env.KINGDOM_PORT ?? "4000", 10),
  environment = process.env.NODE_ENV ?? "development",
  log = true,
} = {}) {
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error("KINGDOM_PORT must be an integer between 0 and 65535.");
  }

  const server = createServer(createRequestHandler({ environment }));

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, resolve);
  });

  if (log) {
    const address = server.address();
    const activePort = typeof address === "object" ? address.port : port;
    console.log(
      `[pal] hello-world runtime listening on http://${host}:${activePort}`,
    );
  }

  return server;
}

const isEntrypoint =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isEntrypoint) {
  startServer().catch((error) => {
    console.error(
      `[pal] failed to start hello-world runtime: ${error.message}`,
    );
    process.exitCode = 1;
  });
}
