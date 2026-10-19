local M = {}
local switch_context
local pending_selections = 0
local pending_tasks = 0

function M.setup()
  if switch_context then
    return
  end
  local cmake = require("cmake-tools")
  local function explicit_context()
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "cmaketools", event = "DirChanged" })) do
      switch_context = autocmd.callback
      vim.api.nvim_del_autocmd(autocmd.id)
    end
    assert(type(switch_context) == "function", "cmake-tools DirChanged callback is unavailable")
  end
  -- Its configure/build/run callbacks share one mutable config. Ordinary tab
  -- navigation must never replace that config in the middle of an operation.
  explicit_context()
  -- Do not let :CMakeSelectCwd reinstall automatic switching. The disabled
  -- hooks (regenerate, virtual text and scratch) require no re-registration.
  cmake.register_autocmd = function() end

  local backend = require("cmake-tools.overseer")
  local run = backend.run
  backend.run = function(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
    pending_tasks = pending_tasks + 1
    local finished = false
    local function finish(...)
      if finished then
        return
      end
      finished = true
      local result = { pcall(on_exit or function() end, ...) }
      -- Hold context through database copying and chained build/run callbacks.
      pending_tasks = pending_tasks - 1
      if not result[1] then
        error(result[2])
      end
    end
    local previous_task = backend.job
    local result = { pcall(run, cmd, env_script, env, args, cwd, opts, finish, on_output) }
    if not result[1] or backend.job == previous_task or backend.job.status == "PENDING" then
      if not finished then
        finished = true
        pending_tasks = pending_tasks - 1
      end
      if not result[1] then
        error(result[2])
      end
    end
    return unpack(result, 2)
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("user_cmake_context", { clear = true }),
    callback = function()
      if cmake.is_cmake_project() then
        local config = cmake.get_config()
        require("cmake-tools.session").save(config.cwd, config)
      end
    end,
  })

  for _, name in ipairs({
    "select_build_type",
    "select_kit",
    "select_configure_preset",
    "select_build_preset",
    "select_test_preset",
    "select_build_target",
    "select_launch_target",
  }) do
    local select = cmake[name]
    cmake[name] = function(...)
      local ui_select = vim.ui.select
      -- Wrap only UI opened synchronously by this CMake selector. Early returns
      -- without a picker do not acquire a pending-selection lock.
      vim.ui.select = function(items, opts, callback)
        pending_selections = pending_selections + 1
        local called = false
        local shown = {
          pcall(ui_select, items, opts, function(...)
            if called then
              return
            end
            called = true
            local result = { pcall(callback, ...) }
            -- Upstream uses schedule_wrap: release after its selected callback has
            -- either started the next task/selector or finished cancellation.
            vim.schedule(function()
              pending_selections = pending_selections - 1
            end)
            if not result[1] then
              error(result[2])
            end
          end),
        }
        if not shown[1] then
          if not called then
            pending_selections = pending_selections - 1
          end
          error(shown[2])
        end
        return unpack(shown, 2)
      end
      local result = { pcall(select, ...) }
      vim.ui.select = ui_select
      if not result[1] then
        error(result[2])
      end
      return unpack(result, 2)
    end
  end
end

local function normalize(path)
  return vim.fs.normalize(vim.fn.resolve(path))
end

-- A nested src/CMakeLists.txt belongs to the outer source tree in the same repo.
function M.root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name:match("^%w+://") then
    return nil
  end
  local dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  local boundary = vim.fs.root(dir, ".git")
  local root
  while dir do
    if vim.fn.filereadable(vim.fs.joinpath(dir, "CMakeLists.txt")) == 1 then
      root = dir
    end
    if dir == boundary then
      break
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  return root and normalize(root) or nil
end

local function available()
  if not require("config.tools").executable("cmake") then
    vim.notify("未找到 CMake；请先安装 cmake，并确认它在 PATH 中。", vim.log.levels.WARN)
    return false
  end
  return true
end

function M.activate()
  local root = M.root()
  if not root then
    vim.notify(
      "当前文件不属于 CMake 工程；Makefile 工程可按 空格 rr 选择 make 任务。",
      vim.log.levels.WARN
    )
    return false
  end
  if not available() then
    return false
  end
  if pending_selections > 0 then
    vim.notify("请先完成或取消 CMake 选项，再切换工程。", vim.log.levels.WARN)
    return false
  end
  local task = require("cmake-tools.overseer").job
  if pending_tasks > 0 or (task and task:is_running()) then
    vim.notify(
      "CMake 任务正在运行；请先按 空格 cs 停止，再切换工程。",
      vim.log.levels.WARN
    )
    return false
  end
  vim.cmd.tcd(vim.fn.fnameescape(root))
  -- Only explicit entry saves/loads project state, including when the tab was
  -- already at this cwd before another tab selected a different source tree.
  switch_context()
  vim.notify("CMake 工程：" .. root .. "；按 空格 cp 选预设，或 空格 cc 配置。")
  return true
end

function M.ready()
  if not available() then
    return false
  end
  local root = M.root()
  local active = normalize(require("cmake-tools").get_config().cwd)
  if not root or active ~= root then
    vim.notify(
      "请先按 空格 cR 使用当前文件的 CMake 工程，再选择预设或构建。",
      vim.log.levels.WARN
    )
    return false
  end
  return true
end

function M.action(command)
  if M.ready() then
    vim.cmd(command)
    return true
  end
  return false
end

return M
