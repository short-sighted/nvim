vim.pack.add({
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/folke/which-key.nvim",
})
require("nvim-web-devicons").setup()
require("lualine").setup({
  options = { theme = "auto", globalstatus = true },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { { "filename", path = 1 } },
    lualine_x = {
      function()
        local names = {}
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
          names[#names + 1] = client.name
        end
        table.sort(names)
        return table.concat(names, ", ")
      end,
      "encoding",
      "filetype",
    },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  extensions = { "fugitive", "quickfix" },
})
require("which-key").setup({
  delay = 400,
  icons = { mappings = false },
  spec = {
    { "<leader>b", group = "文件缓冲区" },
    { "<leader>d", group = "调试" },
    { "<leader>f", group = "查找 / 操作搜索" },
    { "<leader>g", group = "Git" },
    { "<leader>h", group = "Git 变更块" },
    { "<leader>l", group = "语言 / LSP" },
    { "<leader>r", group = "运行 / 构建 / 测试" },
    { "<leader>s", group = "分屏" },
    { "<leader>t", group = "开关 / 终端" },
    { "<leader>x", group = "诊断 / 结果列表" },
  },
})
vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "当前文件操作提示" })
