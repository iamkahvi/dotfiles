<%*
// Scaffolds a folder structure from structures/<type>/, next to this template.
// Each type folder has a _structure.md config (frontmatter) plus the files to copy.
// Files and folders that start with "_" are not copied.
// Each prompt_<key>: <label> frontmatter field asks for one input, in frontmatter order.
// {{key}} placeholders in file names and content are replaced with prompt values.
const { Notice, TFolder, TFile, normalizePath, parseYaml } = tp.obsidian;
const ROOT = normalizePath(`${tp.config.template_file.parent.path}/structures`);

const fail = (msg) => { new Notice(msg, 8000); throw new Error(msg); };
const slugify = (s) => s.toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
const render = (s, vars) => s.replace(/\{\{\s*(\w+)\s*\}\}/g, (m, k) => (k in vars ? vars[k] : m));
const parentOf = (p) => p.split("/").slice(0, -1).join("/");
const ensureFolder = async (p) => {
  if (!p || app.vault.getAbstractFileByPath(p)) return;
  await ensureFolder(parentOf(p));
  await app.vault.createFolder(p);
};

// 1. Load the structure types.
const root = app.vault.getAbstractFileByPath(ROOT);
if (!(root instanceof TFolder)) fail(`Folder not found: ${ROOT}`);
const types = [];
for (const dir of root.children) {
  if (!(dir instanceof TFolder)) continue;
  const cfgFile = dir.children.find((f) => f instanceof TFile && f.name === "_structure.md");
  if (!cfgFile) continue;
  const m = (await app.vault.read(cfgFile)).match(/^---\r?\n([\s\S]*?)\r?\n---/);
  const cfg = (m && parseYaml(m[1])) || {};
  types.push({ dir, cfg, label: cfg.label ?? dir.name });
}
if (!types.length) fail(`No structures in ${ROOT}`);
types.sort((a, b) => a.label.localeCompare(b.label));

// 2. Select a type.
const type = await tp.system.suggester(
  types.map((t) => (t.cfg.description ? `${t.label}: ${t.cfg.description}` : t.label)),
  types, true, "Structure type");

// 3. Ask for the inputs.
const vars = { date: tp.date.now("YYYY-MM-DD") };
const prompts = Object.entries(type.cfg)
  .filter(([k]) => /^prompt_\w+$/.test(k))
  .map(([k, label]) => ({ key: k.slice("prompt_".length), label: String(label ?? k) }));
if (!prompts.length) prompts.push({ key: "name", label: "Name" });
for (const { key, label } of prompts) {
  const value = ((await tp.system.prompt(label, "", true)) ?? "").trim();
  if (!value) fail(`${label} is required`);
  vars[key] = value;
  vars[`${key}_slug`] = slugify(value);
}
vars.slug ??= vars.name_slug ?? "";

// 4. Plan the files.
const target = normalizePath(render(type.cfg.target ?? "inbox", vars));
const sources = [];
const walk = (folder) => {
  for (const c of folder.children) {
    if (c.name.startsWith("_")) continue;
    if (c instanceof TFolder) walk(c); else sources.push(c);
  }
};
walk(type.dir);
const items = await Promise.all(sources.map(async (f) => ({
  path: normalizePath(`${target}/${render(f.path.slice(type.dir.path.length + 1), vars)}`),
  content: render(await app.vault.read(f), vars),
})));
const clashes = items.filter((i) => app.vault.getAbstractFileByPath(i.path));
if (!items.length && app.vault.getAbstractFileByPath(target)) fail(`Already exists: ${target}`);
if (clashes.length) fail(`Already exists: ${clashes.map((i) => i.path).join(", ")}`);
const mainPath = type.cfg.open
  ? normalizePath(`${target}/${render(type.cfg.open, vars)}`)
  : items.find((i) => i.path.endsWith(".md"))?.path;

// 5. Create the files.
// "Create new note from template" (run mode 0) makes an Untitled note first.
// That note becomes the main file, so no empty Untitled note stays behind.
const reuseNewNote = tp.config.run_mode === 0 && mainPath?.endsWith(".md");
await ensureFolder(target);
for (const i of items) {
  await ensureFolder(parentOf(i.path));
  if (reuseNewNote && i.path === mainPath) continue;
  await app.vault.create(i.path, i.content);
}
if (reuseNewNote) {
  await tp.file.move(mainPath.replace(/\.md$/, ""));
  tR += items.find((i) => i.path === mainPath).content;
} else if (mainPath) {
  await app.workspace.getLeaf(false).openFile(app.vault.getAbstractFileByPath(mainPath));
} else {
  // No files to open: show the new folder in the file explorer.
  app.workspace.getLeavesOfType("file-explorer")[0]?.view?.revealInFolder?.(app.vault.getAbstractFileByPath(target));
  if (tp.config.run_mode === 0) {
    // Delete the Untitled note after Templater is done with it.
    const untitled = tp.config.target_file;
    const ref = app.workspace.on("templater:all-templates-executed", async () => {
      app.workspace.offref(ref);
      await app.fileManager.trashFile(untitled);
    });
  }
}
new Notice(`Created ${type.label}: ${target}`);
-%>
