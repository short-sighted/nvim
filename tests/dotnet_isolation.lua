local original_system = vim.system
local original_find = vim.fs.find
local cli = require("neotest-vstest.vstest.cli_wrapper")
local utils = require("neotest-vstest.dotnet_utils")
utils.build_path = function()
  return true
end
utils.get_solution_info = function()
  return { projects = {} }
end
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/B", "p")
vim.fn.writefile({ "<Project/>" }, root .. "/B/B.csproj")
vim.fn.writefile({ "class B {}" }, root .. "/B/B.cs")
vim.g.roslyn_nvim_selected_solution = root .. "/A/A.sln"
local done, failure = false, nil
require("nio").run(function()
  local ok, err = pcall(function()
    local adapter
    for _, a in ipairs(require("config.test_adapters").get()) do
      if a.name == "neotest-vstest" then
        adapter = a
      end
    end
    assert(
      adapter.root(root .. "/B/B.cs") == vim.fn.resolve(root .. "/B"),
      "Stale Roslyn solution escaped project"
    )
  end)
  if not ok then
    failure = err
  end
  done = true
end)
assert(vim.wait(5000, function()
  return done
end))
if failure then
  vim.api.nvim_err_writeln(failure)
  vim.cmd("cquit 1")
end
vim.fn.delete(root, "rf")
-- Probe runner creation with two distinct SDK selections; no processes spawned.
local calls = {}
vim.system = function(argv, opts)
  if argv[2] == "--info" then
    return {
      wait = function()
        return { code = 0, stdout = "Base Path: " .. opts.cwd .. "/sdk/" }
      end,
    }
  end
  calls[#calls + 1] = { argv = argv, opts = opts }
  return { pid = 123, write = function() end, kill = function() end }
end
vim.fs.find = function(name, opts)
  if name == "vstest.console.dll" then
    return { opts.path .. "vstest.console.dll" }
  end
  return original_find(name, opts)
end
vim.g.neotest_vstest = { sdk_path = "/wrong/shared/sdk" }
done = false
require("nio").run(function()
  local ok, err = pcall(function()
    for _, name in ipairs({ "A", "B" }) do
      local dir = "/fixture/" .. name
      local runner = cli.create_test_runner({ proj_dir = dir, dll_file = dir .. "/tests.dll" })
      local call = calls[#calls]
      assert(call.argv[4] == dir .. "/sdk/vstest.console.dll", "SDK leaked: " .. vim.inspect(call))
      assert(call.opts.cwd == dir, "Runner cwd escaped project")
      runner.stop()
    end
  end)
  if not ok then
    failure = err
  end
  done = true
end)
assert(vim.wait(5000, function()
  return done
end))
vim.system = original_system
vim.fs.find = original_find
if failure then
  vim.api.nvim_err_writeln(failure)
  vim.cmd("cquit 1")
end
print("Roslyn root and per-project SDK/runner cwd isolation passed")
vim.cmd("qa!")
