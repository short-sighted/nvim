-- Run with installed plugins and CMake/make: nvim --headless -i NONE '+luafile tests/cpp.lua'
for name in pairs(vim.lsp._enabled_configs) do
  vim.lsp.enable(name, false)
end
local temp = vim.fn.resolve(vim.fn.tempname())
local cpp, cmake = require("config.cpp"), require("cmake-tools")
local original_select = vim.ui.select
local original_notify = vim.notify
local choice
vim.ui.select = function(items, opts, callback)
  for i, item in ipairs(items) do
    local label = opts.format_item and opts.format_item(item) or tostring(item)
    if
      label == choice
      or label:sub(1, #choice + 2) == choice .. " ("
      or (type(item) == "table" and item.short == choice)
    then
      callback(item, i)
      return
    end
  end
  error("Missing selection " .. tostring(choice) .. ": " .. vim.inspect(items))
end
local function write(root, path, lines)
  local target = vim.fs.joinpath(root, path)
  vim.fn.mkdir(vim.fs.dirname(target), "p")
  vim.fn.writefile(lines, target)
end
local function wait_result(start)
  local result
  start(function(value)
    result = value
  end)
  assert(
    vim.wait(30000, function()
      return result ~= nil
    end, 20),
    "CMake action timeout"
  )
  assert(result:is_ok(), vim.inspect(result))
  return result
end
local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end
local original_cwd = vim.fn.getcwd()
local ok, err = pcall(function()
  local const = require("cmake-tools.const")
  assert(not const.cmake_regenerate_on_save and not const.cmake_virtual_text_support)
  assert(const.cmake_compile_commands_options.action == "copy")
  local root = temp .. "/cmake project with spaces"
  write(root, ".git/HEAD", { "ref: refs/heads/main" })
  write(root, "CMakeLists.txt", {
    "cmake_minimum_required(VERSION 3.20)",
    "project(nvim_cpp_fixture LANGUAGES CXX)",
    "add_executable(cpp_fixture src/main.cpp)",
    "add_library(cpp_library STATIC src/library.cpp)",
  })
  write(root, "src/CMakeLists.txt", { "# nested source directory" })
  write(root, "src/main.cpp", {
    "#include <iostream>",
    "int main() {",
    "  int answer = 40;",
    "  answer += 2;",
    '  std::cout << "cpp fixture " << answer << std::endl;',
    "  return answer == 42 ? 0 : 1;",
    "}",
  })
  write(root, "src/library.cpp", { "int library_answer() { return 42; }" })
  write(root, "CMakePresets.json", {
    vim.json.encode({
      version = 3,
      configurePresets = {
        {
          name = "fixture-debug",
          generator = "Unix Makefiles",
          binaryDir = "${sourceDir}/build with spaces",
          cacheVariables = { CMAKE_BUILD_TYPE = "Debug" },
        },
      },
      buildPresets = { { name = "fixture-build", configurePreset = "fixture-debug" } },
    }),
  })
  edit(root .. "/src/main.cpp")
  assert(cpp.root() == root, "Nested CMakeLists selected instead of outer source root")
  assert(vim.fn.getcwd() == original_cwd, "Opening C++ changed cwd")
  local notified
  vim.notify = function(message)
    notified = message
  end
  assert(not cpp.action("CMakeBuild"), "Cross-project build was allowed")
  assert(notified:find("cR", 1, true), "Missing project entry hint")
  vim.notify = original_notify
  assert(cpp.activate())
  assert(vim.fn.getcwd(-1, -1) == original_cwd, "Global cwd changed")
  assert(cmake.get_config().cwd == root and cpp.ready())
  assert(not vim.uv.fs_stat(root .. "/build with spaces"), "Project entry triggered configure")
  choice = "fixture-debug"
  wait_result(cmake.select_configure_preset)
  choice = "fixture-build"
  wait_result(cmake.select_build_preset)
  wait_result(function(done)
    cmake.generate({ bang = false, fargs = {} }, done)
  end)
  local database = root .. "/compile_commands.json"
  assert(vim.uv.fs_lstat(database).type == "file", "Compilation database is missing or symlinked")
  local commands = vim.json.decode(table.concat(vim.fn.readfile(database), "\n"))
  assert(#commands == 2 and commands[1].directory == root .. "/build with spaces")
  local targets = cmake.get_build_targets()
  assert(targets:is_ok(), vim.inspect(targets))
  assert(vim.tbl_contains(targets.data.targets, "cpp_fixture"), "Executable target not discovered")
  assert(vim.tbl_contains(targets.data.targets, "cpp_library"), "Library target not discovered")
  choice = "cpp_fixture"
  wait_result(function(done)
    cmake.select_build_target(false, done)
  end)
  wait_result(function(done)
    cmake.select_launch_target(false, done)
  end)
  wait_result(function(done)
    cmake.build({ fargs = {} }, done)
  end)
  assert(vim.fn.executable(cmake.get_launch_target_path()) == 1, "Selected target not built")
  if vim.env.NVIM_CPP_DAP_TEST == "1" then
    local dap = require("dap")
    edit(root .. "/src/main.cpp")
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    dap.set_breakpoint()
    local stops = 0
    dap.listeners.after.event_stopped.cpp_fixture = function()
      stops = stops + 1
    end
    cmake.debug({ fargs = {} })
    assert(
      vim.wait(30000, function()
        return stops >= 1 and dap.session() and dap.session().current_frame ~= nil
      end, 20),
      "LLDB did not stop at breakpoint"
    )
    assert(dap.session().current_frame.line == 4, "LLDB stopped at wrong source line")
    dap.step_over()
    assert(
      vim.wait(10000, function()
        return stops >= 2
          and dap.session()
          and dap.session().current_frame
          and dap.session().current_frame.line == 5
      end, 20),
      "LLDB did not step to next source line"
    )
    dap.continue()
    assert(
      vim.wait(10000, function()
        return dap.session() == nil
      end, 20),
      "LLDB session did not exit"
    )
    dap.listeners.after.event_stopped.cpp_fixture = nil
    print("C++ LLDB: CMake debug launch, breakpoint line 4, step to line 5 and process exit passed")
  end
  local ran
  cmake.run({ fargs = {} }, function(result)
    ran = result
  end)
  assert(
    vim.wait(30000, function()
      return ran ~= nil
    end, 20),
    "CMake run timeout"
  )
  assert(ran:is_ok(), vim.inspect(ran))
  local other = temp .. "/second project"
  write(other, ".git/HEAD", { "ref: refs/heads/main" })
  write(other, "CMakeLists.txt", { "cmake_minimum_required(VERSION 3.20)", "project(other NONE)" })
  edit(other .. "/CMakeLists.txt")
  vim.notify = function() end
  assert(not cpp.ready(), "Another buffer inherited active project's build settings")
  assert(cpp.activate())
  vim.notify = original_notify
  assert(cmake.get_config().configure_preset == nil, "Configure preset leaked across projects")
  assert(cmake.get_config().build_target == nil, "Build target leaked across projects")
  choice = "Debug"
  wait_result(cmake.select_build_type)
  wait_result(function(done)
    cmake.generate({ bang = false, fargs = {} }, done)
  end)
  assert(cmake.get_build_type() == "Debug", "Non-preset build type selection failed")
  assert(vim.uv.fs_stat(other .. "/out/Debug/CMakeCache.txt"), "Non-preset build directory is wrong")
  wait_result(function(done)
    cmake.build({ target = "all", fargs = {} }, done)
  end)
  edit(root .. "/src/main.cpp")
  assert(cpp.activate())
  assert(cmake.get_config().configure_preset == "fixture-debug", "Project preset not restored")
  assert(cmake.get_config().launch_target == "cpp_fixture", "Project launch target not restored")

  -- Configure/build callbacks must keep A's singleton context after navigation
  -- to a previously activated B tab, including a build -> run continuation.
  local source_tabs = {}
  for _, name in ipairs({ "b", "a" }) do
    local project = temp .. "/async " .. name
    write(project, ".git/HEAD", { "ref: refs/heads/main" })
    write(project, "CMakeLists.txt", {
      "cmake_minimum_required(VERSION 3.20)",
      "project(" .. name .. " LANGUAGES CXX)",
      name == "a" and 'execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1)' or "",
      "add_executable(" .. name .. " main.cpp)",
      name == "a" and 'add_custom_command(TARGET a PRE_LINK COMMAND "${CMAKE_COMMAND}" -E sleep 1)' or "",
    })
    write(project, "main.cpp", {
      "#include <fstream>",
      "int main() { std::ofstream(" .. vim.json.encode(project .. "/ran.marker") .. ') << "ran"; }',
    })
    vim.cmd.tabnew()
    edit(project .. "/main.cpp")
    source_tabs[name] = vim.api.nvim_get_current_tabpage()
    assert(cpp.activate())
    local configured
    cmake.generate({ bang = false, fargs = {} }, function(result)
      configured = result
    end)
    local completion_entry, completion_status
    if name == "a" then
      vim.api.nvim_set_current_tabpage(source_tabs.b)
      assert(cmake.get_config().cwd == project, "Tab navigation replaced in-flight configure context")
      vim.notify = function() end
      assert(not cpp.activate(), "cR switched context during configure")
      vim.notify = original_notify
      require("cmake-tools.overseer").job:subscribe("on_complete", function(task)
        completion_status = task.status
        vim.notify = function() end
        completion_entry = cpp.activate()
        vim.notify = original_notify
      end)
    end
    assert(
      vim.wait(30000, function()
        return configured ~= nil
      end, 20),
      "Slow configure timeout"
    )
    assert(configured:is_ok(), vim.inspect(configured))
    if name == "a" then
      assert(completion_status == "SUCCESS", "Completion guard did not run after task exit")
      assert(completion_entry == false, "cR switched context before queued CMake completion callback")
    end
    assert(
      vim.fn.filereadable(project .. "/compile_commands.json") == 1,
      "Configure copied database to wrong source"
    )
    vim.api.nvim_set_current_tabpage(source_tabs[name])
    choice = name
    wait_result(function(done)
      cmake.select_launch_target(false, done)
    end)
    if name == "b" then
      wait_result(function(done)
        cmake.build({ target = name, fargs = {} }, done)
      end)
    end
  end
  local launched
  cmake.run({ fargs = {} }, function(result)
    launched = result
  end)
  vim.api.nvim_set_current_tabpage(source_tabs.b)
  vim.notify = function() end
  assert(not cpp.action("CMakeRun"), "B action reused A's pending launch")
  assert(not cpp.activate(), "cR switched context during build -> run")
  vim.notify = original_notify
  assert(
    vim.wait(30000, function()
      return launched ~= nil
    end, 20),
    "Slow build -> run timeout"
  )
  assert(launched:is_ok(), vim.inspect(launched))
  assert(vim.fn.filereadable(temp .. "/async a/ran.marker") == 1, "A's selected executable did not run")
  assert(vim.fn.filereadable(temp .. "/async b/ran.marker") == 0, "Tab navigation launched B's executable")
  assert(cpp.activate(), "Finished operation did not permit explicit B entry")

  local selecting, selection_finished
  local auto_select = vim.ui.select
  vim.ui.select = function(_, _, callback)
    selecting = callback
  end
  cmake.select_launch_target(false, function() end)
  vim.ui.select = auto_select
  assert(selecting, "Launch picker was not opened")
  vim.api.nvim_set_current_tabpage(source_tabs.a)
  vim.notify = function() end
  assert(not cpp.activate(), "cR switched context while a CMake picker was pending")
  selecting(nil)
  vim.schedule(function()
    selection_finished = true
  end)
  assert(
    vim.wait(5000, function()
      return selection_finished
    end, 20),
    "Picker cancellation timeout"
  )
  assert(cpp.activate(), "Canceled picker did not release project entry")
  local no_presets
  cmake.select_configure_preset(function(result)
    no_presets = result
  end)
  assert(no_presets and not no_presets:is_ok(), "Expected no-presets early return")
  assert(cpp.activate(), "Selector returning without a picker left a stale project lock")
  vim.notify = original_notify
  print(
    "C++ async isolation: slow configure/database copy, build -> run across tabs, and canceled picker passed"
  )

  local make_root = temp .. "/make project with spaces"
  write(make_root, "Makefile", { ".PHONY: fixture", "fixture:", "\t@echo make-ok > result.txt" })
  local task, failure
  require("overseer").run_task({
    name = "make fixture",
    autostart = false,
    search_params = { dir = make_root },
  }, function(value, message)
    task, failure = value, message
  end)
  assert(
    vim.wait(10000, function()
      return task ~= nil or failure ~= nil
    end, 20),
    "Make target discovery timeout"
  )
  assert(task, failure)
  assert(task.cwd == make_root, "Make provider used wrong project directory")
  assert(task:start(), "Make task did not start")
  assert(
    vim.wait(10000, function()
      return task:is_complete()
    end, 20),
    "Make task timeout"
  )
  assert(task.status == "SUCCESS", "Make task failed: " .. task.status)
  assert(vim.fn.readfile(make_root .. "/result.txt")[1] == "make-ok")
  print(
    "C++: explicit project entry, isolation, preset configure/build/run, targets, compile database copy and Make task passed"
  )
end)
vim.ui.select, vim.notify = original_select, original_notify
vim.cmd.tcd(vim.fn.fnameescape(original_cwd))
vim.fn.delete(temp, "rf")
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
