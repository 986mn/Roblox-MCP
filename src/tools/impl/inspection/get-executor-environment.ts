import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "get-executor-environment",
    {
      title: "Get Roblox Executor Environment Information",
      description:
        "Check and retrieve the capabilities, custom globals, and identification metadata of the running Roblox exploit/executor environment.",
      inputSchema: z.object({}),
    },
    async () =>
      sendAndWait({
        type: "get-executor-environment",
        data: {},
        failureMessage: () => "Failed to get executor environment info.",
      })
  );
}
