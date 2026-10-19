-- Run: nvim --headless -i NONE '+luafile tests/frontend.lua'
for name in pairs(vim.lsp._enabled_configs) do
  vim.lsp.enable(name, false)
end
local temp = vim.fn.resolve(vim.fn.tempname())
local function fixture(name, files)
  local root = vim.fs.joinpath(temp, name)
  for path, content in pairs(files) do
    local target = vim.fs.joinpath(root, path)
    vim.fn.mkdir(vim.fs.dirname(target), "p")
    vim.fn.writefile({ content }, target)
  end
  return root
end
local function detected(path)
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  local root
  vim.lsp.config.tailwindcss.root_dir(buf, function(dir)
    root = dir
  end)
  return root
end
local ok, err = pcall(function()
  assert(
    vim.lsp.config.vtsls.capabilities.workspace.fileOperations.didRename,
    "File browser rename hooks were not advertised to TypeScript"
  )
  local plain =
    fixture("plain git", { [".git/HEAD"] = "ref: refs/heads/main", ["src/main.js"] = "const n = 1;" })
  assert(detected(plain .. "/src/main.js") == nil, "Plain Git project activated Tailwind")
  local postcss = fixture("postcss", {
    ["package.json"] = '{"devDependencies":{"postcss":"*"}}',
    ["postcss.config.js"] = "export default {};",
    ["main.js"] = "const n = 1;",
  })
  assert(detected(postcss .. "/main.js") == nil, "Generic PostCSS activated Tailwind")
  local v3 =
    fixture("v3", { ["tailwind.config.ts"] = "export default {};", ["src/main.js"] = "const n = 1;" })
  assert(detected(v3 .. "/src/main.js") == v3, "Tailwind v3 config not detected")
  local v4 = fixture("v4", {
    ["package.json"] = '{"devDependencies":{"tailwindcss":"^4"}}',
    ["src/app.css"] = '@import "tailwindcss";',
    ["src/main.js"] = "const n = 1;",
  })
  assert(detected(v4 .. "/src/main.js") == v4, "Config-free Tailwind v4 project not detected")
  local mentioned = fixture("description only", {
    ["package.json"] = '{"description":"no tailwindcss here","scripts":{"note":"echo tailwindcss"}}',
    ["main.js"] = "const n = 1;",
  })
  assert(detected(mentioned .. "/main.js") == nil, "Text mentioning Tailwind counted as dependency")
  local mono = fixture("monorepo", {
    ["package.json"] = '{"devDependencies":{"tailwindcss":"^4"},"workspaces":["packages/*"]}',
    ["packages/plain/package.json"] = '{"name":"plain"}',
    ["packages/plain/main.js"] = "const n = 1;",
    ["packages/styled/package.json"] = '{"dependencies":{"tailwindcss":"^4"}}',
    ["packages/styled/main.js"] = "const n = 1;",
  })
  assert(
    detected(mono .. "/packages/plain/main.js") == nil,
    "Monorepo Tailwind dependency leaked into plain package"
  )
  assert(
    detected(mono .. "/packages/styled/main.js") == mono .. "/packages/styled",
    "Styled package root wrong"
  )
  local function tsroot(path)
    local result
    local buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)
    vim.lsp.config.vtsls.root_dir(buf, function(dir)
      result = dir
    end)
    return result
  end
  assert(tsroot(postcss .. "/main.js") == postcss, "JS project root fell back to Neovim cwd")
  local standalone = fixture("standalone", { ["script.js"] = "const n = 1;" })
  assert(tsroot(standalone .. "/script.js") == standalone, "Standalone JS root is wrong")
  local deno = fixture("deno", { ["deno.json"] = "{}", ["script.js"] = "const n = 1;" })
  assert(tsroot(deno .. "/script.js") == nil, "vtsls claimed a Deno project")
end)
vim.fn.delete(temp, "rf")
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
end
print("Frontend: Tailwind v3/v4 activation and plain/PostCSS/monorepo exclusions passed")
vim.cmd("qa!")
