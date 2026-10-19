-- cmake-tools' plugin script requires these modules during packadd.
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/mfussenegger/nvim-dap",
  "https://github.com/stevearc/overseer.nvim",
  "https://github.com/Civitasv/cmake-tools.nvim",
})

local function output()
  require("overseer").open({ enter = false, direction = "bottom" })
end
local native_lldb = require("config.tools").lldb_dap()

require("cmake-tools").setup({
  cmake_command = require("config.tools").executable("cmake") or "cmake",
  cmake_regenerate_on_save = false,
  cmake_virtual_text_support = false,
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
  cmake_compile_commands_options = {
    action = "copy",
    target = function()
      return require("cmake-tools").get_config().cwd
    end,
  },
  cmake_executor = { name = "overseer", opts = { on_new_task = output } },
  cmake_runner = { name = "overseer", opts = { on_new_task = output } },
  cmake_dap_configuration = {
    name = "CMake 调试",
    type = native_lldb and "lldb" or "codelldb",
    request = "launch",
    stopOnEntry = false,
    -- Native LLDB launches directly; codelldb keeps its integrated terminal.
    runInTerminal = not native_lldb,
    console = native_lldb and "internalConsole" or "integratedTerminal",
    initCommands = {},
  },
})

local cpp = require("config.cpp")
cpp.setup()
vim.keymap.set("n", "<leader>cR", cpp.activate, { desc = "使用当前 CMake 工程（标签页目录）" })
for key, item in pairs({
  c = { "CMakeGenerate", "配置 CMake 工程" },
  b = { "CMakeBuild", "构建所选目标" },
  r = { "CMakeRun", "构建并运行所选程序" },
  d = { "CMakeDebug", "构建并调试所选程序" },
  t = { "CMakeSelectBuildTarget", "选择构建目标" },
  l = { "CMakeSelectLaunchTarget", "选择运行 / 调试目标" },
  p = { "CMakeSelectConfigurePreset", "选择配置预设" },
  P = { "CMakeSelectBuildPreset", "选择构建预设" },
  v = { "CMakeSelectBuildType", "选择构建类型（无预设工程）" },
}) do
  vim.keymap.set("n", "<leader>c" .. key, function()
    cpp.action(item[1])
  end, { desc = item[2] })
end
vim.keymap.set("n", "<leader>cs", function()
  require("cmake-tools").stop_executor()
  require("cmake-tools").stop_runner()
end, { desc = "停止 CMake 构建 / 运行任务" })
