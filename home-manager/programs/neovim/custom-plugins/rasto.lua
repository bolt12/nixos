-- rasto: runs the rasto skill (~/.claude/skills/rasto) on the weekly note in
-- the current buffer, inside olaude, so the note's text only reaches the local
-- model. The note is saved first and stays read-only until olaude exits, so a
-- stale buffer can never be written over what rasto adds. When the run changed
-- the note, the buffer is reloaded and :Gdiffsplit shows exactly what rasto
-- wrote (rasto stages the note before writing it).
--
--   :Rasto        run on the note in the current buffer   (<leader>jr)
--   :Rasto undo   take back rasto's last write to that note
--
-- Both also work from the index side of the diff. What counts as a weekly
-- note, and which week it is, is rasto.py's call (`rasto.py check <path>`), so
-- the plugin and the skill never disagree.

local M = {}

M.config = {
  command = "olaude-qwen3-8-27B",
  skill = "~/.claude/skills/rasto",
  keymap = "<leader>jr",
}

local INFO, WARN, ERROR = vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR

-- The run in progress, if any: { buf, unlock } while rasto.py checks the note,
-- then also { term, path, name, before, from }. buf is nil when the note is
-- not loaded in any buffer.
local active

local function notify(msg, level)
  vim.notify(msg, level or INFO, { title = "rasto" })
end

local function skill_file(rel)
  return vim.fs.joinpath(vim.fn.expand(M.config.skill), rel)
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function same_file(a, b)
  local ra = a ~= "" and vim.uv.fs_realpath(a) or nil
  return ra ~= nil and ra == vim.uv.fs_realpath(b)
end

-- The file behind buf. A fugitive buffer of the note (the index side of the
-- diff) counts as the note.
local function file_of(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name:match("^fugitive://") and vim.fn.exists("*FugitiveReal") == 1 then
    name = vim.fn.FugitiveReal(name)
  end
  return name
end

-- The loaded buffer holding the file at path itself, if any.
local function buffer_of(path)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    if vim.api.nvim_buf_is_loaded(b) and not name:match("^%a+://") and same_file(name, path) then
      return b
    end
  end
end

-- Makes buf read-only and returns the function that puts it back.
local function lock(buf)
  if not buf then
    return function() end
  end
  local modifiable, readonly = vim.bo[buf].modifiable, vim.bo[buf].readonly
  vim.bo[buf].modifiable, vim.bo[buf].readonly = false, true
  return function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.bo[buf].modifiable, vim.bo[buf].readonly = modifiable, readonly
    end
  end
end

-- Re-reads buf from disk, without the "file changed" prompt: buf has no
-- changes of its own, since it was locked.
local function reload(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
    pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("silent edit")
    end)
  end
end

-- Fugitive's copies of the note (the index side of an old diff) are stale once
-- rasto has staged or unstaged it.
local function drop_stale_diffs(path)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):match("^fugitive://") and same_file(file_of(b), path) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  pcall(vim.cmd, "diffoff!")
end

-- Runs rasto.py with args and calls back, on the main loop, with its JSON
-- reply, or with { ok = false, error } when there is none.
local function script(args, cwd, callback)
  local function reply(out)
    vim.schedule(function()
      callback(out)
    end)
  end
  local cmd = vim.list_extend({ "python3", skill_file("scripts/rasto.py") }, args)
  local ok, err = pcall(vim.system, cmd, { cwd = cwd, text = true }, function(r)
    local decoded, out = pcall(vim.json.decode, r.stdout or "")
    if decoded and type(out) == "table" then
      return reply(out)
    end
    local text = vim.trim((r.stderr or "") .. (r.stdout or ""))
    reply({ ok = false, error = text ~= "" and text or ("rasto.py exited with code " .. r.code) })
  end)
  if not ok then
    reply({ ok = false, error = tostring(err) })
  end
end

-- rasto.py's view of the note at path: { ok, week, root, note, written, path,
-- name } or { ok = false, error }.
local function check(path, callback)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    return callback({ ok = false, error = "open a weekly note first (journal/WeeklyLogs/<year>/Week-NN-*.md)" })
  end
  script({ "check", path }, vim.fs.dirname(path), function(out)
    if out.ok then
      out.path = vim.fs.joinpath(out.root, out.note)
      out.name = vim.fs.basename(out.note):gsub("%.md$", "")
    end
    callback(out)
  end)
end

