---
name: sync-models
description: Sync ~/.pi/agent/models.json with the tailscale AI proxy (ai.tail37572.ts.net) - fetch the live model list, add new models with correct compat settings, remove stale ones, and smoke-test every model end-to-end through pi. Use when models are added/removed on the proxy, or a model errors out in the pi harness. Examples - "/skill:sync-models", "/skill:sync-models gpt-5.7 doesn't work".
---

# Sync Models

Keeps `~/.pi/agent/models.json` (symlinked to `~/dotfiles/pi/models.json`) in sync with
whatever the tailscale AI proxy actually serves, and verifies every configured model
actually works through the real pi tool-calling path (not just raw curl).

This exists because these proxy-fronted models frequently need model-specific `compat`
quirks (wrong `max_tokens` field name, reasoning+tools needing `/v1/responses` instead of
`/v1/chat/completions`, etc) that only show up when you actually drive a tool call through
pi, not from a plain chat completion.

Scripts (paths relative to this file's directory):
- `scripts/diff-models.sh` — fetches `<baseUrl>/v1/models` for every provider baseUrl in
  `models.json` and reports `NEW` (on proxy, not in config) and `GONE` (in config, not on
  proxy anymore) model ids.
- `scripts/check-models.sh [filter]` — runs every model in `models.json` through
  `pi -p --model <provider>/<id> -t bash` with a real tool call, and reports pass/fail.
  Optional first arg filters by substring (e.g. `gpt-5.6`).

## Known state (read this first)

- **Anthropic models** (`tailscale-ai-anthropic`, `api: anthropic-messages`): reliable.
  New Claude models added here typically just work with the same shape as existing
  entries. Copy an existing entry's structure.
- **OpenAI models** (`tailscale-ai`, `api: openai-completions` by default): frequently
  need per-model overrides. See "OpenAI model checklist" below.
- **Google/Gemini models**: currently **excluded from models.json**. The proxy returns
  Gemini's native `extra_content.google.thought_signature` field on tool calls, but
  pi-ai's `openai-completions` provider only recognizes OpenRouter-style
  `reasoning_details[].type: "reasoning.encrypted"`. Multi-turn tool calls fail with
  `400 Function call is missing a thought_signature`. This is a pi-ai bug, not fixable
  from config. Do not re-add Gemini models until this is confirmed fixed upstream (check
  `npm view @mariozechner/pi-ai version` vs currently installed, and grep
  `dist/providers/openai-completions.js` for `extra_content` handling). If asked to add
  Gemini models anyway, warn the user this is expected to fail multi-turn tool use before
  proceeding.

## Procedure

1. **Check for a pi update first.** Run `pi --version` and compare to
   `npm view @mariozechner/pi-coding-agent version`. If behind, update with
   `bun add -g @mariozechner/pi-coding-agent@latest` (plain `pi update pi` has been
   observed to no-op / not actually bump the version — verify with `pi --version` after).
   Provider/compat bugs get fixed upstream; re-run the diff and tests after updating
   before making config changes, in case an update alone fixes a broken model.

2. **Run the diff script**: `bash scripts/diff-models.sh`. This hits every unique
   `baseUrl` in `models.json`. Review `NEW` and `GONE` lines.

3. **For each `GONE` model**: remove its entry from `models.json`. It's no longer served.

4. **For each `NEW` model**, skip anything with backing provider `gemini` (see Known
   state above) unless explicitly told to add it anyway. For everything else (openai,
   anthropic backing providers):

   a. Determine which provider block it belongs to based on backing provider id and
      baseUrl (`tailscale-ai-anthropic` for anthropic, `tailscale-ai` for openai).

   b. Probe `/v1/responses` and `/v1/chat/completions` directly to learn the model's
      requirements before writing any config:
      ```bash
      # Does chat/completions accept it with a tool + max_tokens?
      curl -s -w '\n%{http_code}\n' "$BASE/v1/chat/completions" \
        -H 'Content-Type: application/json' -H 'Authorization: Bearer no-key' \
        -d '{"model":"<id>","messages":[{"role":"user","content":"hi"}],
             "max_tokens":10,
             "tools":[{"type":"function","function":{"name":"bash","description":"run bash","parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}}]}'
      ```
      Interpret the result:
      - `400 ... 'max_tokens' is not supported ... Use 'max_completion_tokens'` → model
        needs `compat.maxTokensField: "max_completion_tokens"` (or set it at the
        provider level if most models under that provider need it — check whether doing
        so breaks any model that's currently fine with `max_tokens`; the `tailscale-ai`
        provider already sets this at the provider level).
      - `400 Function tools with reasoning_effort are not supported ... use /v1/responses`
        or `404 ... not supported in the v1/chat/completions endpoint ... Use v1/responses` →
        set `"api": "openai-responses"` on that model entry, and add `"reasoning": true`
        if the model is a reasoning model (check the `usage.completion_tokens_details.reasoning_tokens`
        field on a plain non-tool completion call, or just infer from the model family —
        e.g. anything under the `gpt-5.6*` family besides base non-reasoning variants).
      - `200`/`completed` → default config (no extra compat needed) works fine on
        chat/completions.

   c. Also probe `/v1/responses` the same way with `max_output_tokens` instead of
      `max_tokens` to confirm it works there if you're routing through it.

   d. Add the model entry to the right provider block. Match the style of neighboring
      entries: `id`, `name` (human-readable, Title Case), `input`, `contextWindow`,
      `maxTokens`, `cost` (pull `pricing.input/output/input_cache_read/input_cache_write`
      from the proxy's `/v1/models` response for that model id, converting per-token USD
      strings to per-million-token numbers, e.g. `"0.00000020"` → `0.2`), plus `api` /
      `reasoning` / `compat` overrides as determined above.

5. **Validate JSON**: `python3 -m json.tool ~/.pi/agent/models.json > /dev/null` (or
   `jq . ~/.pi/agent/models.json > /dev/null`) before testing.

6. **Run the full smoke test**: `bash scripts/check-models.sh`. This actually drives
   `pi -p --model <provider>/<id> -t bash` with a real tool-calling prompt for every
   configured model — this is the same combination (text + tool call, and reasoning
   where applicable) that has broken models in the past. A model passing a raw curl test
   does not guarantee it passes here; trust this script's result over manual curl probing.

7. **Fix any failures** the smoke test surfaces using the same probing approach as step 4b,
   then re-run `scripts/check-models.sh <model-substring>` to confirm just that model
   before re-running the full suite.

8. **Report** to the user: models added, models removed, models with compat fixes applied
   (and why), and the final pass/fail count from the smoke test. Do not claim a model
   works unless `check-models.sh` shows it passing.

## Notes

- `models.json` is a symlink: `~/.pi/agent/models.json` -> `~/dotfiles/pi/models.json`.
  Edit either path; they're the same file. No separate sync step needed.
- Never guess pricing or compat behavior — always confirm against the proxy's
  `/v1/models` response and live probe requests before writing config.
- Don't push/commit changes to the dotfiles repo unless asked.
