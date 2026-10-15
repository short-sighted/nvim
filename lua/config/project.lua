local M = {}
function M.root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == "" or name:match("^%w+://") then
    return vim.uv.cwd()
  end
  return vim.fs.root(name, {
    {
      ".git",
      "Cargo.toml",
      "go.work",
      "go.mod",
      "pyproject.toml",
      "package.json",
      "CMakeLists.txt",
      "compile_commands.json",
      "global.json",
    },
    function(filename)
      local ext = vim.fs.ext(filename)
      return ext == "sln" or ext == "slnx" or ext == "csproj"
    end,
  }) or vim.uv.cwd()
end
return M
