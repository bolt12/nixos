local function wrap_images_grid()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = vim.api.nvim_buf_get_mark(bufnr, "<")[1]
  local end_line = vim.api.nvim_buf_get_mark(bufnr, ">")[1]

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines > 0 and lines[#lines] ~= "" then
    table.insert(lines, "")
  end

  local cleaned_lines = {}
  for _, line in ipairs(lines) do
    local cline = vim.trim(line:gsub("\r", ""):gsub("%z", ""))
    if cline ~= "" then
      table.insert(cleaned_lines, cline)
    end
  end

  local count = #cleaned_lines
  local cols, rows
  if count <= 4 then
    cols = count
    rows = 1
  else
    cols = 4
    rows = math.ceil(count / 4)
  end

  local gridclass = "grid grid-cols-" .. cols .. " grid-rows-" .. rows .. " gap-2"
  local result = { ':::{class="' .. gridclass .. '"' .. '}' }
  for _, line in ipairs(cleaned_lines) do
    table.insert(result, ':::{class="' .. 'hover:scale-105 transition-transform duration-300' .. '"' .. '}' )
    table.insert(result, line)
    table.insert(result, ":::")
  end
  table.insert(result, ":::")

  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, result)
end

-- Expose command and key mapping for triggering visual selection API request
vim.api.nvim_create_user_command('WrapImagesGrid', function(params)
    wrap_images_grid()
end, { range = true })

vim.api.nvim_set_keymap('x', '<leader>wi', ':WrapImagesGrid<CR>', { noremap = true, silent = true })
