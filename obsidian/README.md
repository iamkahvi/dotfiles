# Obsidian

Templater files for Obsidian vaults. No setup script installs them. Copy them into a vault by hand.

## new_structure

`templates/new_structure.md` makes a folder structure from a type in `templates/structures/<type>/`. It shows a menu of types, asks for the inputs, and copies the files.

### Install in a vault

1. Install the Templater plugin (2.26 or later).
2. Copy `templates/new_structure.md` and `templates/structures/` into the Templater templates folder of the vault. Keep `structures/` next to `new_structure.md`.
3. In Settings > Templater > Template hotkeys, add `new_structure.md`. Turn on "Create" and turn off "Insert".
4. Run "Templater: Create <folder>/new_structure.md" from the command palette.

### Add a type

Make a folder in `structures/` with a `_structure.md` file. The frontmatter has these fields:

- `label`, `description`: text for the menu.
- `target`: folder for the new files, relative to the vault root.
- `open`: file to open after creation, relative to `target`. Default: the first `.md` file.
- `prompt_<key>`: one input. The value is the prompt label. All inputs are required. They run in frontmatter order. If there is no `prompt_` field, the runner asks for `name`.

Example:

```yaml
label: Project
target: projects/{{slug}}
prompt_name: Project folder name
prompt_owner: Owner
```

Put the files to copy next to `_structure.md`. The runner does not copy names that start with `_`.

### Placeholders

These work in file names and in file content:

- `{{key}}`: the value for each prompt, as typed.
- `{{key_slug}}`: the value in lowercase with underscores.
- `{{slug}}`: the same as `{{name_slug}}`.
- `{{date}}`: today, as `YYYY-MM-DD`.

### Behavior

- If a target file or an empty target folder exists, the runner stops and changes nothing.
- With the "Create" command, the Untitled note from Templater becomes the main file. If the type has no files, the runner deletes the Untitled note.
- Templater syntax in structure files is not run. The runner copies it as plain text.
