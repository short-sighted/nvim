vim.pack.add({ "https://github.com/folke/trouble.nvim" })
local trouble = require("trouble")
trouble.setup({
  focus = true,
  open_no_results = true,
  keys = {
    ["<esc>"] = "close",
    ["<cr>"] = { action = "jump", desc = "定位并返回编辑窗口" },
    q = { action = "close", desc = "关闭结果面板" },
    ["?"] = { action = "help", desc = "面板操作说明" },
  },
  modes = {
    project_diagnostics = { mode = "diagnostics", desc = "项目诊断" },
    buffer_diagnostics = { mode = "diagnostics", desc = "当前文件诊断", filter = { buf = 0 } },
  },
})
vim.keymap.set("n", "<leader>xx", function()
  local root = vim.fn.resolve(require("config.project").root())
  trouble.toggle({
    mode = "project_diagnostics",
    filter = {
      function(item)
        return item.filename and vim.fs.relpath(root, vim.fn.resolve(item.filename)) ~= nil
      end,
    },
  })
end, { desc = "项目诊断面板" })
vim.keymap.set("n", "<leader>xb", function()
  trouble.toggle("buffer_diagnostics")
end, { desc = "当前文件诊断面板" })
vim.keymap.set("n", "<leader>xl", function()
  trouble.toggle("lsp")
end, { desc = "LSP 引用 / 定义结果" })
vim.keymap.set("n", "<leader>xs", function()
  trouble.toggle("symbols")
end, { desc = "文件符号面板" })
vim.keymap.set("n", "<leader>xQ", function()
  trouble.toggle("qflist")
end, { desc = "Quickfix 结果面板" })
