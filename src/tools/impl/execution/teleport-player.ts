import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "teleport-player",
    {
      title: "Teleport the player character",
      description:
        "Teleport the LocalPlayer's character to a specified player, set of coordinates, or relative offset, optionally facing a specific lookAt target.",
      inputSchema: z.object({
        targetPlayer: z
          .string()
          .describe("Target player username to teleport to")
          .optional(),
        coordinates: z
          .object({
            x: z.number(),
            y: z.number(),
            z: z.number(),
          })
          .describe("Absolute Vector3 coordinates to teleport to")
          .optional(),
        relativeOffset: z
          .object({
            x: z.number(),
            y: z.number(),
            z: z.number(),
          })
          .describe("Relative Vector3 offset from current position (e.g. {x:0, y:50, z:0} to jump up 50 studs)")
          .optional(),
        lookAt: z
          .object({
            x: z.number(),
            y: z.number(),
            z: z.number(),
          })
          .describe("Optional Vector3 coordinates for the character to face after teleporting")
          .optional(),
      }),
    },
    async (params) => {
      if (!params.targetPlayer && !params.coordinates && !params.relativeOffset) {
        return {
          content: [
            {
              type: "text" as const,
              text: "At least one target option must be specified: 'targetPlayer', 'coordinates', or 'relativeOffset'.",
            },
          ],
          isError: true,
        };
      }
      return sendAndWait({
        type: "teleport-player",
        data: params,
        failureMessage: (response) =>
          "Failed to teleport player. Response: " + JSON.stringify(response),
      });
    }
  );
}
