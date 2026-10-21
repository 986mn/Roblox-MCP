export interface ClientLogEntry {
  timestamp: string;
  level: "info" | "warn" | "error" | "message";
  message: string;
}

const clientLogBuffers: Map<string, ClientLogEntry[]> = new Map();
const MAX_LOGS = 500;

export function addClientLog(clientId: string, level: string, message: string): void {
  let buffer = clientLogBuffers.get(clientId);
  if (!buffer) {
    buffer = [];
    clientLogBuffers.set(clientId, buffer);
  }

  let mappedLevel: ClientLogEntry["level"] = "info";
  const lvl = level.toLowerCase();
  if (lvl.includes("error") || lvl.includes("fatal") || lvl.includes("failed")) {
    mappedLevel = "error";
  } else if (lvl.includes("warning") || lvl.includes("warn")) {
    mappedLevel = "warn";
  } else if (lvl.includes("message") || lvl.includes("info")) {
    mappedLevel = "message";
  }

  buffer.unshift({
    timestamp: new Date().toISOString(),
    level: mappedLevel,
    message,
  });

  if (buffer.length > MAX_LOGS) {
    buffer.length = MAX_LOGS;
  }
}

export function getClientLogs(clientId: string, limit = 100): ClientLogEntry[] {
  const buffer = clientLogBuffers.get(clientId);
  if (!buffer) return [];
  return buffer.slice(0, Math.min(limit, buffer.length));
}

export function clearClientLogs(clientId: string): void {
  clientLogBuffers.delete(clientId);
}
