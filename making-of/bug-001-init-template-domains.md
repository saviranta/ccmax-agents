# Bug 001: Init script template includes Supabase/Vercel domains regardless of user answers

**Discovered:** 2026-03-22
**Severity:** MEDIUM (security — broader network access than intended)
**Component:** `scripts/max-agents-init.sh` + `templates/config.json`
**Status:** Fixed

## Problem

The `templates/config.json` had wildcard Supabase (`*.supabase.co`) and Vercel (`*.vercel.app`, `vercel.com`) domains hardcoded in `security.allowed_network_domains`. The init script's domain logic only *appends* user-specified domains — it never removes the template defaults.

Result: even when the user answers "no" to both Supabase and Vercel prompts, the generated `config.json` still contains those wildcard domains.

## Impact

Projects that don't use Supabase/Vercel get network access to those services anyway. This contradicts the security design where network access should be minimized to only what's needed.

Note: The `settings.json` (which controls the actual sandbox) was NOT affected — it correctly builds its domain list from scratch. So the sandbox enforcement was fine. But `config.json` was wrong, and agents reading it for domain policy would get incorrect information.

## Fix

1. Removed Supabase/Vercel domains from `templates/config.json` — template now only has the base domains (github, npm, yarn).
2. The init script already correctly adds project-specific domains when the user says "yes" — that logic was fine.

## Files Changed

- `templates/config.json` — removed `*.supabase.co`, `*.vercel.app`, `vercel.com` from default domains
