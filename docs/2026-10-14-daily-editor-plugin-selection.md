# 日用 Neovim 插件选型清单

调研日期：2026-10-14。依据当时配置、Context7 文档与项目官方 README。本文保留选型时的候选方案和判断，不代表当前安装状态。

实施后已完善 which-key，并加入 nvim-treesitter、Trouble、Overseer、Flash、Neotest 及七个测试适配器、undotree；保留 Telescope 和 mini.files，未加入 Snacks。当前功能和键位以 [README](../README.md) 为准。下文“当前配置”“推荐组合”等均指调研时的情况。

你的偏好：**终端编辑器，键盘为主，但需要更清晰的提示**。保留 Neovim 0.12 的 `vim.pack`；语言服务器继续考虑 Mason。常用语言包括 Rust、C/C++、Go、C#、Python 和前端。

推荐顺序和学习成本是针对你的使用情况做出的判断，不是按 GitHub 星数排名。插件功能依据下方链接的官方说明；与当前配置的集成方案仍需在选定后验证。

## 当前配置与日用缺口

已经有：Mason、原生 LSP、blink.cmp、friendly-snippets 与个人 snippets、Conform、Gitsigns、Fugitive、Diffview、Telescope、mini.files、mini.pairs/surround/ai/comment、which-key、lualine、nvim-dap 与 dap-ui。

当前缺口主要是操作发现和项目流程：

- 快捷键提示已经有，但目前多为英文；缺少统一的“搜索一个操作并执行”的入口，以及面板内直观的按键提示。
- 未系统配置 Tree-sitter 的语言解析器、高亮与折叠。
- 查找文件、搜索文本已经有；项目范围的替换缺少专门界面。
- 诊断主要靠临时搜索窗口；缺少能持续查看、定位错误与引用的面板。
- 终端能打开，但没有统一的复用、切换与任务输出管理。
- 缺少会话恢复、构建任务管理和测试结果面板。
- 已有调试器连接与操作，但“构建 → 启动调试”“选中一个测试 → 调试”仍需进一步整合。

## 推荐优先挑选

