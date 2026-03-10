#!/usr/bin/env bun
/**
 * deploy.ts
 * Flattens, compiles and deploys ReverseAuction to any EVM chain.
 *
 * Setup: cp .env.example .env  — fill in PRIVATE_KEY and RPC_URL
 * Usage: bun run deploy
 */

import solc from "solc";
import { ethers } from "ethers";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { resolve } from "path";

const ROOT = resolve(import.meta.dir, "..");

// ---- Env --------------------------------------------------------------------
const { PRIVATE_KEY, RPC_URL } = process.env;
if (!PRIVATE_KEY || !RPC_URL) {
  console.error("Error: PRIVATE_KEY and RPC_URL must be set in .env");
  process.exit(1);
}

const COMMIT_DURATION = parseInt(process.env.COMMIT_DURATION ?? "300");
const REVEAL_DURATION = parseInt(process.env.REVEAL_DURATION ?? "300");
const MIN_DEPOSIT     = BigInt(process.env.MIN_DEPOSIT ?? "10000000000000000"); // default 0.01 ETH in wei

// ---- Compile ----------------------------------------------------------------
const source = readFileSync(`${ROOT}/flat/ReverseAuction.flat.sol`, "utf-8");

const input = {
  language: "Solidity",
  sources: { "ReverseAuction.sol": { content: source } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
  },
};

console.log("Compiling...");
const output = JSON.parse(solc.compile(JSON.stringify(input)));

const errors = (output.errors ?? []).filter((e: any) => e.severity === "error");
if (errors.length > 0) {
  errors.forEach((e: any) => console.error(e.formattedMessage));
  process.exit(1);
}

const compiled  = output.contracts["ReverseAuction.sol"]["ReverseAuction"];
const abi       = compiled.abi;
const bytecode  = compiled.evm.bytecode.object;

mkdirSync(`${ROOT}/artifacts`, { recursive: true });
writeFileSync(`${ROOT}/artifacts/ReverseAuction.json`, JSON.stringify({ abi, bytecode }, null, 2));
console.log("✓ Compiled  → artifacts/ReverseAuction.json");

// ---- Deploy -----------------------------------------------------------------
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet   = new ethers.Wallet(PRIVATE_KEY, provider);

console.log(`\nDeployer:    ${wallet.address}`);
console.log(`Network:     ${RPC_URL}`);
console.log(`Commit:      ${COMMIT_DURATION}s`);
console.log(`Reveal:      ${REVEAL_DURATION}s`);
console.log(`Min deposit: ${MIN_DEPOSIT} wei`);
console.log("\nDeploying...");

const factory  = new ethers.ContractFactory(abi, bytecode, wallet);
const contract = await factory.deploy(COMMIT_DURATION, REVEAL_DURATION, MIN_DEPOSIT);
console.log(`Tx hash:   ${contract.deploymentTransaction()?.hash}`);

await contract.waitForDeployment();
const address = await contract.getAddress();

console.log(`\n✓ Deployed → ${address}`);
console.log(`   https://sepolia.etherscan.io/address/${address}`);
