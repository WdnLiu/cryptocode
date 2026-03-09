#!/usr/bin/env bun
/**
 * flatten.ts
 * Resolves all local imports from the entry contract and merges them into
 * a single flat .sol file suitable for pasting into Remix IDE.
 *
 * Usage: bun run flatten
 */

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { resolve, dirname, relative } from "path";

const ROOT   = resolve(import.meta.dir, "..");
const ENTRY  = `${ROOT}/contracts/ReverseAuction.sol`;
const OUTPUT = `${ROOT}/flat/ReverseAuction.flat.sol`;

const visited: Set<string> = new Set();
const segments: string[]   = [];

// Matches any Solidity import and captures the quoted file path
const IMPORT_RE = /^\s*import\s+(?:[^"']*?)?["']([^"']+\.sol)["'][^;]*;/;

function flatten(filePath: string): void {
  const abs = resolve(filePath);
  if (visited.has(abs)) return;
  visited.add(abs);

  const src  = readFileSync(abs, "utf-8");
  const body: string[] = [];

  for (const line of src.split("\n")) {
    const trimmed = line.trim();

    if (trimmed.startsWith("// SPDX-License-Identifier:")) continue;
    if (trimmed.startsWith("pragma solidity"))             continue;

    const match = trimmed.match(IMPORT_RE);
    if (match) {
      flatten(resolve(dirname(abs), match[1]));
      continue;
    }

    body.push(line);
  }

  const content = body.join("\n").trim();
  if (content) {
    const label = relative(ROOT, abs);
    segments.push(`// ---- ${label} ${"─".repeat(Math.max(0, 60 - label.length))}\n\n${content}`);
  }
}

flatten(ENTRY);

const header = [
  "// SPDX-License-Identifier: MIT",
  "pragma solidity ^0.8.24;",
  "",
  `// Flattened: ${new Date().toISOString()}`,
  `// Source:    contracts/ReverseAuction.sol`,
  "",
].join("\n");

mkdirSync(dirname(OUTPUT), { recursive: true });
writeFileSync(OUTPUT, header + "\n" + segments.join("\n\n") + "\n");

console.log(`✓ Flattened → flat/ReverseAuction.flat.sol  (${segments.length} segments)`);
