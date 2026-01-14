# Verification Guide - Claude Statusline

## Quick Verification

Run the verification script:

```bash
bash verify.sh
```

## Manual Verification

### 1. Check Files Exist

```bash
ls -la ~/.claude/statusline-command.sh
ls -la ~/.claude/lib/usage-fetcher.ts
```

### 2. Test Statusline Execution

```bash
echo '{}' | bash ~/.claude/statusline-command.sh
```

**Expected output (4 lines, default config):**
```
Assistant · CC ?.?.? · Unknown · [~] · (:)
Context: ◾◾◾◾◾◾◾◾◾◾ 0% · Usage: 5h: 15% (4h 30m) · 7d: 45%/42% (3d 15h)
MCPs: (none or your configured MCPs)
System: vm · 8 cores · 1.6Gi/16Gi mem · 45G/100G disk · load 0.95/0.81/0.91
```

**With customization (DA_NAME + LOCATION):**
```
Aria at Home Lab · CC ?.?.? · Unknown · [~] · (:)
Context: ◾◾◾◾◾◾◾◾◾◾ 0% · Usage: 5h: 15% (4h 30m) · 7d: 45%/42% (3d 15h)
MCPs: Playwright, BrightData
System: vm · 8 cores · 1.6Gi/16Gi mem · 45G/100G disk · load 0.95/0.81/0.91
```

**Note:** The 7d usage shows `actual%/budget%` — green if under budget, red if over.

### 3. Test Usage Fetcher

```bash
bun run ~/.claude/lib/usage-fetcher.ts
```

Expected output (JSON):
```json
{"five_hour_pct":15,"seven_day_pct":45,"five_hour_reset":"4h 30m","seven_day_reset":"3d 15h","seven_day_budget":42}
```

Or if no OAuth token:
```json
{"error":"no_token"}
```

### 4. Check settings.json Configuration

```bash
jq '.statusLine' ~/.claude/settings.json
```

Expected:
```json
{
  "type": "command",
  "command": "bash $PAI_DIR/statusline-command.sh"
}
```

## Validation Checklist

- [ ] statusline-command.sh exists and is executable
- [ ] usage-fetcher.ts exists
- [ ] Statusline executes without syntax errors
- [ ] Usage fetcher returns valid JSON
- [ ] settings.json has statusLine configured
- [ ] Statusline appears in Claude Code

## Optional: Verify Customization

If you created `~/.claude/statusline.env`:

```bash
cat ~/.claude/statusline.env
```

Should show your custom values:
```bash
DA_NAME="YourName"
DA_COLOR="blue"
LOCATION="Your Location"
```
