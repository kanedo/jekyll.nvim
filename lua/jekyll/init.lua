---module name (dirname of this file)
local jekyll_plugin = 'jekyll'

---@class JekyllNvim
local M = {}

table.unpack = table.unpack or unpack -- 5.1 compatibility
local Path = require('plenary.path')
local telescope = require('telescope.builtin')

---Function returning a random alphanumeric string of length
---@param k integer
---@return string
---@see https://stackoverflow.com/questions/72523578
local random_string = function(k)
  math.randomseed(os.time())
  local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  local n = string.len(alphabet)
  local pw = {}
  for i = 1, k do
    pw[i] = string.byte(alphabet, math.random(n))
  end
  return string.char(table.unpack(pw, 1, k))
end

local modeline = { '', '<!-- vim: set ft=liquid -->' }

---Main point of entry into creating documents that Jekyll understands
---@param path string
---@param content string[]
---@return integer the buffer number
local create_buffer_with_name_and_content = function(path, content)
  local buf = nil
  if vim.fn.filereadable(path) == 1 then
    vim.cmd.edit(path)
    buf = vim.api.nvim_get_current_buf()
    local last_line = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(0, { last_line, 0 })
  else
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, path)
    vim.api.nvim_set_option_value('filetype', 'liquid', { buf = buf })
    vim.schedule(function()
      vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
      vim.api.nvim_buf_set_lines(buf, -1, -1, true, modeline)
      local last_line = vim.api.nvim_buf_line_count(buf) - #modeline
      vim.api.nvim_win_set_cursor(0, { last_line, 0 })
    end)
  end
  return buf
end

---Creates a new document with appropriate frontmatter in either _drafts or _posts
---@param title string primary name of the new document (converted to lower-snake-case)
---@param folder string parent folder of the new document
---@param date_and_time boolean whether a date and time are to be use in the filename
---@return integer? buffer id number
local create_post_or_draft = function(title, folder, date_and_time)
  if title == '' then
    return
  end
  local title_slug = title:lower():gsub(' ', '-'):gsub('[^%w-]', '')
  local filename = string.format('%s.md', title_slug)
  local time = os.date('%H:%M:%S %z')
  local date = os.date('%Y-%m-%d')
  if date_and_time then
    filename = string.format('%s-%s.md', date, title_slug)
  end
  local path = vim.fn.expand(vim.uv.cwd() .. '/' .. folder .. '/' .. filename)
  local content = {
    '---',
    'layout: post',
    string.format("title: '%s'", title),
    'categories: ',
    'tags: ',
    '---',
  }
  if date_and_time then
    local date_front_matter = string.format('date: %sT%s', date, time)
    table.insert(content, 3, date_front_matter)
  end
  create_buffer_with_name_and_content(path, content)
end

M.create_post = function()
  local title = vim.fn.input('Title: ')
  create_post_or_draft(title, '_posts', true)
end

M.create_draft = function()
  local title = vim.fn.input('Title: ')
  create_post_or_draft(title, '_drafts', false)
end

M.create_note = function()
  local date = os.date('%Y-%m-%d')
  local time = os.date('%H:%M:%S')
  local slug = random_string(5)
  local filename = string.format('%s-%s.md', date, slug)
  local path = vim.fn.expand(vim.uv.cwd() .. '/_notes/' .. filename)
  local content = { '---', string.format('date: %sT%s', date, time), '---' }
  create_buffer_with_name_and_content(path, content)
end

M.promote_draft = function()
  local drafts_dir = Path:new(vim.uv.cwd(), '_drafts')
  local posts_dir = Path:new(vim.uv.cwd(), '_posts')
  telescope.find_files({
    prompt_title = 'Select Draft to Promote',
    cwd = tostring(drafts_dir),
    attach_mappings = function(_, map)
      map('i', '<CR>', function(prompt_bufnr)
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        local date_prefix = os.date('%Y-%m-%d')
        local draft_path = Path:new(drafts_dir .. '/' .. selection.value)
        local new_filename = date_prefix .. '-' .. selection.value
        local new_path = Path:new(posts_dir, new_filename)
        local content = draft_path:read()
        content = content:gsub('date:.-\n', '')
        local date_line = 'date: ' .. os.date('%Y-%m-%d %H:%M:%S') .. ' +0000\n'
        content = content:gsub('^(%-%-%-\n)', '%1' .. date_line)
        new_path:write(content, 'w')
        vim.cmd('edit ' .. new_path.filename)
        draft_path:rm()
        print('Draft promoted to post: ' .. new_path.filename)
      end)
      return true
    end,
  })
