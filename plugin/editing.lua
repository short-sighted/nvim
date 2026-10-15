vim.pack.add({ { src = "https://github.com/nvim-mini/mini.nvim", version = "stable" } })
require("mini.pairs").setup()
require("mini.surround").setup()
require("mini.ai").setup({ n_lines = 500 })
require("mini.comment").setup()
require("mini.files").setup()
vim.keymap.set("n", "<leader>e", function()
  local files = require("mini.files")
  if files.close() then
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or not vim.uv.fs_stat(path) then
    path = require("config.project").root()
  end
  files.open(path)
end, { desc = "文件浏览" })
