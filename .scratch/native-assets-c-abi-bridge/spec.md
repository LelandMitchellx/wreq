# 规格说明：基于 Native Assets 与 C-ABI 的 wreq Dart/Flutter 桥接方案

状态: ready-for-agent

## 问题陈述 (Problem Statement)

构建跨平台应用的 Dart 与 Flutter 开发者需要现代化、高保真的 HTTP 客户端能力——特别是 Rust `wreq` 库所提供的真实浏览器指纹模拟能力（例如 Safari 26 模拟、JA3/JA4 TLS 指纹匹配以及 HTTP/2 传输行为仿真）。

然而，以往在 Dart/Flutter 项目中集成 Rust 核心库面临着严峻的工程阻碍：
1. 开发者被迫依赖复杂的外部代码生成工具链（例如 `flutter_rust_bridge_codegen`），导致开发环境配置繁琐，极易发生构建断裂。
2. Flutter 平台通道（Platform Channels）在操作系统跨层传递时带来沉重的序列化开销，且强绑定 Flutter UI 框架，导致无法在无界面的 Dart CLI 命令行工具或服务端微服务中使用。
3. 在 Windows 平台上，MSVC 文件追踪器（FileTracker）对路径长度有 260 字符限制（FTK1011），编译嵌套较深的 BoringSSL 依赖库时频繁失败。
4. 开发者需要一种无摩擦的开箱体验：只需运行标准的 `flutter test` 或 `flutter run`，底层即可自动完成原生代码的增量编译、符号链接与跨平台分发。

## 解决方案 (Solution)

提供一个统一独立的 Dart 插件包，利用 Dart/Flutter 官方的 Native Assets 构建机制（通过 `hook/build.dart` 与 `native_toolchain_rust`），结合精简且零抽象损耗的 C-ABI 暴露 Rust 核心功能。

核心方案特性：
- 终端开发者零心智负担：只要开发机配置了标准的 Rust 工具链，运行常规 Dart 或 Flutter 命令时会自动触发原生资产编译，并将编译产物无缝打包进最终产物中。
- 高内聚、符合 Dart 习惯的面向对象顶层 API：封装全部底层 FFI 指针交互、结构体解包及错误映射，只向外暴露纯粹强类型的 Dart 异步方法。
- Rust 内部常驻多线程 Tokio 异步运行时：保障网络 I/O 与耗时的 TLS 握手在后台工作线程并发处理，绝对不卡顿 Dart UI 主事件循环。
- 确定性内存生命周期回收机制：所有由 Rust 端分配的字符串与内存指针均由 Rust 分配器管理，并在 Dart 侧读取完毕后通过绑定的析构函数（`wreq_free_str`）确定性地交还释放，杜绝内存泄漏。

## 用户故事 (User Stories)

1. 作为一个 Flutter 开发者，我想要从 Dart 端直接调用带目标 URL 的 `wreqGet`，以便于无需编写任何原生平台代码即可发起高保真 Safari 浏览器仿真的网络请求。
2. 作为一个 Flutter 开发者，我想要在执行 `flutter run` 或 `flutter test` 时由构建钩子自动编译 Rust 库，以便于不必手动执行 `cargo build` 或手动拷贝 `.dll`/`.so`/`.dylib` 文件。
3. 作为一个 Dart 服务端或 CLI 命令行开发者，我想要直接引用 `package:wreq` 而无需引入庞大的 Flutter 引擎，以便于在纯命令行工具中也能使用完整的 TLS 指纹模拟。
4. 作为一个移动应用开发者，我想要 Rust 层分配的响应体内容在 Dart 端使用完后安全回收，以便于长时间运行的应用不会发生内存泄漏。
5. 作为一个业务开发者，我想要无效的 URL、DNS 解析失败或网络握手超时等底层错误被捕获并转化为清晰的 Dart 异常，以便于可以在应用界面上优雅地向用户展示错误提示。
6. 作为一个工程开发者，我想要能够在 Dart 中查询底层 `wreq` 的版本字符串，以便于在运行时验证原生资产绑定是否正常并检查版本兼容性。
7. 作为一个 Windows 平台开发者，我想要构建钩子在 Windows 上自动配置 Ninja 生成器，以便于规避 MSVC 260 字符路径限制并确保 BoringSSL 顺利编译完成。
8. 作为一个客户端架构师，我想要 Rust 网络 I/O 在后台独立的 Tokio 线程池执行，以便于 Dart UI 主线程帧率不受网络波动影响。
9. 作为一个自动化测试工程师，我想要使用标准的 `flutter test` 运行全部单元测试与集成测试，以便于 CI/CD 持续集成流水线无需维护专用的原生集成脚手架。
10. 作为一个跨平台开发者，我想要构建钩子在 macOS、Linux 和 Windows 上产出适配当前宿主架构的动态或静态产物，以便于跨操作系统开箱即用。
11. 作为一个安全运维工程师，我想要底层的 TLS 引擎内置标准 Web PKI 证书包，以便于 HTTPS 请求能在各受限环境下稳定安全验证，不依赖宿主机不完整的证书链。
12. 作为一个质量工程师，我想要 C-ABI 边界处具备防御性空指针校验与格式校验，以便于非法入参不会引发原生段错误（Segmentation Fault）导致应用崩溃。
13. 作为一个开源社区贡献者，我想要克隆仓库后无需运行额外的代码生成脚本即可直接运行测试，以便于能够以最低摩擦参与代码贡献。
14. 作为一个 UI 开发者，我想要仓库内置一个示例 Flutter 应用程序，以便于直观地在真机或模拟器屏幕上观察实际网络请求与返回数据。
15. 作为一个合规与反爬工程师，我想要客户端发出的 HTTP/2 帧顺序与 TLS ClientHello 特征与主流浏览器一致，以便于业务请求不会被风控防火墙误判为自动化脚本。
16. 作为一个 Android 平台开发者，我想要在 Android 真机或模拟器上开箱即用运行 wreq 网络请求，以便于直接构建包含原生 TLS 指纹特性的移动应用。

