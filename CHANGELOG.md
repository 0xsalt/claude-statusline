# Changelog

All notable changes to claude-statusline will be documented in this file.

## [1.1.0] - 2026-01-08

### Added
- `statusline.env.template` - Configuration file for customization
- MIT LICENSE file
- Support for `LOCATION` env var (generic alternative to `HOTEL`)

### Changed
- Renamed pack from "Arcana Statusline" to "Claude Statusline" for public release
- Location display is now conditional (only shows if `LOCATION` or `HOTEL` is set)
- Updated documentation with generic examples
- Configuration priority: statusline.env > env vars > defaults

### Backwards Compatible
- `HOTEL` env var still works (maps to `LOCATION` internally)
- Existing setups continue to work without changes

## [1.0.0] - 2026-01-08

### Added
- Initial release (extracted from arcana-hotel)
- `statusline-command.sh` - 4-line status display
- `lib/usage-fetcher.ts` - Claude API usage tracking with caching
- Usage limits display (5h/7d) with time-remaining format
- Color-coded usage indicators (green/yellow/orange/red)
- Context bar visualization
- MCP server display (reads from enabledMcpjsonServers)
- System stats (virt type, cores, memory, disk, load)

### Features
- 4-minute cache with ±60 second jitter for API calls
- OAuth token auto-discovery from ~/.claude/.credentials.json
- Tokyo Night Storm color theme
- Graceful fallback on API errors
