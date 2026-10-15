local M = {}
local prepared = false

-- Upstream's F# stdin protocol splits on spaces, including spaces inside DLL
-- paths. Preserve the upstream runner and cache a quote-aware copy of its script.
function M.setup()
  if prepared then
    return
  end
  local source
  for _, path in ipairs(vim.api.nvim_get_runtime_file("scripts/run_tests.fsx", true)) do
    if path:find("/neotest%-vstest/") then
      source = path
      break
    end
  end
  assert(source, "VSTest runner script missing")
  local text = table.concat(vim.fn.readfile(source), "\n")
  local old = 'args.Split(" ", StringSplitOptions.TrimEntries &&& StringSplitOptions.RemoveEmptyEntries)'
  local replacement = [=[System.Text.RegularExpressions.Regex.Matches(args, """"(?:\\.|[^"\\])*"|\S+""")
        |> Seq.cast<System.Text.RegularExpressions.Match>
        |> Seq.map (fun m -> if m.Value.StartsWith("\"") then JsonConvert.DeserializeObject<string>(m.Value) else m.Value)
        |> Seq.toArray]=]
  local updated, count = text:gsub(vim.pesc(old), function()
    return replacement
  end)
  assert(count == 1, "VSTest protocol changed; compatibility patch needs review")
  local cache = vim.fs.joinpath(vim.fn.stdpath("cache"), "neotest-vstest-compat", vim.fn.sha256(text))
  local target = vim.fs.joinpath(cache, "scripts", "run_tests.fsx")
  if not vim.uv.fs_stat(target) then
    vim.fn.mkdir(vim.fs.dirname(target), "p")
    vim.fn.writefile(vim.split(updated, "\n", { plain = true }), target)
  end
  vim.opt.runtimepath:prepend(cache)
  local cli = require("neotest-vstest.vstest.cli_wrapper")
  cli.create_test_runner = function(project)
    local nio = require("nio")
    nio.scheduler()
    local dotnet = assert(require("config.tools").executable("dotnet"), "请安装 .NET SDK")
    local info = vim
      .system({ dotnet, "--info" }, {
        cwd = project.proj_dir,
        text = true,
        env = { DOTNET_CLI_UI_LANGUAGE = "en" },
      })
      :wait(5000)
    local sdk = info.stdout and info.stdout:match("Base Path:%s*([^\r\n]+)")
    assert(info.code == 0 and sdk, "无法识别当前项目的 .NET SDK")
    local testhost = assert(
      vim.fs.find("vstest.console.dll", {
        path = vim.trim(sdk),
        type = "file",
        upward = false,
      })[1],
      "当前项目 SDK 中没有 vstest.console.dll"
    )
    local process = vim.system({ dotnet, "fsi", target, testhost }, {
      cwd = project.proj_dir,
      detach = false,
      stdin = true,
      stdout = function(err, data)
        local log = require("neotest.logging")
        if data then
          log.trace(data)
        end
        if err then
          log.warn(err)
        end
      end,
    })
    local autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("user-vstest-cleanup", { clear = false }),
      callback = function()
        process:kill(vim.uv.constants.SIGKILL)
      end,
    })
    local runner = {
      execute = function(content)
        process:write(content .. "\n")
      end,
      stop = function()
        process:kill(vim.uv.constants.SIGKILL)
        nio.scheduler()
        vim.api.nvim_del_autocmd(autocmd)
      end,
    }
    local execute = runner.execute
    local tempdir = vim.fs.dirname(vim.fn.tempname())
    local settings = vim.fn.globpath(project.proj_dir, "*.runsettings", false, true)
    runner.execute = function(content)
      content = content:gsub(vim.pesc(project.dll_file), function()
        return vim.json.encode(project.dll_file)
      end)
      for _, path in ipairs(settings) do
        content = content:gsub(vim.pesc(path), function()
          return vim.json.encode(path)
        end)
      end
      content = content:gsub(vim.pesc(tempdir) .. "/[^%s]+", function(path)
        return vim.json.encode(path)
      end)
      execute(content)
    end
    return runner
  end
  -- Upstream's process helper has no cwd support. Scope only .NET project
  -- commands so global.json selects the SDK of the project being tested.
  local lib = require("neotest.lib")
  local run = lib.process.run
  lib.process.run = function(argv, opts)
    local path = argv[3]
    if
      vim.fs.basename(argv[1]) == "dotnet"
      and type(path) == "string"
      and (path:match("%.[cf]sproj$") or path:match("%.slnx?$"))
    then
      local nio = require("nio")
      local future = nio.control.future()
      vim.system(
        argv,
        { cwd = vim.fs.dirname(path), text = true, env = { DOTNET_CLI_UI_LANGUAGE = "en" } },
        future.set
      )
      local result = future.wait()
      nio.scheduler()
      return result.code,
        {
          stdout = opts and opts.stdout and result.stdout or nil,
          stderr = opts and opts.stderr and result.stderr or nil,
        }
    end
    return run(argv, opts)
  end
  prepared = true
end

return M
