# XPastepal

原生 macOS 剪贴板管理器，使用 SwiftUI / AppKit 独立实现。通过本机 PastePal 2.19.6 的应用包分析理解功能，再实现可维护的代码。系统要求 macOS 14 或更新版本。

应用 Bundle ID：`milu.pastepal`。

## 构建与运行

```sh
./scripts/build.sh
open dist/XPastepal.app
```

安装到本机用户应用目录：`./scripts/install.sh`，随后打开 `~/Applications/XPastepal.app`。

直接使用 Swift Package 开发：

```sh
swift build
swift test
```

`Package.swift` 可在 Xcode 中打开。构建脚本生成独立 `.app` 并进行本机 ad-hoc 签名；跨机器发布还需 Developer ID 签名与公证。

## 使用

- 启动后自动记录新复制的文本、链接、图片、富文本和文件引用；不会导入其他应用的历史。
- 记录复制来源应用的名称和图标快照，在卡片、列表、详情和预览中显示；重启或来源应用卸载后仍保留图标。旧记录会尝试从本机应用补齐，无法找到时显示通用应用图标。
- 默认 `⌥⌘V` 呼出快捷面板。设置 → 快捷键可直接录制任意组合、清除、恢复默认；注册冲突会提示并可重试。旧版 `⌃⇧V` 偏好会自动迁移。
- 点击菜单栏图标打开快捷面板，右键可打开资料库、暂停记录、设置或退出。
- 呼出快捷面板会收起资料库和设置窗口，只显示面板；通过“打开资料库”重新显示主窗口。面板从当前停靠边滑入、反向滑出，换边时先退出旧边再进入新边；遵循系统“减少动态效果”。
- 快捷面板支持四边停靠、保持展开、集合与类型筛选；位置由停靠设置控制，不能随意拖动。上下停靠铺满屏幕可用宽度，左右停靠铺满可用高度，避开菜单栏和 Dock。方向键选择，`Return` 粘贴，`Shift+Return` 纯文本，`Tab` 切换搜索焦点，卡片焦点时空格预览，`⌘1–9` 粘贴对应条目，`⌘[` / `⌘]` 切换集合，`Esc` 关闭。
- 粘贴队列：10 秒内连续复制的多条内容自动按复制顺序排队，剪贴板始终放着队首；在其他应用每按一次 `⌘V` 粘贴下一条，全部粘完恢复正常，排队时菜单栏图标显示剩余数量。复制之间粘贴过、间隔超过 10 秒，或在快捷面板选择内容，都按普通复制处理；可在快捷面板横幅或菜单栏右键菜单结束队列，在设置 → 通用关闭。识别 `⌘V` 需要辅助功能权限，未授权时不排队。
- 资料库支持卡片/列表、搜索、类型/来源/集合筛选、详情开关、预览与编辑。`⌘` 点选和 `Shift` 范围多选，可批量复制文字、移组和删除；集合可重命名。
- 图片可手动离线识字（中文/英文），结果可编辑保存。文本支持去首尾空格、去空行、大小写和清理链接追踪参数，生成新记录并保留原记录。
- 支持 XPastepal JSON 备份导入导出；导入合并记录和集合，不覆盖已有记录。该格式不兼容 PastePal 的导出格式。
- 设置 → 备份与同步：默认每 6 小时在有更改时自动备份，支持手动备份和合并恢复，最多保留 30 份 / 512 MB。
- 可选 iCloud 多台 Mac 同步：使用自己的 CloudKit 私有库，支持离线合并、删除同步和失败重试。启用前需要具有 iCloud 权限的开发者签名；见 [配置说明](docs/iCloud-setup.md)。
- 自动粘贴权限使用 [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow) 引导；在设置中点击启用后，可按浮层引导将 XPastepal 拖入系统辅助功能列表。未启用时仍可复制，再自行按 `⌘V`。
- 默认保留最多 500 条普通历史；收藏不受自动数量和日期清理影响。图片/单条文本最大 25 MB。
- 文件记录保存原路径，原文件移动或删除后不会自动保留副本。图片文件在卡片中显示缩略图，也可展开预览。

所有历史保存在 `~/Library/Application Support/XPastepal/history.json`，本地快照位于同目录的 `Backups/`。iCloud 默认关闭；手动启用后同步文本、链接、图片、富文本、收藏和集合，文件路径及本机设置不参与同步。密码管理器及机密/临时剪贴板标记会被过滤；可在设置追加忽略的应用 Bundle ID。

## 项目结构

- `Sources/XPastepalCore`：内容模型、剪贴板采集、去重、分组及本地持久化。
- `Sources/XPastepal`：主资料库、快捷面板、菜单栏、全局快捷键和设置。
- `Tests/XPastepalCoreTests`：使用独立命名剪贴板和临时目录的核心测试，不操作真实剪贴板。
- `Tests/XPastepalTests`：隔离命名快捷键的迁移、持久化和真实注册冲突测试。
- `analysis/PastePal-功能对照.md`：本次对照证据、已实现行为与仍有差异的功能。
- `analysis/PastePal-静态分析.md`：目标应用的版本、架构、框架及功能证据。
- `analysis/rea`：REA 工具配置与反编译分析记录。