end

---@type JekyllNvimOptions
M.opts = {
  augroup_name = 'Jekyll',
}

---@type JekyllUserCommands
M.user_commands = {
  JekyllDraft = function()
    require(jekyll_plugin).create_draft()
  end,
  JekyllPost = function()
    require(jekyll_plugin).create_post()
  end,
  JekyllPromote = function()
    require(jekyll_plugin).promote_draft()
  end,
  JekyllNote = function()
    require(jekyll_plugin).create_note()
  end,
}

---Creates commands used to interact with this plugin from the : prompt
local create_user_commands = function()
  for name, command in pairs(M.user_commands) do
    pcall(function()
      vim.api.nvim_create_user_command(name, command, {})
    end)
  end
  vim.g.loaded_jekyll_nvim = true
end

---Deletes commands used to interact with this plugin from the : prompt
local del_user_commands = function()
  local user_commands = vim.api.nvim_get_commands({ builtin = false })
  for key, _ in pairs(M.user_commands) do
    if vim.fn.has_key(user_commands, key) then
      pcall(function()
        vim.api.nvim_del_user_command(key)
      end)
    end
  end
  vim.g.loaded_jekyll_nvim = false
end

---Determines if the current window should allow the user to interact with this plugin
---@see setup_autocmds
---@return boolean
local is_jekyll_window = function()
  local gemfile = Path:new(vim.uv.cwd(), 'Gemfile')
  local gemfile_exists = Path.exists(gemfile)
  local gemfile_lines = gemfile_exists and Path.readlines(gemfile) or {}
  local gem_match = vim.tbl_contains(gemfile_lines, function(line)
    return string.find(line, 'jekyll')
  end, { predicate = true })
  return gem_match
end

---Determines if the current buffer is on the cdpath of a jekyll window
local is_jekyll_buffer = function()
  return is_jekyll_window() and vim.fn.findfile(vim.fn.expand('%'), vim.o.cdpath)
end

---@param opts JekyllNvimOptions
---@return integer? augroup id number
local setup_autocmds = function(opts)
  ---Create augroup, or retrieve existing one
  local augroup = vim.api.nvim_create_augroup(opts.augroup_name, { clear = false })

  ---Autocommand for making/deleting user_commands on DirChanged event
  ---@param _opts JekyllNvimOptions
  local autocmd_create_del_user_commands = function(_opts)
    vim.api.nvim_create_autocmd('DirChanged', {
      desc = 'Decide whether cwd needs Jekyll user_commands',
      group = _opts.augroup_name,
      callback = function(_)
        if is_jekyll_window() then
          create_user_commands()
        else
          del_user_commands()
        end
      end,
    })
  end

  ---Autocommand for explicitly using the `liquid` filetype so as to get the benefits of snippets, etc...
  ---@param _opts JekyllNvimOptions
  local autocmd_markup_files_use_liquid_ft = function(_opts)
    vim.api.nvim_create_autocmd('BufEnter', {
      desc = 'Change filetype of html/markdown to liquid',
      group = _opts.augroup_name,
      callback = function(_)
        if is_jekyll_buffer() then
          if vim.bo.filetype == 'markdown' or vim.bo.filetype == 'html' then
            vim.bo.filetype = 'liquid'
          end
        end
      end,
    })
  end

  autocmd_create_del_user_commands(opts)
  autocmd_markup_files_use_liquid_ft(opts)
  return augroup
end

---@param opts? JekyllNvimOptions
M.setup = function(opts)
  ---@type JekyllNvimOptions
  local merged_options = vim.tbl_extend('force', M.opts, opts or {})
  if is_jekyll_window() then
    create_user_commands()
  end
  setup_autocmds(merged_options)
end

return M

-- vim: ts=2 sts=2 sw=2 et tw=100
