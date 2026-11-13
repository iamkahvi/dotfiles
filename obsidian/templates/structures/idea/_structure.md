---
label: idea
description: new folder ideas/
target: ideas/{{slug}}
prompt_name: Project folder name
---

Config for the Idea structure. `templates/new_structure.md` reads this file. This file is not copied.

- `target`: folder to create. It can use placeholders.
- `open`: file to open after creation, relative to `target`. Default: the first `.md` file.
- `prompt_<key>`: one input to ask for. The value is the label. Each becomes `{{key}}` and `{{key_slug}}`. Prompts run in frontmatter order.
- Built-in placeholders: `{{date}}` (today), `{{slug}}` (same as `{{name_slug}}`).
- Add files or folders next to this file to copy them into `target`.
