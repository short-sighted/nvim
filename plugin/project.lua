for key, item in pairs({
  b = { "build", "构建当前项目" },
  R = { "run", "运行项目 / 前端开发服务" },
  c = { "check", "检查 / 测试当前项目" },
  v = { "lint", "运行项目静态检查" },
}) do
  vim.keymap.set("n", "<leader>r" .. key, function()
    require("config.project_actions").run(item[1])
  end, { desc = item[2] })
end
