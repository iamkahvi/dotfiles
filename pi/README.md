# pi

Three local pi packages. Each has `extensions/` and `skills/`.

| Folder | Profile | Content |
|---|---|---|
| `common/` | all | Extensions and skills for every machine. |
| `personal/` | personal | Tailnet proxy items (gemini-thought-signatures, web-search, sync-models, browser-mcp). |
| `work/` | work | Shopify items (textarea-decode, tldr). |

`settings.personal.json` and `settings.work.json` list `common` and the profile folder in `packages`.
`setups/install.sh` links `settings.$DOTFILES_PROFILE.json` to `~/.pi/agent/settings.json`.
To add an item, put it in a folder. Do not edit the settings files.

pi writes through the symlink. `/model`, a thinking-level change, and a pi update change the linked file.
Commit the change, or discard it with `git checkout`.

`models.json` is for personal machines. The work Mac keeps a local `~/.pi/agent/models.json`.
