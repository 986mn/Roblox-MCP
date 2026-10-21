import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const src = path.join(root, "src", "http", "assets");
const dest = path.join(root, "dist", "http", "assets");

if (!fs.existsSync(src)) {
  console.error(`[copy-assets] Source not found: ${src}`);
  process.exit(1);
}

fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });
console.log(`[copy-assets] ${src} → ${dest}`);
