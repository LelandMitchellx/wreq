# 05: 响应生命周期与确定性内存自动释放

**What to build:** 完善原生内存管理体系，为大体积响应与高并发场景提供内存安全兜底。结合 Dart `NativeFinalizer` 与显式 `dispose()` 机制，建立双重保障：不仅在调用栈退出时主动清理 C 字符串，即便在 Dart 对象被 GC 回收时，也能自动调用 `wreq_free_str` 释放 Rust 分配的堆内存，杜绝内存泄漏。

**Blocked by:** 03: 健壮的 C-ABI 错误拦截与结构化 Dart 异常映射

**Status:** resolved

- [x] 为原生响应资源绑定 `NativeFinalizer`，在 Dart 对象被垃圾回收时自动触发原生内存清理。
- [x] 提供显式的资源清理通道，支持开发者主动回收大内存响应体。
- [x] 连续发起上百次请求的高压力测试下，进程内存占用保持平稳无单调递增泄漏。
- [x] 编写内存管理压力回归测试。

## 验证结论
- `WreqResponse` 实现 `Finalizable`，挂载 `NativeFinalizer(Native.addressOf<NativeFunction<Void Function(Pointer<CWreqResponse>)>>(_wreqFreeResponse).cast())`。
- 暴露显式 `dispose()` 方法，提供 `isDisposed` 属性，并在释放后防止二次释放与脏读取（抛出 `StateError`）。
- `flutter test` 全部 10 项测试全部绿灯通过。
