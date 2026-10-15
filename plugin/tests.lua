vim.pack.add({
  "https://github.com/nvim-neotest/neotest",
  "https://github.com/nvim-neotest/neotest-python",
  "https://github.com/fredrikaverpil/neotest-golang",
  "https://github.com/rouge8/neotest-rust",
  "https://github.com/marilari88/neotest-vitest",
  "https://github.com/haydenmeade/neotest-jest",
  "https://github.com/nsidorenco/neotest-vstest",
  "https://github.com/orjangj/neotest-ctest",
})
require("neotest").setup({
  adapters = require("config.test_adapters").get(),
  discovery = { enabled = true, concurrent = 2, filter_dir = require("config.test_adapters").filter_dir },
  running = { concurrent = false },
  summary = { animated = false, mappings = { close = { "q", "<Esc>" } } },
  output = { open_on_run = false },
  quickfix = { open = false },
})
local function run(opts)
  return function()
    if vim.bo.buftype ~= "" then
      vim.notify("请先回到源码文件再运行测试。", vim.log.levels.INFO)
      return
    end
    require("neotest").run.run(type(opts) == "function" and opts() or opts)
  end
end
local map = vim.keymap.set
map("n", "<leader>rt", run(), { desc = "运行当前测试" })
map(
  "n",
  "<leader>rf",
  run(function()
    return vim.api.nvim_buf_get_name(0)
  end),
  { desc = "运行当前文件测试" }
)
map(
  "n",
  "<leader>rT",
  run(function()
    return require("config.project").root()
  end),
  { desc = "运行当前项目测试" }
)
map("n", "<leader>rd", run({ strategy = "dap" }), { desc = "调试当前测试" })
map("n", "<leader>rs", function()
  require("neotest").run.stop()
end, { desc = "停止当前测试" })
map("n", "<leader>ro", function()
  require("neotest").output.open({ enter = true })
end, { desc = "当前测试输出" })
map("n", "<leader>rp", function()
  require("neotest").output_panel.toggle()
end, { desc = "测试输出面板" })
map("n", "<leader>rS", function()
  require("neotest").summary.toggle()
end, { desc = "测试树 / 测试状态" })
