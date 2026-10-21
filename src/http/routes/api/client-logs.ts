import type { IncomingMessage, ServerResponse } from "http";
import { getClientLogs, clearClientLogs } from "../../client-logs.js";

export function GET(req: IncomingMessage, res: ServerResponse, url: URL): void {
  const clientId = url.searchParams.get("clientId");
  if (!clientId) {
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Missing 'clientId' parameter." }));
    return;
  }

  const limit = parseInt(url.searchParams.get("limit") || "100", 10);
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ logs: getClientLogs(clientId, limit) }));
}

export function DELETE(req: IncomingMessage, res: ServerResponse, url: URL): void {
  const clientId = url.searchParams.get("clientId");
  if (!clientId) {
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Missing 'clientId' parameter." }));
    return;
  }

  clearClientLogs(clientId);
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ ok: true }));
}
