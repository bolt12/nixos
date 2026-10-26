## Custom Neovim Plugins

### llm-assistant.lua

Multi-mode LLM assistant integrating with a local llama-swap instance (OpenAI-compatible API).

**Modes:**

- **Code Assistant** (`<leader>p` in visual mode): Select code, type a prompt, get a response, replace/append/yank the result. Uses `qwen3.8-27B-full` at temperature 0.35.
- **Journal Summary** (`<leader>j` in visual mode): Select journal entries, get an automatic weekly summary appended below. Uses `qwen3.8-27B-full` at temperature 1.0.
- **LLM Menu** (`<leader>l` in visual mode): Full menu with mode selection, model picker (fetched live from API), and image generation stub.

All popups display available keybindings in their border text.

### rasto.lua

Runs the rasto skill (`~/.claude/skills/rasto`) on the weekly note in the current buffer, in a terminal tab running `olaude-qwen3-8-27B` with the skill's own settings, so the note's text only reaches the local model. The skill names each OwnTracks stop from that day's text, asks you to confirm, and adds one block per day with the day's map and its Wanderer and TREK links.

- `:Rasto` (`<leader>jr` in normal mode): saves the note and keeps it read-only until you quit olaude (`/exit`). If the run changed the note, the buffer reloads and the run's tab becomes `:Gdiffsplit` of exactly what rasto wrote; otherwise the tab closes. Running it again while a run is open takes you back to that run.
- `:Rasto undo`: asks, then takes back rasto's last write to the note's week. It works from either side of the diff.
- "Journal: rasto" in the LLM menu does the same as `:Rasto`. The menu opens on a visual selection, which rasto ignores.

`rasto.py check` decides what counts as a weekly note, so the plugin and the skill agree. The olaude command, the keymap and the skill folder are in `M.config` at the top of the file.

### journal-wrap-images.lua

Wraps selected markdown image lines into a responsive CSS grid layout for Emanote journals. Triggered with `<leader>wi` in visual mode.
