local Popup = require("nui.popup")
local Layout = require("nui.layout")
local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event
local curl = require("plenary.curl")

-- ==========================================================================
-- Config
-- ==========================================================================

local Config = {
  api_url = "http://10.100.0.100:8080/v1/chat/completions",
  models_url = "http://10.100.0.100:8080/v1/models",
  images_url = "http://10.100.0.100:8080/v1/images/generations",
  api_key = "not-needed",
  request_timeout = 120000,
  image_timeout = 600000, -- 10 min (accounts for first-time model download)

  image_models = {
    { id = "flux1-schnell", label = "FLUX.1 Schnell", default_size = "1024x1024" },
    { id = "sd3.5-medium", label = "SD 3.5 Medium", default_size = "1024x1024" },
  },
  default_image_model = "flux1-schnell",

  profiles = {
    code_assistant = {
      model = "qwen3-coder-next-full",
      temperature = 0.35,
      system_prompt = "You are a highly skilled and helpful assistant for a code editor. "
        .. "Your primary role is to respond to user queries related to coding. "
        .. "Provide detailed explanations for code-related questions, refactor code if needed, "
        .. "and debug errors effectively. Aim to enhance the user's understanding by "
        .. "offering clear insights and constructive feedback. Be polite, professional, "
        .. "and ensure your responses are easy to follow. "
        .. "Examples: 'Given the code snippet, explain how it works.' "
        .. "or 'Refactor this function to improve readability and performance.'",
      result_action = "replace",
      needs_prompt = true,
    },
    journal_summary = {
      model = "qwen3.5-27B-creative",
      temperature = 1.0,
      system_prompt = [[You are a personal journal assistant that creates weekly summaries.

Your task is to read through journal entries and create a thoughtful, well-structured summary.

[Clear Objective]
Analyze a weekly journal entry provided in markdown format and generate a
structured, first-person summary that captures the essence of the week's
experiences. The output must be a markdown-formatted summary following a
specific template structure with four distinct sections: Summary, Significant
Events, Fun and Memorable Moments, and Reflection.

[Background & Context]
The input will be a personal weekly journal entry containing daily
experiences, thoughts, and observations. The summary should distill this
content while maintaining the authentic voice and perspective of the journal
writer. This summary serves as a personal record and reflection tool.

[Tone and Style]
Mirror the original journal writer's voice, tone, and stylistic choices.
Maintain first-person perspective throughout. The writing should feel natural
and authentic to the original author, preserving their unique expressions,
vocabulary preferences, and emotional nuances. If the journal is informal,
keep the summary informal; if reflective, maintain that contemplative quality.

[Constraints and Guidelines]
- Start with a brief overview sentence capturing the week's theme
- Group related activities and themes together
- Highlight accomplishments, breakthroughs, and progress
- Note challenges or blockers encountered
- Capture emotional tone and energy levels where apparent
- End with a "Looking ahead" section if there are forward-looking mentions
- Use markdown formatting (headers, bullets, bold for emphasis)
- Keep the summary concise but comprehensive (aim for 200-400 words)
- Preserve the author's voice -- don't make it sound corporate
- If entries mention specific projects, tools, or people, keep those references
- Do NOT add information that isn't in the entries
- Write in the same language as the journal entries
- Strictly follow this markdown structure:
  ```
  # Summary
  [Single paragraph, 2-3 sentences maximum, capturing the week's essence]

  ## Significant Events:
  - [Bullet point 1]
  - [Bullet point 2]
  - [Continue as needed, typically 3-5 points]

  ## Fun and Memorable Moments:
  - [Bullet point 1]
  - [Bullet point 2]
  - [Continue as needed, typically 2-4 points]

  ## Reflection
  [Single paragraph, 50-100 words, identifying patterns, themes, or insights]
  ```
- Summary section: Keep extremely concise (2-3 sentences) while capturing the
  week's overall character
- Significant Events: Focus on impactful, important, or milestone moments
- Fun and Memorable Moments: Highlight lighter, amusing, or emotionally
  positive experiences
- Reflection: Must be 50-100 words, focusing on patterns, recurring themes,
  personal growth insights, or overarching observations
- Preserve specific details, names, and contexts from the original journal
- Maintain chronological accuracy when relevant
- Ensure no overlap between Significant Events and Fun/Memorable Moments
  sections

[Creativity vs. Precision]
Prioritize precision and accuracy to the source material. Creative
interpretation should only serve to better capture the journal writer's
authentic voice. When condensing content, preserve the most meaningful and
characteristic elements rather than inventing new perspectives.

[Role Prompting]
You are the journal writer themselves, creating a summary of your own week.
You have perfect recall of your experiences and can distinguish between what
was truly significant versus merely routine. You understand your own writing
patterns and can authentically replicate your voice.

[Voice Analysis Instructions]
Before writing the summary, briefly analyze (internally, not in output):
- Vocabulary level and word choices
- Sentence structure preferences (short/long, simple/complex)
- Emotional expression style (reserved/expressive, direct/metaphorical)
- Use of humor, if any
- Recurring phrases or expressions

[Task]
Read the provided weekly journal entry and create the structured summary
according to all specifications above, ensuring it reads as if the journal
writer created it themselves.
]],
      result_action = "append_below",
      needs_prompt = false,
    },
    visual_journal = {
      model = "qwen3.5-27B-creative",
      temperature = 0.9,
      system_prompt = [=[You are a visual storytelling assistant that distills journal entries into a single abstract image prompt for Stable Diffusion / FLUX image generators.

## Your Task

Read the provided journal entries and produce ONE image prompt that abstractly captures the week's essence — its emotional arc, recurring themes, and defining energy.

## Process (internal — do NOT include in output)

1. **Analyze** the journal entries for:
   - Dominant emotions and emotional trajectory (rising, falling, turbulent, calm)
   - Recurring themes, motifs, or preoccupations
   - Key events that defined the week's character
   - Sensory details that could translate into symbolic imagery

2. **Synthesize** a single composite image concept that:
   - Uses symbolic and metaphorical imagery rather than literal scene recreation
   - Blends multiple themes into one cohesive visual
   - Captures the *feeling* of the week, not specific moments
   - Works as an abstract or semi-abstract composition

## Prompt Writing Guidelines

Write the prompt optimized for Stable Diffusion / FLUX models:
- **Keyword-heavy**: comma-separated descriptive phrases work better than prose
- **2-4 sentences max**: front-load the most important visual elements
- **No people or character descriptions**: use objects, landscapes, textures, colors as metaphors
- **Include style direction**: lighting, color palette, artistic style, composition
- **Include atmosphere**: mood, energy, symbolic elements

## Output Format

Output ONLY the prompt block, no titles, explanations, or commentary:

[PROMPT]
[Your detailed abstract image prompt here — comma-separated keywords and short phrases, 2-4 sentences, symbolic/metaphorical imagery, include style/lighting/mood direction]
[/PROMPT]]=],
      result_action = "append_below",
      needs_prompt = false,
    },
  },

  -- Fallback model list when API is unreachable
  fallback_models = {
    local_models = {
      "glm-4.7-flash-full-creative",
      "glm-4.7-flash-full",
      "glm-4.7-flash-hass",
      "gpt-oss-120b-full",
      "gpt-oss-20b-full",
      "nemotron-3-nano-full",
      "qwen3-coder-next-full",
      "qwen3.5-27B-creative",
      "qwen3.5-27B-full",
      "step-3.5-flash-full",
    },
    cloud_models = {
      "claude-sonnet-4-5-20250929",
      "claude-opus-4-5-20251101",
      "claude-haiku-4-20250515",
      "GLM-5",
      "GLM-4.7",
      "GLM-4.5",
    },
  },
}

