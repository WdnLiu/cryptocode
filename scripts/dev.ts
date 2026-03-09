#!/usr/bin/env bun
import { file, serve } from "bun";
import { resolve, extname } from "path";
import { $ } from "bun";

const ROOT = resolve(import.meta.dir, "..");
const PREFERRED_PORT = 1234;

const MIME: Record<string, string> = {
  ".html": "text/html",
  ".js":   "application/javascript",
  ".css":  "text/css",
  ".json": "application/json",
  ".sol":  "text/plain",
};

let port = PREFERRED_PORT;
while (true) {
  try {
    serve({
      port,
      async fetch(req) {
        const url  = new URL(req.url);
        const path = url.pathname === "/" ? "/owner.html" : url.pathname;
        const abs  = resolve(ROOT, "." + path);
        const f    = file(abs);
        if (!await f.exists()) return new Response("Not found", { status: 404 });
        return new Response(f, {
          headers: { "Content-Type": MIME[extname(abs)] ?? "text/plain" },
        });
      },
    });
    break;
  } catch {
    port++;
  }
}

console.log(`\n  owner  → http://localhost:${port}/owner.html`);
console.log(`  bidder → http://localhost:${port}/bidder.html\n`);

await $`xdg-open http://localhost:${port}/owner.html`.quiet();
await $`xdg-open http://localhost:${port}/bidder.html`.quiet();
