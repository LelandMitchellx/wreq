# 06: Flutter 演示应用全链路交互与 UI 展现

**What to build:** 在 `example/` 目录中实现一个功能完备的 Flutter 演示界面。用户可在界面中输入目标网址、选择浏览器模拟类型、配置自定义 Header 并一键发起网络请求。界面以卡片和可滚动文本形式直观展示 HTTP 状态码、响应耗时（毫秒）、TLS 握手细节及响应正文内容，支持在真实设备或桌面环境中直接体验与调试。

**Blocked by:** 04: 请求参数定制与自定义请求头扩展, 05: 响应生命周期与确定性内存自动释放

**Status:** resolved

- [x] 演示应用具备 URL 输入框、配置面板及一键发送请求的操作按钮。
- [x] 请求成功时实时呈现 HTTP 状态码、响应正文以及请求耗时。
- [x] 请求失败时在 UI 弹窗或错误栏中优雅显示异常信息。
- [x] 运行 `flutter run` 在桌面宿主（Windows/macOS/Linux）上能流畅运行且界面交互无卡顿。
- [x] Android 交叉编译与真机设备适配：支持 `aarch64-linux-android` 等目标架构编译与 Native Assets 打包。
- [x] 解决 Android 平台 `libc++_shared.so` 运行时依赖缺失与 `HookConfig.code` 生命周期守卫问题。
- [x] 真实 Android 设备端到端运行验证：成功加载 `libwreq.so` 并完成真实 HTTP/2 TLS 指纹请求（200 OK）。

## 交付说明与修复记录 (Android 平台交叉编译与真机运行时修复)

### 1. 遇到问题与现象
- **构建期目标缺失**：`flutter build apk` 报错 `RustValidationException: The rust-toolchain.toml does not include the target aarch64-linux-android`。
- **CMake 工具链冲突**：`btls-sys`（BoringSSL）在多次 CMake 配置过程中 `CMAKE_SYSTEM_NAME` 丢失导致 Windows 平台符号冲突与配置失败。
- **Bindgen 头文件解析失败**：NDK clang 解析 `sys/cdefs.h` 时报错 `This file should only be allocated from C code`，原因系 target triple 未带 API 版本且缺少 `__ANDROID_API__` 宏定义与 sysroot include 路径。
- **资产构建守卫异常**：运行 Flutter 调试/分析阶段触发非代码资产构建时，`hook/build.dart` 抛出 `Bad state: HookConfig.code should only be accessed when building code assets`。
- **真机运行时加载失败**：APK 安装至真机（Android 17 / API 37, ARM64）启动时抛出：
  `dlopen failed: library "libc++_shared.so" not found: needed by .../libwreq.so`，导致无法解析 `wreq_version`。

### 2. 核心修复方案
1. **补齐 Rust 目标工具链**（`rust/rust-toolchain.toml`）：
   在 `targets` 列表中补齐 `aarch64-linux-android`、`armv7-linux-androideabi`、`x86_64-linux-android` 等架构。
2. **CMake Toolchain Wrapper 隔离**（`hook/build.dart`）：
   动态生成专用的 `android_toolchain_$abi.cmake` 包装器，固化 `CMAKE_SYSTEM_NAME Android`、`ANDROID_ABI` 及 `ANDROID_PLATFORM`，并传给 `CMAKE_TOOLCHAIN_FILE`，避免构建子阶段被重置。
3. **Bindgen 参数精细化注入**（`hook/build.dart`）：
   动态提取 NDK sysroot 路径，注入 `--sysroot=$sysroot -I$extraInclude --target=$targetTriple$apiLevel -D__ANDROID_API__=$apiLevel`，确保 bindgen 头文件宏条件完全满足。
4. **HookConfig 资产类型判断守卫**（`hook/build.dart`）：
   在访问 `input.config.code` 前，严格增加 `if (!input.config.buildCodeAssets) return;` 保护逻辑。
5. **自动捆绑 NDK C++ 运行时**（`hook/build.dart`）：
   定位 NDK `sysroot/usr/lib/$ndkArchDir/libc++_shared.so`，使用 `CodeAsset(..., name: 'libc++_shared.so', linkMode: DynamicLoadingBundled())` 将其自动打包至 APK 的 `jniLibs/` 对应 ABI 目录中。

### 3. 真机端到端验证结果
- **测试设备**：真实 Android 设备 `PLR110`（Android 17, API 37, arm64-v8a），通过 ADB 无线调试连接。
- **APK 结构校验**：`app-debug.apk` 与 `app-release.apk` 内均已包含 `lib/arm64-v8a/libwreq.so` 与 `lib/arm64-v8a/libc++_shared.so`。
- **运行时加载验证**：真机 UI 成功显示 `Native Core Version: wreq-0.16.3`。
- **全链路网络交互验证**：在真机界面点击 "Send Request" 请求 `https://pingly.us.kg/api/all`，成功返回 `Status: 200`（耗时 2248ms），正确展示 HTTP/2 帧事件、JA3/JA4 TLS 指纹和完整响应数据。
