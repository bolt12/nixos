## Custom Neovim Plugins

### llm-assistant.lua

Multi-mode LLM assistant integrating with a local llama-swap instance (OpenAI-compatible API).

**Modes:**

- **Code Assistant** (`<leader>p` in visual mode): Select code, type a prompt, get a response, replace/append/yank the result. Uses `qwen3-coder-next-full` at temperature 0.35.
- **Journal Summary** (`<leader>j` in visual mode): Select journal entries, get an automatic weekly summary appended below. Uses `glm-4.7-flash-full-creative` at temperature 1.0.
- **LLM Menu** (`<leader>l` in visual mode): Full menu with mode selection, model picker (fetched live from API), and image generation stub.

All popups display available keybindings in their border text.

### journal-wrap-images.lua

Wraps selected markdown image lines into a responsive CSS grid layout for Emanote journals. Triggered with `<leader>wi` in visual mode.
