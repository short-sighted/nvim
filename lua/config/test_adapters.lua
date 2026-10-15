local M = {}
local adapters
local ignored = {
  ".git",
  "node_modules",
  ".venv",
  "venv",
  "target",
  "bin",
  "obj",
  "build",
  "out",
  "_deps",
  "vendor",
  "__pycache__",
  ".pytest_cache",
}

function M.filter_dir(name)
  return not vim.tbl_contains(ignored, name) and not name:match("^cmake%-build")
end

local function package_root(path)
  return vim.fs.root(path, { "package.json" })
end

function M.framework(path)
  local root = package_root(path)
  if not root then
    return nil
  end
  local configured = (vim.g.neotest_frameworks or {})[root]
  if configured == "jest" or configured == "vitest" then
    return configured
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(root, "package.json")), "\n"))
  end)
  if not ok then
    return nil
  end
  for _, kind in ipairs({ "devDependencies", "dependencies" }) do
    if data[kind] and (data[kind].vitest or data[kind]["@vitest/ui"]) then
      return "vitest"
    end
  end
  for _, kind in ipairs({ "devDependencies", "dependencies" }) do
    if data[kind] and data[kind].jest then
      return "jest"
    end
  end
end

-- VSTest caches a selected solution in each instance. Keep instances per project
-- so opening another solution does not reuse the first solution's discovery.
local function dotnet_adapter()
  local instances = {}
  local function instance(path)
    local root = vim.fs.root(path, {
      function(name)
        return name:match("%.slnx?$") or name:match("%.[cf]sproj$")
      end,
    })
    if not root then
      return nil
    end
    if not instances[root] then
      local dotnet = require("config.tools").executable("dotnet")
      if not dotnet then
        return nil
      end
      require("config.vstest_compat").setup()
      instances[root] = require("neotest-vstest")({
        solution_selector = function(solutions)
          local valid = vim.tbl_filter(function(solution)
            return vim.fs.relpath(vim.fn.resolve(root), vim.fn.resolve(solution)) ~= nil
          end, solutions)
          local selected = vim.g.roslyn_nvim_selected_solution
          if selected and vim.tbl_contains(valid, selected) then
            return selected
          end
          if #valid == 1 then
            return valid[1]
          end
          if #valid > 1 then
            return assert(
              require("nio").ui.select(valid, { prompt = "选择当前项目的解决方案" }),
              "已取消测试发现"
            )
          end
          error("当前项目没有可用解决方案")
        end,
        broad_recursive_discovery = false,
        dap_settings = { type = "coreclr" },
        discovery_directory_filter = function(pathname)
          return not M.filter_dir(vim.fs.basename(pathname))
        end,
      })
    end
    return instances[root], root
  end
  local adapter = { name = "neotest-vstest", filter_dir = M.filter_dir }
  adapter.root = function(path)
    local owner, root = instance(path)
    if not owner then
      return nil
    end
    -- Standalone projects must never enter upstream's global Roslyn fallback.
    local solution_dir = vim.fs.root(path, function(name)
      return name:match("%.slnx?$")
    end)
    if solution_dir == root then
      return owner.root(path) or root
    end
    return root
  end
  adapter.is_test_file = function(path)
    if not path:match("%.[cf]s$") and not path:match("%.[cf]sproj$") then
      return false
    end
    local owner = instance(path)
    return owner and owner.is_test_file(path) or false
  end
  adapter.discover_positions = function(path)
    local owner = instance(path)
    return owner and owner.discover_positions(path)
  end
  adapter.build_spec = function(args)
    local owner, root = instance(args.tree:data().path)
    local spec = owner and owner.build_spec(args)
    if spec then
      spec.context = spec.context or {}
      spec.context.user_project = root
    end
    return spec
  end
  adapter.results = function(spec, result, tree)
    return instances[spec.context.user_project].results(spec, result, tree)
  end
  return adapter
end