-- Highlights
vim.api.nvim_set_hl(0, "LLMSuccess", { fg = "#00ff00", bg = "#000000", bold = true })
vim.api.nvim_set_hl(0, "LLMError", { fg = "#ff0000", bg = "#000000", bold = true })
vim.api.nvim_set_hl(0, "LLMStatus", { fg = "#61afef", bold = true })

-- ==========================================================================
-- State
-- ==========================================================================

local State = {
  active_job = nil,
  elapsed_timer = nil,
  elapsed_seconds = 0,
  model_override = nil,
  cached_models = nil,
  -- Selection context (saved when entering a flow)
  sel = {
    buf = nil,
    start_line = nil,
    start_col = nil,
    end_line = nil,
    end_col = nil,
    text_lines = nil,
  },
}

-- ==========================================================================
-- Helpers
-- ==========================================================================

local function split_lines(str)
  local result = {}
  for line in (str .. "\n"):gmatch("(.-)\n") do
    table.insert(result, line)
  end
  return result
end

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_line = end_pos[2] - 1
  local end_col = end_pos[3] - 1

  if end_col >= 2147483646 then
    end_col = #vim.fn.getline(end_line + 1)
  end

  local lines = vim.api.nvim_buf_get_text(0, start_line, start_col, end_line, end_col, {})
  return lines, start_line, start_col, end_line, end_col
