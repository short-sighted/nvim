-- Run from the config directory: nvim --headless -i NONE '+luafile tests/runtime.lua'
local ok, err = pcall(function()
  for name in pairs(vim.lsp._enabled_configs) do
    vim.lsp.enable(name, false)
  end
  for _, command in ipairs({ "Mason", "Git", "DiffviewOpen", "Telescope", "ConformInfo", "WhichKey" }) do
    assert(vim.fn.exists(":" .. command) == 2, "Missing runtime command: " .. command)
  end
  local baseline = { vim.bo.tabstop, vim.bo.shiftwidth, vim.bo.expandtab }
  for _, ft in ipairs({ "go", "python", "rust", "cpp", "cs", "javascript", "typescriptreact", "lua" }) do
    vim.bo.filetype = ft
    local width = ({ go = 4, python = 4, rust = 4, cpp = 4, cs = 4 })[ft] or 2
    assert(vim.fn.shiftwidth() == width, "Wrong indentation for " .. ft)
    assert(vim.bo.expandtab == (ft ~= "go"), "Wrong tabs/spaces for " .. ft)
    vim.bo.filetype = "text"
    assert(vim.bo.tabstop == baseline[1], "tabstop leaked from " .. ft)
    assert(vim.bo.shiftwidth == baseline[2], "shiftwidth leaked from " .. ft)
    assert(vim.bo.expandtab == baseline[3], "expandtab leaked from " .. ft)
  end
  local temp = vim.fn.tempname()
  vim.fn.mkdir(temp .. "/project with spaces/src", "p")
  vim.fn.writefile({ "{}" }, temp .. "/project with spaces/package.json")
  vim.fn.writefile({ "const answer = 42;" }, temp .. "/project with spaces/src/test.js")
  vim.cmd.edit(vim.fn.fnameescape(temp .. "/project with spaces/src/test.js"))
  assert(
    require("config.project").root() == vim.fn.resolve(temp .. "/project with spaces"),
    "Wrong project root"
  )
  vim.fn.mkdir(temp .. "/project with spaces/.vscode", "p")
  vim.fn.writefile({
    "{ // JSONC is accepted by the native DAP provider",
    '"configurations": [{"type":"pwa-node","request":"launch","name":"fixture", "program":"${workspaceFolder}/${relativeFile}", "args":["${relativeFileDirname}"], "env":{"PROJECT":"${workspaceFolderBasename}"}}], "inputs":[{"id":"fixture","type":"promptString","description":"fixture"}]}',
  }, temp .. "/project with spaces/.vscode/launch.json")
  local configs = require("dap").providers.configs["dap.launch.json"](0)
  assert(
    #configs == 1 and configs[1].program == vim.fn.resolve(temp .. "/project with spaces/src/test.js"),
    "launch.json project-relative variables use the wrong cwd"
  )
  assert(
    configs[1].env.PROJECT == "project with spaces",
    "launch.json workspaceFolderBasename uses the wrong cwd"
  )
  assert(configs[1].args[1] == "src", "launch.json relativeFileDirname uses the wrong cwd")
  assert(getmetatable(configs[1]).__call, "launch.json inputs lost their callable configuration")
  vim.cmd.enew()
  assert(require("config.project").root() == vim.uv.cwd(), "Unnamed buffer should use cwd")
  vim.snippet.expand("hello ${1:world}! $0")
  assert(vim.api.nvim_get_current_line() == "hello world! ", "Snippet did not expand")
  assert(vim.snippet.active({ direction = 1 }), "Snippet placeholder not active")
  vim.snippet.jump(1)
  vim.snippet.stop()
  assert(#require("lualine").get_config().sections.lualine_x > 0, "Statusline not initialized")
  vim.fn.delete(temp, "rf")
  print("Runtime smoke: commands, filetype undo, project paths, launch.json, snippet and statusline passed")
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
