# 02: 核心 GET 请求与异步 Tokio 后台网络执行

**What to build:** 在 Dart 端暴露异步 `wreqGet(String url)` API。调用时，通过 C-ABI 将目标 URL 传递到底层 Rust 客户端；Rust 内部利用常驻的后台 Tokio 运行时发起 Safari 26 浏览器模拟特性的 HTTP GET 请求，并将最终的响应状态码与响应体安全回传给 Dart；端到端通过 `flutter test` 验证对真实站点的连通性与内容正确性。

**Blocked by:** 01: 基础库版本查询与原生资产自动构建验证

**Status:** resolved

- [x] 提供 Dart 异步方法 `Future<WreqResponse> wreqGet(String url)`。
- [x] Rust 侧在独立后台工作线程（Tokio Multi-threaded Runtime）中执行网络 I/O，不阻塞调用方线程。
- [x] 请求携带真实的 Safari 26 浏览器指纹及 HTTP/2 传输特征。
- [x] 对可达的目标 URL 发起请求能成功拿到 200 状态码及非空的响应文本内容。

## 交付说明 (Resolution)

已在 `lib/wreq.dart` 与 `rust/src/lib.rs` 中完整实现 `wreqGet` 异步网络请求链条：
1. Dart 端通过 `Isolate.run` 调度底层 C-ABI 并在 `try-finally` 中完成指针内存回收。
2. Rust 端基于 `OnceLock` 维护常驻 Tokio 多线程异步运行时，以 Safari 26 浏览器指纹执行异步 GET 请求。
3. 在 `test/wreq_test.dart` 中成功完成对真实站点的端到端网络请求验证。
