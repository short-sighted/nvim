vim.pack.add({
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/sindrets/diffview.nvim",
})

require("gitsigns").setup({
  current_line_blame = false,
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    map("n", "]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        gs.nav_hunk("next")
      end
    end, "下一处 Git 变更")
    map("n", "[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        gs.nav_hunk("prev")
      end
    end, "上一处 Git 变更")
    map("n", "<leader>hs", gs.stage_hunk, "暂存变更块")
    map("n", "<leader>hr", gs.reset_hunk, "还原变更块")
    map("x", "<leader>hs", function()
      gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "暂存选中行")
    map("x", "<leader>hr", function()
      gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "还原选中行")
    map("n", "<leader>hS", gs.stage_buffer, "暂存整个文件")
    map("n", "<leader>hu", gs.reset_buffer_index, "取消文件暂存")
    map("n", "<leader>hp", gs.preview_hunk, "预览变更块")
    map("n", "<leader>hb", function()
      gs.blame_line({ full = true })
    end, "查看行提交信息")
    map("n", "<leader>hd", gs.diffthis, "与暂存区比较")
    map("n", "<leader>ht", gs.toggle_current_line_blame, "切换行提交提示")
    map({ "o", "x" }, "ih", gs.select_hunk, "选择 Git 变更块")
  end,
})
require("diffview").setup({})
local map = vim.keymap.set
map("n", "<leader>gs", "<cmd>Git<cr>", { desc = "Git 状态" })
map("n", "<leader>gl", "<cmd>Git log --oneline --decorate<cr>", { desc = "Git 提交历史" })
map("n", "<leader>gc", "<cmd>Git commit<cr>", { desc = "Git 提交" })
map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "查看 Git 差异" })
map("n", "<leader>gD", "<cmd>DiffviewClose<cr>", { desc = "关闭差异视图" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "当前文件历史" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "仓库历史" })
