vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-telescope/telescope.nvim",
})
require("telescope").setup({
  defaults = {
    file_ignore_patterns = { "%.git/" },
    mappings = { i = { ["<Esc>"] = require("telescope.actions").close } },
  },
  pickers = {
    find_files = { hidden = true },
    live_grep = { additional_args = { "--hidden", "--glob", "!.git/*" } },
    buffers = { sort_mru = true, ignore_current_buffer = true },
  },
})
local function picker(name, opts)
  return function()
    require("telescope.builtin")[name](
      vim.tbl_extend("force", { cwd = require("config.project").root() }, opts or {})
    )
  end
end
local map = vim.keymap.set
map("n", "<leader>ff", picker("find_files"), { desc = "查找项目文件" })
map("n", "<leader>fg", picker("live_grep"), { desc = "搜索项目文本" })
map("n", "<leader>fw", picker("grep_string"), { desc = "搜索光标词" })
map("n", "<leader>fb", picker("buffers"), { desc = "打开的文件" })
map("n", "<leader>fr", picker("oldfiles"), { desc = "最近文件" })
map("n", "<leader>fR", picker("oldfiles", { only_cwd = true }), { desc = "当前项目最近文件" })
map("n", "<leader>fh", picker("help_tags"), { desc = "搜索帮助" })
map("n", "<leader>fk", picker("keymaps"), { desc = "搜索键位" })
map("n", "<leader>fc", picker("commands"), { desc = "搜索命令" })
map("n", "<leader>f/", picker("current_buffer_fuzzy_find"), { desc = "搜索当前文件" })
map("n", "<leader>fp", function()
  vim.notify(require("config.project").root(), vim.log.levels.INFO, { title = "Project root" })
end, { desc = "显示项目目录" })
map("n", "<leader>ls", picker("lsp_document_symbols"), { desc = "查找文件符号" })
map("n", "<leader>lS", picker("lsp_dynamic_workspace_symbols"), { desc = "查找项目符号" })
map("n", "<leader>ld", picker("lsp_definitions"), { desc = "选择定义位置" })
map("n", "<leader>lR", picker("lsp_references"), { desc = "选择引用位置" })