| 编号 | 插件 / 组件 | 你实际获得的操作 | 当前配置的处理 | 成本与建议 |
| --- | --- | --- | --- | --- |
| A1 | [which-key.nvim](https://github.com/folke/which-key.nvim) | 按前缀看到后续操作；补齐中文说明、分组与常用入口 | **已安装，完善配置** | 低；优先做，解决“不知道能按什么” |
| A2 | [snacks.nvim](https://github.com/folke/snacks.nvim) | 搜索命令/键位、最近文件、清晰的输入和选择窗口、通知历史、可复用终端、启动入口、缩进与作用域提示 | 模块按需启用；若选 picker，它替换 Telescope 的主要搜索入口；mini.files 可继续保留 | 中；推荐，但不全开，也不强制启用文件侧栏或动画 |
| A3 | [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | 结构化高亮、按代码结构折叠；为标签处理、测试发现等提供基础 | 新增；保留已有语言缩进，初期不统一改用实验性 Tree-sitter 缩进 | 中；推荐补齐，需 parser、C 编译器及匹配版本的 tree-sitter CLI |
| A4 | [trouble.nvim](https://github.com/folke/trouble.nvim) | 固定面板查看项目错误、警告、引用和调用关系，Enter 定位 | 接管诊断面板入口；搜索窗口仍用于临时查找 | 低至中；推荐，先提供清楚的打开、切换焦点、返回与关闭操作 |
| A5 | [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim) | 在界面中填写搜索、替换、文件范围，查看匹配后执行项目替换 | 新增；搜索与替换分工 | 中；推荐，比要求你先掌握复杂替换命令更易用；文本替换不能代替 LSP 符号重命名 |
| A6 | [persistence.nvim](https://github.com/folke/persistence.nvim) | 恢复上次打开的文件和窗口布局，从会话列表继续工作 | 新增；与启动入口连接，提供明确的恢复操作 | 低；推荐；需统一按项目根保存，避免当前 cwd 与项目根不同造成会话混淆 |
| A7 | [overseer.nvim](https://github.com/stevearc/overseer.nvim) | 从列表选择构建/运行任务，查看输出、重跑任务；支持连接调试前构建任务 | 新增；连接现有 DAP，按项目定义任务 | 中；推荐；支持 make/npm/cargo/tasks.json 等，Go/.NET 等仍需针对项目配置任务 |
| A8 | [flash.nvim](https://github.com/folke/flash.nvim) | 输入目标文字后按屏幕标签快速跳转，减少反复移动光标 | 新增一个明确的跳转入口 | 低至中；适合键盘偏好；初期保留熟悉的搜索与移动，不直接覆盖 mini.surround 的 `s` 前缀 |

A2 的选择需要明确：

- **A2-S：Snacks picker 为主。** 文件、文本、命令、键位搜索使用同一套界面。推荐此选项；沿用目前的主要快捷键，mini.files 仍用于键盘浏览与文件操作。
- **A2-T：Telescope 为主。** 保留现有搜索，补齐 commands/keymaps/registers 等入口；Snacks 仅选需要的终端、输入、通知、缩进等模块。适合已经开始习惯当前 Telescope 的情况。

不建议同时提供两套名字相近、键位不同的主要搜索流程。最终只确定一个主入口。

## 有明确需求再加

| 编号 | 插件 / 组件 | 适合的需求 | 取舍 |
| --- | --- | --- | --- |
| B1 | [neotest](https://github.com/nvim-neotest/neotest) + 对应适配器 | 列出测试、运行当前测试/文件、查看失败信息、调试测试 | 值得加，但配置成本较高；按实际测试框架接入，不能只安装主体就认为六种语言全部可用 |
| B2 | [gbprod/yanky.nvim](https://github.com/gbprod/yanky.nvim) | 找回前几次复制内容，循环选择粘贴历史 | 推荐给经常复制/剪切的人；初期使用简单存储，持久化历史按需要选择 |
| B3 | [mbbill/undotree](https://github.com/mbbill/undotree) | 直观看到撤销分支，找回曾经改过又撤销的内容 | 低成本；已有 `undofile`，此插件增加可视入口；与 Snacks 的 undo picker 二选一即可 |
| B4 | [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | 在编辑器内更清楚地阅读 README、标题、表格和任务列表 | 常写文档时推荐；依赖 Markdown parser，属于编辑器内渲染，不是完整浏览器预览 |
| B5 | [bufferline.nvim](https://github.com/akinsho/bufferline.nvim) | 随时看到当前打开的文件、修改状态与诊断标记 | 可选；这里显示的通常是 buffer，不是 Vim tabpage；喜欢简洁界面可继续用文件列表 |
| B6 | [aerial.nvim](https://github.com/stevearc/aerial.nvim) | 持续显示当前文件的类、函数和符号，快速浏览结构 | 经常阅读大文件时选；先试 Trouble 的 symbols，若已满足就不再增加另一套大纲 |
| B7 | [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | 更一致地区分代码、高亮、诊断和面板 | 可选；选主题时优先考虑长时间阅读与对比度，图标仍需终端配置 Nerd Font |
| B8 | [LazyGit](https://github.com/jesseduffield/lazygit) + Snacks lazygit 模块 | 键盘操作暂存、提交、分支、stash 和历史，界面提供操作提示 | 你优先关注 Git 时推荐；LazyGit 是外部程序，不是 LSP，也无需再装 lazygit.nvim 来重复封装 |

保留 Gitsigns 的行级变更提示和 Diffview 的差异/历史查看。若选 B8，LazyGit 可以成为主要 Git 操作入口，Fugitive 留作高级命令或按你的选择移除其入口。

文件浏览方面，当前 [mini.files](https://github.com/nvim-mini/mini.files) 很符合你的键盘偏好，建议保留。只有明确希望固定树形侧栏时，再选择 [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) 或 Snacks explorer；不同时启用多个默认文件浏览器。

## 按语言选择增强

LSP 主体和补全继续使用现有方案。下列插件补充项目操作，不能自动保证具备完整 IDE 的全部重构能力。

| 编号 | 语言与候选 | 增加什么 | 集成注意事项 |
| --- | --- | --- | --- |
| L1 | Rust：[rustaceanvim](https://github.com/mrcjkb/rustaceanvim) | rust-analyzer 专有操作，例如运行入口、宏展开，以及 Rust 专用调试/测试集成 | Rust 使用频繁时选；它接管 Rust LSP，必须停用现有重复的 rust_analyzer 启用入口；语言服务仍可使用 Mason 安装的二进制 |
| L2 | Rust：[crates.nvim](https://github.com/saecki/crates.nvim) | Cargo.toml 依赖管理、版本与功能相关操作 | 独立增强，不必为了它更换 Rust LSP；补全与 blink 的衔接按选定版本验证 |
| L3 | C/C++：[cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim) | 选择 CMake preset/目标、生成、构建、运行，管理 compile_commands | 只在使用 CMake 的项目选；clangd 继续负责补全、诊断与跳转；可与 Overseer 整合 |
| L4 | Go：neotest 的 Go 适配器 | 当前测试、测试文件、失败输出与调试测试 | 主体 gopls + Delve 已有；按实际 Go 测试框架挑适配器，避免为同一功能再堆一套大型 Go 插件 |
| L5 | C#：[easy-dotnet.nvim](https://github.com/GustavEikaas/easy-dotnet.nvim) | solution/project 选择、构建、运行、测试与包管理 | 增强明显，但较重；额外依赖 EasyDotnet 服务。它也提供 Roslyn/DAP，需明确关闭重复管理，或做一次完整接管方案；Mason 与现有 Roslyn 保留的方案优先评估 |
| L6 | Python：[venv-selector.nvim](https://github.com/linux-cultist/venv-selector.nvim) | 从列表发现并切换 venv/Poetry/Conda/uv 等环境，连接分析与调试 | 经常切环境时选；只使用项目 `.venv` 则当前自动发现已经足够；须让 LSP 与 DAP 使用同一个所选解释器 |
| L7 | 前端：[nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag) | 自动补闭合标签、同步重命名成对标签 | HTML/JSX/Vue 等常用时推荐；需要对应 parser，避免与补全 snippet 重复生成闭合标签 |

测试优先按项目选 pytest、Go test、Jest/Vitest、Cargo、dotnet test、CTest/GoogleTest 等适配器。尤其 C++ 与 .NET 的测试发现、构建和调试要用实际项目验证。

## 生态中的几个选型结论

1. **继续完善当前配置：我的推荐。** 保留 `vim.pack`、Mason、已有语言配置与刚调整的补全手感，集中补齐入口和项目流程。先改善每天都用的操作，再增加语言专属工具。
2. **整体换成发行版：备选。** [LazyVim](https://www.lazyvim.org/) 提供现成配置与 Extras，适合希望沿用其整体习惯的人；它基于 lazy.nvim。选择这条路线意味着重新确定配置管理、快捷键和现有定制的迁移方式，不能与当前配置直接混装。
3. **按当前文档配置 Tree-sitter。** 当前 `main` 是不兼容重写；不要照搬旧 `nvim-treesitter.configs.setup` 教程。官方目前列出 Neovim 0.12、tree-sitter CLI 0.26.1+ 与 C 编译器等要求；插件更新也要协调 parser 更新。[官方 README](https://github.com/nvim-treesitter/nvim-treesitter)
4. **Dressing 不作为新配置首选。** 仓库已归档，作者推荐 Snacks 改善 `vim.ui.*`。[项目说明](https://github.com/stevearc/dressing.nvim)
5. **Mason 继续负责语言工具安装。** UI 插件、Tree-sitter parsers、项目依赖、LazyGit、EasyDotnet 辅助服务等各有其安装方式，不能都当成 LSP 包交给 Mason。

## 我建议的第一轮组合

**A1～A8，A2 选 A2-S；Git 选 B8。** 保留 mini.files、blink.cmp 与目前的 Tab/Enter 补全、Conform、Gitsigns、Diffview、lualine、原生 snippet 和现有 DAP。

如果你希望第一轮同时完成测试，再加 **B1**，并先接入你最常用项目的测试框架。复制与撤销体验可加 **B2、B3**；标签栏 B5、大纲 B6 和主题 B7 由你决定。

语言增强建议：前端选 **L7**；Rust 重度使用选 **L1、L2**；CMake 项目选 **L3**；多 Python 环境选 **L6**；C# 项目操作频繁时评估 **L5**。

选定后的完善工作需要包含：

- 一个统一的操作搜索入口；中文操作说明和一致的分组。
- 每个面板可直接看到选择、确认、返回、关闭等按键；光标与焦点行为一致。
- 项目根一致地用于搜索、任务、会话、Git 与调试。
- Git/LSP/终端/测试状态可见，出错时有可找到的输出记录。
- 验证插件重叠、键位冲突、parser 版本和各语言真实项目；提供一页常用操作说明。

回复编号即可，例如：`A1-A8（A2-S）+ B1/B2/B8 + L1/L2/L7`，或“按第一轮推荐组合”。也可以明确排除某项。
