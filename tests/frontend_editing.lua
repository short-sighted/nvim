-- Run: nvim --headless -i NONE '+luafile tests/frontend_editing.lua'
vim.o.clipboard = ""
for name in pairs(vim.lsp._enabled_configs) do
  vim.lsp.enable(name, false)
end
local cases = {
  { ft = "html", text = "<div", needle = "<div></div>", rename = "<span></span>", col = 1 },
  {
    ft = "vue",
    text = "<div",
    lines = { "<template>", "<div", "</template>" },
    line = 2,
    needle = "<div></div>",
    rename = "<span></span>",
    col = 1,
  },
  {
    ft = "javascriptreact",
    text = "const view = <div",
    needle = "const view = <div></div>",
    rename = "const view = <span></span>",
    col = 14,
  },
  {
    ft = "typescriptreact",
    text = "const view = <div",
    needle = "const view = <div></div>",
    rename = "const view = <span></span>",
    col = 14,
  },
}
local index = 0
local function later(ms, fn)
  vim.defer_fn(function()
    local ok, err = pcall(fn)
    if not ok then
      vim.api.nvim_err_writeln(err)
      vim.cmd("cquit 1")
    end
  end, ms)
end
local function next_case()
  index = index + 1
  local c = cases[index]
  if not c then
    print("Actual insert: HTML/Vue/JSX/TSX tag closing and paired rename passed")
    vim.cmd("qa!")
    return
  end
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, c.lines or { c.text })
  vim.bo.filetype = c.ft
  vim.api.nvim_win_set_cursor(0, { c.line or 1, #c.text - 1 })
  vim.api.nvim_input("A>")
  later(400, function()
    assert(
      vim.api.nvim_get_current_line() == c.needle,
      c.ft .. ": close failed " .. vim.api.nvim_get_current_line()
    )
    vim.api.nvim_input("<Esc>")
    later(100, function()
      vim.api.nvim_win_set_cursor(0, { c.line or 1, c.col })
      vim.api.nvim_input("ciwspan<Esc>")
      later(400, function()
        assert(
          vim.api.nvim_get_current_line() == c.rename,
          c.ft .. ": rename failed " .. vim.api.nvim_get_current_line()
        )
        next_case()
      end)
    end)
  end)
end
later(100, next_case)
