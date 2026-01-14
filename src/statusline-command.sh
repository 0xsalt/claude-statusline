#!/bin/bash

# PAI Statusline Command
# Displays system status, context usage, and capabilities
# Receives JSON input from Claude Code via stdin

# Read JSON input from stdin
input=$(cat)

# =============================================================================
# CONFIGURATION
# =============================================================================
# Priority: statusline.env file > environment variables > defaults

# Determine claude directory early (needed for config file)
claude_dir="${PAI_DIR:-$HOME/.claude}"
if [[ ! "$claude_dir" == *".claude" ]]; then
    claude_dir="$claude_dir/.claude"
fi

# Source config file if exists
if [ -f "$claude_dir/statusline.env" ]; then
    source "$claude_dir/statusline.env"
fi

# Get Digital Assistant configuration (env vars override config file)
DA_NAME="${DA:-${DA_NAME:-Assistant}}"
DA_COLOR="${DA_COLOR:-purple}"

# Location: check LOCATION first, then HOTEL for backwards compatibility
# Empty string means "don't show location"
LOCATION="${LOCATION:-${HOTEL:-}}"

# =============================================================================
# EXTRACT DATA FROM JSON INPUT (provided by Claude Code)
# =============================================================================

# Version and model info
cc_version=$(echo "$input" | jq -r '.version // "?.?.?"')
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
model_id=$(echo "$input" | jq -r '.model.id // ""')

# Workspace info
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
dir_name=$(basename "$current_dir")

# Context window data (official API since v2.0.70)
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
current_usage=$(echo "$input" | jq '.context_window.current_usage // null')

# Calculate context percentage
if [ "$current_usage" != "null" ]; then
    input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
    cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')
    current_tokens=$((input_tokens + cache_creation + cache_read))
    context_percent=$((current_tokens * 100 / context_size))
else
    context_percent=0
    current_tokens=0
fi

# Cost data
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# =============================================================================
# CLAUDE USAGE LIMITS (5hr/7day windows)
# =============================================================================

usage_5h_pct=""
usage_7d_pct=""
usage_5h_reset=""
usage_7d_reset=""
usage_7d_budget=""
usage_error=""

# Fetch usage data (cached, ~3 min TTL)
if [ -f "$claude_dir/lib/usage-fetcher.ts" ]; then
    usage_json=$(bun run "$claude_dir/lib/usage-fetcher.ts" 2>/dev/null)
    if [ -n "$usage_json" ]; then
        usage_5h_pct=$(echo "$usage_json" | jq -r '.five_hour_pct // ""')
        usage_7d_pct=$(echo "$usage_json" | jq -r '.seven_day_pct // ""')
        usage_5h_reset=$(echo "$usage_json" | jq -r '.five_hour_reset // ""')
        usage_7d_reset=$(echo "$usage_json" | jq -r '.seven_day_reset // ""')
        usage_7d_budget=$(echo "$usage_json" | jq -r '.seven_day_budget // ""')
        usage_error=$(echo "$usage_json" | jq -r '.error // ""')
    fi
fi

# =============================================================================
# GIT/HOTEL INFORMATION
# =============================================================================

