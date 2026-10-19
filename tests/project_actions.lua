for name in pairs(vim.lsp._enabled_configs) do
  vim.lsp.enable(name, false)
end
local temp = vim.fn.resolve(vim.fn.tempname())
local function project(name, files, source, filetype)
  local dir = vim.fs.joinpath(temp, name)
  for path, content in pairs(files) do
    local target = vim.fs.joinpath(dir, path)
    vim.fn.mkdir(vim.fs.dirname(target), "p")
    vim.fn.writefile({ content }, target)
  end
  local path = vim.fs.joinpath(dir, source)
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].filetype = filetype
  return dir, buf
end
local ok, err = pcall(function()
  local found, actions = pcall(require, "config.project_actions")
  assert(found, "Project build/run/check controls missing")
  local root, buf = project("mono space", {
    [".git/HEAD"] = "ref: refs/heads/main",
    ["package.json"] = '{"packageManager":"pnpm@10.0.0","scripts":{"build":"wrong root"}}',
    ["pnpm-lock.yaml"] = "lockfileVersion: '9.0'",
    ["packages/web/package.json"] = '{"scripts":{"build":"vite build","dev":"vite","typecheck":"vue-tsc --noEmit"}}',
    ["packages/web/src/App.vue"] = "<template><div/></template>",
  }, "packages/web/src/App.vue", "vue")
  local task = assert(actions.resolve("build", buf))
  assert(task.cwd == root .. "/packages/web", "Frontend task escaped nearest package")
  assert(vim.deep_equal(task.cmd, { "pnpm", "run", "build" }), "Workspace package manager ignored")
  assert(actions.resolve("run", buf).cmd[3] == "dev", "Dev script missing")
  assert(actions.resolve("check", buf).cmd[3] == "typecheck", "Type checking script missing")
  assert(actions.resolve("lint", buf) == nil, "Missing lint script silently invented")
  local dotnet, cs = project("dotnet repo", {
    [".git/HEAD"] = "ref: refs/heads/main",
    ["src/App/App.csproj"] = "<Project/>",
    ["src/App/Program.cs"] = "class Program {}",
  }, "src/App/Program.cs", "cs")
  assert(require("config.project").root(cs) == dotnet .. "/src/App", ".git overrode nearest csproj")
  local run = assert(actions.resolve("run", cs))
  assert(run.cwd == dotnet .. "/src/App" and run.cmd[3] == "--project", "Dotnet run project not explicit")
  local rust, rs = project(
    "rust project",
    { ["Cargo.toml"] = '[package]\nname="sample"\nversion="0.1.0"', ["src/lib.rs"] = "pub fn value() {}" },
    "src/lib.rs",
    "rust"
  )
  local clippy = assert(actions.resolve("lint", rs))
  assert(clippy.cwd == rust and clippy.cmd[2] == "clippy", "Cargo lint action missing")
  assert(not vim.tbl_contains(clippy.cmd, "--all-features"), "Mutually exclusive Cargo features forced")
  local go, gb = project(
    "go project",
    { ["go.mod"] = "module example.test/sample", ["main.go"] = "package main" },
    "main.go",
    "go"
  )
  assert(actions.resolve("lint", gb).cmd[2] == "vet", "Go vet missing")
  assert(actions.resolve("build", gb).cwd == go, "Go task root wrong")
end)
vim.fn.delete(temp, "rf")
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
end
print("Project actions: package manager, package/csproj isolation, Rust and Go controls passed")
vim.cmd("qa!")
