local Popup = require("nui.popup")
local Input = require("nui.input")
local Layout = require("nui.layout")
local event = require("nui.utils.autocmd").event
local curl = require("plenary.curl")
local json = vim.fn.json_encode
local decode = vim.fn.json_decode

-- Constants for API interaction
local API_URL = "https://api.openai.com/v1/chat/completions"
local API_KEY = ""

-- Setup highlight groups to indicate success and error messages
-- Green for successful completion messages
vim.api.nvim_set_hl(0, "SuccessMsg", { fg = "#00ff00", bg = "#000000", bold = true })
-- Red for error messages
vim.api.nvim_set_hl(0, "ErrorMsg", { fg = "#ff0000", bg = "#000000", bold = true })

-- Utility function to split strings based on a given delimiter
function string:split(delimiter)
    local result = {}
    -- Starting position for finding the delimiter
    local from = 1
    -- Find the delimiter in the string
    local delim_from, delim_to = string.find(self, delimiter, from, true)

    while delim_from do
        -- Insert the substring before the delimiter into the result table
        if delim_from ~= 1 then
            table.insert(result, string.sub(self, from, delim_from - 1))
        end
        -- Move the starting position past the last delimiter
        from = delim_to + 1
        -- Find the next delimiter
        delim_from, delim_to = string.find(self, delimiter, from, true)
    end

    -- Add the remaining substring after the last delimiter
    if from <= #self then
        table.insert(result, string.sub(self, from))
    end

    return result
end

-- Constructs the payload for the API request to OpenAI using the custom
-- prompt and journal content
local function create_api_payload(custom_prompt, journal_content)
    return json({
        model = "gpt-4.1-mini",
        messages = {
            {
                role = "system",
                content = "You are a highly skilled and helpful assistant for a code editor. " ..
                          "Your primary role is to respond to user queries related to coding. " ..
                          "Provide detailed explanations for code-related questions, refactor code if needed, " ..
                          "and debug errors effectively. Aim to enhance the user's understanding by " ..
                          "offering clear insights and constructive feedback. Be polite, professional, " ..
                          "and ensure your responses are easy to follow." ..
                          "Examples: 'Given the code snippet, explain how it works.' " ..
                          "or 'Refactor this function to improve readability and performance.'"
            },
            {
                role = "user",
                content = custom_prompt .. "\n\n```" .. journal_content .. "```"
            }
        },
        temperature = 0.35,
    })
end

-- Sends a POST request to the OpenAI API with the constructed payload
local function send_post_request(custom_prompt, journal_content)
    local payload = create_api_payload(custom_prompt, journal_content)

    local response = curl.request({
        url = API_URL,
        method = "post",
        headers = {
            content_type = "application/json",
            authorization = "Bearer " .. API_KEY,
        },
        body = payload,
        timeout = 50000,
    })

    -- Check if the response status is not successful
    if response.status ~= 200 then
        return nil, "HTTP request failed: " .. response.status
    end

    -- Parse the JSON response to extract the desired content
    local parsed_response = decode(response.body)
    return parsed_response.choices[1].message.content, nil
end

-- Retrieves the currently selected text range in visual mode
local function get_visual_selection()
    local start_line, start_col, end_line, end_col

    -- Determine the range for selection based on given parameters or the
    -- current visual selection
    -- Adjust for zero-based indexing
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2] - 1
    local start_col = start_pos[3] - 1
    local end_line = end_pos[2] - 1
    local end_col = end_pos[3] - 1

    -- Handle very large column values
    if end_col >= 2147483646 then
        end_col = #vim.fn.getline(end_line + 1)
    end

    -- Return the selected text and the corresponding line and column
    -- positions
    return vim.api.nvim_buf_get_text(0, start_line, start_col, end_line, end_col, {}),
           start_line, start_col, end_line, end_col
end

