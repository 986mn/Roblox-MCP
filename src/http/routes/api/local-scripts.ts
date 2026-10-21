import fs from "fs";
import path from "path";
import type { IncomingMessage, ServerResponse } from "http";
import { readJsonBody } from "../../body.js";

const USER_SCRIPTS_DIR = path.join(process.cwd(), "user-scripts");

// Ensure user-scripts directory exists
if (!fs.existsSync(USER_SCRIPTS_DIR)) {
  fs.mkdirSync(USER_SCRIPTS_DIR, { recursive: true });
  // Add some sample scripts
  fs.writeFileSync(
    path.join(USER_SCRIPTS_DIR, "fly.luau"),
    `-- Simple fly script
local Player = game.Players.LocalPlayer
local Character = Player.Character
local Root = Character and Character:FindFirstChild("HumanoidRootPart")
if not Root then return end

local flySpeed = 50
local flying = true

-- Fly implementation`
  );
  fs.writeFileSync(
    path.join(USER_SCRIPTS_DIR, "noclip.luau"),
    `-- Simple noclip script
local Player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")

local Connection
Connection = RunService.Stepped:Connect(function()
    local Character = Player.Character
    if not Character then return end
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)

-- To disable, run: Connection:Disconnect()`
  );
}

export async function GET(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
  const file = url.searchParams.get("file");

  if (file) {
    // Read file content
    const safeFile = path.basename(file);
    const filePath = path.join(USER_SCRIPTS_DIR, safeFile);
    if (!fs.existsSync(filePath)) {
      res.writeHead(404, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "File not found" }));
      return;
    }

    const content = fs.readFileSync(filePath, "utf-8");
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ content }));
    return;
  }

  // List all files in the directory
  try {
    const files = fs.readdirSync(USER_SCRIPTS_DIR).filter(f => f.endsWith(".luau") || f.endsWith(".lua"));
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ files }));
  } catch (err) {
    res.writeHead(500, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: String(err) }));
  }
}

export async function POST(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
  const file = url.searchParams.get("file");
  if (!file) {
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Missing file parameter" }));
    return;
  }

  const safeFile = path.basename(file);
  if (!/\.(lua|luau)$/i.test(safeFile)) {
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Only .lua and .luau files can be saved" }));
    return;
  }
  const filePath = path.join(USER_SCRIPTS_DIR, safeFile);

  try {
    const body = await readJsonBody<{ content: string }>(req);
    if (typeof body.content !== "string") {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Missing content" }));
      return;
    }
    fs.writeFileSync(filePath, body.content, "utf-8");
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ success: true }));
  } catch (err) {
    res.writeHead(500, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: String(err) }));
  }
}
