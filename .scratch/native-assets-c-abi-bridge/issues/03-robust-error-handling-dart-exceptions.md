# 03: 健壮的 C-ABI 错误拦截与结构化 Dart 异常映射

**What to build:** 构建全链路防御性异常处理机制。当遇到非法 URL、DNS 解析失败、TLS 握手超时、证书无效或连接拒绝等故障时，Rust 端拦截所有潜在 panic 并序列化为结构化错误信封返回；Dart 端解析信封并抛出强类型的 `WreqException`，包含清晰的错误分类与原因描述，杜绝段错误或应用静默闪退。

**Blocked by:** 02: 核心 GET 请求与异步 Tokio 后台网络执行

**Status:** resolved

- [x] 传入畸形 URL（如 `invalid://host`）时，Dart 端抛出结构化的 `WreqException`。
- [x] 网络超时或目标主机不可达时，Rust 端安全截获错误并返回错误信封，不引发 panic 或原生进程中断。
- [x] Dart 端异常类提供可读的错误消息及状态码。
- [x] 针对各类网络故障场景补充端到端单元测试，确认异常可被常规 `try-catch` 捕获。

## 交付说明 (Resolution)

已在 `lib/wreq.dart` 与 `rust/src/lib.rs` 中落地结构化异常映射并完成端到端 TDD 闭环：
1. Rust 侧在 `wreq_get` 外层封装 `std::panic::catch_unwind`，防御性拦截所有网络与运行时 panic，转换为包含错误信息与状态码（-1）的 `CWreqResponse` 错误信封回传。
2. Dart 侧暴露公开强类型异常 `WreqException`（包含 `message` 与 `statusCode`），解析信封后抛出并保证底层内存正常释放。
3. 在 `test/wreq_test.dart` 中覆盖了畸形协议、不可达域名以及常规 `try-catch` 捕获用例，全部通过 `flutter test` 与 `dart analyze`。
