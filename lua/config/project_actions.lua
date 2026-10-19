local M = {}
local frontend_types = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  vue = true,
  svelte = true,
  html = true,
  css = true,
  scss = true,
  json = true,
}

function M.resolve(action, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file, ft = vim.api.nvim_buf_get_name(bufnr), vim.bo[bufnr].filetype
  if file == "" or vim.bo[bufnr].buftype ~= "" then
    return nil, "请先打开项目中的源码文件。"
  end
  if frontend_types[ft] then
    local frontend = require("config.frontend")
    local root, package = frontend.package(file)
    if not root then
      return nil, "当前文件没有可用的 package.json。"
    end
    local candidates = {
      build = { "build" },
      run = { "dev", "start" },
      check = { "typecheck", "type-check", "check" },
      lint = { "lint" },
    }
    local script
    for _, name in ipairs(candidates[action] or {}) do
      if type(package.scripts) == "table" and package.scripts[name] then
        script = name
        break
      end
    end
    if not script then
      return nil, "package.json 未定义对应脚本；按 空格 rr 查看项目提供的任务。"
    end
    return { name = "前端: " .. script, cmd = { frontend.package_manager(root), "run", script }, cwd = root }
  end
  local commands
  local root = require("config.project").root(bufnr)
  if ft == "rust" then
    root = vim.fs.root(file, "Cargo.toml")
    commands = {
      build = { "cargo", "build" },
      run = { "cargo", "run" },
      check = { "cargo", "check", "--all-targets" },
      lint = { "cargo", "clippy", "--all-targets" },
    }
  elseif ft == "go" then
    root = vim.fs.root(file, { "go.mod", "go.work" })
    commands = {
      build = { "go", "build", "./..." },
      run = { "go", "run", "." },
      check = { "go", "test", "./..." },
      lint = { "go", "vet", "./..." },
    }
  elseif ft == "cs" then
    root = vim.fs.root(file, function(name)
      return name:match("%.csproj$")
    end)
    if root then
      local projects = vim.fn.globpath(root, "*.csproj", false, true)
      if #projects ~= 1 then
        return nil, "同目录存在多个 .csproj；请按 空格 rr 选择具体项目任务。"
      end
      commands = {
        build = { "dotnet", "build", projects[1] },
        run = { "dotnet", "run", "--project", projects[1] },
        check = { "dotnet", "test", projects[1] },
        lint = { "dotnet", "format", projects[1], "--verify-no-changes" },
      }
    end
  end
  local cmd = commands and commands[action]
  if root and cmd then
    return { name = ft .. ": " .. action, cmd = cmd, cwd = root }
  end
  return nil, "此项目请使用 空格 rr 选择任务；CMake 工程使用 空格 c 系列操作。"
end

function M.run(action)
  local ft = vim.bo.filetype
  if (ft == "c" or ft == "cpp" or ft == "cmake") and require("config.cpp").root() then
    local command = ({ build = "CMakeBuild", run = "CMakeRun", check = "CMakeRunTest" })[action]
    if command then
      require("config.cpp").action(command)
      return
    end
  end
  local definition, err = M.resolve(action)
  if not definition then
    vim.notify(err, vim.log.levels.INFO)
    return
  end
  if not require("config.tools").executable(definition.cmd[1]) then
    vim.notify(
      "未找到工具：" .. definition.cmd[1] .. "；请先安装并检查 PATH。",
      vim.log.levels.WARN
    )
    return
  end
  local task = require("overseer").new_task(definition)
  if not task:start() then
    vim.notify("任务无法启动；按 空格 rl 查看输出。", vim.log.levels.ERROR)
    return
  end
  require("overseer").open({ enter = false, direction = "bottom" })
end

return M
