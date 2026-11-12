---
name: rex-diagram
description: Draw or display diagrams in a Rex terminal pane with the Kitty graphics protocol. Use when the user asks for a visual explanation, diagram, or image in Rex.
---

# Rex diagram

1. Run `rex __internal skill` and follow its target selection rules.
2. Create an SVG or PNG in a temporary directory. For a reference image, inspect it first. Use simple shapes, readable labels, and sufficient contrast. Do not copy a screenshot when the user asks for a new diagram.
3. Open the image beside the agent's pane unless the user specifies another target:

   ```sh
   rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=right --ratio 55 --focus=false --keep-open --shell=none --json -- python3 /ABSOLUTE/SKILL/DIR/show.py /ABSOLUTE/PATH/diagram.svg
   ```

   Replace `/ABSOLUTE/SKILL/DIR` with this skill's directory. The helper accepts PNG, SVG, JPEG, and other formats ImageMagick can read. Python 3 is required; non-PNG images also require `magick`.
4. Capture the new block to check for errors. An `OK` response confirms transmission, not visual appearance. Ask the user to review the image. Keep the pane open.

The helper fits the image to the pane and redraws it after a resize. It sends direct, chunked PNG data and checks the terminal response. Press Enter to finish. Do not send graphics into the agent's own pane. Do not close existing panes or delete user files.
