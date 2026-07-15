# Kitty 快捷键迁移设计

日期：2026-07-15

## 背景

当前工作流使用 `lemon-tmux`，前缀键为 `Ctrl+Q`。用户正在将本地终端窗口、标签页和布局管理迁移到 Kitty 0.47.4，希望保留高频且必要的 tmux 肌肉记忆，同时继续使用 Kitty 原生快捷键和能力。

当前 `~/.config/kitty/kitty.conf` 已包含主题、字体、窗口外观、滚动历史和标签栏设置，但没有活动的自定义 `map`。Kitty 默认 `kitty_mod` 仍为 `Ctrl+Shift`，所有默认快捷键均有效。

## 目标

- 保留 Kitty 全部默认快捷键。
- 使用 `Ctrl+Q` 作为一次性的 Kitty 临时键盘模式。
- 迁移 session、tab、切分窗口、焦点、尺寸、布局和常用系统操作。
- 让新建 tab 和 Kitty window 继承当前工作目录并加入当前 session。
- 使用 Kitty 原生 session 选择和手动保存功能。
- 让修改范围清晰、可回退、可验证。

## 非目标

- 不模拟 tmux 的后台 server、detach 或 attach。
- 不迁移 tmux copy-mode；继续使用 Kitty 原生选择、剪贴板和 scrollback。
- 不迁移 TPM 插件管理快捷键。
- 不迁移 tmux 时钟。
- 不迁移原 tmux FZF shell 拼接命令；继续保留 Kitty 原生 hints 和文件选择器。
- 不启用 session 的自动前台程序恢复。
- 不增加 kitten、自定义脚本或第三方依赖。

## 概念对应

| tmux | Kitty | 说明 |
|---|---|---|
| session | session | 项目工作环境；不提供 tmux server 式进程持久化 |
| window | tab | 标签栏中的工作区 |
| pane | Kitty window | tab 内运行 shell 或程序的终端区域 |
| prefix | 临时键盘模式 | 由 `Ctrl+Q` 进入，执行一次动作后退出 |

典型组织结构如下：

```text
Kitty 进程
└── Session
    └── OS window
        └── Tab
            ├── Kitty window
            └── Kitty window
```

Session 是逻辑分组，可以定义多个 OS window，也可以在一个 OS window 中管理多个 session，因此该结构表示推荐用法，不是强制的一对一约束。

## 快捷键模式

创建名为 `tmux` 的 Kitty 键盘模式：

- 入口键为 `Ctrl+Q`。
- 每次执行一个动作后自动退出。
- 等待第二个按键超过 2 秒后自动退出。
- 未识别的第二个按键结束模式。
- `Escape` 主动退出模式。
- `Ctrl+Q` 后再次按 `Ctrl+Q`，向前台终端程序发送原始 `Ctrl+Q`。

不修改 `kitty_mod`，也不设置 `clear_all_shortcuts yes`。

模式入口的完整定义为：

```text
map --new-mode tmux --on-action end --on-unknown end --timeout 2.0 ctrl+q
```

其中 `--on-unknown end` 会提示一次并退出模式；各模式内动作使用 `map --mode tmux ...` 定义。

## 布局设计

启用并按以下顺序排列布局：

```text
splits,stack,tall,fat,grid,horizontal,vertical
```

`splits` 排在第一位，作为默认布局。这样左右和上下切分可以使用 Kitty 原生任意嵌套分割。

Kitty 与 tmux 的切分参数命名不同，映射必须按视觉结果转换：

| 视觉效果 | tmux | Kitty |
|---|---|---|
| 左右并排 | `split-window -h` | `launch --location=vsplit` |
| 上下排列 | `split-window -v` | `launch --location=hsplit` |

使用 `stack` 布局模拟 tmux 的当前 pane 放大：进入 `stack` 时只显示当前 Kitty window，再次触发恢复之前的布局。

## Session 映射

Session 文件统一保存到：

```text
~/.local/share/kitty/sessions/
```

该目录当前不存在，实施时创建。

| 前缀后的按键 | 动作 | 行为 |
|---|---|---|
| `s` | `goto_session` | 扫描 session 目录并交互选择；活动 session 直接切换，未活动 session 从文件创建 |
| `Shift+S` | `save_as_session` | 将当前聚焦 OS window 另存为新的 session 文件，并提示输入文件名 |
| `Ctrl+S` | `save_as_session` | 仅保存当前 session 的窗口并覆盖当前 session 文件 |

保存策略：

- 使用 `--save-only`，保存后不自动打开编辑器。
- 新 session 使用 `--match=state:focused_os_window`，限制在当前聚焦 OS window，避免混入其他项目。
- 新 session 使用 `--base-dir ~/.local/share/kitty/sessions`，未指定文件名时由 Kitty 提示输入。
- 更新使用 `--match=session:.` 和目标 `.`，只覆盖当前 session。
- 不使用 `--use-foreground-process`，避免恢复时重新执行危险或一次性的前台命令。
- 没有活动 session 时，`Ctrl+S` 不应创建或覆盖文件；用户先用 `Shift+S` 另存。

三个 Session 动作的完整形式为：

```text
goto_session ~/.local/share/kitty/sessions
save_as_session --save-only --match=state:focused_os_window --base-dir ~/.local/share/kitty/sessions
save_as_session --save-only --match=session:. .
```

## Tab 映射

Kitty tab 对应原 tmux window。

