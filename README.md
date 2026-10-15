# Neovim 0.12 配置

使用 Neovim 0.12 原生 `vim.pack` 管理插件，Mason 管理语言服务、格式化器与调试适配器。没有 lazy.nvim 或自定义插件加载器。

## 目录

- `init.lua`：加载 `lua/config` 中的基础选项、键位和 autocmd。
- `plugin/`：按 LSP、补全、Git、导航、编辑、格式化、调试、UI 分领域，自动由 runtime 加载。
- `after/ftplugin/`：语言缩进的最终覆盖，同时追加 `b:undo_ftplugin`。实际检查发现内置 ftplugin 会覆盖普通 `ftplugin/` 写入的恢复记录，所以这里确实需要后置执行。
- `snippets/`：个人 VS Code 格式 snippet，与 friendly-snippets 一起由 blink.cmp 加载。
- `lua/config/mason_registry/`：Mason 原生 Lua registry，修正 Apple Silicon 的 netcoredbg 发行包选择。
- `lua/user/health.lua`：`:checkhealth user`。
- `nvim-pack-lock.json`：原生生成的插件 revision 锁文件，需要随配置提交版本控制。

## 安装与检查

需要 Neovim >= 0.12、Git、ripgrep，以及所用语言的工具链：Node/npm、Rust/Cargo、Go、.NET SDK、Python。Mason 安装服务，不代替编译器和项目依赖。C# 当前使用 Roslyn 5.12，需要符合服务要求的 .NET SDK；本机验证使用 SDK 10.0.401。

