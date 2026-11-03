# dotfiles

Rules for work on this repo only. The general rules are in `agents/AGENTS.md`.

- Read `docs/machine-branching-plan.md` first. It defines the platform and profile axes and the labels for each file.
- Tracked files use `$HOME` or `~`. They do not use `/Users/<name>` or `/home/<name>`.
- Do not track secrets. Put them in `~/.zshenv.local`.
- Do not track pi state (`auth.json`, `sessions/`, `models-store.json`, and the other names in `.gitignore`).
- Put new pi extensions and skills in `pi/common`, `pi/personal`, or `pi/work`. Do not edit the settings files for that.
- Add each new linked file to the link list in `setups/install.sh`.