-- Creates a popup for user input, and selected text and puts them in a layout
local function create_first_layout()
    local selected_text_popup = Popup({
      relative = { type = "buf", position = "50%" },
      size = { width = "100%", height = "50%" },
      border = { style = "rounded", text = { top = " Selected Text " } },
    })

    local input_popup = Popup({
      relative = { type = "buf", position = "50%" },
      size = { width = "50%", height = "50%" },
      enter = true,
      focusable = true,
      zindex = 50,
      border = {
        padding = { top = 2, bottom = 2, left = 3, right = 3 },
        style = "rounded",
        text = {
            top = " What's your request? ",
            top_align = "center",
            bottom = "Type <leader>s to submit your prompt or :q to quit",
            bottom_align = "left"
        },
      },
    })
    local first_layout = Layout(
      {
        position = "50%",
        size = {
          width = "50%",
          height = "50%",
        },
      },
      Layout.Box({
        Layout.Box(input_popup, { size = "70%" }),
        Layout.Box(selected_text_popup, { size = "30%" }),
      }, { dir = "row" }))

    -- Create result popup
    local result_popup = Popup({
      relative = { type = "buf", position = "50%" },
      border = { style = "rounded", text = { top = " Response " } },
    })

    local second_layout = Layout(
      {
        position = "50%",
        size = {
          width = "50%",
          height = "50%",
        },
      },
      Layout.Box({
        Layout.Box(result_popup, { size = "100%" }),
      }, { dir = "row" }))

    return selected_text_popup , input_popup , result_popup, first_layout , second_layout
end

-- Handles the submission process: unmounts input popup, sends request, and
-- displays result
local function handle_submission(first_layout, second_layout, selected_text_popup, result_popup, prompt, selected_text)
    vim.api.nvim_echo({{"Sending request to ChatGPT API...", "Normal"}}, false, {})
    first_layout:unmount()

    local result, err = send_post_request(prompt, selected_text)

    if result then
        vim.api.nvim_echo({{"Done!", "SuccessMsg"}}, false, {})
        second_layout:mount()
        vim.api.nvim_buf_set_lines(result_popup.bufnr, 0, -1, false, result:split('\n'))
    else
        vim.api.nvim_echo({{"Failed: " .. err, "ErrorMsg"}}, false, {})
    end
end

-- Main function to print the currently selected text from visual mode
local function PrintVisualSelection()
    -- Get the current buffer number
    local curr_buf = vim.api.nvim_get_current_buf()
    -- Get the selected text
    local selection, start_line, start_col, end_line, end_col = get_visual_selection()

    -- Create the the first user input layout
    local selected_text_popup, input_popup, result_popup, first_layout, second_layout = create_first_layout()

    -- Map key for submission to handle the API request
    input_popup:map("n", "<leader>s", function()
        -- Get lines from the input popup
        local lines = vim.api.nvim_buf_get_lines(input_popup.bufnr, 0, -1, false)
        -- Concatenate lines to form the prompt
        local prompt = table.concat(lines, '\n')
        -- Fetch (possibly altered) selected text
        local selected_text_altered = vim.api.nvim_buf_get_lines(selected_text_popup.bufnr, 0, -1, false)
        local selected_text = table.concat(selected_text_altered, '\n')
        handle_submission(first_layout, second_layout, selected_text_popup, result_popup, prompt, selected_text)
    end, { noremap = true })

    -- Map key for saving the result back into the original buffer
    result_popup:map("n", "<leader>s", function()
        -- Get lines from the (possibly altered) result popup
        local result_lines = vim.api.nvim_buf_get_lines(result_popup.bufnr, 0, -1, false)
        -- Substitute text with result
        vim.api.nvim_buf_set_text(curr_buf, start_line, start_col, end_line, end_col, result_lines)
        second_layout:unmount()  -- Close the result popup
    end, { noremap = true })  -- Define key mapping options

    first_layout:mount()

    -- Populate the yanked text popup
    vim.api.nvim_buf_set_lines(selected_text_popup.bufnr, 0, -1, false, selection)

    vim.cmd("startinsert")
end

-- Expose command and key mapping for triggering visual selection API request
vim.api.nvim_create_user_command('ChatGPTUI', function(params)
    PrintVisualSelection()
end, { range = true })

vim.api.nvim_set_keymap('x', '<leader>p', ':ChatGPTUI<CR>', { noremap = true, silent = true })
