# 0001: 采用 Native Assets 与 C-ABI 构建 Dart/Rust 桥接层

使用 Dart Native Assets（`native_toolchain_rust`）搭配轻量级 C-ABI，而非 `flutter_rust_bridge` 或 Platform Channels。

## 状态 (Status)

已采纳 (Accepted)

## 背景 (Context)

`wreq` 是一个基于 Rust 的原生 HTTP 客户端，具备高保真 TLS/JA3/JA4 浏览器指纹模拟能力，底层依赖 BoringSSL。我们需要将 `wreq` 跨平台暴露给 Dart 和 Flutter（支持桌面端与移动端），同时保持极简的工程复杂度和零额外代码生成负担。

## 决策 (Decision)

我们采用官方 Dart/Flutter Native Assets 体系（`native_toolchain_rust` 与 `hook/build.dart`）配合精简的 `extern "C"` ABI。Dart 端通过 C-ABI 与 Rust 引擎交互；Rust 内部由 Tokio 工作线程池异步执行网络 I/O，并向 Dart 返回安全分配与释放的内存字符串。

## 影响 (Consequences)

- 本包作为纯 Dart 原生插件独立运行（同时支持无界面的 Dart CLI/服务端应用与 Flutter UI 应用），无强依赖 Flutter UI 框架的包袱。
- 开发者的开发流中无需引入额外的重量级代码生成器或外部工具（如 `flutter_rust_bridge_codegen`）。
- Dart 原生构建钩子（build hook）自动调用 `cargo` 并在各目标平台上编译和链接对应的动态库（cdylib）或静态库（staticlib）。