## 实现决策 (Implementation Decisions)

- **Dart 原生资产构建集成 (Native Assets Integration)**：构建流程完全依托 `hook/build.dart` 与 `native_toolchain_rust`。该钩子负责定位 Rust 清单文件、调度 Cargo 编译，并将生成的动态库资产标识注入 Dart 构建图。
- **极简 C-ABI 接缝 (Minimal C-ABI Seam)**：Dart 与 Rust 之间通过标准的 `extern "C"` 边界进行解耦。摒弃重型代码生成器，以换取极简的依赖树、秒级编译体验与清晰的跨语言调试视野。
- **确定性内存释放模型 (Deterministic Memory Reclamation)**：Rust 侧分配的 C 风格字符串统一通过 `CString::into_raw` 移交裸指针；Dart 端在包装层中将其转为 Dart 字符串后，立即在 `try-finally` 块中调用配套的 `wreq_free_str`，实现零泄漏的双向安全。
- **常驻异步运行时 (Embedded Asynchronous Runtime)**：Rust 侧通过 `OnceLock` 惰性初始化多线程 Tokio 运行时，网络请求派发至内部线程池并发处理，Dart 端通过非阻塞等待获取结果。
- **编译工具链自适应 (Build Toolchain Adaptation)**：针对 Windows 环境，构建钩子在 Cargo 进程环境中注入 `CMAKE_GENERATOR=Ninja`，避免 MSVC FileTracker 路径过长错误（FTK1011）。
- **纯 Dart 高层门面 (High-level Dart Facade)**：包的对外公开接口只暴露符合 Dart 习惯的强类型对象，内部隐藏所有 `Pointer` 运算、动态库寻址及 Native Assets 底层细节。
- **双端模块化分层解耦架构 (Dual-End Modular Architecture)**：Dart 端解耦至 `lib/src/` 内部模块，由 `lib/wreq.dart` 统一门面导出；Rust 核心解耦至 `abi.rs`、`runtime.rs`、`request.rs`、`emulation.rs` 及顶级 C-ABI `lib.rs`。
- **Native Assets 内部模块资产绑定 (Internal Asset Binding via Option C)**：`hook/build.dart` 将 `RustBuilder` 的 `assetName` 绑定为 `'src/bindings.dart'`，借助 Dart 默认推导机制免去在各 `@Native` 声明中手工硬编码 `assetId`。
- **主流高保真指纹环境收敛 (Mainstream Browser Emulation Focus)**：精简 `EmulationProfile` 预设，专注提供 Chrome 149、Safari iOS 26.2 与 Firefox 151 主流环境。
- **Android 工具链与真机支持 (Android Toolchain & Real Device Compatibility)**：`rust-toolchain.toml` 增加 `aarch64-linux-android` 目标，确保 NDK 交叉编译与 Android APK 动态库打包无缝协作。

## 测试决策 (Testing Decisions)

- **单一最高测试接缝原则 (Single Highest Test Seam)**：严格遵从项目的测试准则，所有测试均针对公开的最顶层 Dart API（`package:wreq/wreq.dart`）展开。不单独针对私有内部 C 符号或底层指针转换编写脆弱的白盒单元测试。
- **黑盒外部行为验证 (External Behavior Verification)**：测试只断言外部可观测行为，例如断言版本获取返回合法的语义化版本字符串、网络 GET 请求返回有效响应正文与状态码，实现细节的内部重构不导致测试破坏。
- **测试覆盖模块 (Target Modules)**：覆盖顶层 Dart 门面及其通过原生资产加载器、动态库分发到底层 Rust 编译产物的完整端到端调用链。
- **现有测试依据 (Prior Art)**：在 `test/wreq_test.dart` 中已建立端到端验证，直接使用 `flutter test` 验证 `getWreqVersion()` 以及对真实 HTTPS 站点的 `wreqGet()`。

## 不在范围内 (Out of Scope)

- 基于 Dart Streams 或 NativePorts 的流式请求体与流式响应体传输（规划为后续里程碑特性）。
- 全双工 WebSocket 协议连接管理。
- 自定义 CA 根证书导入与 mTLS 双向客户端证书认证。
- 磁盘持久化 Cookie 存储（当前范围内仅维护内存级 Cookie）。
- 针对不支持 Native Assets 的远古版本 Dart/Flutter SDK 的 MethodChannel 降级回退方案。

## 进一步说明 (Further Notes)

- 本规格说明直接对齐架构决策记录 ADR-0001（`docs/adr/0001-native-assets-c-abi-bridge.md`）。
- 要求 Dart SDK 3.5+ 以及 Flutter 3.24+，且需开启 Native Assets 特性支持。
