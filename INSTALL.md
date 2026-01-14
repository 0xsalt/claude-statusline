# Installation Guide - Claude Statusline

> **AI Installation:** This pack is designed for AI-assisted installation. The AI should follow the steps below and prompt the user for customization preferences.

## Prerequisites

- Claude Code installed
- Bun runtime (for usage-fetcher.ts)
- jq (for JSON parsing in statusline)

## AI Installation Flow

When installing this pack, the AI should:

1. **Copy required files** (Steps 1-2 below)
2. **Update settings.json** (Step 3)
3. **Ask user:** "Would you like to personalize your statusline? You can customize:
   - Assistant name (default: 'Assistant')
   - Name color (purple/blue/green/cyan/yellow/orange)
   - Location/workspace name (optional, e.g., 'Home Lab')"
4. **If user wants customization:**
   - Copy config template to `~/.claude/statusline.env`
   - Prompt for each value and update the file
5. **If user declines:** Skip customization - defaults work fine
6. **Verify** the statusline works

## Quick Install

```bash
# Set your claude directory
CLAUDE_DIR="${PAI_DIR:-$HOME/.claude}"

# Copy statusline script
cp src/statusline-command.sh "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"

# Copy usage fetcher
mkdir -p "$CLAUDE_DIR/lib"
cp src/lib/usage-fetcher.ts "$CLAUDE_DIR/lib/usage-fetcher.ts"

# (Optional) Copy config template for customization
cp src/statusline.env.template "$CLAUDE_DIR/statusline.env"
```

## Configure settings.json

Add or update the statusLine section in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash $PAI_DIR/statusline-command.sh"
  }
}
```

**Note:** This requires `PAI_DIR` to be set in your settings.json `env` section (standard for PAI installations). If you don't have PAI_DIR configured, use the explicit path:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Customization (Optional)

Edit `~/.claude/statusline.env` to personalize your statusline:

```bash
# Your assistant's display name (default: "Assistant")
DA_NAME="Claude"

# Display name color: purple/blue/green/cyan/yellow/orange
DA_COLOR="blue"

# Your workspace/location name (leave empty to hide)
LOCATION="Home Lab"
```

**All settings are optional.** The statusline works out of the box with no configuration.

### Configuration Priority

The script checks for values in this order:
1. `~/.claude/statusline.env` file
2. Environment variables (`DA`, `DA_COLOR`, `LOCATION`)
3. Built-in defaults

## Verify Installation

```bash
# Test statusline
echo '{}' | bash ~/.claude/statusline-command.sh

# Test usage fetcher
bun run ~/.claude/lib/usage-fetcher.ts
```

## Troubleshooting

### Statusline not appearing
- Check settings.json has statusLine configured
- Verify script is executable: `chmod +x ~/.claude/statusline-command.sh`

### Usage shows "fetch_failed"
- Verify OAuth credentials exist: `~/.claude/.credentials.json`
- Check token hasn't expired

### Syntax errors
- Run: `bash -n ~/.claude/statusline-command.sh`
- Fix any reported issues

### Location not showing
- Ensure `LOCATION` is set in `~/.claude/statusline.env`
- Or set `LOCATION` environment variable in settings.json `env` section
