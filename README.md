---
name: Claude Statusline
pack-id: claude-statusline-v1.1.0
version: 1.1.0
author: 0xsalt
description: Custom statusline for Claude Code with usage tracking, context display, and system stats
type: feature
purpose-type: [ui, monitoring]
platform: claude-code
dependencies: []
keywords: [statusline, usage, context, monitoring, display, claude-code]
license: MIT
---

# Claude Statusline

> Custom multi-line statusline with Claude API usage tracking

## What This Pack Does

Provides a comprehensive statusline for Claude Code:

- **Identity Display** - Assistant name, optional location, CC version, model
- **Usage Tracking** - 5h/7d API usage limits with time-remaining
- **Context Monitoring** - Visual context bar with percentage
- **MCP Display** - Lists enabled MCP servers
- **System Stats** - CPU, memory, disk, load averages

## What's Included

| Component | File | Purpose |
|-----------|------|---------|
| Statusline Script | `src/statusline-command.sh` | Main 4-line status display |
| Usage Fetcher | `src/lib/usage-fetcher.ts` | API usage with 4min ±60s cache |
| Config Template | `src/statusline.env.template` | Optional customization |

## Features

### Usage Tracking
- Fetches from `api.anthropic.com/api/oauth/usage`
- Caches responses for 4 minutes (±60s jitter)
- Shows time remaining until reset
- Color-coded: green (<40%), yellow (40-59%), orange (60-79%), red (80%+)

### Statusline Layout

**Default (no customization):**
```
Assistant · CC 2.1.1 · Opus · [project] · (repo:branch)
Context: ◽◽◽◾◾◾◾◾◾◾ 30% · Usage: 5h: 15% (4h 30m) · 7d: 45%/42% (3d 15h)
MCPs: Playwright, BrightData
System: vm · 8 cores · 1.6Gi/16Gi mem · 45G/100G disk · load 0.95/0.81/0.91
```

**With customization (DA_NAME + LOCATION):**
```
Aria at Home Lab · CC 2.1.1 · Opus · [project] · (repo:branch)
Context: ◽◽◽◾◾◾◾◾◾◾ 30% · Usage: 5h: 15% (4h 30m) · 7d: 45%/42% (3d 15h)
MCPs: Playwright, BrightData
System: vm · 8 cores · 1.6Gi/16Gi mem · 45G/100G disk · load 0.95/0.81/0.91
```

**Usage format explained:**
- `5h: 15% (4h 30m)` — 15% of 5-hour limit used, resets in 4h 30m
- `7d: 45%/42% (3d 15h)` — 45% used vs 42% budget (on track), resets in 3d 15h
  - Green: under budget | Red: over budget

## Customization

Copy `statusline.env.template` to `~/.claude/statusline.env` and edit:

```bash
# Your assistant's display name (e.g., "Claude", "Aria", "Helper")
DA_NAME="YourAssistantName"

# Display name color: purple/blue/green/cyan/yellow/orange
DA_COLOR="cyan"

# Your workspace name (leave empty to hide)
LOCATION="Home Lab"
```

All settings are optional - the statusline works out of the box with sensible defaults.

## Dependencies

- None (standalone pack)

## Installation

See [INSTALL.md](INSTALL.md).

## Verification

See [VERIFY.md](VERIFY.md) or run `bash verify.sh`.
