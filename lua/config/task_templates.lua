local M = {}

function M.definitions(dir)
  local templates = {}
  local function add(name, command, params)
    templates[#templates + 1] = {
      name = name,
      params = params,
      tags = name:find("构建") and { "build" } or nil,
      builder = function(values)
        return { name = name, cmd = type(command) == "function" and command(values) or command, cwd = dir }
      end,
    }
  end
  local frontend = require("config.frontend")
  local package_root, package = frontend.package(vim.fs.joinpath(dir, "package.json"))
  if package_root == dir and type(package.scripts) == "table" then
    local manager = frontend.package_manager(dir)
    for script in pairs(package.scripts) do
      add(manager .. " run " .. script, { manager, "run", script })
    end
  end
  if vim.uv.fs_stat(vim.fs.joinpath(dir, "go.mod")) or vim.uv.fs_stat(vim.fs.joinpath(dir, "go.work")) then
    add("Go: 构建项目", { "go", "build", "./..." })
    add("Go: 运行项目", { "go", "run", "." })
    add("Go: 测试项目", { "go", "test", "./..." })
  end
  local projects = vim.fn.globpath(dir, "*.csproj", false, true)
  vim.list_extend(projects, vim.fn.globpath(dir, "*.sln", false, true))
  vim.list_extend(projects, vim.fn.globpath(dir, "*.slnx", false, true))
  for _, project in ipairs(projects) do
    local name = vim.fs.basename(project)
    add(".NET: 构建 " .. name, { "dotnet", "build", project })
    add(".NET: 测试 " .. name, { "dotnet", "test", project })
    if project:match("%.csproj$") then
      add(".NET: 运行 " .. name, { "dotnet", "run", "--project", project })
    end
  end
  if vim.uv.fs_stat(vim.fs.joinpath(dir, "CMakeLists.txt")) then
    local params = { build_dir = { type = "string", default = "build", desc = "CMake 构建目录" } }
    add("CMake: 配置 Debug", function(p)
      return {
        "cmake",
        "-S",
        dir,
        "-B",
        p.build_dir,
        "-DCMAKE_BUILD_TYPE=Debug",
        "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
      }
    end, params)
    add("CMake: 构建项目", function(p)
      return { "cmake", "--build", p.build_dir }
    end, params)
    add("CMake: 测试项目", function(p)
      return { "ctest", "--test-dir", p.build_dir, "--output-on-failure" }
    end, params)
  end
  return templates
end

function M.register()
  require("overseer").register_template({
    name = "user-project-tasks",
    generator = function(opts)
      return M.definitions(opts.dir)
    end,
  })
end

return M
