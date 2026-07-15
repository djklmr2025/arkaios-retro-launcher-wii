import { createServer } from "node:http";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { randomUUID } from "node:crypto";

const host = process.env.ARKAIOS_NODE_HOST || "127.0.0.1";
const port = Number(process.env.ARKAIOS_NODE_PORT || 8787);
const dataDir = resolve(process.env.ARKAIOS_NODE_DATA || "data");
const nodeStorePath = resolve(dataDir, "nodes.json");
const catalogStorePath = resolve(dataDir, "catalogs.json");

async function readJson(path, fallback) {
  if (!existsSync(path)) {
    return fallback;
  }
  return JSON.parse(await readFile(path, "utf8"));
}

async function writeJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, JSON.stringify(value, null, 2), "utf8");
}

function sendJson(res, status, value) {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "content-type"
  });
  res.end(JSON.stringify(value, null, 2));
}

async function readBody(req) {
  const chunks = [];
  let size = 0;

  for await (const chunk of req) {
    size += chunk.length;
    if (size > 1024 * 1024) {
      throw new Error("payload_too_large");
    }
    chunks.push(chunk);
  }

  if (chunks.length === 0) {
    return {};
  }

  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function normalizeDevice(body, req) {
  if (!body || typeof body !== "object") {
    throw new Error("invalid_body");
  }
  if (!body.device_id || !String(body.device_id).startsWith("arkwii-")) {
    throw new Error("invalid_device_id");
  }

  return {
    device_id: String(body.device_id),
    name: String(body.name || "ARKAIOS Wii"),
    launcher_version: String(body.launcher_version || "0.1.0"),
    online: Boolean(body.online),
    local_ip: body.local_ip ? String(body.local_ip) : "",
    capabilities: Array.isArray(body.capabilities) ? body.capabilities.map(String) : [],
    catalog_summary: body.catalog_summary || { game_count: 0, systems: [] },
    remote_addr: req.socket.remoteAddress || "",
    last_seen: new Date().toISOString()
  };
}

function sanitizeCatalog(body) {
  const items = Array.isArray(body.items) ? body.items : Array.isArray(body) ? body : [];
  return items.map((item) => ({
    label: String(item.Label || item.label || ""),
    system: String(item.System || item.system || ""),
    launcher: String(item.Launcher || item.launcher || ""),
    game_id: String(item.GameId || item.game_id || ""),
    source: String(item.Source || item.source || "")
  })).filter((item) => item.label && item.system);
}

async function handle(req, res) {
  if (req.method === "OPTIONS") {
    sendJson(res, 204, {});
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  if (req.method === "GET" && url.pathname === "/health") {
    sendJson(res, 200, { ok: true, service: "arkaios-node-server", request_id: randomUUID() });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/wii/nodes") {
    const nodes = await readJson(nodeStorePath, {});
    sendJson(res, 200, { nodes: Object.values(nodes) });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/wii/heartbeat") {
    const body = await readBody(req);
    const device = normalizeDevice(body, req);
    const nodes = await readJson(nodeStorePath, {});
    nodes[device.device_id] = device;
    await writeJson(nodeStorePath, nodes);
    sendJson(res, 200, { ok: true, device_id: device.device_id, last_seen: device.last_seen });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/wii/catalog") {
    const body = await readBody(req);
    if (!body.device_id || !String(body.device_id).startsWith("arkwii-")) {
      throw new Error("invalid_device_id");
    }
    const catalogs = await readJson(catalogStorePath, {});
    catalogs[String(body.device_id)] = {
      device_id: String(body.device_id),
      updated: new Date().toISOString(),
      items: sanitizeCatalog(body)
    };
    await writeJson(catalogStorePath, catalogs);
    sendJson(res, 200, { ok: true, device_id: String(body.device_id), item_count: catalogs[String(body.device_id)].items.length });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/wii/manifest") {
    sendJson(res, 200, {
      schema: "arkaios.wii.remote.manifest.v1",
      downloads: {
        commercial_roms: false,
        exploits: false,
        allowed: ["homebrew", "metadata", "covers", "patches"]
      },
      endpoints: {
        heartbeat: "/api/wii/heartbeat",
        catalog: "/api/wii/catalog"
      }
    });
    return;
  }

  sendJson(res, 404, { ok: false, error: "not_found" });
}

const server = createServer((req, res) => {
  handle(req, res).catch((error) => {
    const status = error.message === "payload_too_large" ? 413 : 400;
    sendJson(res, status, { ok: false, error: error.message });
  });
});

server.listen(port, host, () => {
  console.log(`ARKAIOS Wii node server listening on http://${host}:${port}`);
});
