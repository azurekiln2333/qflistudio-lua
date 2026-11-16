# GitHub 应用构建

`Full applications` 工作流构建完整应用。
所有平台使用 `lib/main.dart`。
`Native libraries` 工作流单独构建运行库。

## 构建产物

| Artifact | 内容 | 使用限制 |
| --- | --- | --- |
| `app-windows-x86_64` | 完整 Windows 目录压缩包 | EXE 未签名 |
| `app-linux-x86_64` | 完整 Linux bundle 压缩包 | 依赖系统 GTK3 |
| `app-macos-arm64` | ARM64 `.app` 压缩包 | 临时签名，未公证 |
| `app-macos-x86_64` | x64 `.app` 压缩包 | 临时签名，未公证 |
| `app-android-universal` | 三种 ABI 的 APK，以及 AAB | 使用测试签名 |
| `app-ios-arm64` | iPhoneOS `Runner.app` 压缩包 | 安装前必须签名 |
| `app-ohos-arm64-v8a` | ARM64 HAP | 安装前必须签名 |
| `app-web-browser` | 完整 Web 目录压缩包 | 支持编辑保存，禁用 native 运行 |

Android APK 覆盖 ARM64、ARMv7 和 x64。
桌面压缩包包含运行库、Flutter 引擎和资源。
请解压整个目录后启动应用。
Apple 压缩包保留文件权限与符号链接。
macOS 包通过深度签名检查后上传。
Web 目录需要通过 HTTP 服务访问。

每个 Artifact 包含以下内容：

- `packages/`：通过包检查的应用产物。
- `reports/`：构建日志、依赖锁文件和包检查报告。
- `manifest.json`：源码版本、工具链和验证状态。
- `licenses/`：项目及第三方许可证。
- `SHA256SUMS`：文件检查值。

构建失败时，Artifact 仅用于查看失败证据。
请先检查 `manifest.json` 的 `status`。
`passed` 表示构建与包检查通过。
该状态不代表设备启动或浏览器验收通过。
设备与浏览器测试状态单独记录。
`browser_tests` 记录源码级 Chrome 测试。
`release_bundle_browser_tests` 记录发布包测试。
源码测试通过不代表发布包验收通过。

## 下载位置

1. 打开 GitHub 仓库的 **Actions**。
2. 选择 **Full applications**。
3. 打开目标构建记录。
4. 在 **Artifacts** 区下载对应平台。
5. 解压 Artifact，再解压 `packages/` 内的应用包。

下载需要登录 GitHub。
工作流保留 Artifact 14 天。
过期后可重新运行工作流。
构建不会自动发布 GitHub Release。

## 固定构建输入

共享内核仓库：`azurekiln2333/qflistudio-core`。
固定提交：`573d1b6eecf1c2b392ad753264a5a09f62f8335e`。
CI 在应用目录旁检出该提交。
本地内核目录的未提交改动不参与云构建。

Flutter-OH 版本：`3.41.9+ohos-1.0.2`。
固定提交：`62357a93d653bf844f730bb1f4b7cc9e2139d14e`。
Dart 版本：`3.11.5`。
工具链的两个 Git 依赖也固定到提交。
实际解析结果保存在锁文件中。
CI 不使用本地修改过的 Flutter SDK。

OHOS 使用 API26 完整命令行工具包。
Flutter HAR 的自动填充接口要求 API26。
云端配置使用工具包内置的编译 SDK。
脚本删除云端配置中的 `compileSdkVersion`。
目标 API 保持为 24。
兼容 API 保持为 18。
工具包来自 `ErBWs/ohos-sdk` 的第三方镜像。
下载版本为 `26.0.0.821`。
脚本检查固定 SHA256 后解压。
脚本检查 SDK 元数据中的 API 版本。
该检查确认下载内容，不能证明上游来源。
CI 只在干净的云端检出中删除签名配置。
本地证书与密码不上传。

## 本地空间

云构建将 SDK、缓存和中间文件放在 runner。
只下载目标应用包即可减少本地构建需求。
已有本地缓存不会自动删除。
本地 `build/` 可能还包含可用安装包和报告。
删除前应确认其中内容。
