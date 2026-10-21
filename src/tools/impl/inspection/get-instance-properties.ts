import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "get-instance-properties",
    {
      title: "Get properties, attributes and tags of a Roblox instance",
      description:
        "Inspect a Roblox Instance by path or debug ID to retrieve its properties, attributes, and tags.",
      inputSchema: z.object({
        root: z
          .string()
          .describe("The path or expression returning the target instance (e.g., 'game.Workspace.Part' or 'game.Players.LocalPlayer')")
          .optional(),
        debugId: z
          .string()
          .describe("Target instance DebugId (used when path is unknown or instance is outside workspace)")
          .optional(),
        properties: z
          .array(z.string())
          .describe("Optional specific list of property names to retrieve. If omitted, common class properties will be probed automatically.")
          .optional(),
      }),
    },
    async ({ root, debugId, properties }) => {
      if (!root && !debugId) {
        return {
          content: [{ type: "text" as const, text: "Either 'root' path or 'debugId' must be provided." }],
          isError: true,
        };
      }
      return sendAndWait({
        type: "get-instance-properties",
        data: { root, debugId, properties },
        failureMessage: (response) =>
          "Failed to retrieve instance properties. Response: " + JSON.stringify(response),
      });
    }
  );
}