end

local function save_selection()
  local lines, sl, sc, el, ec = get_visual_selection()
  if not lines or #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("No text selected", vim.log.levels.WARN)
    return false
  end
  State.sel = {
    buf = vim.api.nvim_get_current_buf(),
    start_line = sl,
    start_col = sc,
    end_line = el,
    end_col = ec,
    text_lines = lines,
  }
  return true
end

local function parse_image_prompts(text)
  local prompts = {}
  for prompt in text:gmatch("%[PROMPT%](.-)%[/PROMPT%]") do
    local trimmed = prompt:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      table.insert(prompts, trimmed)
    end
  end
  return prompts
end

local function save_base64_png(b64_data, filepath)
  local decoded = vim.base64.decode(b64_data)
  local f, err = io.open(filepath, "wb")
  if not f then
    return false, "Cannot write to " .. filepath .. ": " .. (err or "unknown error")
  end
  f:write(decoded)
  f:close()
  return true
end

-- ==========================================================================
-- API
-- ==========================================================================

local Api = {}

function Api.chat(opts, on_result, on_error)
  -- Cancel any existing job
  Api.cancel()

  local profile = opts.profile or Config.profiles.code_assistant
  local model = State.model_override or profile.model
  local messages = {
    { role = "system", content = profile.system_prompt },
    { role = "user", content = opts.user_content },
  }

  local payload = vim.fn.json_encode({
    model = model,
    messages = messages,
    temperature = profile.temperature,
  })

  -- Start elapsed timer
  State.elapsed_seconds = 0
  State.elapsed_timer = vim.loop.new_timer()
  State.elapsed_timer:start(1000, 1000, vim.schedule_wrap(function()
    State.elapsed_seconds = State.elapsed_seconds + 1
    vim.api.nvim_echo(
      { { string.format("Requesting %s... %ds (Esc to cancel)", model, State.elapsed_seconds), "LLMStatus" } },
      false, {}
    )
  end))

  vim.api.nvim_echo(
    { { string.format("Requesting %s... (Esc to cancel)", model), "LLMStatus" } },
    false, {}
  )

  State.active_job = curl.post(Config.api_url, {
    body = payload,
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. Config.api_key,
    },
    timeout = Config.request_timeout,
    callback = function(response)
      vim.schedule(function()
        Api.stop_timer()
        if response.status ~= 200 then
          on_error("HTTP " .. (response.status or "?") .. ": " .. (response.body or "no body"))
          return
        end
        local ok, parsed = pcall(vim.fn.json_decode, response.body)
        if not ok or not parsed.choices or not parsed.choices[1] then
          on_error("Failed to parse response")
          return
        end
        on_result(parsed.choices[1].message.content)
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
        Api.stop_timer()
        on_error("Request failed: " .. (err.message or vim.inspect(err)))
      end)
    end,
  })
