# GitHub 原生库构建

工作流位于 `.github/workflows/native.yml`。
它独立构建 Lua 和 Script 原生库。
它不依赖 Flutter 或 `qfli_studio_core`。

## 构建范围

| 平台 | 架构 | 库格式 | 验证方式 |
| --- | --- | --- | --- |
| Windows | x86_64 | `.dll` | Lua 与 Script 主机测试 |
| Linux | x86_64 | `.so` | Lua 与 Script 主机测试 |
| macOS | arm64、x86_64 | `.dylib` | Lua 与 Script 主机测试 |
| Android | arm64-v8a、armeabi-v7a、x86_64 | `.so` | 交叉编译与库检查 |
| OHOS | arm64-v8a、x86_64 | `.so` | 交叉编译与库检查 |
| iOS | arm64 真机、arm64/x86_64 模拟器 | `.a`、XCFramework | 交叉编译与库检查 |

桌面测试会加载实际编译的库。
移动平台的编译成功不代表设备测试通过。
OHOS 使用 OpenHarmony API 18 的公开 SDK。
它不验证华为 HarmonyOS 的 HAP 打包。
Web 不使用这些原生库。

## 下载产物

1. 打开 GitHub 仓库。
2. 进入 **Actions**。
3. 选择原生库构建工作流。
4. 打开一次构建记录。
5. 在 **Artifacts** 区域下载产物。

下载时请登录 GitHub。
工作流保留产物 14 天。
过期后请重新触发构建。
工作流不会发布 GitHub Release。

| 下载名称 | 内容 |
| --- | --- |
| `native-linux-x86_64` | Linux 双库与主机测试报告 |
| `native-windows-x86_64` | Windows 双库与主机测试报告 |
| `native-macos-arm64` | ARM64 双库与主机测试报告 |
| `native-macos-x86_64` | Intel 双库与主机测试报告 |
| `native-android-arm64-v8a` | Android ARM64 双库与检查报告 |
| `native-android-armeabi-v7a` | Android ARM32 双库与检查报告 |
| `native-android-x86_64` | Android x64 双库与检查报告 |
| `native-ohos` | ARM64 与 x64 双库及检查报告 |
| `native-ios` | 真机与模拟器静态库、XCFramework |

产物包含两个原生库、头文件和许可证。
产物还包含源码版本、SHA-256 和验证报告。
每个架构目录包含 `manifest.json`。
`SHA256SUMS` 记录文件摘要。
`reports/` 保存构建和验证日志。
失败的任务可能只提供诊断报告。
请先检查构建结论。

这些库不是 APK、HAP、IPA 或桌面安装包。
它们也不包含 Flutter 引擎和应用资源。
下载库后，应用构建仍需匹配平台工具链。
现有应用构建仍会从源码编译 native 层。
本次改动不会自动切换应用的库加载方式。

## 本地空间

以下大小来自 2026 年 11 月 17 日的检查。
整个工作区约占 4.19 GiB。

| 目录 | 大小 | 内容 |
| --- | ---: | --- |
| `build/` | 2,420.97 MiB | 应用构建、安装包与审计报告 |
| `.dart_tool/` | 1,016.76 MiB | Dart 与 Flutter 缓存 |
| `ohos/entry/build/` | 548.05 MiB | OHOS 模块构建输出 |
| `ohos/build/` | 55.27 MiB | OHOS 构建输出 |
| `native/build/` | 13.28 MiB | 本地原生库与中间文件 |
| `android/.gradle/` | 6.97 MiB | 项目 Gradle 缓存 |

这些目录已列入 Git 忽略规则。
整个 `ohos/` 目录约占 802.90 MiB。
其中还包含依赖包和 Flutter 生成资源。
当前两个 Windows 库合计约 1.8 MiB。
本地空间主要用于应用构建和 Dart 缓存。

GitHub 构建使用云端磁盘。
它不会删除本地文件。
它也不会删除本机 SDK 或全局缓存。
下次在本地构建应用时，工具会重建缓存。

清理前请备份 `build/` 中的安装包和报告。
不要把所有构建输出都视为无用临时文件。
本次任务未删除本地缓存。
