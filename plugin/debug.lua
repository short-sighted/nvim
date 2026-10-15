vim.pack.add({
  "https://github.com/mfussenegger/nvim-dap",
  "https://github.com/nvim-neotest/nvim-nio",
  "https://github.com/rcarriga/nvim-dap-ui",
})
local dap, dapui = require("dap"), require("dapui")
local tools = require("config.tools")
local root = require("config.project").root
dapui.setup()
dap.listeners.after.event_initialized.user_ui = function()
  dapui.open()
end
dap.listeners.before.event_terminated.user_ui = function()
  dapui.close()
end
dap.listeners.before.event_exited.user_ui = function()
  dapui.close()
end

local function missing(package)
  vim.notify("Debug adapter unavailable. Install with :MasonInstall " .. package, vim.log.levels.WARN)
end
dap.adapters.codelldb = function(callback)
  local command = tools.executable("codelldb")
  if not command then
    return missing("codelldb")
  end
  callback({ type = "executable", command = command })
end
local native_lldb = tools.lldb_dap()
if native_lldb then
  dap.adapters.lldb = { type = "executable", command = native_lldb }
end
dap.adapters.go = function(callback, config)
  local command = tools.executable("dlv")
  if not command then
    return missing("delve")
  end
  callback({
    type = "server",
    port = "${port}",
    executable = {
      command = command,
      args = { "dap", "-l", "127.0.0.1:${port}" },
      -- Delve builds relative to the adapter process, not just launch.cwd.
      cwd = config.cwd or root(),
    },
  })
end
dap.adapters.python = function(callback)
  local command = tools.executable("debugpy-adapter")
  if not command then
    return missing("debugpy")
  end
  callback({ type = "executable", command = command })
end
dap.adapters.debugpy = dap.adapters.python
dap.adapters.coreclr = function(callback)
  local command = vim.g.netcoredbg_path or tools.executable("netcoredbg")
  if not command or vim.fn.executable(command) ~= 1 then
    vim.notify(
      "C# debugging needs netcoredbg. Run :MasonInstall netcoredbg or set vim.g.netcoredbg_path to a compatible build.",
      vim.log.levels.WARN
    )
    return
  end
  callback({ type = "executable", command = command, args = { "--interpreter=vscode" } })
end
local function js_adapter(callback)
  local command = tools.executable("node")
  local server = tools.mason_path("packages/js-debug-adapter/js-debug/src/dapDebugServer.js")
  if not command or not vim.uv.fs_stat(server) then
    return missing("js-debug-adapter")
  end
  callback({
    type = "server",
    host = "127.0.0.1",
    port = "${port}",
    executable = { command = command, args = { server, "${port}", "127.0.0.1" } },
  })
end
dap.adapters["pwa-node"] = js_adapter
dap.adapters["node"] = js_adapter
dap.adapters["pwa-chrome"] = js_adapter
dap.adapters["chrome"] = js_adapter

local function input_program(prompt)
  return function()
    return coroutine.create(function(co)
      vim.ui.input({ prompt = prompt, default = root() .. "/", completion = "file" }, function(value)
        coroutine.resume(co, value and value ~= "" and vim.fn.fnamemodify(value, ":p") or dap.ABORT)
      end)
    end)
  end
end
local native = {
  {
    name = "Launch executable",
    type = native_lldb and "lldb" or "codelldb",
    request = "launch",
    program = input_program("Executable: "),
    cwd = root,
    args = {},
    stopOnEntry = false,
  },
  {
    name = "Attach to process",
    type = native_lldb and "lldb" or "codelldb",
    request = "attach",
    pid = require("dap.utils").pick_process,
    cwd = root,
  },
}
for _, ft in ipairs({ "c", "cpp", "rust" }) do
  dap.configurations[ft] = vim.deepcopy(native)
