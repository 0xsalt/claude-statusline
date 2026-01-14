#!/usr/bin/env bun
/**
 * Claude Usage Fetcher
 * Fetches 5hr/7day usage limits from Anthropic's OAuth usage endpoint.
 * Caches results to avoid excessive API calls.
 */

import { readFileSync, writeFileSync, existsSync, statSync } from "fs";
import { homedir } from "os";

// Configuration
const CACHE_FILE = "/tmp/.claude_usage_cache";
const CACHE_TTL_MS = 4 * 60 * 1000; // 4 minutes
const CACHE_JITTER_MS = 60 * 1000; // ±60 seconds jitter
const CREDENTIALS_PATH = `${homedir()}/.claude/.credentials.json`;
const API_URL = "https://api.anthropic.com/api/oauth/usage";

interface UsageWindow {
  utilization: number;
  resets_at: string;
}

interface UsageData {
  five_hour: UsageWindow | null;
  seven_day: UsageWindow | null;
  seven_day_oauth_apps?: UsageWindow | null;
  seven_day_opus?: UsageWindow | null;
  seven_day_sonnet?: UsageWindow | null;
}

interface CacheData {
  timestamp: number;
  jitter: number;
  data: UsageData;
}

interface OutputData {
  five_hour_pct: number;
  seven_day_pct: number;
  five_hour_reset: string;
  seven_day_reset: string;
  seven_day_budget?: number;
  opus_pct?: number;
  error?: string;
}

function getOAuthToken(): string | null {
  try {
    const creds = JSON.parse(readFileSync(CREDENTIALS_PATH, "utf-8"));
    return creds?.claudeAiOauth?.accessToken ?? null;
  } catch {
    return null;
  }
}

function readCache(): CacheData | null {
  try {
    if (!existsSync(CACHE_FILE)) return null;
    const content = readFileSync(CACHE_FILE, "utf-8");
    return JSON.parse(content);
  } catch {
    return null;
  }
}

function writeCache(data: UsageData): void {
  const jitter = Math.floor(Math.random() * CACHE_JITTER_MS * 2) - CACHE_JITTER_MS;
  const cacheData: CacheData = {
    timestamp: Date.now(),
    jitter,
    data,
  };
  try {
    writeFileSync(CACHE_FILE, JSON.stringify(cacheData), { mode: 0o600 });
  } catch {
    // Ignore cache write failures
  }
}

function isCacheValid(cache: CacheData): boolean {
  const effectiveTTL = CACHE_TTL_MS + cache.jitter;
  return Date.now() - cache.timestamp < effectiveTTL;
}

function formatTimeRemaining(isoString: string): string {
  try {
    const resetTime = new Date(isoString);
    const now = new Date();
    const diffMs = resetTime.getTime() - now.getTime();

    if (diffMs <= 0) {
      return "now";
    }

    const totalMinutes = Math.floor(diffMs / (1000 * 60));
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;

    if (hours === 0) {
      return `${minutes}m`;
    }

    return `${hours}h ${minutes}m`;
  } catch {
    return "?";
  }
}

function calculateBudget(isoString: string): number | null {
  try {
    const resetTime = new Date(isoString);
    const now = new Date();
    const diffMs = resetTime.getTime() - now.getTime();

    if (diffMs <= 0) {
      return 100;
    }

    // Continuous rate: 14%/day = 100%/168h
    // Budget = percentage of 7-day window elapsed
    const hoursRemaining = diffMs / (1000 * 60 * 60);
    const hoursElapsed = 168 - hoursRemaining;
    const budget = Math.round((hoursElapsed / 168) * 100);

    return Math.max(0, Math.min(100, budget));
  } catch {
    return null;
  }
}

async function fetchUsage(token: string): Promise<UsageData> {
  const response = await fetch(API_URL, {
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      "anthropic-beta": "oauth-2025-04-20",
      "User-Agent": "claude-code-statusline/1.1.0",
    },
  });

  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }

  return response.json();
}

async function main(): Promise<void> {
  // Check cache first
  const cache = readCache();
  if (cache && isCacheValid(cache)) {
    const output: OutputData = {
      five_hour_pct: Math.round(cache.data.five_hour?.utilization ?? 0),
      seven_day_pct: Math.round(cache.data.seven_day?.utilization ?? 0),
      five_hour_reset: formatTimeRemaining(cache.data.five_hour?.resets_at ?? ""),
      seven_day_reset: formatTimeRemaining(cache.data.seven_day?.resets_at ?? ""),
    };
    const budget = calculateBudget(cache.data.seven_day?.resets_at ?? "");
    if (budget !== null) {
      output.seven_day_budget = budget;
    }
    if (cache.data.seven_day_opus) {
      output.opus_pct = Math.round(cache.data.seven_day_opus.utilization);
    }
    console.log(JSON.stringify(output));
    return;
  }

  // Get OAuth token
  const token = getOAuthToken();
  if (!token) {
    console.log(JSON.stringify({ error: "no_token" }));
    return;
  }

  // Fetch from API
  try {
    const data = await fetchUsage(token);
    writeCache(data);

    const output: OutputData = {
      five_hour_pct: Math.round(data.five_hour?.utilization ?? 0),
      seven_day_pct: Math.round(data.seven_day?.utilization ?? 0),
      five_hour_reset: formatTimeRemaining(data.five_hour?.resets_at ?? ""),
      seven_day_reset: formatTimeRemaining(data.seven_day?.resets_at ?? ""),
    };
    const budget = calculateBudget(data.seven_day?.resets_at ?? "");
    if (budget !== null) {
      output.seven_day_budget = budget;
    }
    if (data.seven_day_opus) {
      output.opus_pct = Math.round(data.seven_day_opus.utilization);
    }
    console.log(JSON.stringify(output));
  } catch (err) {
    // On error, try to use stale cache if available
    if (cache) {
      const output: OutputData = {
        five_hour_pct: Math.round(cache.data.five_hour?.utilization ?? 0),
        seven_day_pct: Math.round(cache.data.seven_day?.utilization ?? 0),
        five_hour_reset: formatTimeRemaining(cache.data.five_hour?.resets_at ?? ""),
        seven_day_reset: formatTimeRemaining(cache.data.seven_day?.resets_at ?? ""),
        error: "stale",
      };
      const budget = calculateBudget(cache.data.seven_day?.resets_at ?? "");
      if (budget !== null) {
        output.seven_day_budget = budget;
      }
      console.log(JSON.stringify(output));
    } else {
      console.log(JSON.stringify({ error: "fetch_failed" }));
    }
  }
}

main();