local function finish(code)
  local run = active
  active = nil
  if not run then
    return
  end
  run.unlock()
  local changed = read_file(run.path) ~= run.before
  local quit = code == 0 and "" or (" (olaude exited with code " .. code .. ")")
  if changed then
    reload(run.buf)
    drop_stale_diffs(run.path)
    -- The diff takes the terminal's place, so the run's tab becomes its review.
    local wins = vim.fn.win_findbuf(run.term)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
      vim.wo.winbar = ""
      vim.cmd("edit " .. vim.fn.fnameescape(run.path))
    else
      vim.cmd("tabedit " .. vim.fn.fnameescape(run.path))
    end
    local diffed = vim.fn.exists(":Gdiffsplit") == 2 and pcall(vim.cmd, "Gdiffsplit")
    notify(
      run.name .. " changed" .. quit .. ". "
        .. (diffed and "The diff shows only rasto's blocks; close the tab to keep them, " or "Review it with git diff; ")
        .. ":Rasto undo takes them back.",
      code == 0 and INFO or WARN
    )
  elseif code == 0 then
    notify(run.name .. " is unchanged.")
  else
    -- Keep the terminal, so whatever olaude said last can still be read.
    return notify(run.name .. " is unchanged" .. quit .. ".", WARN)
  end
  if vim.api.nvim_buf_is_valid(run.term) then
    pcall(vim.api.nvim_buf_delete, run.term, { force = true })
  end
  if not changed and vim.api.nvim_win_is_valid(run.from) then
    vim.api.nvim_set_current_win(run.from)
  end
end

local function start(out)
  local before = read_file(out.path)
  local from = vim.api.nvim_get_current_win()
  vim.cmd("tabnew")
  local term = vim.api.nvim_get_current_buf()
  local args = { M.config.command, "--settings=" .. skill_file("settings.json"), "/rasto " .. out.note }
  local ok, job = pcall(vim.fn.jobstart, args, {
    term = true,
    cwd = out.root,
    on_exit = function(_, code)
      vim.schedule(function()
        finish(code)
      end)
    end,
  })
  if not ok or job <= 0 then
    pcall(vim.api.nvim_buf_delete, term, { force = true })
    active.unlock()
    active = nil
    return notify("could not start " .. M.config.command .. (ok and "" or (": " .. tostring(job))), ERROR)
  end
  active = vim.tbl_extend("force", active, { term = term, path = out.path, name = out.name, before = before, from = from })
  pcall(vim.api.nvim_buf_set_name, term, "rasto://" .. out.name)
  vim.wo.winbar = " rasto · " .. out.name .. " · the note is read-only until you quit olaude (/exit); then the diff opens"
  vim.cmd("startinsert")
end

function M.run()
  if active then
    if active.term and vim.api.nvim_buf_is_valid(active.term) then
      local wins = vim.fn.win_findbuf(active.term)
      if #wins > 0 then
        vim.api.nvim_set_current_win(wins[1])
      else
        vim.cmd("tab sbuffer " .. active.term)
      end
      vim.cmd("startinsert")
      notify("rasto is already running on " .. active.name)
    end
    return
  end
  if vim.fn.executable(M.config.command) ~= 1 then
    return notify(M.config.command .. " is not on PATH", ERROR)
  end
  if vim.fn.filereadable(skill_file("settings.json")) ~= 1 then
    return notify("the rasto skill is not installed at " .. M.config.skill, ERROR)
  end
  local cur = vim.api.nvim_get_current_buf()
  local path = file_of(cur)
  local buf = path == vim.api.nvim_buf_get_name(cur) and cur or buffer_of(path)
  if buf and vim.bo[buf].modified then
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("write")
    end)
    if not ok then
      return notify("could not save the note: " .. err, ERROR)
    end
  end
  -- Locked from here, so the note cannot change between the check and the run.
  active = { buf = buf, unlock = lock(buf) }
  check(path, function(out)
    if not out.ok then
      active.unlock()
      active = nil
      return notify(out.error, WARN)
    end
    start(out)
  end)
end

function M.undo()
  if active then
    return notify("a rasto run is still open: quit olaude in its tab first", WARN)
  end
  check(file_of(vim.api.nvim_get_current_buf()), function(out)
    if not out.ok then
      return notify(out.error, WARN)
    end
    local buf = buffer_of(out.path)
    if buf and vim.bo[buf].modified then
      return notify("save or discard your changes to " .. out.name .. " first", WARN)
    end
    if not out.written then
      return notify("rasto has nothing to take back in " .. out.name)
    end
    if vim.fn.confirm("Take back rasto's last write to " .. out.name .. "?", "&Undo\n&Cancel", 2) ~= 1 then
      return
    end
    local unlock = lock(buf)
    script({ "undo", out.path }, out.root, function(r)
      unlock()
      reload(buf)
      drop_stale_diffs(out.path)
      notify(r.ok and r.show or r.error, r.ok and INFO or WARN)
    end)
  end)
end

vim.api.nvim_create_user_command("Rasto", function(cmd)
  if cmd.args == "" then
    M.run()
  elseif cmd.args == "undo" then
    M.undo()
  else
    notify("usage: :Rasto or :Rasto undo", WARN)
  end
end, {
  nargs = "?",
  desc = "rasto: add this week's services to the note, or undo that",
  complete = function()
    return { "undo" }
  end,
})

vim.keymap.set("n", M.config.keymap, M.run, { silent = true, desc = "rasto: add this week's services to the note" })

return M
