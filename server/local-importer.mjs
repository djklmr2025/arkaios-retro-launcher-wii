#!/usr/bin/env node
/**
 * ARKAIOS Wii - Importador local de catalogo
 * ------------------------------------------
 * Escanea una carpeta LOCAL del usuario (sus propios backups/dumps ya
 * existentes en su PC/USB/SD) y genera un catalogo compatible con
 * /api/wii/catalog del arkaios-node-server.
 *
 * NO descarga nada de internet. NO toca sitios de ROMs comerciales.
 * Solo lee archivos que el usuario ya tiene en su disco y los organiza.
 *
 * Uso:
 *   node server/local-importer.mjs --dir "D:\Roms" --device arkwii-mi-wii-01
 *   node server/local-importer.mjs --dir "D:\Roms" --device arkwii-mi-wii-01 --post http://127.0.0.1:8787
 *   node server/local-importer.mjs --dir "D:\Roms" --device arkwii-mi-wii-01 --out data/catalog-local.json
 */

import { readdir, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { extname, basename, dirname, join, resolve, relative } from "node:path";

// Extension -> {system, launcher}. Solo metadata de organizacion;
// no valida ni verifica legalidad del contenido.
const SYSTEM_MAP = {
  ".wbfs": { system: "Nintendo Wii", launcher: "usbloadergx" },
  ".iso": { system: "Nintendo GameCube / Wii", launcher: "nintendont-or-usbloadergx" },
  ".gcm": { system: "Nintendo GameCube", launcher: "nintendont" },
  ".z64": { system: "Nintendo 64", launcher: "not64" },
  ".n64": { system: "Nintendo 64", launcher: "not64" },
  ".v64": { system: "Nintendo 64", launcher: "not64" },
  ".nds": { system: "Nintendo DS", launcher: "desmume-wii" },
  ".nes": { system: "Nintendo Entertainment System", launcher: "retroarch" },
  ".sfc": { system: "Super Nintendo", launcher: "retroarch" },
  ".smc": { system: "Super Nintendo", launcher: "retroarch" },
  ".gba": { system: "Game Boy Advance", launcher: "retroarch" },
  ".gbc": { system: "Game Boy Color", launcher: "retroarch" },
  ".gb": { system: "Game Boy", launcher: "retroarch" },
  ".md": { system: "Sega Genesis/MegaDrive", launcher: "retroarch" },
  ".bin": { system: "Sega Genesis/MegaDrive", launcher: "retroarch" },
  ".pce": { system: "PC Engine/TurboGrafx 16", launcher: "retroarch" }
};

function parseArgs(argv) {
  const args = { dir: null, device: null, post: null, out: null };
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    const val = argv[i + 1];
    if (key === "--dir") { args.dir = val; i += 1; }
    else if (key === "--device") { args.device = val; i += 1; }
    else if (key === "--post") { args.post = val; i += 1; }
    else if (key === "--out") { args.out = val; i += 1; }
  }
  return args;
}

async function walk(dir) {
  const found = [];
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      found.push(...(await walk(full)));
    } else {
      found.push(full);
    }
  }
  return found;
}

function toGameId(filePath) {
  const name = basename(filePath, extname(filePath));
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

function toLabel(filePath) {
  return basename(filePath, extname(filePath))
    .replace(/[_.]+/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

async function buildCatalog(rootDir) {
  const root = resolve(rootDir);
  const files = await walk(root);
  const items = [];

  for (const filePath of files) {
    const ext = extname(filePath).toLowerCase();
    const mapping = SYSTEM_MAP[ext];
    if (!mapping) continue;

    items.push({
      label: toLabel(filePath),
      system: mapping.system,
      launcher: mapping.launcher,
      game_id: toGameId(filePath),
      source: "local_backup",
      source_type: "user_backup",
      relative_path: relative(root, filePath).replace(/\\/g, "/")
    });
  }

  return items;
}

async function postCatalog(baseUrl, deviceId, items) {
  const res = await fetch(new URL("/api/wii/catalog", baseUrl), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ device_id: deviceId, items })
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`node-server respondio ${res.status}: ${JSON.stringify(body)}`);
  }
  return body;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.dir) {
    console.error("Falta --dir <carpeta con tus ROMs propias>");
    process.exit(1);
  }
  if (!existsSync(args.dir)) {
    console.error(`No existe la carpeta: ${args.dir}`);
    process.exit(1);
  }

  console.log(`Escaneando ${args.dir} ...`);
  const items = await buildCatalog(args.dir);
  console.log(`Encontrados ${items.length} archivos reconocidos.`);

  const summary = items.reduce((acc, it) => {
    acc[it.system] = (acc[it.system] || 0) + 1;
    return acc;
  }, {});
  console.table(summary);

  if (args.out) {
    const outPath = resolve(args.out);
    await mkdir(dirname(outPath), { recursive: true });
    await writeFile(outPath, JSON.stringify({ device_id: args.device, items }, null, 2), "utf8");
    console.log(`Catalogo guardado en ${outPath}`);
  }

  if (args.post) {
    if (!args.device) {
      console.error("Falta --device arkwii-... para hacer POST al node-server");
      process.exit(1);
    }
    console.log(`Enviando catalogo a ${args.post} ...`);
    const result = await postCatalog(args.post, args.device, items);
    console.log("Respuesta del servidor:", result);
  }

  if (!args.out && !args.post) {
    console.log(JSON.stringify(items, null, 2));
  }
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
