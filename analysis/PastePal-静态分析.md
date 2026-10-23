# PastePal 本机应用包静态分析

分析日期：2026-10-14（Asia/Taipei）。分析对象为本机 `/Applications/PastePal.app`。本报告仅依据应用包内的二进制、清单、权限和资源元信息；未读取剪贴板历史、账户数据或应用容器，未修改应用包。

## 已确认信息

| 项目 | 结果 |
| --- | --- |
| 名称 | PastePal |
| 版本 | 2.19.6（214） |
| Bundle ID | `com.onmyway133.PastePal` |
| 主程序 | `/Applications/PastePal.app/Contents/MacOS/PastePal` |
| 架构 | Universal Mach-O：`x86_64`、`arm64` |
| 主程序大小 | 28,436,496 字节 |
| 最低系统 | macOS 12.0 |
| 构建环境 | Xcode 26.2 / macOS SDK 26.2 |
| 应用模式 | `LSUIElement = true`，菜单栏常驻应用 |
| URL Scheme | `pastepal` |
| 签名来源 | Apple Mac OS Application Signing；Team ID `T78DK947F2` |
| 签名验证 | `codesign --verify --deep --strict` 成功 |
| SHA-256 | `ecc6c102b1b66b89ce70e649e682fd2c0c0041207281b4c047faaf4b8771e547` |

当前工作区及其祖先目录没有额外 `AGENTS.md` 文件。本次依据聊天中提供的全局指令执行。

## 静态分析与反汇编可行性

- 两个架构的加载命令均未发现 `LC_ENCRYPTION_INFO` 或 `LC_ENCRYPTION_INFO_64`；无需解密即可读取当前二进制的机器指令。
- 已用系统 `otool -arch arm64 -tv` 成功解码 `__TEXT,__text` 中的 ARM64 指令，确认可以直接反汇编。
- ARM64 符号表有 3,911 项，其中只有 1 项为已定义符号，其余主要是外部导入；3,210 项含 Swift 名称编码。发布构建已移除大部分内部符号，反编译不能恢复原始 Swift 源码、变量名和源文件结构。
- 可在反编译器中直接分析主程序。对于 Swift/SwiftUI，伪代码适合辅助辨认系统 API 调用与数据流，不宜视作可维护源码。
- XPastepal 采用独立实现，参考本报告的功能与交互需求；不将原应用机器码、反编译伪代码、图标、音效或字符串整包搬入新应用。

## 技术组成

系统依赖包含 AppKit、SwiftUI、Combine、Carbon、CoreData、CloudKit、StoreKit、Vision、LinkPresentation、PDFKit、QuickLookUI、QuickLookThumbnailing、MultipeerConnectivity、JavaScriptCore、ServiceManagement 和 sqlite3。

这些依赖表明应用使用原生 macOS 技术。CoreData 编译模型 `PastePal2.momd` 是明确的本地存储结构证据；CloudKit/iCloud 容器权限表明存在云同步能力。Vision、JavaScriptCore、MultipeerConnectivity 的具体用途由下述功能文案佐证，但未审计其全部实现。

包内存在以下组件资源 bundle，通常来自 Swift Package Manager；仅凭资源目录无法保证其精确版本：

- `KeyboardShortcuts`
- `Kingfisher`
- `CloudKitSyncMonitor`
- `RevenueCat`
- `ReuseAcross`

## 权限和系统集成

- App Sandbox 已开启。
- 允许用户主动选择的文件读写和应用作用域书签。
- 允许网络客户端访问。
- 声明 CloudKit、CloudDocuments、推送与专属 iCloud 容器。
- 辅助功能用途为向先前激活的应用发送粘贴快捷键。
- Bonjour 声明 `_pastepal._tcp` 与 `_pastepal._udp`，本地网络说明对应点对点分享。
- 声明 JIT 与关闭库验证权限；这与脚本转换功能相符，但不是实现所必需的通用配置，新应用无需默认复制。

## 从资源确认的产品能力

英文和中文等本地化资源存在；顶层有 37 个本地化目录。以下是对功能文案的归纳，不代表所有功能均在当前机器上启用或已完成动态验证。

| 功能 | 包内证据 | XPastepal 实现优先级 |
| --- | --- | --- |
| 剪贴板记录 | 监听开关、历史保留期、历史清空设置 | 首版 |
| 类型识别 | 文字、图片、链接、文件、多文件等文案 | 首版 |
| 来源应用 | 按应用过滤、允许或忽略应用列表 | 首版 |
| 搜索 | 内容搜索、大小写开关、类型/日期/集合等查询 | 首版基础搜索 |
| 集合整理 | 新建集合、名称与图标、条目归档 | 首版 |
| 菜单栏和快捷面板 | 上下左右侧边面板、全局快捷键、键盘导航 | 首版菜单栏与快捷面板 |
| 复制与粘贴 | 原样复制、纯文本复制、双击操作、Cmd+V 发送 | 首版 |
| 隐私控制 | 暂停监听、敏感/临时数据过滤、忽略词语和类型 | 首版基础保护 |
| 本地持久化 | CoreData 编译模型 | 首版，独立数据格式 |
| 队列粘贴 | 顺序粘贴、一次粘贴全部 | 后续 |
| 文本转换 | 大小写、去空行、去多余空格、脚本 | 后续 |
| OCR | 图片识别、截图提取文字 | 后续 |
| 链接预览 | 新链接预览抓取、移除跟踪参数 | 后续 |
| 数据保留 | 自动清理旧条目、集合/命名条目保留 | 首版有限数量保留 |
| 跨设备同步 | iCloud 配置、同步状态 | 后续，需要自己的容器 |
| 附近分享 | Peer Share、Bonjour、MultipeerConnectivity | 后续 |
| 系统快捷指令 | 包内 App Intents 描述 | 后续 |

App Intents 元数据包含：`AddItemIntent`、`ClearClipboardIntent`、`GetItemIntent`、`OpenAppIntent`、`TransformIntent`。这些名称是集成入口的证据，不包含实现代码。

## 首版建议

用 AppKit 和 SwiftUI 构建独立菜单栏应用，监听系统剪贴板变化，记录文字、链接、图片和文件引用，附带来源应用与时间。提供全局快捷键唤起、搜索、类型筛选、收藏或集合、详情预览、复制与纯文本复制、删除和暂停监听。数据保存到 XPastepal 自己的 Application Support 目录；采用数量上限与敏感类型过滤，避免无限增长。

直接粘贴在用户主动授权辅助功能后启用；未授权时保留复制功能。首版不依赖原应用的 iCloud 容器、账户或历史数据，也不需要从原应用迁移任何资源。

## 可复现的只读命令

```sh
plutil -p /Applications/PastePal.app/Contents/Info.plist
file /Applications/PastePal.app/Contents/MacOS/PastePal
otool -L /Applications/PastePal.app/Contents/MacOS/PastePal
otool -l /Applications/PastePal.app/Contents/MacOS/PastePal
otool -arch arm64 -tv /Applications/PastePal.app/Contents/MacOS/PastePal
nm -arch arm64 /Applications/PastePal.app/Contents/MacOS/PastePal
codesign -dv --verbose=4 /Applications/PastePal.app
codesign -d --entitlements :- /Applications/PastePal.app
codesign --verify --deep --strict /Applications/PastePal.app
shasum -a 256 /Applications/PastePal.app/Contents/MacOS/PastePal
```

本报告保存元信息摘要，不保存反汇编代码或专有素材。