| 前缀后的按键 | Kitty 动作 | 行为 |
|---|---|---|
| `c` | `new_tab_with_cwd` | 在当前目录新建 tab，并加入当前 session |
| `n` | `next_tab` | 切换到下一个 tab |
| `p` | `previous_tab` | 切换到上一个 tab |
| `1` 至 `9` | `goto_tab` | 跳转到对应编号的 tab |
| `w` | `select_tab` | 打开交互式 tab 选择器 |
| `,` | `set_tab_title` | 交互式重命名当前 tab |
| `<` | `move_tab_backward` | 当前 tab 左移 |
| `>` | `move_tab_forward` | 当前 tab 右移 |
| `&` | `close_tab` | 关闭当前 tab |

关闭 tab 沿用 Kitty 的 `confirm_os_window_close -1` 默认策略：存在运行中的前台程序时要求确认，只有空闲 shell 时允许直接关闭。

## Kitty Window 映射

Kitty window 对应原 tmux pane。

| 前缀后的按键 | Kitty 动作 | 行为 |
|---|---|---|
| `h` | `launch --location=vsplit` | 左右切分，新终端位于右侧 |
| `v` | `launch --location=hsplit` | 上下切分，新终端位于下方 |
| `Left` | `neighboring_window left` | 聚焦左侧相邻终端 |
| `Right` | `neighboring_window right` | 聚焦右侧相邻终端 |
| `Up` | `neighboring_window up` | 聚焦上方相邻终端 |
| `Down` | `neighboring_window down` | 聚焦下方相邻终端 |
| `Alt+Left` | `resize_window narrower 5` | 当前终端变窄 5 格 |
| `Alt+Right` | `resize_window wider 5` | 当前终端变宽 5 格 |
| `Alt+Up` | `resize_window taller 5` | 当前终端变高 5 格 |
| `Alt+Down` | `resize_window shorter 5` | 当前终端变矮 5 格 |
| `q` | `focus_visible_window` | 显示编号并选择终端 |
| `x` | `close_window_with_confirmation` | 确认后关闭当前终端 |
| `z` | `toggle_layout stack` | 放大当前终端或恢复之前布局 |
| `!` | `detach_window new-tab` | 将当前终端移动到新 tab |
| `Space` | `next_layout` | 切换到下一个启用布局 |

切分动作使用 `launch --cwd=current --add-to-session .`，显式继承当前工作目录，并以当前 window 为来源加入当前 session。没有活动 session 时仍正常创建切分。

尺寸调整是一次性动作；连续调整需要重复按前缀。大量调整仍可使用 Kitty 默认的 `Ctrl+Shift+R` 交互式调整模式。

## 系统映射

| 前缀后的按键 | Kitty 动作 | 行为 |
|---|---|---|
| `r` | `load_config_file` | 重新加载默认 `kitty.conf` |
| `l` | `clear_terminal to_cursor_scroll active` | 清除当前屏幕内容和滚动历史 |
| `?` | `command_palette` | 打开动作与快捷键搜索面板 |
| `:` | `kitty_shell window` | 打开 Kitty 控制命令 shell |
| `Ctrl+Q` | `send_key ctrl+q` | 向前台程序发送原始 `Ctrl+Q` |
| `Escape` | `pop_keyboard_mode` | 取消前缀模式 |

## 文件修改范围

实施只进行以下文件系统变更：

1. 为当前 `~/.config/kitty/kitty.conf` 创建带时间戳的备份。
2. 在现有 `kitty.conf` 末尾追加一个带 `BEGIN/END` 标记的迁移区块。
3. 创建 `~/.local/share/kitty/sessions/`。

不改动现有主题、字体、窗口外观、滚动历史和标签栏配置，不覆盖现有 `kitty.conf.bak`。

## 失败处理

- Kitty 模式超时或遇到未知按键时退出，避免长期截获普通输入。
- `Escape` 始终可以取消模式。
- 单个 Kitty window 使用显式关闭确认。
- Tab 关闭使用 Kitty 原生运行中程序检测。
- 更新不存在的当前 session 时不创建文件，并提示用户先执行另存。
- 不自动执行 session 保存、关闭 tab 或关闭 window 的验证动作。
- 如果新增配置无法加载，保留原配置备份并报告解析错误，不继续触发功能测试。

## 验证设计

实施后按以下顺序验证：

1. 检查配置差异，只允许出现已批准的迁移区块。
2. 使用本机 Kitty 0.47.4 解析修改后的配置，确认没有语法、动作名或键位错误。
3. 检查解析后的配置包含 `splits` 默认布局和 `tmux` 键盘模式。
4. 利用当前默认的 `auto_reload_config 0.1` 自动加载；需要时使用 Kitty 默认 `Ctrl+Shift+F5` 手动重载。
5. 不自动执行关闭窗口或写入 session 的破坏性动作。
6. 提供手动冒烟顺序：前缀取消、左右/上下切分、相邻切换、tab 创建与切换、session 另存和更新。

## 成功标准

- Kitty 默认 `Ctrl+Shift` 快捷键保持有效。
- `Ctrl+Q` 进入一次性模式，动作完成、超时、未知键或 `Escape` 后退出。
- 左右和上下切分方向与原 tmux 肌肉记忆一致。
- 新 tab 和新 Kitty window 继承工作目录并归入当前 session。
- Session 可以从标准目录选择、另存并更新。
- 单个终端关闭保持确认，运行中的 tab 关闭受到保护。
- 配置可由 Kitty 0.47.4 无错误加载，并有可用备份。
