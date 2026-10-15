-- Run: nvim --headless -i NONE '+luafile tests/daily.lua'
local cases = {
  {
    name = "Treesitter",
    run = function()
      for name in pairs(vim.lsp._enabled_configs) do
        vim.lsp.enable(name, false)
      end
      vim.cmd.enew()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "int main() {", "  return 0;", "}" })
      vim.bo.filetype = "cpp"
      assert(
        vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()],
        "C++ treesitter highlighting missing"
      )
      assert(vim.wo.foldmethod == "expr", "Structure folds missing")
      local cpp = vim.api.nvim_get_current_buf()
      vim.wo.foldlevel = 0
      vim.cmd.enew()
      vim.bo.filetype = "text"
      assert(vim.wo.foldmethod == "manual", "Tree-sitter fold settings leaked to plain text")
      vim.api.nvim_set_current_buf(cpp)
      assert(vim.wo.foldlevel == 0, "Returning to a buffer reset closed folds")
      vim.cmd.enew()
      vim.bo.filetype = "text"
      assert(
        not vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()],
        "Unknown parser must preserve plain text editing"
      )
      print("Treesitter highlighting, structure folds and fallback passed")
    end,
  },
  {
    name = "Diagnostics",
    run = function()
      for name in pairs(vim.lsp._enabled_configs) do
        vim.lsp.enable(name, false)
      end
      assert(vim.fn.exists(":Trouble") == 2, "Trouble entry missing")
      local temp = vim.fn.tempname()
      local bufs = {}
      for i = 1, 2 do
        local dir = temp .. "/project " .. i
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ "{}" }, dir .. "/package.json")
        vim.fn.writefile({ "sample" }, dir .. "/test.txt")
        bufs[i] = vim.fn.bufadd(dir .. "/test.txt")
        vim.fn.bufload(bufs[i])
      end
      local ns = vim.api.nvim_create_namespace("daily-diagnostics-test")
      for i, b in ipairs(bufs) do
        vim.diagnostic.set(
          ns,
          b,
          { { lnum = 0, col = 0, message = "project " .. i, severity = vim.diagnostic.severity.ERROR } }
        )
      end
      vim.api.nvim_set_current_buf(bufs[1])
      vim.fn.maparg("<leader>xx", "n", false, true).callback()
      local trouble = require("trouble")
      assert(
        vim.wait(2000, function()
          return #trouble.get_items("project_diagnostics") == 1
        end),
        "Project filter failed"
      )
      assert(trouble.get_items("project_diagnostics")[1].buf == bufs[1], "Other project diagnostic leaked")
      trouble.close("project_diagnostics")
      vim.api.nvim_set_current_buf(bufs[2])
      vim.fn.maparg("<leader>xb", "n", false, true).callback()
      assert(
        vim.wait(2000, function()
          return #trouble.get_items("buffer_diagnostics") == 1
        end),
        "Buffer diagnostics failed"
      )
      assert(trouble.get_items("buffer_diagnostics")[1].buf == bufs[2], "Wrong buffer diagnostic")
      trouble.close("buffer_diagnostics")
      vim.diagnostic.reset(ns)
      vim.fn.delete(temp, "rf")
      print("Trouble project isolation, buffer filter and close passed")
    end,
  },
  {
    name = "Tasks",
    run = function()
      for name in pairs(vim.lsp._enabled_configs) do
        vim.lsp.enable(name, false)
      end
      assert(vim.fn.exists(":OverseerRun") == 2, "Task runner missing")
      local root = vim.fn.tempname() .. "/project with spaces"
      vim.fn.mkdir(root, "p")
      vim.fn.writefile({ "module example.test/daily", "go 1.23" }, root .. "/go.mod")
      local before = vim.uv.cwd()
      local defs = require("config.task_templates").definitions(root)
      assert(#defs >= 2, "Go project task templates missing")
      local definition = defs[1].builder({})
      assert(definition.cwd == root and type(definition.cmd) == "table", "Task argv/cwd wrong")
      local overseer = require("overseer")
      for _, exit in ipairs({ 0, 1, "missing" }) do
        local name = "fixture " .. exit
        overseer.register_template({
          name = name,
          builder = function()
            return {
              cmd = exit == "missing" and { "/missing/daily-tool" }
                or { "/bin/sh", "-c", 'printf "task output\\n"; exit ' .. exit },
              cwd = root,
            }
          end,
        })
      end
      for _, exit in ipairs({ 0, 1, "missing" }) do
        local name = "fixture " .. exit
        local co = coroutine.create(function()
          local c = require("config.tasks").before_debug({
            name = "fixture",
            type = "unused",
            request = "launch",
            preLaunchTask = name,
            cwd = root,
          })
          if exit == 0 then
            assert(c._task_abort == nil, "Successful build aborted")
          else
            assert(c._task_abort == require("dap").ABORT, "Failed build did not block debug")
          end
        end)
        local good, res = coroutine.resume(co)
        assert(good, res)
        assert(
          vim.wait(5000, function()
            return coroutine.status(co) == "dead"
          end),
          "Task callback did not finish"
        )
      end
      assert(vim.uv.cwd() == before, "Task changed global cwd")
      assert(
        #overseer.list_tasks({ status = { overseer.STATUS.FAILURE } }) == 1,
        "Failure case must run an actual failed task"
      )
      vim.fn.delete(root, "rf")
      print("Task templates, argv/cwd, successful/failed preLaunchTask and cwd preservation passed")
    end,
  },
  {
    name = "Test adapters",
    run = function()
      assert(vim.fn.exists(":Neotest") == 2, "Neotest UI missing")
      local cfg = require("config.test_adapters")
      assert(not cfg.filter_dir("node_modules"), "Dependency discovery not excluded")
      assert(cfg.filter_dir("tests"), "Test directory excluded")
      local root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/src", "p")
      vim.fn.writefile({ '{"devDependencies":{"vitest":"*"}}' }, root .. "/package.json")
      local adapters = cfg.get()
      local jest, vitest
      for _, a in ipairs(adapters) do
        if a.name == "neotest-jest" then
          jest = a
        elseif a.name == "neotest-vitest" then
          vitest = a
        end
      end
      local path = root .. "/src/example.test.js"
      vim.fn.writefile({ 'test("example",()=>{});' }, path)
      assert(jest and vitest and #adapters == 7, "Missing language adapters")
      -- Framework guards must decide from the test file, not Neovim cwd.
      local nio = require("nio")
      local done = false
      nio.run(function()
        assert(not jest.is_test_file(path), "Jest claimed Vitest file")
        assert(vitest.is_test_file(path), "Vitest missed project file")
        done = true
      end)
      assert(
        vim.wait(5000, function()
          return done
        end),
        "Framework detection timed out"
      )
      vim.fn.delete(root, "rf")
      print("Test adapters, directory exclusions and framework isolation passed")
    end,
  },
}
for _, case in ipairs(cases) do
  local ok, err = pcall(case.run)
  if not ok then
    vim.api.nvim_err_writeln(case.name .. ": " .. tostring(err))
    vim.cmd("cquit 1")
  end
end
print("Daily editor integration: 4 groups passed")
vim.cmd("qa!")
