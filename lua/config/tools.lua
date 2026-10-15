local M = {}
local lldb_path
function M.lldb_dap()
  if lldb_path ~= nil then
    return lldb_path or nil
  end
  lldb_path = M.executable("lldb-dap") or false
  if not lldb_path and vim.uv.os_uname().sysname == "Darwin" and vim.fn.executable("xcrun") == 1 then
    local result = vim.system({ "xcrun", "--find", "lldb-dap" }, { text = true }):wait(2000)
    if result.code == 0 then
      lldb_path = vim.trim(result.stdout)
    end
  end
  return lldb_path or nil
end
function M.mason_path(relative)
  return vim.fs.joinpath(vim.fn.stdpath("data"), "mason", relative)
end
function M.executable(name)
  local managed = M.mason_path("bin/" .. name)
  if vim.fn.executable(managed) == 1 then
    return managed
  end
  local path = vim.fn.exepath(name)
  return path ~= "" and path or nil
end
function M.python(root)
  root = root or require("config.project").root()
  for _, directory in ipairs({ ".venv", "venv" }) do
    local path = vim.fs.joinpath(root, directory, "bin", "python")
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  if vim.env.VIRTUAL_ENV then
    local path = vim.fs.joinpath(vim.env.VIRTUAL_ENV, "bin", "python")
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  return vim.fn.exepath("python3")
end
return M
