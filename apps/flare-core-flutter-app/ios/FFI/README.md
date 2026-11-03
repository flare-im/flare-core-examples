# iOS Rust FFI（`flare_sdk_create` 等）

## 你遇到的错误

**Flutter / Xcode：`Internal Inconsistency` / `Build operation failed without specifying any errors`**：常见根因仍是 **未在 `ios/FFI/build/` 放置 `libflare_im_core_sdk_ffi.a`**（链接阶段失败，错误被 Xcode 吞掉）。Runner 工程已增加 **Verify Rust FFI staticlib** 构建阶段，会调用 `scripts/ensure_ios_ffi_staticlib.sh` 按当前 SDK 自动构建/验证静态库，缺库或平台不匹配时会直接 `exit 1` 并打印原因。

`dlsym(RTLD_DEFAULT, flare_sdk_create): symbol not found` 表示：**Dart 用 `DynamicLibrary.process()` 查符号，但主程序里没有链进 Rust 静态库**。  
仅写 Dart FFI 不够，必须把 `libflare_im_core_sdk_ffi.a` 链进 **Runner**，并用 **`-force_load`** 拉入全部目标文件（否则链接器会认为无人引用而把整库裁掉）。

## 本示例已做的集成

1. **Rust 静态库由独立脚本同步**：Xcode 和 `./scripts/setup_ios.sh` 都会调用 **`scripts/ensure_ios_ffi_staticlib.sh`**，直接构建 **`flare-im-core-sdk-ffi`** 并将 **`libflare_im_core_sdk_ffi.a`** 放到 **`ios/FFI/build/`**，不依赖 `xtask` 编译通过。
2. **`ios/Flutter/Debug.xcconfig` / `Release.xcconfig`**：  
   `-Wl,-force_load,$(SRCROOT)/FFI/build/libflare_im_core_sdk_ffi.a -lc++`

## 你需要准备的环境

- 安装 [Rust](https://rustup.rs)，并确保 `cargo` 在 PATH 中（Xcode 构建时也会用 PATH）。
- 首次构建前建议手动安装 target（脚本里也会 `rustup target add`）：
  ```bash
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
  ```
- 可先在本示例目录执行 **`./scripts/setup_ios.sh`**，它会完成 `flutter pub get`、Rust FFI 静态库同步和 `pod install`。

## 再试运行

```bash
cd flare-core-examples/apps/flare-core-flutter-app
./scripts/setup_ios.sh
flutter run -d "iPhone 17 Pro"
```

若链接仍报错（缺系统库等），把 Xcode **Report navigator** 里完整 **Link** 日志贴出再补 `-framework Security` 等依赖。

## `未生成静态库` / `aws-lc-sys` CMake 报错

`bindings/c` 属于 **workspace**，Rust 产物在 **`flare-core-sdk-engine/target/<triple>/release/`**；`scripts/ensure_ios_ffi_staticlib.sh` 从该目录拷贝或 `lipo` 到 Flutter 工程。

若 `cargo` 在编译 `aws-lc-sys` 时失败（CMake 提示缺少 `tool` 目录、`go_tests.txt` 等），多半是 **中途失败留下的损坏 CMake 缓存**。在仓库根下执行：

```bash
rm -rf flare-core-sdk-engine/target/aarch64-apple-ios-sim/release/build/aws-lc-sys-*
# Intel 模拟器则换 x86_64-apple-ios；真机换 aarch64-apple-ios
```

然后重新在 Xcode / `flutter run` 构建。仍失败时再执行 `cargo clean -p aws-lc-sys`（在 `flare-im-core-sdk` 目录）后重试。