end

function Api.cancel()
  Api.stop_timer()
  if State.active_job then
    pcall(function() State.active_job:shutdown() end)
    State.active_job = nil
    vim.api.nvim_echo({ { "" } }, false, {})
  end
end

function Api.stop_timer()
  if State.elapsed_timer then
    State.elapsed_timer:stop()
    State.elapsed_timer:close()
    State.elapsed_timer = nil
  end
end

function Api.generate_image(opts, on_result, on_error)
  local payload = vim.fn.json_encode({
    model = opts.model,
    prompt = opts.prompt,
    size = opts.size or "1024x1024",
    response_format = "b64_json",
  })

  local job = curl.post(Config.images_url, {
    body = payload,
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. Config.api_key,
    },
    timeout = Config.image_timeout,
    callback = function(response)
      vim.schedule(function()
        if response.status ~= 200 then
          on_error("HTTP " .. (response.status or "?") .. ": " .. (response.body or "no body"))
          return
        end
        local ok, parsed = pcall(vim.fn.json_decode, response.body)
        if not ok or not parsed.data or not parsed.data[1] then
          on_error("Failed to parse image response")
          return
        end
        on_result(parsed.data[1].b64_json)
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
        on_error("Image request failed: " .. (err.message or vim.inspect(err)))
      end)
    end,
  })

  return job
end

function Api.fetch_models(callback)
  if State.cached_models then
    callback(State.cached_models)
    return
  end

  curl.get(Config.models_url, {
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. Config.api_key,
    },
    timeout = 5000,
    callback = function(response)
      vim.schedule(function()
        if response.status ~= 200 then
          callback(nil)
          return
        end
        local ok, parsed = pcall(vim.fn.json_decode, response.body)
        if not ok or not parsed.data then
          callback(nil)
          return
        end
        -- Categorize models into local and cloud
        local cloud_set = {}
        for _, m in ipairs(Config.fallback_models.cloud_models) do
          cloud_set[m] = true
        end
        local local_models = {}
        local cloud_models = {}
        for _, m in ipairs(parsed.data) do
          local id = m.id
          if cloud_set[id] then
            table.insert(cloud_models, id)
          else
            table.insert(cloud_models, id)
            -- Also add to local if not in cloud set
          end
        end
        -- Re-sort: local = not in cloud_set, cloud = in cloud_set
        local_models = {}
        cloud_models = {}
        for _, m in ipairs(parsed.data) do
          if cloud_set[m.id] then
            table.insert(cloud_models, m.id)
          else
            table.insert(local_models, m.id)
          end
        end
        table.sort(local_models)
        table.sort(cloud_models)
        State.cached_models = { local_models = local_models, cloud_models = cloud_models }
        callback(State.cached_models)
      end)
    end,
    on_error = function()
      vim.schedule(function()
        callback(nil)
      end)
    end,
  })
end

-- ==========================================================================
-- Actions
-- ==========================================================================

local Actions = {}

function Actions.replace(result_lines)
  local s = State.sel
  vim.api.nvim_buf_set_text(s.buf, s.start_line, s.start_col, s.end_line, s.end_col, result_lines)
  vim.notify("Selection replaced", vim.log.levels.INFO)
end

function Actions.append_below(result_lines)
  local s = State.sel
  -- Insert after the end of selection
  vim.api.nvim_buf_set_lines(s.buf, s.end_line + 1, s.end_line + 1, false, result_lines)
  vim.notify("Result appended below selection", vim.log.levels.INFO)
end

function Actions.yank(result_lines)
  local text = table.concat(result_lines, "\n")
  vim.fn.setreg("+", text)
  vim.notify("Result copied to clipboard", vim.log.levels.INFO)
end

-- ==========================================================================
-- UI
-- ==========================================================================

