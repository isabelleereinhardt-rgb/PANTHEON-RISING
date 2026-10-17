# Connecting Claude to Your Roblox Studio Project

## Why Claude could not see your game yet

The first session ran in a **cloud container** (a remote Linux computer). Roblox Studio
runs on **your Windows laptop**. The Studio MCP connection is a local program
(`%LOCALAPPDATA%\Roblox\mcp.bat`) that only works when Claude Code also runs **on that
same laptop**. So the cloud session cannot see or edit your place.

## How to connect (on your laptop)

1. Install Claude Code on Windows (see https://code.claude.com/docs).
2. Open **Roblox Studio** and open the Pantheon Rising place.
3. Make sure Studio's MCP server feature is turned on in Studio (Assistant / MCP settings).
   If `%LOCALAPPDATA%\Roblox\mcp.bat` does not exist, Studio's MCP is not installed yet.
4. In a terminal (PowerShell or Command Prompt), run this **once**:

   ```
   claude mcp add --transport stdio Roblox_Studio -- "cmd.exe" "/c" "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
   ```

   (You pasted this command twice in your message. You only need to run it once. If it says the
   name already exists, it is already added.)
5. Start `claude` in that terminal and run `/mcp`. `Roblox_Studio` should show as **connected**.
6. Clone this GitHub repo on the laptop and start Claude in that folder, so it can read
   `docs/AUDIT-01.md` and `tools/StudioInventory.lua`.

## First thing to ask Claude once connected

> Run `tools/StudioInventory.lua` through the Roblox Studio MCP (read-only), then complete the
> "Project inventory" section of `docs/AUDIT-01.md` using the real output. Don't change anything in the place yet.

## No laptop session? Use this instead

Open Studio, then **View > Command Bar**, paste all of `tools/StudioInventory.lua`, and press Enter.
Copy everything between `===== HONORIS INVENTORY BEGIN =====` and `END` from the Output window
and paste it into a chat with Claude. The script only reads your place. It never changes it.

## Before any edits: make a backup

**File > Save to File As...** and save `PantheonRising_backup_YYYY-MM-DD.rbxl` to your computer.
That file is your rollback point.
