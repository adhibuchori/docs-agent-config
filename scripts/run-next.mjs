#!/usr/bin/env node
import { spawn } from 'node:child_process';

/**
 * Launches the local Next.js binary, adding --no-experimental-webstorage only on
 * the Node versions that actually have the flag.
 *
 * Node 25 turns on --experimental-webstorage by default and injects a half-built
 * localStorage global, which crashes SSR inside next-themes (see
 * .claude/anti-patterns/nodejs-25-webstorage-ssr.md). The flag disables it.
 *
 * Passing that flag unconditionally — as the sibling docs repos do — makes the
 * script fail outright on Node 20 and 22 with "node: bad option", so the build
 * only works on the exact Node version it was written for. Gating on the major
 * version keeps both cases working.
 *
 * Usage: node scripts/run-next.mjs <dev|build|start> [...args]
 */

const nodeMajor = Number.parseInt(process.versions.node.split('.')[0], 10);
const needsWebstorageOptOut = nodeMajor >= 25;

const nodeArgs = needsWebstorageOptOut ? ['--no-experimental-webstorage'] : [];
const nextBin = new URL('../node_modules/.bin/next', import.meta.url).pathname;

const child = spawn(process.execPath, [...nodeArgs, nextBin, ...process.argv.slice(2)], {
  stdio: 'inherit',
});

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

child.on('error', (error) => {
  console.error('[run-next] failed to launch Next.js:', error.message);
  process.exit(1);
});
