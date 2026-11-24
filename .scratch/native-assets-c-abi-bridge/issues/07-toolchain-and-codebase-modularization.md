# 07: Android 交叉编译支持、双端代码模块化解耦与资产绑定优化

**What to build:**
1. 配置并修复 Android 目标工具链（`aarch64-linux-android`），确保在真机调试与打包场景下原生 `libwreq.so` 顺利编译并打入 APK，解决动态库加载失败问题。
2. 对 Dart 端代码进行模块化解耦，重构为标准 `lib/src/` 内部模块（`bindings.dart`, `client.dart`, `response.dart`, `exception.dart`, `profile.dart`），由根目录 `lib/wreq.dart` 统一重导出。
3. 优化 Native Assets 原生资产绑定策略（方案 C）：在 `hook/build.dart` 中将 `assetName` 精准绑定至 `src/bindings.dart`，免除在内部所有 `@Native` 注解上手动声明 `assetId`。
4. 对 Rust 核心库进行模块化解耦，拆分为 `abi.rs`、`runtime.rs`、`request.rs`、`emulation.rs` 及 C-ABI 顶级门面 `lib.rs`。
5. 精简 `EmulationProfile` 浏览器模拟指纹，仅保留主流最新版本（Chrome 149、Safari iOS 26.2、Firefox 151），并在 Rust、Dart、单元测试与示例应用中全链路对齐。

**Blocked by:** 06 (Flutter 交互式 UI 示例)

**Status:** resolved

- [x] 在 `rust-toolchain.toml` 中添加 `aarch64-linux-android` 支持，真机与 APK 构建时原生 `libwreq.so` 成功打包并加载。
- [x] Dart 代码解耦至 `lib/src/` 且无破坏性公共 API 变更，`dart analyze` 保持 0 issues。
- [x] 原生构建钩子配置方案 C 资产绑定，Dart FFI 运行时可自动解析符号寻址，代码干净简洁。
- [x] Rust 核心拆分为 5 个单一职责模块，`cargo check` 编译通过，0 警告 0 报错。
- [x] `EmulationProfile` 精简至 Chrome, Safari (iOS), Firefox，端到端测试 11/11 全数通过。

## 交付说明 (Resolution)

1. **Android 交叉编译与真机兼容**：
   - 完善 `rust-toolchain.toml` 目标架构支持；排查并解决 Android 动态库加载依赖路径，验证了构建输出与动态库打包。
2. **Dart 模块化与资产推导优化**：
   - 将原单文件 `lib/wreq.dart` 拆分至 `lib/src/`；更新 `hook/build.dart` 中 `assetName: 'src/bindings.dart'`，借助 Dart 默认推导规则免去冗余的 `assetId` 样板代码。
3. **Rust 模块化解耦**：
   - `abi.rs` 集中管理 C 结构体与内存释放；`runtime.rs` 提供全局 Tokio Runtime 单例；`request.rs` 处理异步请求管线；`emulation.rs` 解析模拟配置；`lib.rs` 保持纯粹的 extern "C" 门面与 panic 防护。
4. **指纹预设收敛**：
   - 保留 `chrome149`、`safariIos26_2`、`firefox151`，并在 `example` UI 与 `test/wreq_test.dart` 中同步更新并通过全量测试。
