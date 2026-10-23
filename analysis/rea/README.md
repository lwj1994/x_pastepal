# REA 本机安装与 PastePal 原生分析

分析日期：2026-10-14。目标仅为 `/Applications/PastePal.app` 的发布包；未读取剪贴板历史数据库。

## 已安装

| 组件 | 版本 | 路径 |
| --- | --- | --- |
| REA | 6.4.0 | `/Users/luwenjie/.local/share/mise/installs/node/26.0.0/bin/rea` |
| Ghidra | 12.1.4 | `/opt/homebrew/opt/ghidra/libexec` |
| OpenJDK | 21.0.12.1 | `/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` |
| REA skill | 37，170 工具 | `/Users/luwenjie/.agents/skills/reverse-engineer-anything` |

官方来源：[morluto/rea](https://github.com/morluto/rea)。REA 使用官方 npm registry 安装，Ghidra 与 OpenJDK 使用 Homebrew formula 安装。

Codex 的 REA MCP 已写入 `~/.codex/config.toml`，仅新增 REA 条目。首次备份为 `~/.codex/config.toml.rea.backup`；补充独立 PATH 前的备份为 `~/.codex/config.toml.rea-before-path-fix.backup`。程序对比确认其余 TOML 配置语义与首次备份相同。重新启动 Codex 后可在新会话发现 REA 工具；本次分析通过同一 REA MCP 标准协议直接连接。

`doctor-ready.json` 的 Codex、Ghidra、skill 三项定向检查整体 `healthy: true`。`mcp-initialize.json` 与 `mcp-tools.json` 记录成功初始化和 170 个可发现工具。Homebrew 的 fontconfig/glib postinstall 仍返回警告；Ghidra/Java 原生平台和反编译器检查已通过，不能把这些额外警告误写为 Ghidra 未安装。

## 命令行复现

```sh
cd /Users/luwenjie/Documents/GitHub/x_pastepal
. ./analysis/rea/env.sh
rea doctor --client codex --provider ghidra --skill --json
node analysis/rea/session.mjs
```

`env.sh` 仅设置当前 shell 的 REA 环境，避免机器现有 mise Java 17 设置覆盖 Ghidra 所需 Java 21；不改变其他项目的 Java 版本。`session.mjs` 接受一行一个 JSON 工具调用，并将完整结果保存到本目录。以下是本次实际成功的核心调用，首次原生查询会等待 Ghidra 自动分析：

```json
{"name":"open_binary","arguments":{"path":"/Users/luwenjie/.rea/targets/pastepal-ecc6c102/PastePal.arm64","provider_id":"ghidra"},"save":"open-arm64"}
{"name":"search_procedures","arguments":{"pattern":"paste|clip|duplicate|search|changeCount","mode":"regex"},"save":"procedures-search"}
{"name":"procedure_pseudo_code","arguments":{"procedure":"0x100134364"},"save":"rea-clipboard-changeCount"}
{"name":"close_binary","arguments":{"snapshot_path":"/Users/luwenjie/Documents/GitHub/x_pastepal/analysis/rea/pastepal-snapshot.json","overwrite":true},"save":"close-binary"}
{"exit":true}
```

## 原始文件与切片

- 原始可执行文件：`/Applications/PastePal.app/Contents/MacOS/PastePal`。
- 原始 SHA-256：`ecc6c102b1b66b89ce70e649e682fd2c0c0041207281b4c047faaf4b8771e547`。
- REA `inspect_macho`：`macho.json`；证据 ID `ev_e8520b0ce545592ed3607df12023ba9c6e110cea4c142615001c2a20392f3589`。
- Universal 文件包含 x86_64 与 arm64；所分析 arm64 的最低系统版本为 macOS 12.0、构建 SDK 为 26.2。
- Ghidra 当前适配器无法保证 Universal Mach-O 架构选择，首次拒绝保存在 `open-binary.json`。使用 Apple `lipo -thin arm64` 只读提取到 `~/.rea/targets/pastepal-ecc6c102/PastePal.arm64`，切片哈希见 `arm64-sha256.txt`。未修改原始应用。
- 二进制切片留在本机 REA 数据目录，不是 XPastepal 源码或分发资源。

## 分析范围与限制

原生分析返回机器码派生的伪代码，不是原作者 Swift 源码。符号已大幅剥离；函数名、字符串与静态引用需要组合解读，不能单凭文本存在推断完整运行行为。

默认自动分析在 `Objective-C Message Analyzer` 中出现 `ArrayIndexOutOfBoundsException`，日志保存在 `ghidra-default-analysis.log` 和 `ghidra-npm-6.4-analysis.log`。官方仓库 main 文档描述的 `REA_GHIDRA_DISABLED_ANALYZERS` 尚未进入本次 npm 6.4.0：尝试设置后实际结果的 `analyzer_preset` 仍是 `ghidra-default`，不能声称成功跳过。第二次 REA 查询最终在约 394 秒后完成自动分析，随后反编译已定位函数成功；这些分析器错误仍限制整体覆盖，不表示目标应用运行时存在同样异常。

## 已完成的真实反编译

1. **REA MCP + Ghidra 默认分析**：成功执行 `procedure_pseudo_code`，目标 `0x100134364`。原始响应是 `rea-clipboard-changeCount.json`，规范化证据是 `rea-clipboard-evidence.json`，可直接阅读的输出是 `rea-clipboard-changeCount.c`。证据 ID：`ev_3b4b3cc59df36e81a4bf05dbe4c5d6f2d2af4ff8095319e71de5ff82bedc56cd`。`close-binary.json` 确认会话关闭并写入 `pastepal-snapshot.json`（2 条证据记录）。
2. **直接 Ghidra 定向后备方案**：使用 `-noanalysis -readOnly -deleteProject`，仅对已定位的 8 个函数执行反汇编和反编译，全部完成。可复现命令为 `sh analysis/rea/run-targeted.sh`；脚本主体是 `TargetedDecompile.java`，日志为 `targeted-headless.log`，伪代码在 `targeted-pseudocode/`。这一组结果来自直接调用 Ghidra，不能归为 REA MCP 调用。

| 地址 | 定位依据 | 结论与边界 |
| --- | --- | --- |
| `0x100134364` | `changeCount` selector → 交叉引用指令 → `LC_FUNCTION_STARTS` | 读取剪贴板变化计数，与缓存计数比较；首次缓存为 -1 时仅更新并返回；相同时返回；变化后读取 `pasteboardItems` 并进入检查与处理分支 |
| `0x10013f3d8`、`0x10013f900`、`0x10013fd5c` | 上述采集函数的直接调用 | 存在多个布尔检查和条目筛选分支；未恢复所有设置字段含义，因此不把它们完整等同于某项隐私规则或去重算法 |
| `0x1001af3a8`、`0x1001af49c` | `ClipboardItem.PasteboardItem.DataProvider` 的 Objective-C 方法元数据 | 前者构造包含数据类型、自身和条目的任务上下文并交给后续函数；后者返回空操作。属于剪贴板数据提供回调附近代码 |
| `0x1001ae8ac`、`0x1001ae8e8` | `ClipboardItem.PasteboardItem` 的 Objective-C 方法元数据 | 分别调用父类 `init` 和 `initWithPasteboardPropertyList:ofType:` |

`clipboard-objc-metadata.txt` 另确认 `ClipboardChecker` 的 `lastChangeCount`、`recentDetections` 字段，以及 `ClipboardManager` 的 `pasteboard`、`checker`、`ruleChecker`、`queue`、`preferredFolder` 和 `timer` 字段。结合采集函数偏移可推断上述计数属于 `ClipboardChecker.lastChangeCount`；字段名本身不证明完整去重实现。

定位原始证据保存在 `targeted-addresses.json`、`changeCount-assembly.txt`。这次已验证**变化检测和非空条目分支**，对**内容去重、搜索排序、所有隐私过滤规则**仍未形成完整代码级结论；XPastepal 的实现选择应单独说明。未启动或注入 PastePal 进程，未检查用户历史内容，未处理应用授权逻辑。