git_repo=""
git_branch=""
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git_remote_url=$(git -C "$current_dir" remote get-url origin 2>/dev/null || \
                     git -C "$current_dir" remote get-url "$(git -C "$current_dir" remote | head -1)" 2>/dev/null || \
                     echo "")
    if [ -n "$git_remote_url" ]; then
        git_repo=$(echo "$git_remote_url" | sed -E 's#.*/([^/]+)\.git$#\1#')
    else
        git_repo=$(basename "$(git -C "$current_dir" rev-parse --show-toplevel)")
    fi
    git_branch=$(git -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# =============================================================================
# COUNT CAPABILITIES
# =============================================================================

# Count skills (directories in skills/)
skills_count=0
if [ -d "$claude_dir/skills" ]; then
    skills_count=$(find "$claude_dir/skills" -maxdepth 1 -type d -not -path "$claude_dir/skills" 2>/dev/null | wc -l | tr -d ' ')
fi

# Count commands (check multiple locations)
commands_count=0
# Primary: Arcana commands
if [ -d "$claude_dir/Arcana/commands" ]; then
    commands_count=$(ls -1 "$claude_dir/Arcana/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
fi
# Fallback: direct commands directory
if [ "$commands_count" -eq 0 ] && [ -d "$claude_dir/commands" ]; then
    commands_count=$(ls -1 "$claude_dir/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
fi

# Count MCPs - from .mcpServers keys (standard) or .enabledMcpjsonServers (legacy)
# Check both settings.json and settings.local.json
mcp_names_raw=""
mcps_count=0
for settings_file in "$claude_dir/settings.json" "$claude_dir/settings.local.json"; do
    if [ -f "$settings_file" ] && [ "$mcps_count" -eq 0 ]; then
        # Try .mcpServers first (standard), fallback to .enabledMcpjsonServers (legacy)
        mcp_data=$(jq -r '
          (if .mcpServers then (.mcpServers | keys) else .enabledMcpjsonServers // [] end)
          | join(" "), length
        ' "$settings_file" 2>/dev/null)
        mcp_names_raw=$(echo "$mcp_data" | head -1)
        mcps_count=$(echo "$mcp_data" | tail -1)
    fi
done

# Count Fabric patterns
fabric_count=0
fabric_patterns_dir="$claude_dir/skills/fabric/fabric-repo/patterns"
if [ ! -d "$fabric_patterns_dir" ]; then
    fabric_patterns_dir="${HOME}/.config/fabric/patterns"
fi
if [ -d "$fabric_patterns_dir" ]; then
    fabric_count=$(find "$fabric_patterns_dir" -maxdepth 1 -type d -not -path "$fabric_patterns_dir" 2>/dev/null | wc -l | tr -d ' ')
fi

# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

# Detect virtualization type
virt_type="metal"
if command -v systemd-detect-virt >/dev/null 2>&1; then
    detected=$(systemd-detect-virt 2>/dev/null)
    case "$detected" in
        "none") virt_type="metal" ;;
        "kvm"|"qemu") virt_type="vm" ;;
        "docker"|"podman"|"lxc"|"lxc-libvirt"|"systemd-nspawn") virt_type="ct" ;;
        *) virt_type="$detected" ;;
    esac
elif [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup 2>/dev/null; then
    virt_type="ct"
elif [ -f /.dockerenv ]; then
    virt_type="ct"
fi

# CPU cores
cpu_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "?")

# Memory (Linux)
if command -v free >/dev/null 2>&1; then
    mem_info=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
else
    # macOS fallback
    mem_info="N/A"
fi

# Disk usage for root or home
disk_info=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2}')

# Load average (1/5/15 min)
if [ -f /proc/loadavg ]; then
    load_avg=$(awk '{print $1 "/" $2 "/" $3}' /proc/loadavg)
else
    load_avg=$(uptime | sed -E 's/.*load average[s]?: ([0-9.]+),? ([0-9.]+),? ([0-9.]+).*/\1\/\2\/\3/')
fi

# =============================================================================
# CONTEXT VISUAL BAR
# =============================================================================

# Generate visual context bar (10 segments)
# Returns: filled_part|empty_part (to be colored separately)
generate_context_bar() {
    local percent=$1
    local filled=$((percent / 10))
    local empty=$((10 - filled))
    local filled_bar=""
    local empty_bar=""

    for ((i=0; i<filled; i++)); do
        filled_bar+="◽"  # White/bright for USED
    done
    for ((i=0; i<empty; i++)); do
        empty_bar+="◾"  # Black/dark for UNUSED
    done

    echo "${filled_bar}|${empty_bar}"
}

context_bar_raw=$(generate_context_bar $context_percent)
context_bar_filled="${context_bar_raw%%|*}"
context_bar_empty="${context_bar_raw##*|}"

# =============================================================================
# COLORS - Tokyo Night Storm Theme
# =============================================================================