local UI = {}

function UI.show_result(result_text, profile)
  local result_lines = split_lines(result_text)
  local is_journal = (profile.result_action == "append_below")

  local title = is_journal and " Journal Summary " or " Result "
  local primary_label = is_journal and "append" or "replace"
  local secondary_label = is_journal and "replace" or "append"

  local result_popup = Popup({
    relative = "editor",
    position = "50%",
    size = { width = "60%", height = "60%" },
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
        bottom = string.format(
          " <leader>s %s | <leader>a append | <leader>r replace | <leader>y yank | <Esc> close ",
          primary_label
        ),
        bottom_align = "center",
      },
    },
    buf_options = {
      modifiable = true,
      filetype = "markdown",
    },
  })

  result_popup:mount()
  vim.api.nvim_buf_set_lines(result_popup.bufnr, 0, -1, false, result_lines)

  -- Helper to get (possibly edited) lines from the result buffer
  local function get_result()
    return vim.api.nvim_buf_get_lines(result_popup.bufnr, 0, -1, false)
  end

  local function close()
    result_popup:unmount()
  end

  -- Primary action: <leader>s
  if is_journal then
    result_popup:map("n", "<leader>s", function()
      Actions.append_below(get_result())
      close()
    end, { noremap = true })
  else
    result_popup:map("n", "<leader>s", function()
      Actions.replace(get_result())
      close()
    end, { noremap = true })
  end

  -- Explicit append
  result_popup:map("n", "<leader>a", function()
    Actions.append_below(get_result())
    close()
  end, { noremap = true })

  -- Explicit replace
  result_popup:map("n", "<leader>r", function()
    Actions.replace(get_result())
    close()
  end, { noremap = true })

  -- Yank
  result_popup:map("n", "<leader>y", function()
    Actions.yank(get_result())
    close()
  end, { noremap = true })

  -- Close
  result_popup:map("n", "<Esc>", close, { noremap = true })
  result_popup:map("n", "q", close, { noremap = true })

  vim.api.nvim_echo({ { "Done!", "LLMSuccess" } }, false, {})
end

function UI.show_prompt_and_selection(profile, selected_text_str, on_submit)
  local selected_text_popup = Popup({
    relative = "editor",
    size = { width = "100%", height = "100%" },
    border = {
      style = "rounded",
      text = {
        top = " Selected Text ",
        top_align = "center",
        bottom = " <Tab> switch pane ",
        bottom_align = "center",
      },
    },
    buf_options = { modifiable = true },
  })

  local input_popup = Popup({
    relative = "editor",
    size = { width = "100%", height = "100%" },
    enter = true,
    focusable = true,
    zindex = 50,
    border = {
      padding = { top = 1, bottom = 1, left = 2, right = 2 },
      style = "rounded",
      text = {
        top = " Prompt ",
        top_align = "center",
        bottom = " <leader>s submit | <Esc> cancel ",
        bottom_align = "center",
      },
    },
    buf_options = { modifiable = true },
  })

  local layout = Layout(
    {
      position = "50%",
      size = { width = "60%", height = "50%" },
    },
    Layout.Box({
      Layout.Box(input_popup, { size = "65%" }),
      Layout.Box(selected_text_popup, { size = "35%" }),
    }, { dir = "row" })
  )

  layout:mount()

  -- Populate selected text
  vim.api.nvim_buf_set_lines(selected_text_popup.bufnr, 0, -1, false, split_lines(selected_text_str))

  vim.cmd("startinsert")

  -- Tab to switch between panes
  local in_prompt = true
  local function switch_pane()
    if in_prompt then
      vim.api.nvim_set_current_win(selected_text_popup.winid)
    else
      vim.api.nvim_set_current_win(input_popup.winid)
    end
    in_prompt = not in_prompt
  end

  input_popup:map("n", "<Tab>", switch_pane, { noremap = true })
  selected_text_popup:map("n", "<Tab>", switch_pane, { noremap = true })

  -- Submit
  local function submit()
    local prompt_lines = vim.api.nvim_buf_get_lines(input_popup.bufnr, 0, -1, false)
    local prompt = table.concat(prompt_lines, "\n")
    local sel_lines = vim.api.nvim_buf_get_lines(selected_text_popup.bufnr, 0, -1, false)
    local selected_text = table.concat(sel_lines, "\n")
    layout:unmount()
    on_submit(prompt, selected_text)
  end

  input_popup:map("n", "<leader>s", submit, { noremap = true })
  selected_text_popup:map("n", "<leader>s", submit, { noremap = true })

  -- Cancel
  local function cancel()
    layout:unmount()
  end
  input_popup:map("n", "<Esc>", cancel, { noremap = true })
  selected_text_popup:map("n", "<Esc>", cancel, { noremap = true })
  input_popup:map("n", "q", cancel, { noremap = true })
  selected_text_popup:map("n", "q", cancel, { noremap = true })

  -- Set up cancel keymap for when request is in progress
  -- (will be set up after submit, during the waiting state)
