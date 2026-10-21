export type ToolFieldType = "text" | "textarea" | "select";

export interface ToolFieldOption {
  value: string;
  label: string;
}

export interface ToolField {
  key: string;
  label: string;
  type: ToolFieldType;
  placeholder?: string;
  default?: string;
  options?: ToolFieldOption[];
}

export interface ToolCatalogEntry {
  key: string;
  name: string;
  desc: string;
  category: "Search" | "Execution" | "Inspection" | "Remote Spy" | "GUI";
  fields: ToolField[];
}

export const DASHBOARD_TOOL_CATALOG: ToolCatalogEntry[] = [
  {
    key: "script-grep",
    name: "Script Grep",
    desc: "Search across all decompiled scripts using regex or literal patterns",
    category: "Search",
    fields: [
      { key: "query", label: "Search Pattern", type: "text", placeholder: "e.g. RemoteEvent or \\bfunction\\b" },
      {
        key: "literal",
        label: "Literal Match",
        type: "select",
        default: "false",
        options: [
          { value: "false", label: "Regex" },
          { value: "true", label: "Literal" },
        ],
      },
      {
        key: "caseSensitive",
        label: "Case Sensitive",
        type: "select",
        default: "true",
        options: [
          { value: "true", label: "Yes" },
          { value: "false", label: "No" },
        ],
      },
      { key: "limit", label: "Max Scripts", type: "text", placeholder: "50", default: "50" },
    ],
  },
  {
    key: "semantic-search",
    name: "Semantic Search",
    desc: "Natural language search across script sources using embeddings",
    category: "Search",
    fields: [
      { key: "query", label: "Natural Language Query", type: "text", placeholder: "e.g. inventory management logic" },
      { key: "limit", label: "Max Results", type: "text", placeholder: "10", default: "10" },
    ],
  },
  {
    key: "execute",
    name: "Execute Code",
    desc: "Run Luau code in the Roblox client",
    category: "Execution",
    fields: [{ key: "code", label: "Luau Code", type: "textarea", placeholder: "print(\"Hello from dashboard!\")" }],
  },
  {
    key: "execute-file",
    name: "Execute File",
    desc: "Run a local .luau or .lua file by absolute path",
    category: "Execution",
    fields: [{ key: "filePath", label: "Absolute File Path", type: "text", placeholder: "C:\\Users\\You\\script.luau" }],
  },
  {
    key: "get-data-by-code",
    name: "Get Data by Code",
    desc: "Execute Luau code and retrieve returned values",
    category: "Execution",
    fields: [
      { key: "code", label: "Luau Code", type: "textarea", placeholder: "return game.PlaceId" },
      { key: "timeout", label: "Timeout (ms)", type: "text", placeholder: "15000", default: "15000" },
    ],
  },
  {
    key: "search-instances",
    name: "Search Instances",
    desc: "Query game instances with QueryDescendants selectors",
    category: "Inspection",
    fields: [
      { key: "selector", label: "QueryDescendants Selector", type: "text", placeholder: "e.g. Part, Model > Humanoid, .Tagged" },
      { key: "root", label: "Root", type: "text", placeholder: "game", default: "game" },
      { key: "limit", label: "Max Results", type: "text", placeholder: "50", default: "50" },
    ],
  },
  {
    key: "get-console-output",
    name: "Console Output",
    desc: "Retrieve the client's console/output log",
    category: "Inspection",
    fields: [
      { key: "limit", label: "Max Lines", type: "text", placeholder: "50", default: "50" },
      { key: "filter", label: "Filter", type: "text", placeholder: "Only include lines containing this text" },
    ],
  },
  {
    key: "get-descendants-tree",
    name: "Descendants Tree",
    desc: "Explore the game instance hierarchy tree",
    category: "Inspection",
    fields: [
      { key: "root", label: "Root Instance", type: "text", placeholder: "game.Workspace" },
      { key: "maxDepth", label: "Max Depth", type: "text", placeholder: "3", default: "3" },
      { key: "classFilter", label: "Class Filter", type: "text", placeholder: "e.g. BasePart" },
    ],
  },
  { key: "get-game-info", name: "Game Info", desc: "Get PlaceId, GameId, version, and metadata", category: "Inspection", fields: [] },
  {
    key: "get-executor-environment",
    name: "Executor Environment",
    desc: "Query available executor APIs and globals",
    category: "Inspection",
    fields: [],
  },
  {
    key: "get-instance-properties",
    name: "Instance Properties",
    desc: "Inspect properties, attributes, and tags of a Roblox instance",
    category: "Inspection",
    fields: [
      { key: "root", label: "Root path or expression", type: "text", placeholder: "game.Workspace.Part or game.Players.LocalPlayer" },
      { key: "debugId", label: "Debug ID", type: "text", placeholder: "GetDebugId() hash if path is unavailable" },
      { key: "properties", label: "Comma-separated properties", type: "text", placeholder: "e.g. Size, Anchored, Color" },
    ],
  },
  {
    key: "teleport-player",
    name: "Teleport Player",
    desc: "Teleport the character to a player, coordinate, or offset",
    category: "Execution",
    fields: [
      { key: "targetPlayer", label: "Target Player Name", type: "text", placeholder: "Username of player to teleport to" },
      { key: "coordinates", label: "Coordinates X,Y,Z", type: "text", placeholder: "e.g. 0, 50, 0" },
      { key: "relativeOffset", label: "Relative Offset X,Y,Z", type: "text", placeholder: "e.g. 0, 10, -5" },
      { key: "lookAt", label: "LookAt Coordinates X,Y,Z", type: "text", placeholder: "Make character face these coordinates" },
    ],
  },
  {
    key: "set-player-property",
    name: "Player Properties",
    desc: "Set player/character properties such as WalkSpeed, Noclip, or Gravity",
    category: "Execution",
    fields: [
      { key: "walkSpeed", label: "Walk Speed", type: "text", placeholder: "Roblox default: 16" },
      { key: "jumpPower", label: "Jump Power", type: "text", placeholder: "Roblox default: 50" },
      { key: "jumpHeight", label: "Jump Height", type: "text", placeholder: "Roblox default: 7.2" },
      { key: "gravity", label: "Gravity", type: "text", placeholder: "Roblox default: 196.2" },
      { key: "hipHeight", label: "Hip Height", type: "text", placeholder: "Custom rig hip height offset" },
      {
        key: "noclip",
        label: "Noclip",
        type: "select",
        default: "",
        options: [
          { value: "", label: "Unchanged" },
          { value: "true", label: "Enable" },
          { value: "false", label: "Disable" },
        ],
      },
    ],
  },
  { key: "ensure-remote-spy", name: "Ensure Remote Spy", desc: "Load or verify Cobalt remote spy", category: "Remote Spy", fields: [] },
  {
    key: "get-remote-spy-logs",
    name: "Remote Spy Logs",
    desc: "List captured Cobalt remote and bindable call logs",
    category: "Remote Spy",
    fields: [
      {
        key: "direction",
        label: "Direction",
        type: "select",
        default: "Both",
        options: [
          { value: "Both", label: "Both" },
          { value: "Incoming", label: "Incoming" },
          { value: "Outgoing", label: "Outgoing" },
        ],
      },
      { key: "remoteNameFilter", label: "Name Filter", type: "text", placeholder: "Remote name contains..." },
      { key: "limit", label: "Max Remotes", type: "text", placeholder: "50", default: "50" },
      { key: "maxCallsPerRemote", label: "Calls per Remote", type: "text", placeholder: "5", default: "5" },
    ],
  },
  { key: "clear-remote-spy-logs", name: "Clear Remote Logs", desc: "Clear all captured Cobalt remote spy logs", category: "Remote Spy", fields: [] },
  {
    key: "block-remote",
    name: "Block Remote",
    desc: "Block or unblock a remote by exact name and direction",
    category: "Remote Spy",
    fields: [
      { key: "remoteName", label: "Remote Name", type: "text", placeholder: "Exact remote name" },
      {
        key: "direction",
        label: "Direction",
        type: "select",
        default: "Outgoing",
        options: [
          { value: "Incoming", label: "Incoming" },
          { value: "Outgoing", label: "Outgoing" },
        ],
      },
      {
        key: "shouldBlock",
        label: "Action",
        type: "select",
        default: "true",
        options: [
          { value: "true", label: "Block" },
          { value: "false", label: "Unblock" },
        ],
      },
    ],
  },
  {
    key: "ignore-remote",
    name: "Ignore Remote",
    desc: "Ignore or unignore remote spy logging for a remote",
    category: "Remote Spy",
    fields: [
      { key: "remoteName", label: "Remote Name", type: "text", placeholder: "Exact remote name" },
      {
        key: "direction",
        label: "Direction",
        type: "select",
        default: "Outgoing",
        options: [
          { value: "Incoming", label: "Incoming" },
          { value: "Outgoing", label: "Outgoing" },
        ],
      },
      {
        key: "shouldIgnore",
        label: "Action",
        type: "select",
        default: "true",
        options: [
          { value: "true", label: "Ignore" },
          { value: "false", label: "Unignore" },
        ],
      },
    ],
  },
  {
    key: "fire-remote",
    name: "Fire Remote",
    desc: "Invoke/fire a RemoteEvent or RemoteFunction with custom parameters",
    category: "Remote Spy",
    fields: [
      { key: "path", label: "Remote Path", type: "text", placeholder: "game.ReplicatedStorage.RemoteEvent" },
      { key: "args", label: "Arguments (JSON array)", type: "text", placeholder: "[\"hello\", 123]" },
      {
        key: "isFunction",
        label: "Is RemoteFunction",
        type: "select",
        default: "false",
        options: [
          { value: "false", label: "No (RemoteEvent)" },
          { value: "true", label: "Yes (RemoteFunction)" },
        ],
      },
    ],
  },
  {
    key: "click-button",
    name: "Click Button",
    desc: "Fire click signals on a TextButton or ImageButton",
    category: "GUI",
    fields: [
      { key: "path", label: "Button Path", type: "text", placeholder: "game.Players.LocalPlayer.PlayerGui.ScreenGui.Button" },
      { key: "action", label: "Signal", type: "text", placeholder: "Activated or MouseButton1Click" },
    ],
  },
  {
    key: "type-text-box",
    name: "Type TextBox",
    desc: "Enter text into a Roblox TextBox by path",
    category: "GUI",
    fields: [
      { key: "path", label: "TextBox Path", type: "text", placeholder: "game.Players.LocalPlayer.PlayerGui.ScreenGui.TextBox" },
      { key: "text", label: "Text", type: "text", placeholder: "Text to enter" },
      {
        key: "enter",
        label: "Press Enter",
        type: "select",
        default: "false",
        options: [
          { value: "false", label: "No" },
          { value: "true", label: "Yes" },
        ],
      },
      {
        key: "useKeyPress",
        label: "Input Mode",
        type: "select",
        default: "true",
        options: [
          { value: "true", label: "Simulate keystrokes" },
          { value: "false", label: "Set Text directly" },
        ],
      },
    ],
  },
];