end
dap.configurations.go = {
  {
    name = "Debug package",
    type = "go",
    request = "launch",
    mode = "debug",
    program = function()
      return vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    end,
    cwd = root,
  },
  {
    name = "Debug package tests",
    type = "go",
    request = "launch",
    mode = "test",
    program = function()
      return vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    end,
    cwd = root,
  },
  {
    name = "Attach to Go process",
    type = "go",
    request = "attach",
    mode = "local",
    processId = require("dap.utils").pick_process,
    cwd = root,
  },
}
dap.configurations.python = {
  {
    name = "Debug current file",
    type = "python",
    request = "launch",
    program = "${file}",
    cwd = root,
    pythonPath = tools.python,
    console = "integratedTerminal",
    justMyCode = true,
  },
}
dap.configurations.cs = {
  {
    name = "Launch .NET DLL",
    type = "coreclr",
    request = "launch",
    program = input_program("Built DLL: "),
    cwd = root,
    args = {},
    stopAtEntry = false,
  },
  {
    name = "Attach .NET process",
    type = "coreclr",
    request = "attach",
    processId = require("dap.utils").pick_process,
  },
}
for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" }) do
  dap.configurations[ft] = {
    {
      name = "Attach Node process",
      type = "pwa-node",
      request = "attach",
      processId = require("dap.utils").pick_process,
      cwd = root,
      sourceMaps = true,
    },
    {
      name = "Launch browser for app URL",
      type = "pwa-chrome",
      request = "launch",
      url = function()
        return coroutine.create(function(co)
          vim.ui.input({ prompt = "App URL: " }, function(value)
            coroutine.resume(co, value and value ~= "" and value or dap.ABORT)
          end)
        end)
      end,
      webRoot = root,
      sourceMaps = true,
    },
  }
  if ft == "javascript" or ft == "typescript" then
    table.insert(dap.configurations[ft], 1, {
      name = "Debug current Node file",
      type = "pwa-node",
      request = "launch",
      program = "${file}",
      cwd = root,
      sourceMaps = true,
      console = "integratedTerminal",
    })
  end
end
-- Override the native provider's cwd with the current buffer's project root.
dap.providers.configs["dap.launch.json"] = function(bufnr)
  local workspace = root(bufnr)
  local path = vim.fs.joinpath(workspace, ".vscode", "launch.json")
  local ok, configs = pcall(require("dap.ext.vscode").getconfigs, path)
  if ok then
    -- Native DAP otherwise expands project variables using Neovim's cwd.
    local name = vim.api.nvim_buf_get_name(bufnr)
    local relative = vim.fs.relpath(workspace, name) or name
    local variables = {
      workspaceFolder = workspace,
      workspaceFolderBasename = vim.fs.basename(workspace),
      relativeFile = relative,
      relativeFileDirname = vim.fs.dirname(relative) or ".",
    }
    local function expand(value)
      if type(value) == "string" then
        return (
          value:gsub("%${([%w]+)}", function(variable)
            return variables[variable] or "${" .. variable .. "}"
          end)
        )
      elseif type(value) == "table" then
        for key, child in pairs(value) do
          value[key] = expand(child)
        end
      end
      return value
    end
    expand(configs)
    return configs
  end
  vim.notify("Invalid launch.json: " .. tostring(configs), vim.log.levels.WARN)
  return {}
end
local map = vim.keymap.set
map("n", "<F5>", dap.continue, { desc = "调试继续" })
map("n", "<F10>", dap.step_over, { desc = "调试单步跳过" })
map("n", "<F11>", dap.step_into, { desc = "调试单步进入" })
map("n", "<F12>", dap.step_out, { desc = "调试单步退出" })
map("n", "<leader>dc", dap.continue, { desc = "启动 / 继续调试" })
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "切换断点" })
map("n", "<leader>dB", function()
  vim.ui.input({ prompt = "Breakpoint condition: " }, function(value)
    if value and value ~= "" then
      dap.set_breakpoint(value)
    end
  end)
end, { desc = "条件断点" })
map("n", "<leader>do", dap.step_over, { desc = "单步跳过" })
map("n", "<leader>di", dap.step_into, { desc = "单步进入" })
map("n", "<leader>dO", dap.step_out, { desc = "单步退出" })
map("n", "<leader>dq", dap.terminate, { desc = "停止调试" })
map("n", "<leader>dr", dap.repl.toggle, { desc = "调试交互窗口" })
map("n", "<leader>du", dapui.toggle, { desc = "调试面板" })
map({ "n", "x" }, "<leader>de", dapui.eval, { desc = "表达式求值" })
