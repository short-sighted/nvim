-- Actual providers must use the selected project's tasks.json and variables.
local root = vim.fn.tempname()
for _, name in ipairs({ "A", "B" }) do
  vim.fn.mkdir(root .. "/" .. name .. "/.vscode", "p")
  vim.fn.writefile({
    vim.json.encode({
      version = "2.0.0",
      tasks = {
        {
          label = name,
          type = "process",
          command = "/bin/echo",
          args = {
            "${workspaceFolder}",
            "${relativeFile}",
          },
        },
      },
    }),
  }, root .. "/" .. name .. "/.vscode/tasks.json")
  vim.fn.writefile({ "text" }, root .. "/" .. name .. "/file.txt")
end
vim.cmd.cd(root .. "/A")
vim.cmd.edit(root .. "/B/file.txt")
local before = vim.fn.getcwd()
local done, failure = false, nil
require("overseer").run_task(
  { name = "B", autostart = false, search_params = { dir = root .. "/B" } },
  function(task, err)
    local ok, e = pcall(function()
      assert(task, err)
      assert(task.cmd[2] == vim.fn.resolve(root .. "/B"), vim.inspect(task.cmd))
      assert(task.cmd[3] == "file.txt", vim.inspect(task.cmd))
      assert(vim.fn.getcwd() == before, "cwd changed")
    end)
    if not ok then
      failure = e
    end
    done = true
  end
)
assert(
  vim.wait(5000, function()
    return done
  end),
  "task resolution timeout"
)
if failure then
  vim.api.nvim_err_writeln(failure)
  vim.cmd("cquit 1")
end
vim.fn.delete(root, "rf")
print("Cross-project VSCode task selection and variables passed")
vim.cmd("qa!")
