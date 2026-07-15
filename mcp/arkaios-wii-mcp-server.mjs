#!/usr/bin/env node
/**
 * ARKAIOS Wii - Servidor MCP
 * --------------------------
 * Expone el arkaios-node-server local como herramientas MCP, para que un
 * agente compatible pueda leer el catalogo y estado de los nodos Wii.
 *
 * Solo opera sobre metadata local. No descarga ROMs comerciales, no navega
 * sitios de distribucion y no ejecuta acciones fuera del servidor ARKAIOS.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE_URL = process.env.ARKAIOS_NODE_BASE_URL || "http://127.0.0.1:8787";

async function callNodeServer(path, options = {}) {
  const res = await fetch(new URL(path, BASE_URL), options);
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`arkaios-node-server ${path} -> ${res.status}: ${JSON.stringify(body)}`);
  }
  return body;
}

function asText(value) {
  return { content: [{ type: "text", text: JSON.stringify(value, null, 2) }] };
}

const server = new McpServer({
  name: "arkaios-wii",
  version: "0.1.0"
});

server.tool(
  "arkaios_wii_health",
  "Verifica si el arkaios-node-server local responde.",
  {},
  async () => asText(await callNodeServer("/health"))
);

server.tool(
  "arkaios_wii_list_nodes",
  "Lista los nodos Wii ARKAIOS registrados.",
  {},
  async () => asText(await callNodeServer("/api/wii/nodes"))
);

server.tool(
  "arkaios_wii_get_manifest",
  "Obtiene el manifest remoto, politica de descargas permitidas y endpoints.",
  {},
  async () => asText(await callNodeServer("/api/wii/manifest"))
);

server.tool(
  "arkaios_wii_submit_catalog",
  "Sube o actualiza el catalogo local de un device_id. Solo acepta metadata de homebrew o backups locales del usuario.",
  {
    device_id: z.string().regex(/^arkwii-[a-zA-Z0-9-]{8,}$/, "device_id debe empezar con 'arkwii-'"),
    items: z.array(z.object({
      label: z.string(),
      system: z.string(),
      launcher: z.string().optional(),
      game_id: z.string().optional(),
      source: z.string().optional(),
      source_type: z.enum(["homebrew", "user_backup"]).optional(),
      relative_path: z.string().optional()
    }))
  },
  async ({ device_id, items }) =>
    asText(await callNodeServer("/api/wii/catalog", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ device_id, items })
    }))
);

const transport = new StdioServerTransport();
await server.connect(transport);