local function frontend_adapter(adapter, runner)
  local build = adapter.build_spec
  adapter.build_spec = function(args)
    local spec = build(args)
    if not spec then
      return
    end
    local root = package_root(args.tree:data().path)
    local binary
    local dir = root
    while dir do
      local candidate = vim.fs.joinpath(dir, "node_modules", ".bin", runner)
      if vim.uv.fs_stat(candidate) then
        binary = candidate
        break
      end
      local parent = vim.fs.dirname(dir)
      dir = parent ~= dir and parent or nil
    end
    if not binary then
      error("项目没有安装 " .. runner .. "；请先安装项目测试依赖。")
    end
    -- Upstream splits the runner string on spaces. Use a single argv entry.
    spec.command[1] = binary
    spec.cwd = root
    if args.strategy == "dap" then
      spec.strategy.runtimeExecutable = require("config.tools").executable("node")
      spec.strategy.program = binary
      spec.strategy.cwd = root
    end
    return spec
  end
  return adapter
end

function M.get()
  if adapters then
    return adapters
  end
  local tools = require("config.tools")
  local native = tools.lldb_dap() and "lldb" or "codelldb"
  require("neotest-rust.dap").get_test_binary = require("config.rust_tests").binary
  local go = require("neotest-golang")({
    go_test_args = { "-v", "-count=1" },
    dap_mode = "manual",
    dap_manual_config = function()
      return { name = "调试 Go 测试", type = "go", request = "launch", mode = "test", args = {} }
    end,
  })
  local build_go = go.build_spec
  go.build_spec = function(args)
    local spec = build_go(args)
    if spec and args.strategy == "dap" and spec.strategy then
      spec.strategy.cwd = vim.fs.root(args.tree:data().path, { "go.mod" }) or require("config.project").root()
    end
    return spec
  end
  local jest = frontend_adapter(require("neotest-jest")({ jestCommand = "jest" }), "jest")
  local jest_file = jest.is_test_file
  jest.is_test_file = function(path)
    return M.framework(path) == "jest" and jest_file(path)
  end
  local vitest = frontend_adapter(
    require("neotest-vitest")({ vitestCommand = "vitest", filter_dir = M.filter_dir }),
    "vitest"
  )
  local vitest_file = vitest.is_test_file
  vitest.is_test_file = function(path)
    return M.framework(path) == "vitest" and vitest_file(path)
  end
  local cpp = require("neotest-ctest").setup({ dap_adapter = native })
  local build_cpp = cpp.build_spec
  cpp.build_spec = function(args)
    local spec = build_cpp(args)
    if spec and args.strategy ~= "dap" then
      local ctest = spec.context.ctest
      local selection = assert(spec.command:match("%-I%s+([%d,]+)"), "CTest selection missing")
      local config = require("neotest-ctest.config")
      spec.command = vim.list_extend(vim.deepcopy(config.cmd), {
        "--test-dir",
        ctest._test_dir,
        "--quiet",
        "--output-on-failure",
        "--output-junit",
        ctest._output_junit_path,
        "--output-log",
        ctest._output_log_path,
        "-I",
        selection,
      })
      vim.list_extend(spec.command, config.extra_args or {})
    end
    return spec
  end
  adapters = {
    require("neotest-python")({
      python = tools.python,
      dap = { justMyCode = false },
    }),
    go,
    require("neotest-rust")({ dap_adapter = native }),
    vitest,
    jest,
    dotnet_adapter(),
    cpp,
  }
  for _, adapter in ipairs(adapters) do
    for _, method in ipairs({
      "root",
      "is_test_file",
      "filter_dir",
      "discover_positions",
      "build_spec",
      "results",
    }) do
      local original = adapter[method]
      if original then
        adapter[method] = function(...)
          -- nio may resume a discovery coroutine inside a libuv callback.
          if vim.in_fast_event() then
            require("nio").scheduler()
          end
          local result = original(...)
          if method == "root" and result then
            if vim.in_fast_event() then
              require("nio").scheduler()
            end
            return vim.fn.resolve(result)
          end
          return result
        end
      end
    end
  end
  return adapters
end

return M
