# 01: 基础库版本查询与原生资产自动构建验证

**What to build:** 在 Dart 端暴露顶层 `getWreqVersion()` 函数，当 Dart 或 Flutter 运行时首次加载时，构建钩子（`hook/build.dart`）自动调用 Cargo 编译 Rust 动态库或静态库；Dart 通过 C-ABI 获取语义化版本字符串并安全释放底层 CString 内存；通过顶层自动化测试验证端到端构建与跨语言通信畅通。

**Blocked by:** None (可以立即开始)

**Status:** resolved

- [x] 运行 `flutter test` 时，自动完成 Rust `wreq` 动态资产的增量编译并顺利加载。
- [x] 调用 `getWreqVersion()` 能够返回非空且合法的语义化版本号字符串（如 `wreq-0.16.3`，匹配 SemVer 正则 `^wreq-\d+\.\d+\.\d+.*$`）。
- [x] C 侧分配的字符串指针通过 `wreq_free_str` 确定性释放，无裸指针泄漏。
- [x] 在 CI 或本地单测中调用该方法通过断言（测试用例位于 `test/wreq_test.dart`）。

## 交付说明 (Resolution)

已在 `lib/wreq.dart` 中接入 `getWreqVersion()` 并在 `test/wreq_test.dart` 编写了高保真测试。测试验证了：
1. 运行 `flutter test` 时原生构建钩子自动增量编译 Rust 动态库。
2. 跨语言获取版本字符串符合语义化规范（`wreq-0.16.3`）。
3. 连续 50 次请求下的内存生命周期安全与幂等性保障。
