import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "fire-remote",
    {
      title: "Fire or invoke a RemoteEvent or RemoteFunction",
      description:
        "Execute network calls by firing RemoteEvents (FireServer) or invoking RemoteFunctions (InvokeServer) with custom arguments.",
      inputSchema: z.object({
        path: z
          .string()
          .describe("The path or expression returning the target RemoteEvent or RemoteFunction (e.g. 'game.ReplicatedStorage.RemoteEvent')"),
        args: z
          .array(z.any())
          .describe("Optional arguments array to pass to the remote. String arguments starting with 'loadstring:' will evaluate as a Roblox expression (e.g. 'loadstring:game.Players.LocalPlayer').")
          .optional()
          .default([]),
        isFunction: z
          .boolean()
          .describe("Set to true if target is a RemoteFunction (calls InvokeServer and yields for result). If false, fires RemoteEvent (calls FireServer, returns immediately).")
          .optional()
          .default(false),
      }),
    },
    async ({ path, args, isFunction }) => {
      return sendAndWait({
        type: "fire-remote",
        data: { path, args, isFunction },
        failureMessage: (response) =>
          "Failed to fire/invoke remote. Response: " + JSON.stringify(response),
      });
    }
  );
}