RESET='\033[0m'
BRIGHT_PURPLE='\033[38;2;187;154;247m'
BRIGHT_BLUE='\033[38;2;122;162;247m'
DARK_BLUE='\033[38;2;100;140;200m'
BRIGHT_GREEN='\033[38;2;158;206;106m'
DARK_GREEN='\033[38;2;130;170;90m'
BRIGHT_ORANGE='\033[38;2;255;158;100m'
BRIGHT_CYAN='\033[38;2;125;207;255m'
BRIGHT_YELLOW='\033[38;2;224;175;104m'
DIM='\033[38;2;169;177;214m'
VERY_DIM='\033[38;2;80;85;100m'  # Dark gray for unused context
SEPARATOR='\033[38;2;140;152;180m'
BOLD_ORANGE='\033[1;38;2;255;165;0m'

# Map DA_COLOR to actual ANSI color code
case "$DA_COLOR" in
    "purple") DA_DISPLAY_COLOR='\033[38;2;147;112;219m' ;;
    "blue") DA_DISPLAY_COLOR="$BRIGHT_BLUE" ;;
    "green") DA_DISPLAY_COLOR="$BRIGHT_GREEN" ;;
    "cyan") DA_DISPLAY_COLOR="$BRIGHT_CYAN" ;;
    "yellow") DA_DISPLAY_COLOR="$BRIGHT_YELLOW" ;;
    "orange") DA_DISPLAY_COLOR="$BRIGHT_ORANGE" ;;
    *) DA_DISPLAY_COLOR='\033[38;2;147;112;219m' ;;
esac

# Context bar color based on usage
if [ $context_percent -ge 80 ]; then
    CONTEXT_COLOR='\033[38;2;247;118;142m'  # Red - danger
elif [ $context_percent -ge 60 ]; then
    CONTEXT_COLOR="$BRIGHT_ORANGE"           # Orange - warning
elif [ $context_percent -ge 40 ]; then
    CONTEXT_COLOR="$BRIGHT_YELLOW"           # Yellow - caution
else
    CONTEXT_COLOR="$BRIGHT_GREEN"            # Green - good
fi

# Usage colors based on percentage (same thresholds as context)
get_usage_color() {
    local pct=$1
    if [ -z "$pct" ] || [ "$pct" = "null" ]; then
        echo "$DIM"
    elif [ "$pct" -ge 80 ]; then
        echo '\033[38;2;247;118;142m'  # Red - danger
    elif [ "$pct" -ge 60 ]; then
        echo "$BRIGHT_ORANGE"           # Orange - warning
    elif [ "$pct" -ge 40 ]; then
        echo "$BRIGHT_YELLOW"           # Yellow - caution
    else
        echo "$BRIGHT_GREEN"            # Green - good
    fi
}

USAGE_5H_COLOR=$(get_usage_color "$usage_5h_pct")
USAGE_7D_COLOR=$(get_usage_color "$usage_7d_pct")

# 7-day budget coloring: red if over budget, green if under
USAGE_7D_BUDGET_COLOR="$BRIGHT_GREEN"
if [ -n "$usage_7d_pct" ] && [ -n "$usage_7d_budget" ] && [ "$usage_7d_pct" != "null" ] && [ "$usage_7d_budget" != "null" ]; then
    if [ "$usage_7d_pct" -gt "$usage_7d_budget" ]; then
        USAGE_7D_BUDGET_COLOR='\033[38;2;247;118;142m'  # Red - over budget
    fi
fi

# =============================================================================
# FORMAT MCP NAMES
# =============================================================================

mcp_names_formatted=""
for mcp in $mcp_names_raw; do
    case "$mcp" in
        "playwright") formatted="${BRIGHT_BLUE}Playwright${RESET}" ;;
        "brightdata") formatted="${BRIGHT_ORANGE}BrightData${RESET}" ;;
        "httpx") formatted="${DARK_BLUE}HTTPx${RESET}" ;;
        *) formatted="${DIM}${mcp^}${RESET}" ;;
    esac

    if [ -z "$mcp_names_formatted" ]; then
        mcp_names_formatted="$formatted"
    else
        mcp_names_formatted="$mcp_names_formatted${SEPARATOR}, ${formatted}"
    fi
