-- Native :checkhealth user discovers the user.health namespace.
local M = {}
function M.check()
  local health, tools = vim.health, require("config.tools")
  health.start("Neovim configuration")
  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim >= 0.12")
  else
    health.error("Neovim 0.12 is required")
  end
  for _, name in ipairs({ "git", "rg", "node", "npm", "go", "cargo", "dotnet", "python3" }) do
    local path = tools.executable(name)
    if path then
      health.ok(name .. ": " .. path)
    else
      health.warn("Missing toolchain: " .. name)
    end
  end
  health.start("Language servers (Mason preferred)")
  local servers = {
    ["lua-language-server"] = "lua-language-server",
    ["rust-analyzer"] = "rust-analyzer",
    clangd = "clangd",
    gopls = "gopls",
    ["basedpyright-langserver"] = "basedpyright",
    ruff = "ruff",
    vtsls = "vtsls",
    ["roslyn-language-server"] = "roslyn",
    ["vscode-eslint-language-server"] = "eslint-lsp",
    ["vscode-html-language-server"] = "html-lsp",
    ["vscode-css-language-server"] = "css-lsp",
    ["vscode-json-language-server"] = "json-lsp",
    ["vue-language-server"] = "vue-language-server",
    svelteserver = "svelte-language-server",
    ["tailwindcss-language-server"] = "tailwindcss-language-server",
  }
  for binary, package in pairs(servers) do
    local path = tools.executable(binary)
    if path then
      health.ok(binary .. ": " .. path)
    else
      health.warn("Missing " .. binary, { ":MasonInstall " .. package })
    end
  end
  health.start("Formatters")
  for binary, package in pairs({
    stylua = "stylua",
    ["clang-format"] = "clang-format",
    goimports = "goimports",
    gofumpt = "gofumpt",
    ruff = "ruff",
    prettier = "prettier",
    rustfmt = "Rust toolchain",
  }) do
    local path = tools.executable(binary)
    if path then
      health.ok(binary .. ": " .. path)
    else
      health.warn("Missing " .. binary .. " (" .. package .. ")")
    end
  end
  health.start("Debug adapters")
  local lldb = tools.lldb_dap()
  if lldb then
    health.ok("Native lldb-dap (preferred): " .. lldb)
  end
  for binary, package in pairs({ codelldb = "codelldb", dlv = "delve", ["debugpy-adapter"] = "debugpy" }) do
    local path = tools.executable(binary)
    if path then
      health.ok(binary .. ": " .. path)
    else
      health.warn("Missing adapter", { ":MasonInstall " .. package })
    end
  end
  local netcoredbg = vim.g.netcoredbg_path or tools.executable("netcoredbg")
  if netcoredbg then
    health.ok("netcoredbg: " .. netcoredbg)
  else
    health.warn("C# adapter missing", { ":MasonInstall netcoredbg" })
  end
  local js = tools.mason_path("packages/js-debug-adapter/js-debug/src/dapDebugServer.js")
  if vim.uv.fs_stat(js) then
    health.ok("js-debug-adapter: " .. js)
  else
    health.warn("Node/browser adapter missing", { ":MasonInstall js-debug-adapter" })
  end
  health.info("Project Python: " .. tools.python())
  health.start("代码结构与测试")
  for _, binary in ipairs({ "tree-sitter", "cc", "cmake", "ctest", "cargo-nextest" }) do
    local path = tools.executable(binary)
    if path then
      health.ok(binary .. ": " .. path)
    else
      health.warn("缺少工具：" .. binary .. "；对应高亮安装或测试流程需要它。")
    end
  end
  local missing_parsers = {}
  for _, lang in ipairs({
    "c",
    "cpp",
    "rust",
    "go",
    "c_sharp",
    "python",
    "javascript",
    "typescript",
    "tsx",
    "vue",
    "svelte",
    "html",
    "css",
    "json",
    "jsonc",
    "yaml",
    "toml",
    "bash",
    "lua",
    "markdown",
    "markdown_inline",
  }) do
    if not pcall(vim.treesitter.language.add, lang) then
      missing_parsers[#missing_parsers + 1] = lang
    end
  end
  if #missing_parsers == 0 then
    health.ok("常用语言的 21 个 Tree-sitter parsers 已安装")
  else
    health.warn("缺少 parsers", { ":TSInstall " .. table.concat(missing_parsers, " ") })
  end
  health.info(
    "测试依赖使用项目环境：pytest/unittest、Go test、cargo-nextest、Jest/Vitest、dotnet test、CTest。"
  )
  health.info(
    "C++ 需要构建后的 CTestTestfile.cmake；C# 测试发现可能构建项目，首次操作需要等待。"
  )
  health.info("Servers require working toolchains; executable shims may need a version selected in mise.")
end
return M
