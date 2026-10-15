vim.pack.add({ "https://github.com/stevearc/conform.nvim" })
local conform = require("conform")
conform.setup({
  formatters_by_ft = {
    lua = { "stylua" },
    rust = { "rustfmt" },
    c = { "clang_format" },
    cpp = { "clang_format" },
    go = { "goimports", "gofumpt" },
    python = { "ruff_organize_imports", "ruff_format" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    vue = { "prettier" },
    svelte = { "prettier" },
    html = { "prettier" },
    css = { "prettier" },
    scss = { "prettier" },
    json = { "prettier" },
    jsonc = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    cs = { lsp_format = "prefer", name = "roslyn" },
  },
  default_format_opts = {
    lsp_format = "fallback",
  },
  format_on_save = function(bufnr)
    if vim.g.autoformat ~= true or vim.b[bufnr].autoformat == false then
      return
    end
    return { timeout_ms = 1500, lsp_format = "fallback" }
  end,
})
vim.keymap.set({ "n", "x" }, "<leader>lf", function()
  conform.format({ async = true })
end, { desc = "格式化文件 / 选区" })
vim.keymap.set("n", "<leader>tf", function()
  vim.g.autoformat = not vim.g.autoformat
  vim.notify("保存时格式化：" .. (vim.g.autoformat and "开启" or "关闭"))
end, { desc = "切换保存时格式化" })
