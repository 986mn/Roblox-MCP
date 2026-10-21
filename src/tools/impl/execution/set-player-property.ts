import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "set-player-property",
    {
      title: "Set properties of the player character",
      description:
        "Modify character stats or physics properties including WalkSpeed, JumpPower, JumpHeight, HipHeight, Gravity, and Noclip.",
      inputSchema: z.object({
        walkSpeed: z
          .number()
          .describe("The WalkSpeed of the local player character (Roblox default: 16)")
          .optional(),
        jumpPower: z
          .number()
          .describe("The JumpPower of the local player character (Roblox default: 50). Using this sets UseJumpPower = true.")
          .optional(),
        jumpHeight: z
          .number()
          .describe("The JumpHeight of the local player character (Roblox default: 7.2). Using this sets UseJumpPower = false.")
          .optional(),
        gravity: z
          .number()
          .describe("The global workspace gravity (Roblox default: 196.2)")
          .optional(),
        hipHeight: z
          .number()
          .describe("The HipHeight of the local player character (Roblox default is calculated based on rig size)")
          .optional(),
        noclip: z
          .boolean()
          .describe("Enable or disable Noclip (disables collisions for the player's character parts)")
          .optional(),
      }),
    },
    async (params) => {
      return sendAndWait({
        type: "set-player-property",
        data: params,
        failureMessage: (response) =>
          "Failed to set player properties. Response: " + JSON.stringify(response),
      });
    }
  );
}