## 当前范围

此版本实现本机剪贴板管理、本地轮换备份和可选的多台 Mac iCloud 同步。未实现 iOS 客户端、附近分享、一次粘贴整个队列、自动 OCR 索引、JavaScript 转换、热边缘和系统快捷指令。采用独立的数据格式、图标和界面代码，不依赖原应用的账户或云容器。云端真实双机验证需要配置专用 CloudKit 容器与签名；默认 ad-hoc 构建仅提供本地功能。

第三方权限库使用固定版本 PermissionFlow 2.11.3，全局快捷键使用 KeyboardShortcuts 3.1.0；许可见 `THIRD_PARTY_NOTICES.md`。更新后如系统不再识别本机 ad-hoc 签名，请在权限列表中重新加入当前应用。

`open dist/XPastepal.app --args --demo` 会使用独立临时目录和命名剪贴板展示明确的演示内容，不采集系统剪贴板；正常使用请不加这个参数。`--background` 仅后台启动，不打开主窗口；`--quick-panel` 启动时直接显示快捷面板。

## Quick panel performance checks

The shortcut fires on key-down. The panel reuses a prewarmed hosting view and slides its
content through Core Animation, without moving the window on every frame. Card images
are downsampled off the main actor and cached. When a visible panel loses focus to
another app, a temporary Escape shortcut dismisses it, including in pinned mode; the
registration is released when the panel regains focus or closes.

Card selection runs on the first mouse release. A single tap handler uses the
native event's click count to activate on the second release, avoiding a wait
for a separate double-tap recognizer. The reference investigation is in
[PastePal selection dispatch](analysis/PastePal-selection.md).

Run `./scripts/check-click-interactions.sh` to check the actual card and list-row
views in a standalone AppKit event loop. It covers release-to-select, double-click,
drag cancellation, and the child copy button using in-process mouse events.
Reported latency measures the selection callback, not display presentation.

Run the opt-in Release profiling fixture with 200 records, including 4K images:

```sh
XPASTEPAL_PROFILE_PANEL=1 swift test -c release --filter PanelInteractionTests.profilePanelFrames
```

This reports animation submission time and checks that the animation performs no
per-frame window moves. It does not measure compositor FPS. The regular tests cover
all four edges, interrupted transitions, hosting-view reuse, thumbnail invalidation,
and Escape registration cleanup without sending keystrokes to other applications.

## Backup and synchronization behavior

The reference investigation is recorded in [PastePal backup and sync](analysis/PastePal-backup-sync.md).
PastePal's local Core Data and CloudKit integration are confirmed; an automatic rotating backup
policy is **not** confirmed. XPastepal implements its own JSON snapshots and CloudKit protocol.

- Automatic snapshots are enabled by default, taken on a save when the selected interval
  (1, 6, or 24 hours) has elapsed. Manual snapshots and snapshots before importing or
  applying remote changes share the 30-file / 512 MiB retention budget. Snapshots are local,
  owner-readable files containing clipboard content, not encrypted application archives.
- Recovery **merges** missing content. It preserves current edits, settings, device identity,
  and cloud consent. Deleted entries receive new UUIDs so other Macs can accept the recovery.
  A corrupt primary file is preserved as `history-corrupt-<UUID>.json` before recovery.
- Cloud sync is opt-in and runs while the app is open, approximately once per minute.
  A failed upload leaves the local changes on disk and retries with backoff. Each Mac must
  run a cloud-signed build using the same container and CloudKit environment.
- Stable IDs and persisted Lamport revisions resolve concurrent whole-record edits
  deterministically; equal counters use device UUID ordering. This is not a wall-clock
  "latest edit wins" rule or a per-field merge. Deletion always wins for an existing UUID,
  including automatic retention cleanup. Avoid inconsistent retention policies across Macs.
- Tombstones are retained to prevent long-offline Macs resurrecting deleted records.
  The current safety limit is 100,000 live/deleted sync records; tombstone compaction is
  not implemented. A full snapshot supports up to 20,000 items, 1,000 collections and
  160 MiB combined content; exceeding limits stops the operation with an error.
- File references remain on their originating Mac; no referenced file contents are copied.
  Backups, ignored-app rules, monitoring preferences and keyboard shortcuts do not sync.
  Turning sync off keeps both local and cloud data. After an iCloud account change, sync
  stops until explicitly disabled and re-enabled; re-enabling authorizes merging the
  current local library into the new account.
- Use JSON export/import to transfer archives manually. Do not clone the live data directory
  between running installations: it includes the sync device identity.

The synchronization tests use two isolated stores and an in-memory transport, covering offline
merges, deletion, restart, account changes, failed uploads, corrupt recovery and cancellation.
They do not substitute for the two-Mac CloudKit acceptance checks in the setup guide.

