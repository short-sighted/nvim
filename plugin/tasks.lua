vim.pack.add({ "https://github.com/stevearc/overseer.nvim" })
require("overseer").setup({
  -- The project-scoped listener uses public Overseer APIs without changing cwd.
  dap = false,
  disable_template_modules = { "overseer.template.vscode", "overseer.template.npm" },
  task_list = {
    direction = "bottom",
    keymaps = {
      ["?"] = { "keymap.show_help", desc = "任务操作说明" },
      ["<CR>"] = { "keymap.run_action", desc = "选择任务操作" },
      o = { "keymap.open", desc = "打开任务输出" },
      q = { "<CMD>close<CR>", desc = "关闭任务面板" },
      ["<Esc>"] = { "<CMD>close<CR>", desc = "关闭任务面板" },
    },
  },
})
require("config.task_templates").register()
require("overseer").register_template(require("config.overseer.vscode"))
require("dap").listeners.on_config.user_tasks = require("config.tasks").before_debug
vim.keymap.set("n", "<leader>rr", require("config.tasks").run, { desc = "选择运行 / 构建任务" })
vim.keymap.set("n", "<leader>rl", "<cmd>OverseerToggle<cr>", { desc = "任务列表与输出" })
vim.keymap.set(
  "n",
  "<leader>ra",
  require("config.tasks").restart,
  { desc = "重跑当前项目最近任务" }
)