end

function UI.show_model_picker(on_select)
  Api.fetch_models(function(models)
    local model_data = models or Config.fallback_models
    local items = {}

    -- Local models header
    table.insert(items, Menu.separator("Local", { char = "─" }))
    for _, m in ipairs(model_data.local_models) do
      table.insert(items, Menu.item(m, { id = m }))
    end

    -- Cloud models header
    table.insert(items, Menu.separator("Cloud", { char = "─" }))
    for _, m in ipairs(model_data.cloud_models) do
      table.insert(items, Menu.item(m, { id = m }))
    end

    local menu = Menu({
      relative = "editor",
      position = "50%",
      size = { width = 45, height = 20 },
      border = {
        style = "rounded",
        text = {
          top = " Select Model ",
          top_align = "center",
          bottom = " j/k navigate | <CR> select | <Esc> back ",
          bottom_align = "center",
        },
      },
    }, {
      lines = items,
      keymap = {
        focus_next = { "j", "<Down>" },
        focus_prev = { "k", "<Up>" },
        close = { "<Esc>", "q" },
        submit = { "<CR>" },
      },
      on_submit = function(item)
        on_select(item.id or item.text)
      end,
    })

    menu:mount()
  end)
end

function UI.show_image_model_picker(on_select)
  local items = {}
  for _, m in ipairs(Config.image_models) do
    local suffix = m.id == Config.default_image_model and " (default)" or ""
    table.insert(items, Menu.item(m.label .. suffix, { id = m.id, size = m.default_size }))
  end

  local menu = Menu({
    relative = "editor",
    position = "50%",
    size = { width = 35, height = #Config.image_models + 4 },
    border = {
      style = "rounded",
      text = {
        top = " Image Model ",
        top_align = "center",
        bottom = " <CR> select | <Esc> cancel ",
        bottom_align = "center",
      },
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>" },
      focus_prev = { "k", "<Up>" },
      close = { "<Esc>", "q" },
      submit = { "<CR>" },
    },
    on_submit = function(item)
      on_select({ model = item.id, size = item.size })
    end,
  })

  menu:mount()
end

function UI.show_mode_menu()
  local items = {
    Menu.item("Code Assistant", { id = "code_assistant" }),
    Menu.item("Journal Summary", { id = "journal_summary" }),
    Menu.item("Image Generation", { id = "image_generation" }),
    Menu.separator("", { char = "─" }),
    Menu.item("Select Model...", { id = "select_model" }),
  }

  local menu = Menu({
    relative = "editor",
    position = "50%",
    size = { width = 42, height = 10 },
    border = {
      style = "rounded",
      text = {
        top = " LLM Assistant ",
        top_align = "center",
        bottom = " j/k navigate | <CR> select | <Esc> close ",
        bottom_align = "center",
      },
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>" },
      focus_prev = { "k", "<Up>" },
      close = { "<Esc>", "q" },
      submit = { "<CR>" },
    },
    on_submit = function(item)
      local id = item.id or item.text
      if id == "code_assistant" then
        require("llm-assistant").code_assistant()
      elseif id == "journal_summary" then
        require("llm-assistant").journal_summary()
      elseif id == "image_generation" then
        require("llm-assistant").image_generation()
      elseif id == "select_model" then
        UI.show_model_picker(function(model)
          State.model_override = model
          vim.notify("Model set to: " .. model, vim.log.levels.INFO)
          -- Re-open mode menu after model selection
          vim.schedule(function()
            UI.show_mode_menu()
          end)
        end)
      end
    end,
  })

  menu:mount()
end

-- ==========================================================================
-- Modes
-- ==========================================================================

local Modes = {}

function Modes.code_assistant()
  if not save_selection() then return end
  local profile = Config.profiles.code_assistant
  local selected_text_str = table.concat(State.sel.text_lines, "\n")

  UI.show_prompt_and_selection(profile, selected_text_str, function(prompt, selected_text)
    if prompt == "" then
      vim.notify("Empty prompt, cancelled", vim.log.levels.WARN)
      return
    end

    local user_content = prompt .. "\n\n```\n" .. selected_text .. "\n```"

    -- Set up Esc to cancel during request
    local cancel_map = vim.api.nvim_set_keymap
    cancel_map("n", "<Esc>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Api.cancel()
        vim.notify("Request cancelled", vim.log.levels.WARN)
        -- Remove this temporary mapping
        pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
      end,
    })

    Api.chat({
      profile = profile,
      user_content = user_content,
    }, function(result)
      pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
      UI.show_result(result, profile)
    end, function(err)
      pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
      vim.notify(err, vim.log.levels.ERROR)
    end)
  end)
