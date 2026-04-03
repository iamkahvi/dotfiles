---
name: loop
description: Run a prompt or command on a recurring interval. Use when asked to poll, watch, or repeat something periodically. Examples - "/skill:loop 5m run tests", "/skill:loop check the deploy every 20m".
---

# Loop: Recurring Task Runner

Run a prompt or shell command on a recurring interval using a background bash loop.

## Parse the input

Parse the user's input into `[interval] <prompt>` using these rules in priority order:

1. **Leading token**: if the first whitespace-delimited token matches `^\d+[smhd]$` (e.g. `5m`, `2h`), that's the interval; the rest is the prompt.
2. **Trailing "every" clause**: if the input ends with `every <N><unit>` or `every <N> <unit-word>` (e.g. `every 20m`, `every 5 minutes`), extract that as the interval and strip it. Only match when what follows "every" is a time expression — `check every PR` has no interval.
3. **Default**: interval is `10m` and the entire input is the prompt.

If the resulting prompt is empty, show usage and stop:
```
Usage: /skill:loop [interval] <prompt>

Run a prompt or command on a recurring interval.

Intervals: Ns, Nm, Nh, Nd (e.g. 5m, 30m, 2h, 1d).
If no interval is specified, defaults to 10m.

Examples:
  /skill:loop 5m run the tests
  /skill:loop 30m check the deploy
  /skill:loop check CI status every 20m
```

Examples:
- `5m run tests` → interval `5m`, prompt `run tests` (rule 1)
- `check the deploy every 20m` → interval `20m`, prompt `check the deploy` (rule 2)
- `run tests every 5 minutes` → interval `5m`, prompt `run tests` (rule 2)
- `check the deploy` → interval `10m`, prompt `check the deploy` (rule 3)
- `check every PR` → interval `10m`, prompt `check every PR` (rule 3 — "every" not followed by time)

## Convert interval to seconds

- `Ns` → N seconds
- `Nm` → N * 60 seconds
- `Nh` → N * 3600 seconds
- `Nd` → N * 86400 seconds

## Execute

1. **Run the prompt immediately** — don't wait for the first interval. Execute whatever the user asked for right now.

2. **Set up the loop.** After the first execution, use bash to start a background loop that will remind you to re-run. The mechanism depends on what the prompt is:

   - **If the prompt is a shell command** (e.g. `run tests`, `check CI status`): run it in a `while true; do sleep <seconds>; <command>; done &` background loop using `bash`, and tell the user the PID so they can `kill` it later.

   - **If the prompt requires agent reasoning** (e.g. `check if the deploy looks healthy`, `review new PRs`): tell the user you'll execute it now, then explain that pi doesn't have a built-in cron scheduler, so for recurring agent tasks they should use an external scheduler (cron, launchd, `watch`) that invokes `pi --prompt "<the prompt>"` on the interval. Provide the exact crontab line or `watch` command they'd need.

3. **Confirm** what's scheduled: the prompt, the interval in human-readable form, and how to stop it.
