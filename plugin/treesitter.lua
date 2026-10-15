vim.pack.add({ { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" } })
require("nvim-treesitter").setup({})

local function attach(bufnr)
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "" then
    return
  end
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang or not pcall(vim.treesitter.language.add, lang) then
    return
  end
  local ok = pcall(vim.treesitter.start, bufnr, lang)
  if not ok then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    -- Set only buffer-local window options; preserve user folds on re-entry.
    local opts = vim.wo[win][0]
    if opts.foldexpr ~= "v:lua.vim.treesitter.foldexpr()" then
      opts.foldmethod = "expr"
      opts.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      opts.foldlevel = 99
    end
  end
end
local group = vim.api.nvim_create_augroup("user-treesitter", { clear = true })
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = group,
  callback = function(ev)
    attach(ev.buf)
  end,
})
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "TSUpdate",
  callback = function()
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          attach(buf)
        end
      end
    end)
  end,
})
vim.api.nvim_create_autocmd("PackChanged", {
  group = group,
  callback = function(ev)
    if ev.data and ev.data.kind == "update" and ev.data.spec.name == "nvim-treesitter" then
      vim.notify(
        "Tree-sitter 插件已更新：重新启动 Neovim 后执行 :TSUpdate，使 parsers 与插件匹配。"
      )
    end
  end,
})
