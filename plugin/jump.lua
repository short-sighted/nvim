vim.pack.add({ "https://github.com/folke/flash.nvim" })
require("flash").setup({
  modes = {
    search = { enabled = false },
    char = { enabled = false },
  },
})
vim.keymap.set({ "n", "x", "o" }, "<leader>j", function()
  require("flash").jump()
end, { desc = "文字标签跳转" })
vim.keymap.set({ "n", "x", "o" }, "<leader>J", function()
  if not pcall(vim.treesitter.get_parser, 0) then
    vim.notify("当前文件没有 Tree-sitter parser，使用 空格 j 文字跳转。", vim.log.levels.INFO)
    return
  end
  require("flash").treesitter()
end, { desc = "代码结构选择" })
