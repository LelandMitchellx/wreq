# 04: 请求参数定制与自定义请求头扩展

**What to build:** 扩展请求能力，支持在 Dart 端配置自定义请求头（Headers）、超时时间（Timeout）以及模拟的浏览器环境配置（Browser Profile）。配置参数通过结构化序列化协议越过 C-ABI 传递给底层 Rust 客户端并在 HTTP 请求中准确生效；通过端到端测试验证远程端点可正确接收自定义 Header。

**Blocked by:** 03: 健壮的 C-ABI 错误拦截与结构化 Dart 异常映射

**Status:** resolved

- [x] Dart 客户端支持传递可选的 `headers`（`Map<String, String>`）与 `timeout`（`Duration`）。
- [x] 自定义请求头通过 C-ABI 安全编解码并在发出的 HTTP 请求中如实体现。
- [x] 设置极短超时时间（如 1ms）时，能准确触发并捕获超时异常。
- [x] 编写测试断言回显接口（如 httpbin 或 mock 端点）成功回传了注入的自定义头部。

## 验证结论
- `rust/src/lib.rs` 新增 `wreq_request` 接口，借助 `serde` / `serde_json` 解析 `RequestEnvelope`，支持超时设置、浏览器 Profile 映射（Safari26、Chrome131、Firefox133）及 Header 注入。
- `lib/wreq.dart` `wreqGet` 暴露 `headers`、`timeout` 与 `emulation` 参数。
- `flutter test` 全部 8 项测试执行通过。
