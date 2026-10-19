local M = {}

local tailwind_configs = {
  "tailwind.config.js",
  "tailwind.config.cjs",
  "tailwind.config.mjs",
  "tailwind.config.ts",
  "tailwind.config.cts",
  "tailwind.config.mts",
}

function M.package(path)
  local root = vim.fs.root(path, "package.json")
  if not root then
    return
  end
  local ok, package = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(root, "package.json")), "\n"))
  end)
  if ok and type(package) == "table" then
    return root, package
  end
end

function M.package_manager(root)
  local managers = { pnpm = true, yarn = true, npm = true, bun = true }
  local dir = root
  while dir do
    local package_root, package = M.package(vim.fs.joinpath(dir, "package.json"))
    if package_root == dir then
      local manager = type(package.packageManager) == "string" and package.packageManager:match("^([%w]+)@")
      if managers[manager] then
        return manager
      end
    end
    for _, pair in ipairs({
      { "pnpm-lock.yaml", "pnpm" },
      { "yarn.lock", "yarn" },
      { "bun.lock", "bun" },
      { "bun.lockb", "bun" },
      { "package-lock.json", "npm" },
    }) do
      if vim.uv.fs_stat(vim.fs.joinpath(dir, pair[1])) then
        return pair[2]
      end
    end
    if vim.uv.fs_stat(vim.fs.joinpath(dir, ".git")) then
      break
    end
    local parent = vim.fs.dirname(dir)
    dir = parent ~= dir and parent or nil
  end
  return "npm"
end

function M.typescript_root(bufnr, on_dir)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" or file:match("^%w+://") then
    return
  end
  local root = vim.fs.root(bufnr, {
    { "pnpm-workspace.yaml", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock", "bun.lockb" },
    { "package.json", "tsconfig.json", "jsconfig.json" },
    ".git",
  }) or vim.fs.dirname(file)
  local deno = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })
  if deno and #deno >= #root then
    return
  end
  on_dir(root)
end

-- Stop at the nearest package so a workspace dependency cannot activate
-- Tailwind in an unrelated package. v4 needs no tailwind.config file.
function M.tailwind_root(bufnr, on_dir)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" or file:match("^%w+://") then
    return
  end
  for dir in vim.fs.parents(file) do
    for _, name in ipairs(tailwind_configs) do
      if vim.uv.fs_stat(vim.fs.joinpath(dir, name)) then
        on_dir(dir)
        return
      end
    end
    local manifest = vim.fs.joinpath(dir, "package.json")
    if vim.uv.fs_stat(manifest) then
      local ok, package = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(manifest), "\n"))
      end)
      if ok and type(package) == "table" then
        for _, field in ipairs({
          "dependencies",
          "devDependencies",
          "optionalDependencies",
          "peerDependencies",
        }) do
          local dependencies = package[field]
          if type(dependencies) == "table" and dependencies.tailwindcss then
            on_dir(dir)
            return
          end
        end
      end
      return
    end
    if vim.uv.fs_stat(vim.fs.joinpath(dir, ".git")) then
      return
    end
  end
end

return M
