local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.numberwidth = 2
opt.signcolumn = "yes"
opt.cursorline = true
opt.cursorlineopt = "number"
opt.termguicolors = true
opt.winborder = "rounded"
opt.colorcolumn = ""
opt.showmode = false
opt.laststatus = 3

-- Scroll
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.sidescroll = 1

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.wrapscan = true
opt.inccommand = "split"

-- Indent
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = -1
opt.smartindent = true
opt.autoindent = true
opt.shiftround = true

-- Whitespace
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  extends = "›",
  precedes = "‹",
}

-- Completion
opt.completeopt = { "menu", "menuone", "noselect", "popup" }
opt.pumheight = 10
opt.pumwidth = 15
opt.pummaxwidth = 80
opt.wildmenu = true
opt.wildmode = "longest:full,full"
opt.wildoptions = { "pum", "fuzzy" }

-- Files
opt.confirm = true
opt.autoread = true
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 250
opt.backup = false
opt.writebackup = true

-- Splits
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.equalalways = false

-- Input
opt.timeout = true
opt.timeoutlen = 500
opt.ttimeoutlen = 10
opt.backspace = { "indent", "eol", "start" }
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.virtualedit = "block"

-- Project config / security
opt.exrc = true
opt.modeline = false
opt.modelineexpr = false

-- Grep
opt.grepprg = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"

-- Diff
opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "algorithm:histogram",
  "indent-heuristic",
  "linematch:60",
}
