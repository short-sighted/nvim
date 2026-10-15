local M = {}

function M.run()
  local root = require("config.project").root()
  require("overseer").run_task({ search_params = { dir = root } })
end

function M.restart()
  local overseer = require("overseer")
  local root = vim.fn.resolve(require("config.project").root())
  local tasks = overseer.list_tasks({
    status = { overseer.STATUS.SUCCESS, overseer.STATUS.FAILURE, overseer.STATUS.CANCELED },
    sort = require("overseer.task_list").sort_finished_recently,
  })
  for _, task in ipairs(tasks) do
    if task.cwd and vim.fn.resolve(task.cwd) == root then
      overseer.run_action(task, "restart")
      return
    end
  end
  vim.notify("当前项目没有可重跑的任务；按 空格 rr 选择任务。", vim.log.levels.INFO)
end

local function run_debug_task(name, config, cwd, callback)
  local overseer = require("overseer")
  overseer.run_task({
    name = name ~= "${defaultBuildTask}" and name or nil,
    tags = name == "${defaultBuildTask}" and { overseer.TAG.BUILD } or nil,
    autostart = false,
    search_params = { dir = cwd },
    params = { [require("overseer.vscode").LAUNCH_CONFIG_KEY] = config },
  }, function(task, err)
    if not task then
      vim.notify("无法找到调试任务 " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
      callback(false)
      return
    end
    local done = false
    local function finish(success)
      if done then
        return
      end
      done = true
      if not success then
        vim.notify(
          "调试任务失败：" .. name .. "；按 空格 rl 查看输出。",
          vim.log.levels.ERROR
        )
      end
      callback(success)
    end
    task:subscribe("on_complete", function(_, status)
      finish(status == overseer.STATUS.SUCCESS)
      return false
    end)
    task:subscribe("on_result", function()
      finish(task.status ~= overseer.STATUS.FAILURE)
      return false
    end)
    if not task:start() then
      vim.notify(
        "无法启动调试任务：" .. name .. "；请检查命令和工具是否安装。",
        vim.log.levels.ERROR
      )
      finish(false)
    end
  end)
end

function M.before_debug(config)
  local dap = require("dap")
  dap.listeners.after.event_terminated.user_tasks = nil
  if not config.preLaunchTask and not config.postDebugTask then
    return config
  end
  local root = require("config.project").root()
  local cwd = type(config.cwd) == "string" and not config.cwd:find("%${") and config.cwd or root
  dap.listeners.after.event_terminated.user_tasks = config.postDebugTask
      and function()
        run_debug_task(config.postDebugTask, config, cwd, function() end)
      end
    or nil
  if config.preLaunchTask then
    local co = coroutine.running()
    run_debug_task(config.preLaunchTask, config, cwd, function(success)
      vim.schedule(function()
        local ok, err = coroutine.resume(co, success)
        if not ok then
          vim.notify(tostring(err), vim.log.levels.ERROR)
        end
      end)
    end)
    if not coroutine.yield() then
      config._task_abort = dap.ABORT
    end
  end
  return config
end

return M
