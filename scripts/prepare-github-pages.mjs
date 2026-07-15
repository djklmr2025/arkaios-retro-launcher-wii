import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = process.cwd();
const docs = resolve(root, "docs");
const dist = resolve(root, "dist");
const pages = ["panel", "convertidor", "sync", "node", "manifest"];

function asSubpage(html, page) {
  return html
    .replace('<body data-page="home">', `<body data-page="${page}">`)
    .replaceAll('href="./', 'href="../')
    .replaceAll('src="./', 'src="../')
    .replaceAll('fetch("./', 'fetch("../');
}

await rm(docs, { recursive: true, force: true });
await mkdir(docs, { recursive: true });

await cp(resolve(dist, "assets"), resolve(docs, "assets"), { recursive: true });
await cp(resolve(dist, "media"), resolve(docs, "media"), { recursive: true });
await cp(resolve(dist, "arkaios-wii-manifest.json"), resolve(docs, "arkaios-wii-manifest.json"));

const rootHtml = await readFile(resolve(dist, "index.html"), "utf8");
await writeFile(resolve(docs, "index.html"), rootHtml, "utf8");

for (const page of pages) {
  const pageDir = resolve(docs, page);
  await mkdir(pageDir, { recursive: true });
  await writeFile(resolve(pageDir, "index.html"), asSubpage(rootHtml, page), "utf8");
}

console.log(`Prepared GitHub Pages docs for: home, ${pages.join(", ")}`);
