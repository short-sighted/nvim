vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
  { src = "https://github.com/mason-org/mason.nvim", version = vim.version.range("2") },
  { src = "https://github.com/mason-org/mason-lspconfig.nvim", version = vim.version.range("2") },
  "https://github.com/seblyng/roslyn.nvim",
  -- Capability generation does not require completion.setup() to have run.
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1") },
})

require("mason").setup({
  -- Headless health/smoke checks should not refresh registries over the network.
  registry_cache = { refresh = #vim.api.nvim_list_uis() > 0 },
  registries = {
    "lua:config.mason_registry",
    "github:mason-org/mason-registry",
    "github:Crashdummyy/mason-registry",
  },
})
-- Hydrate the local Lua registry without a network refresh, including headless.
for source in require("mason-registry").sources:iterate({ include_uninstalled = true }) do
  if source.id == "config.mason_registry" then
    source:install():get_or_throw()
    break
  end
end
require("roslyn").setup({ broad_search = true })
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { source = true },
  update_in_insert = false,
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      completion = { callSnippet = "Replace" },
      telemetry = { enable = false },
      format = { enable = false },
    },
  },
})
vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      cargo = { allFeatures = true, buildScripts = { enable = true } },
      procMacro = { enable = true },
      check = { command = "clippy" },
      -- Debugging is handled by DAP rather than an unregistered LSP command.
      lens = { debug = { enable = false } },
    },
  },
})
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
  },
})
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      analyses = { unusedparams = true, nilness = true },
      hints = { assignVariableTypes = true, compositeLiteralFields = true, parameterNames = true },
    },
  },
})
vim.lsp.config("roslyn", {
  cmd = function(dispatchers)
    return vim.lsp.rpc.start({ require("roslyn.utils").get_roslyn_lsp_path(), "--stdio" }, dispatchers)
  end,
  settings = {
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
    },
    ["csharp|code_lens"] = { dotnet_enable_references_code_lens = true },
    ["csharp|completion"] = { dotnet_show_completion_items_from_unimported_namespaces = true },
  },
})
vim.lsp.config("basedpyright", {
  settings = { basedpyright = { disableOrganizeImports = true } },
  before_init = function(_, config)
    -- Project configuration and pyright's discovery handle other environments.
    local root = config.root_dir
    if not root then
      return
    end
    for _, directory in ipairs({ ".venv", "venv" }) do
      local python = vim.fs.joinpath(root, directory, "bin", "python")
      if vim.fn.executable(python) == 1 then
        config.settings.python =
          vim.tbl_extend("force", config.settings.python or {}, { pythonPath = python })
        break
      end
    end
  end,
})
vim.lsp.config("ruff", {})
vim.lsp.config("vtsls", {
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
  settings = {
    vtsls = {
      autoUseWorkspaceTsdk = true,
      tsserver = {
        globalPlugins = {
          {
            name = "@vue/typescript-plugin",
            location = require("config.tools").mason_path(
              "packages/vue-language-server/node_modules/@vue/language-server"
            ),
            languages = { "vue" },
            configNamespace = "typescript",
            enableForWorkspaceTypeScriptVersions = true,
          },
        },
      },
    },
  },
})
vim.lsp.config("eslint", { settings = { format = { enable = false } } })
vim.lsp.config("jsonls", { settings = { json = { validate = { enable = true } } } })

local group = vim.api.nvim_create_augroup("user-lsp", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
    if client.name == "ruff" or client.name == "vtsls" or client.name == "eslint" then
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    map("n", "gd", vim.lsp.buf.definition, "跳转定义")
    map("n", "gD", vim.lsp.buf.declaration, "跳转声明")
    map("n", "grr", vim.lsp.buf.references, "查找引用")
    map("n", "gri", vim.lsp.buf.implementation, "查找实现")
    map("n", "gy", vim.lsp.buf.type_definition, "跳转类型定义")
    map("n", "K", vim.lsp.buf.hover, "查看文档")
    map("n", "<leader>lk", vim.lsp.buf.signature_help, "函数参数提示")
    map("n", "<leader>lr", vim.lsp.buf.rename, "重命名符号")
    map({ "n", "x" }, "<leader>la", vim.lsp.buf.code_action, "代码操作")
    map("n", "<leader>lo", function()
      vim.lsp.buf.code_action({
        context = { only = { "source.organizeImports" }, diagnostics = {} },
        apply = true,
      })
    end, "整理导入")
    map("n", "<leader>li", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
    end, "切换内联提示")
    map("n", "<leader>lc", vim.lsp.codelens.run, "执行代码透镜")
    if client:supports_method("textDocument/codeLens") then
      vim.lsp.codelens.enable(true, { bufnr = ev.buf, client_id = client.id })
    end
    if client.name == "clangd" then
      map("n", "<leader>lh", "<cmd>LspClangdSwitchSourceHeader<cr>", "切换源码 / 头文件")
    end
  end,
})
vim.keymap.set("n", "<leader>lm", "<cmd>Mason<cr>", { desc = "Mason 工具管理" })
vim.keymap.set("n", "<leader>le", vim.diagnostic.open_float, { desc = "当前行诊断" })
vim.keymap.set("n", "<leader>xq", vim.diagnostic.setqflist, { desc = "诊断发送到结果列表" })
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "下一条诊断" })
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "上一条诊断" })

local binaries = {
  lua_ls = "lua-language-server",
  rust_analyzer = "rust-analyzer",
  clangd = "clangd",
  gopls = "gopls",
  basedpyright = "basedpyright-langserver",
  ruff = "ruff",
  vtsls = "vtsls",
  eslint = "vscode-eslint-language-server",
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  jsonls = "vscode-json-language-server",
  vue_ls = "vue-language-server",
  svelte = "svelteserver",
  tailwindcss = "tailwindcss-language-server",
}
local function enable_available()
  for name, binary in pairs(binaries) do
    if require("config.tools").executable(binary) then
      vim.lsp.enable(name)
    end
  end
  local roslyn = require("roslyn.utils").get_roslyn_lsp_path()
  vim.lsp.enable("roslyn", vim.fn.executable(roslyn) == 1)
end
enable_available()
require("mason-registry"):on("package:install:success", vim.schedule_wrap(enable_available))
-- The custom Roslyn package is not mapped by mason-lspconfig.
require("mason-registry").refresh(function(success)
  if not success or #vim.api.nvim_list_uis() == 0 then
    return
  end
  local registry = require("mason-registry")
  if registry.has_package("roslyn") then
    local package = registry.get_package("roslyn")
    if not package:is_installed() and not package:is_installing() then
      package:install()
    end
  end
end)
require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",
    "rust_analyzer",
    "clangd",
    "gopls",
    "basedpyright",
    "ruff",
    "vtsls",
    "eslint",
    "html",
    "cssls",
    "jsonls",
    "vue_ls",
    "svelte",
    "tailwindcss",
  },
  automatic_enable = false,
})
