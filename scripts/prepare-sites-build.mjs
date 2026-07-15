import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const root = process.cwd();
const indexHtml = await readFile(resolve(root, "dist/index.html"), "utf8");
const manifestJson = await readFile(resolve(root, "dist/arkaios-wii-manifest.json"), "utf8");
const hostingJson = await readFile(resolve(root, ".openai/hosting.json"), "utf8");

const serverSource = `const indexHtml = ${JSON.stringify(indexHtml)};
const manifestJson = ${JSON.stringify(manifestJson)};

function response(body, contentType) {
  return new Response(body, {
    headers: {
      "content-type": contentType,
      "cache-control": "public, max-age=60"
    }
  });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/arkaios-wii-manifest.json") {
      return response(manifestJson, "application/json; charset=utf-8");
    }

    if (url.pathname === "/" || url.pathname === "/index.html") {
      return response(indexHtml, "text/html; charset=utf-8");
    }

    return new Response("Not found", { status: 404 });
  }
};
`;

await mkdir(resolve(root, "dist/server"), { recursive: true });
await mkdir(resolve(root, "dist/.openai"), { recursive: true });
await writeFile(resolve(root, "dist/server/index.js"), serverSource, "utf8");
await writeFile(resolve(root, "dist/.openai/hosting.json"), hostingJson, "utf8");

console.log("Prepared Sites build entrypoint: dist/server/index.js");