done

# =============================================================================
# OUTPUT STATUSLINE
# =============================================================================

# Separators (unicode)
SEP_DOT="·"  # middle dot U+00B7

# LINE 1: Identity + Versions + [cwd] + (git)
# Build location portion (only if LOCATION is set)
location_part=""
if [ -n "$LOCATION" ]; then
    # Convert from kebab-case to Title Case (e.g., "the-raven" -> "The Raven")
    location_name=$(echo "$LOCATION" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    location_part=" ${DIM}at${RESET} ${BRIGHT_ORANGE}${location_name}${RESET}"
fi
printf "${DA_DISPLAY_COLOR}${DA_NAME}${RESET}${location_part} ${DIM}${SEP_DOT}${RESET} ${BRIGHT_PURPLE}CC ${cc_version}${RESET} ${DIM}${SEP_DOT}${RESET} ${BRIGHT_CYAN}${model_name}${RESET} ${DIM}${SEP_DOT}${RESET} ${DIM}[${RESET}${BRIGHT_PURPLE}${dir_name}${RESET}${DIM}]${RESET} ${DIM}${SEP_DOT}${RESET} ${DIM}(${RESET}${BOLD_ORANGE}${git_repo}:${git_branch}${RESET}${DIM})${RESET}\n"

# LINE 2: Context + Usage
context_line="${DIM}Context:${RESET} ${CONTEXT_COLOR}${context_bar_filled}${VERY_DIM}${context_bar_empty}${RESET} ${BRIGHT_ORANGE}${context_percent}%%${RESET}"
if [ -n "$usage_5h_pct" ] && [ "$usage_5h_pct" != "null" ]; then
    context_line+=" ${DIM}${SEP_DOT}${RESET} ${DIM}Usage:${RESET} "
    context_line+="${USAGE_5H_COLOR}5h: ${usage_5h_pct}%%${RESET}"
    if [ -n "$usage_5h_reset" ] && [ "$usage_5h_reset" != "null" ]; then
        context_line+="${DIM} (${usage_5h_reset})${RESET}"
    fi
    context_line+=" ${DIM}${SEP_DOT}${RESET} "
    # 7d usage with budget: 45%/42% format (red if over, green if under)
    if [ -n "$usage_7d_budget" ] && [ "$usage_7d_budget" != "null" ]; then
        context_line+="${DIM}7d: ${RESET}${USAGE_7D_BUDGET_COLOR}${usage_7d_pct}%%${RESET}${DIM}/${usage_7d_budget}%%${RESET}"
    else
        context_line+="${USAGE_7D_COLOR}7d: ${usage_7d_pct}%%${RESET}"
    fi
    if [ -n "$usage_7d_reset" ] && [ "$usage_7d_reset" != "null" ]; then
        context_line+="${DIM} (${usage_7d_reset})${RESET}"
    fi
    if [ "$usage_error" = "stale" ]; then
        context_line+=" ${VERY_DIM}[cached]${RESET}"
    fi
fi
printf "${context_line}\n"

# LINE 3: MCP list (if any)
if [ -n "$mcp_names_formatted" ]; then
    printf "${DIM}MCPs:${RESET} ${mcp_names_formatted}\n"
fi

# LINE 4: System stats
printf "${DIM}System:${RESET} ${BRIGHT_CYAN}${virt_type}${RESET} ${DIM}${SEP_DOT}${RESET} ${DIM}${cpu_cores} cores${RESET} ${DIM}${SEP_DOT}${RESET} ${BRIGHT_GREEN}${mem_info} mem${RESET} ${DIM}${SEP_DOT}${RESET} ${BRIGHT_YELLOW}${disk_info} disk${RESET} ${DIM}${SEP_DOT}${RESET} ${BRIGHT_ORANGE}load ${load_avg}${RESET}\n"
