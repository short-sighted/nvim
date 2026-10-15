-- Configure before loading the Vimscript plugin.
vim.g.undotree_WindowLayout = 1
vim.g.undotree_SplitWidth = 32
vim.g.undotree_DiffpanelHeight = 10
vim.g.undotree_SetFocusWhenToggle = 1
vim.pack.add({ "https://github.com/mbbill/undotree" })
vim.keymap.set("n", "<leader>tu", "<cmd>UndotreeToggle<cr>", { desc = "撤销历史与分支" })
