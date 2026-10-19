local M = {}
function M.root(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or name:match("^%w+://") then
    return vim.uv.cwd()
  end
  local ft = vim.bo[bufnr].filetype
  if ft == "c" or ft == "cpp" or ft == "cmake" then
    local source = require("config.cpp").root(bufnr)
    if source then
      return source
    end
  end
  local markers = {
    ".git",
    "Cargo.toml",
    "go.work",
    "go.mod",
    "pyproject.toml",
    "package.json",
    "CMakeLists.txt",
    "CMakePresets.json",
    "Makefile",
    "makefile",
    "GNUmakefile",
    "compile_commands.json",
    "global.json",
  }
  -- One predicate gives project files equal priority at each directory level.
  -- Separate marker groups let an ancestor .git override a nearer .csproj.
  return vim.fs.root(name, function(filename)
    local ext = vim.fs.ext(filename)
    return vim.tbl_contains(markers, filename) or ext == "sln" or ext == "slnx" or ext == "csproj"
  end) or vim.uv.cwd()
end
return M