end

function Modes.journal_summary()
  if not save_selection() then return end
  local profile = Config.profiles.journal_summary
  local selected_text_str = table.concat(State.sel.text_lines, "\n")

  -- No prompt step -- go directly to API
  local model = State.model_override or profile.model

  -- Set up Esc to cancel during request
  local cancel_map = vim.api.nvim_set_keymap
  cancel_map("n", "<Esc>", "", {
    noremap = true,
    silent = true,
    callback = function()
      Api.cancel()
      vim.notify("Request cancelled", vim.log.levels.WARN)
      pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
    end,
  })

  Api.chat({
    profile = profile,
    user_content = selected_text_str,
  }, function(result)
    pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
    UI.show_result(result, profile)
  end, function(err)
    pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
    vim.notify(err, vim.log.levels.ERROR)
  end)
end

function Modes.image_generation(opts)
  opts = opts or {}
  if not save_selection() then return end
  local profile = Config.profiles.visual_journal
  local selected_text_str = table.concat(State.sel.text_lines, "\n")
  local buf_dir = vim.fn.expand("%:p:h")

  local function proceed(save_dir)
    save_dir = vim.fn.fnamemodify(save_dir, ":p"):gsub("/$", "")

  -- Phase 1: Pick image model
  UI.show_image_model_picker(function(image_model)
    -- Phase 2: LLM generates single abstract prompt
    local cancel_map = vim.api.nvim_set_keymap
    cancel_map("n", "<Esc>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Api.cancel()
        vim.notify("Request cancelled", vim.log.levels.WARN)
        pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
      end,
    })

    Api.chat({
      profile = profile,
      user_content = selected_text_str,
    }, function(result)
      pcall(vim.api.nvim_del_keymap, "n", "<Esc>")

      local prompts = parse_image_prompts(result)
      if #prompts == 0 then
        UI.show_result(result, profile)
        return
      end

      -- Phase 3: Generate image, save PNG, insert markdown link
      local prompt = prompts[1]

      -- Status bar timer for image generation
      State.elapsed_seconds = 0
      State.elapsed_timer = vim.loop.new_timer()
      State.elapsed_timer:start(1000, 1000, vim.schedule_wrap(function()
        State.elapsed_seconds = State.elapsed_seconds + 1
        vim.api.nvim_echo(
          { { string.format("Generating image with %s... %ds (Esc to cancel)", image_model.model, State.elapsed_seconds), "LLMStatus" } },
          false, {}
        )
      end))
      vim.api.nvim_echo(
        { { string.format("Generating image with %s... (Esc to cancel)", image_model.model), "LLMStatus" } },
        false, {}
      )

      local image_job = Api.generate_image({
        model = image_model.model,
        prompt = prompt,
        size = image_model.size,
      }, function(b64_data)
        Api.stop_timer()

        vim.fn.mkdir(save_dir, "p")
        local filename = "journal-" .. os.date("%Y%m%d-%H%M%S") .. ".png"
        local filepath = save_dir .. "/" .. filename
        local ok, err = save_base64_png(b64_data, filepath)
        if not ok then
          vim.notify("Failed to save image: " .. (err or "unknown error"), vim.log.levels.ERROR)
          return
        end

        -- Build path relative to buffer directory for markdown link
        local rel_path
        local buf_prefix = buf_dir .. "/"
        if filepath:sub(1, #buf_prefix) == buf_prefix then
          rel_path = filepath:sub(#buf_prefix + 1)
        else
          rel_path = filepath
        end
        Actions.append_below({ "", string.format("![Visual Journal](%s)", rel_path) })
        vim.notify("Image saved: " .. rel_path, vim.log.levels.INFO)
      end, function(err)
        Api.stop_timer()
        vim.notify("Image generation failed: " .. err, vim.log.levels.ERROR)
      end)

      -- Allow cancelling image generation with Esc
      cancel_map("n", "<Esc>", "", {
        noremap = true,
        silent = true,
        callback = function()
          Api.stop_timer()
          if image_job then
            pcall(function() image_job:shutdown() end)
          end
          vim.notify("Image generation cancelled", vim.log.levels.WARN)
          vim.api.nvim_echo({ { "" } }, false, {})
          pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
        end,
      })
    end, function(err)
      pcall(vim.api.nvim_del_keymap, "n", "<Esc>")
      vim.notify(err, vim.log.levels.ERROR)
    end)
  end)
  end -- proceed

  if opts.save_dir then
    proceed(opts.save_dir)
  else
    vim.ui.input({
      prompt = "Save image to: ",
      default = buf_dir .. "/images/",
      completion = "dir",
    }, function(input)
      if not input or input == "" then
        vim.notify("Image generation cancelled", vim.log.levels.WARN)
        return
      end
      proceed(input)
    end)
  end
end

function Modes.menu()
  if not save_selection() then return end
  UI.show_mode_menu()
end

-- ==========================================================================
-- Entry points
-- ==========================================================================

-- Commands
vim.api.nvim_create_user_command("LLMAssistant", function()
  Modes.code_assistant()
end, { range = true })

vim.api.nvim_create_user_command("LLMJournal", function()
  Modes.journal_summary()
end, { range = true })

vim.api.nvim_create_user_command("LLMMenu", function()
  Modes.menu()
end, { range = true })

vim.api.nvim_create_user_command("LLMImage", function(cmd)
  local dir = cmd.args ~= "" and cmd.args or nil
  Modes.image_generation({ save_dir = dir })
end, { range = true, nargs = "?", complete = "dir" })

-- Keymaps (visual mode)
vim.api.nvim_set_keymap("x", "<leader>p", ":LLMAssistant<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<leader>j", ":LLMJournal<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<leader>l", ":LLMMenu<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<leader>i", ":LLMImage<CR>", { noremap = true, silent = true })

-- Module return (for require and mode menu self-reference)
return {
  code_assistant = Modes.code_assistant,
  journal_summary = Modes.journal_summary,
  image_generation = Modes.image_generation,
  menu = Modes.menu,
}