Windows 的默认 shell 优先选择 PATH 中的 PowerShell 7（`pwsh`），未安装时使用系统自带的 Windows PowerShell（`powershell`），并配置命令参数、UTF-8 输出和重定向。macOS、Linux（含 WSL）沿用 Neovim 原有 shell。配置参考 [Neovim PowerShell 帮助](https://neovim.io/doc/user/options/#shell-powershell)。

文件图标与状态栏符号需要终端使用 Nerd Font。iTerm2 在 **Settings → Profiles → 当前使用的 profile → Text → Font** 中选择 Nerd Font；本机已安装的字体名称包括 `Maple Mono NF CN` 和 `JetBrainsMono NFM`。如果启用了独立的 Non-ASCII Font，也需要将它设为 Nerd Font，或关闭独立字体选项，让非 ASCII 字符使用主字体。仅安装字体并不会改变 iTerm2 当前使用的字体；Monaco 不包含这些图标。修改后新开一个使用该 profile 的标签页检查。参见 [iTerm2 字体设置](https://iterm2.com/documentation-preferences-profiles-text.html)。

打开 Neovim 时，`vim.pack.add()` 按锁文件安装缺少的插件。Mason 的安装清单自动安装常用 LSP；Roslyn 使用额外 registry 单独安装。正常启动不自动更新已安装插件和服务。初次安装需联网，安装完成会启用新服务，必要时重新打开文件。

```vim
:Mason
:checkhealth user
:checkhealth mason
:checkhealth vim.lsp
:ConformInfo
```

手动补齐工具可使用以下原生命令。这里的名称是 **Mason package 名**；`plugin/lsp.lua` 的 `ensure_installed` 使用 **LSP config 名**。

```vim
:MasonInstall lua-language-server rust-analyzer clangd gopls basedpyright ruff
:MasonInstall vtsls eslint-lsp html-lsp css-lsp json-lsp vue-language-server svelte-language-server tailwindcss-language-server
:MasonInstall roslyn
:MasonInstall stylua clang-format goimports gofumpt prettier
:MasonInstall codelldb delve debugpy js-debug-adapter netcoredbg
```

插件更新使用 `:packupdate` / `:lua vim.pack.update()`，审阅原生更新缓冲区后保存确认。服务和工具在 `:Mason` 中更新；registry 使用 `:MasonUpdate`。Headless 检查不自动刷新 registry 或安装服务。

## LSP

| 语言 | 服务 | 说明 |
| --- | --- | --- |
| Lua | lua_ls | LuaJIT、Neovim runtime、`vim` 类型与补全 |
| Rust | rust_analyzer | Cargo workspace、proc macro、Clippy；编译诊断在保存后刷新 |
| C/C++ | clangd | 后台索引、clang-tidy、头文件/实现切换 |
| Go | gopls | 静态分析、gofumpt、imports、inlay hints |
| C# | Roslyn + roslyn.nvim | solution/project 选择、源码生成、引用、提示 |
| Python | basedpyright + Ruff | 类型与跳转由 basedpyright 提供，lint/imports 由 Ruff 提供 |
| JS/TS/React | vtsls + ESLint | TypeScript、JavaScript、React；ESLint 使用项目配置与依赖 |
| Vue 3 | vue_ls + vtsls | 通过 Mason 中的 `@vue/typescript-plugin` 配置 hybrid 模式 |
| Svelte | svelte | Svelte/TypeScript 服务 |
| HTML/CSS/JSON/Tailwind | html/cssls/jsonls/tailwindcss | 服务按文件类型和项目标记工作 |

只启用一套 Rust 服务和一套 TS 服务。不要同时开启 ts_ls 与 vtsls。Python 的 Ruff hover 已禁用；格式化由 Conform 统一处理。项目 `.venv`/`venv` 会用于 Python 分析和调试，其他环境可由项目 pyright 配置选择。

C/C++ 项目应生成 `compile_commands.json`，例如 CMake 设置 `CMAKE_EXPORT_COMPILE_COMMANDS=ON`；非标准构建目录可在项目 `.clangd` 中设置 `CompileFlags.CompilationDatabase`。不要在全局配置中硬编码某个编译器或项目路径。

Rust 需要可运行的工具链、Clippy 和标准库源码。使用 rustup 管理时，可按当前工具链执行 `rustup component add clippy rust-src rustfmt`。如果使用 mise shim，请先确认当前项目选中了可运行的语言版本。

C# 打开 `.cs` 时自动寻找 `.sln`、`.slnx` 或 `.csproj`，多 solution 用 `:Roslyn target` 切换。首次分析前通常需要恢复项目依赖。Roslyn 使用独立 stdio 进程，退出编辑器后不会保留 daemon。

前端项目需要自己的 ESLint、Vue/Svelte、TypeScript 等依赖。Prettier 优先使用项目 `node_modules/.bin`。Svelte 的格式化还需要项目安装并配置 `prettier-plugin-svelte`；Vue 2 需要按 Vue language-tools 文档使用兼容版本与配置。

## 快捷键

`<leader>` 是空格，`<localleader>` 是反斜杠。按空格停顿可看到 which-key 提示；`<leader>?` 查看当前文件操作，`<leader>fk` 搜索全部映射，`<leader>fc` 搜索命令。

| 功能 | 快捷键 |
| --- | --- |
| 保存 / 退出窗口 | `<leader>w` / `<leader>q` |
| 切换窗口 | `Ctrl-h/j/k/l` |
| 垂直 / 水平分屏 | `<leader>sv` / `<leader>sh` |
| 上一个 / 下一个 buffer | `Shift-h` / `Shift-l` |
| 删除 buffer | `<leader>bd` |
| 文件浏览 | `<leader>e`，mini.files 中 `h/l` 进出目录，`=` 同步编辑 |
| 项目文件 / grep / 光标词 | `<leader>ff` / `fg` / `fw` |
| buffer / 最近文件 / 当前项目最近文件 | `<leader>fb` / `fr` / `fR` |
| 当前文件搜索 / 帮助 | `<leader>f/` / `fh` |
| 显示项目根 | `<leader>fp` |
| 定义 / 声明 / 引用 / 实现 / 类型定义 | `gd` / `gD` / `grr` / `gri` / `gy` |
| hover / 签名 | `K` / `<leader>lk` |
| 重命名 / code action / organize imports | `<leader>lr` / `la` / `lo` |
| 符号 / workspace 符号 | `<leader>ls` / `lS` |
| 定义与引用 picker | `<leader>ld` / `lR` |
| inlay hints / code lens | `<leader>li` / `lc` |
| C/C++ 头文件切换 | `<leader>lh` |
| Mason | `<leader>lm` |
| 当前行 / 当前文件 / 当前项目诊断 | `<leader>le` / `<leader>xb` / `<leader>xx` |
| 上一个 / 下一个诊断 | `[d` / `]d` |
| LSP 引用与定义列表 / 符号树 / Quickfix（Trouble） | `<leader>xl` / `xs` / `xQ` |
| 标签跳转 / 语法节点跳转（Flash） | `<leader>j` / `J` |
| 撤销历史与分支（undotree） | `<leader>tu` |
| 第 100 列参考线（默认关闭） | `<leader>tc` |
| 格式化文件或选区 | `<leader>lf` |
| 保存格式化开关 | `<leader>tf`，默认关闭；`vim.b.autoformat=false` 可排除当前 buffer |
| 打开终端 | `<leader>tt`，终端中双按 Esc 回普通模式 |

补全：候选出现时默认选中第一项，但不自动插入文本。`Tab` / `Shift-Tab` 选择下一项 / 上一项，`Enter` 确认；没有候选时 Enter 正常换行。`Ctrl-n/p` 选择与 `Ctrl-y` 确认保留为备选。`Ctrl-Space` 打开，`Ctrl-e` 关闭，`Ctrl-b/f` 滚动文档。snippet 展开后，Tab/Shift-Tab 优先跳占位符；没有候选或可跳转的 snippet 时 Tab 回落普通缩进。命令行模式的 Enter 仍直接执行命令。

例如 C++ 中先 `#include <iostream>`，输入 `std::c` 后，如果首项就是 `cin`，直接按 Enter 插入 `std::cin`；否则用 Tab/Shift-Tab 选中 `cin` 再按 Enter。候选显示时若只想换行，先按 `Ctrl-e` 关闭候选，再按 Enter。未出现候选时可按 `Ctrl-Space` 手动打开，并用 `:checkhealth vim.lsp` 检查 clangd 是否附加。

个人 snippet 包含 Rust `fn/test/impl`、C++ `main/class`、Go `fn/ife/test`、C# `class/async/prop`、Python `def/main/test`、TS/React 与 Vue/Svelte 组件骨架。通过补全选择展开，然后用 Tab 跳占位符。

编辑：`gcc/gc` 注释，mini.surround 使用 `sa/sd/sr` 添加/删除/替换环绕，mini.ai 扩展 `a/i` 文本对象。Flash 的 `空格 j` 输入目标文本后按标签跳转，`空格 J` 选择语法节点；原生 `f/F/t/T`、`/` 和 surround 的 `s` 保持原样。

undotree 使用 `空格 tu` 打开并聚焦历史面板，`j/k` 浏览、Enter 切换到所选状态，`?` 显示帮助、`q` 关闭。差异面板显示历史变更；`u` 和 `Ctrl-r` 仍是原生撤销/重做。`undofile` 已开启，历史保存在 Neovim 的默认 undo 目录。第 100 列参考线默认关闭，避免把长注释中的一列字符看成选区；需要时用 `空格 tc` 切换。

## 语法高亮与折叠

nvim-treesitter 使用 `main` 分支和原生 `vim.treesitter.start()`，折叠使用 `vim.treesitter.foldexpr()`。默认展开全部，`zc/zo` 关闭/打开当前折叠，`zM/zR` 关闭/打开全部。切换文件保留手动选择的折叠状态；无 parser 的文件正常编辑。

已安装 C/C++、Rust、Go、C#、Python、JS/TS/TSX、Vue、Svelte、HTML/CSS、JSON/JSONC、YAML/TOML、Bash、Lua、Markdown parsers。安装需要 C 编译器和 `tree-sitter` CLI（本机 0.27.1）。插件更新后重启并执行 `:TSUpdate`，新增语言使用 `:TSInstall <语言>`。Parser 属于 Tree-sitter；语言服务仍由 Mason 管理。

## 运行与测试

| 操作 | 快捷键 |
| --- | --- |
| 选择运行/构建任务 / 任务列表 / 重跑最近任务 | `<leader>rr` / `rl` / `ra` |
| 运行光标附近测试 / 当前文件 / 当前项目 | `<leader>rt` / `rf` / `rT` |
| 调试光标附近测试 / 停止测试 | `<leader>rd` / `rs` |
| 测试输出 / 输出面板 / 测试树 | `<leader>ro` / `rp` / `rS` |

`rt`/`rd` 操作光标所在处或附近的测试。Overseer 自动提供常见 Cargo、npm、Make 等任务，并追加 Go、.NET、CMake 的构建/运行/测试模板。CMake 首次选择配置任务，默认 Debug 构建目录 `build`，可在表单中修改。项目 `.vscode/tasks.json` 按当前文件项目查找，`${workspaceFolder}` 按该文件对应 workspace 展开。任务面板 Enter 选择操作、`o` 打开输出、`?` 查看键位、`q`/Esc 关闭。

Neotest 在第一次使用测试操作时初始化，不在打开编辑器时自动运行测试，不启用 watch。发现会排除 node_modules、target、bin/obj、build 等依赖和产物目录。

| 语言 | 适配器与项目要求 |
| --- | --- |
| Python | neotest-python，项目 pytest（或配置 unittest）；优先 `.venv`/`venv` |
| Go | neotest-golang，Go 工具链；调试使用 Mason Delve |
| Rust | neotest-rust，Cargo 和 cargo-nextest；调试使用 LLDB/codelldb |
| 前端 | neotest-vitest / neotest-jest，使用项目的 node_modules 测试运行器 |
| C# | neotest-vstest，项目 SDK 与 xUnit/NUnit/MSTest；首次发现可能构建测试元数据 |
| C++ | neotest-ctest，CMake/CTest、已注册且构建好的测试；调试构建需包含调试信息 |

Jest/Vitest 从测试文件所属 package.json 识别；同时安装时默认 Vitest，可在项目配置设置 `vim.g.neotest_frameworks[项目绝对路径] = "jest"`。项目特殊的配置文件、测试参数或 CTest 构建目录仍需按适配器文档调整。测试运行器和项目依赖由项目自身安装，Mason 负责 LSP 和调试适配器。

实际验证使用含空格路径的七个独立项目：每个均发现并运行一个通过测试、一个预期失败测试，且单测试断点和单步通过。配置包含针对当前锁定 revision 的路径与 SDK 隔离兼容代码；升级适配器后应重跑验证。

## Git

| 操作 | 快捷键 |
| --- | --- |
| 状态 / log / commit | `<leader>gs` / `gl` / `gc` |
| 打开 / 关闭 Diffview | `<leader>gd` / `gD` |
| 文件 / 仓库历史 | `<leader>gh` / `gH` |
| 上一个 / 下一个 hunk | `[c` / `]c`，diff 模式保留原生跳转 |
| stage / reset hunk | `<leader>hs` / `hr`，也支持选区 |
| stage / unstage 整个 buffer | `<leader>hS` / `hu` |
| hunk 预览 / blame / buffer diff | `<leader>hp` / `hb` / `hd` |
| blame 开关 / hunk 文本对象 | `<leader>ht` / `ih` |

Fugitive 状态页面中 `s/u` 暂存/取消暂存、`=` 查看差异、`cc` 进入提交。配置不会自动 commit 或 push。hunk reset 会修改 buffer；使用前可先预览。

## 调试

`<leader>db` 断点，`dB` 条件断点，`dc` 启动/继续，`di/do/dO` 单步，`dq` 停止，`du` UI，`dr` REPL，`de` 求值。也支持 F5/F10/F11/F12。

- C/C++/Rust：优先使用本机可用的 `lldb-dap`（macOS 通过 xcrun 定位），否则使用 Mason 的 codelldb。选择带调试信息的可执行文件；Rust 可先 `cargo build`。
- Go：当前 package、package tests、attach。Delve 的进程 cwd 与项目根一致，以便正确构建模块。
- Python：当前文件，优先项目 `.venv`/`venv`；debugpy 自身使用 Mason 的独立环境。
- C#：选择构建好的 DLL，或 attach 进程。Apple Silicon 的本地 Mason registry 提供官方 netcoredbg 3.2.0-1092 原生 arm64 包；不需要 Rosetta。
- Node：运行当前 JS/TS 文件或 attach。TS 需要 Node 的兼容支持，或在 `launch.json` 中指定项目运行器/编译产物与 source map。
- React/Vue/Svelte：提供浏览器 launch，启动时输入实际开发服务器 URL；不自动启动 dev server。需要本机 Chrome/Chromium。SSR 也可 attach Node。

项目 `.vscode/launch.json` 从当前 buffer 的项目根按需加载，支持 JSONC、参数、环境变量、source map 和浏览器 URL。优先使用项目的配置来描述构建产物与测试入口。项目构建由用户执行，不在启动编辑器时自动构建。

示例：

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Node server",
      "type": "pwa-node",
      "request": "launch",
      "program": "${workspaceFolder}/dist/server.js",
      "cwd": "${workspaceFolder}",
      "sourceMaps": true,
      "args": ["--name", "value with spaces"]
    }
  ]
}
```

编辑器的项目搜索和 DAP 不会改变全局 cwd。Go 等工具对路径别名敏感；手写调试路径时，应与项目实际路径一致。Overseer 接入 `preLaunchTask` / `postDebugTask`；构建失败或命令无法启动会阻止调试，可用 `空格 rl` 查看输出。VS Code 扩展专用设置仍需对应 Neovim 适配器支持。

## 验证

配置 smoke check（已安装插件后，无需网络）：

```sh
nvim --headless -i NONE '+luafile tests/runtime.lua'
nvim --headless -i NONE '+luafile tests/daily.lua'
nvim --headless -i NONE '+luafile tests/project_tasks.lua'
nvim --headless -i NONE '+luafile tests/dotnet_isolation.lua'
nvim --headless -i NONE '+luafile tests/undo.lua'
```

该检查验证 runtime 命令、语言局部设置及恢复、带空格的项目路径、项目 launch.json、snippet 展开和状态栏。完整真实 LSP、格式化与调试验证结果记录在实施计划的执行记录中。

## 文档参考

- [Neovim pack](https://neovim.io/doc/user/pack.html)、[LSP](https://neovim.io/doc/user/lsp.html)
- [Mason](https://github.com/mason-org/mason.nvim)、[mason-lspconfig](https://github.com/mason-org/mason-lspconfig.nvim)
- [Roslyn](https://github.com/seblyng/roslyn.nvim)、[Vue language-tools](https://github.com/vuejs/language-tools/wiki/Neovim)
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)、[netcoredbg arm64 发行包](https://github.com/Samsung/netcoredbg/releases/expanded_assets/3.2.0-1092)

## 版本控制

提交 `init.lua`、`lua/`、`plugin/`、`after/`、`snippets/`、`tests/`、README、插件选型文档，以及 `.gitignore`、`.stylua.toml` 和 `nvim-pack-lock.json`。锁文件保存插件 revision，应与配置一同提交。

插件安装目录、Mason 工具、parser、缓存、日志、swap/undo 文件和会话文件属于本机运行数据，不纳入仓库。默认数据位置可通过 `:echo stdpath('data')`、`:echo stdpath('state')` 和 `:echo stdpath('cache')` 查看。`.gitignore` 同时排除误放在配置目录中的常见运行数据、本地 `.env` 和 `docs/superpowers/` 中的内部实施记录；`.env.example`、`.env.sample` 可提交。

插件选型文档保留调研背景；当前已启用的功能和操作以本 README 为准。
