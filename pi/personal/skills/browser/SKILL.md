---
name: browser
description: Use Pi's browser tools to navigate, interact with, and verify web pages. Use for browser automation, page inspection, and UI testing.
---

# Browser tools

Read `../../extensions/browser-tools/node_modules/pi-browser-tools/skills/browser/SKILL.md` for the tool workflow and reference.

Local configuration overrides its statement that Chromium launches headed by default: **new browser launches are headless by default**. `/browser-headless` toggles the mode for this session's next launch. The shared Chromium must be stopped before a mode change takes effect; `/browser-quit` affects all Pi sessions. Ask the user before stopping it.

`/browser-data` lets the user inspect domains and optionally clear cookies and site storage for a domain and its subdomains. It prompts before deletion and keeps saved passwords. Chrome may reset persistent-storage permission for affected hosts.
