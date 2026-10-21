import type { IncomingMessage, ServerResponse } from "http";
import { DASHBOARD_TOOL_CATALOG } from "../../../tools/catalog.js";

export async function GET(_req: IncomingMessage, res: ServerResponse): Promise<void> {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ tools: DASHBOARD_TOOL_CATALOG }));
}
