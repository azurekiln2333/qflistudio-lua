# Lua 离线门控与 OHOS/Android 发布构建准备审计

- **任务**: `10-15-lua-store-readiness`（planning）
- **审计者**: pi worker C（离线门控 + 发布构建准备）
- **工作目录**: `D:/MyNewProjects/qfli_lua`（已确认，未串其他语言项目）
- **共享核心**: `D:/MyNewProjects/qfli_studio_core`
- **模式**: 只读审计、非破坏性环境检查。**未修改产品/配置**，未 `build clean`，未安装设备，未 `task.py start`，未提交。
- **说明**: 工作区有他人未提交改动，本报告不触碰、不回滚任何既有变更。
- **修订（第 2 版）**: 据主代理协调意见下调过度结论。**已确证的联网门控缺陷仅 G1、G2**；原 G3–G8 降级为观察/环境项（N3–N8），不再预设为缺陷：
  - OHPM ignored 生成锁文件引用项目外 SDK/Pub Cache 属 ohpm 正常机制，仅 NUL/缺文件/真实构建错误才算缺陷（N5）；
  - 缺 `hvigorw` 不自动是发布阻塞，`flutter build hap` 为官方入口（N8）；
  - 缺签名材料记为环境阻塞，**不推断必产 unsigned**，实际可能直接构建失败（N4）；
  - OHOS INTERNET 可能支持 loopback 预览，**未验证前不删除**（N3）；
  - Android debug 签名 release 可用于本次验证，但不可宣称商店签名完备（N6）。

---

## 0. 结论摘要（TL;DR）

| 编号 | 结论 | 严重度 |
| --- | --- | --- |
| 编号 | 结论 | 严重度 |
| --- | --- | --- |
| G1 | 离线档位下，编辑器菜单的 **`git`** 与 **`cloud_pull`** 入口未被 `offlineOnly` 门控；GitPage 暴露“推送/拉取/远程仓库”联网动作 | 高（联网漏门控，**已确证缺陷**） |
| G2 | 离线档位下，Profile → 设置 页的 **“AI 助手 / 个人 AI 接口”** 仍可见（`SettingsPage.showAi` 默认 `true`，ProfilePage 未传参）；编辑器侧已正确置 false | 中（联网漏门控，**已确证缺陷**） |
| N3 | OHOS 声明 `ohos.permission.INTERNET`，Android release 未声明。**不是缺陷**：可能用于 loopback 预览等，未验证前不应删除，仅记录平台差异 | 观察项（待验证） |
| N4 | `ohos/build-profile.json5` 被 git 跟踪且含签名口令密文；引用的 `.cer/.p7b/.p12` 在当前机器上不存在 | 观察项（**环境阻塞**；须实测失败形态，不得断言必产 unsigned）；口令入库为待评估泄露面 |
| N5 | `ohos/entry/oh-package-lock.json5`（**ignored 生成文件**）引用项目外 SDK/Pub Cache → 属 ohpm 正常机制，非自动故障 | 观察项（仅 NUL/缺文件/真实构建错误才算缺陷） |
| N6 | Android release 使用 debug 签名，**可用于本次设备/功能验证**，但非商店就绪 | 观察项（不阻塞本轮验证） |
| N7 | 现有 release APK / HAP 产物早于当前未提交改动，不能作为当前源码的通过证据 | 中（证据有效性） |
| N8 | 项目未纳入 `hvigorw` 包装器；OHOS 构建可走官方工具链入口（`flutter build hap` / DevEco） | 观察项（非自动发布阻塞） |

**门控总体评价**：共享核心对离线档位的门控**覆盖面广且大多正确**（首页云项目页签、在线终端、AI 入口、社区、登录、签到积分、后台管理页、`settings.showAi` 编辑器侧）。**已确证的漏门控仅 G1、G2 两处**。其余 N3–N8 为观察/环境项，需实测或按各平台机制判断，不预设为缺陷。

---

## 1. 审计范围与方法

- 只读追踪 `lib/main.dart` 中 `luaProfile.isOffline == true`（经 `StudioProfile.offlineOnly` 默认继承）到 `../qfli_studio_core` 的联网动作：Git、云终端、登录、云项目、AI、社区。
- 检查 Android/OHOS manifest、权限、签名、本地 SDK/JBR/NDK、ohpm 锁文件与构建命令。
- 只读设备状态：`adb devices`、`hdc list targets`。
- 阅读 PRD、`frontend/native-startup.md`、`backend/lua-toolchain.md`，以及既有原生/OHPM 任务。

---

## 2. 离线档位定义链

`qfli_lua/lib/main.dart:24-52`

```dart
const StudioProfile luaProfile = StudioProfile(
  id: 'lua',
  isOffline: true,          // main.dart:34
  productKey: StudioProductCatalog.scriptKey,
  runtimeKind: 'lua-5.4-native',
  ...
);
...
StudioProfile.current = luaProfile;  // main.dart:65（runApp 之前定档）
```

`qfli_studio_core/lib/services/studio_profile.dart:104-111`

```dart
this.isOffline = false,
bool? offlineOnly,
...
}) : offlineOnly = offlineOnly ?? isOffline;   // 未显式传参时继承 isOffline
```

→ Lua 档位下 `isOffline == true` 且 **`offlineOnly == true`**。全部门控应依据 **`offlineOnly`**（`isOffline` 额外负责教程/示例切本地变体）。

共享核心中 `offlineOnly/isOffline` 全部引用点（只读）：

| 文件 | 行 | 动作 |
| --- | --- | --- |
| `editor/editor_page.dart` | 203 | 云项目 CloudSync 初始化前判 `offlineOnly`（✔ 正确） |
| `editor/editor_page.dart` | 1000-1001 | `.sql` 云 MySQL 云执行前判 `offlineOnly`（✔） |
| `editor/editor_page.dart` | 1092 | hint 后转在线运行前判 `offlineOnly`（✔） |
| `editor/editor_page.dart` | 1116 | 127 退出后转在线运行前判 `offlineOnly`（✔） |
| `editor/editor_page.dart` | 1415-1419 | 设置页 `showAi: offlineOnly != true`（✔ 编辑器侧） |
| `editor/editor_page.dart` | 1625-1626 | 菜单“AI 助手”判 `offlineOnly`（✔） |
| `editor/editor_page.dart` | 1646-1647 | 菜单“在线终端（服务器执行）”判 `offlineOnly`（✔） |
| `editor/editor_page.dart` | 1881 | `TerminalPane.onlineEnabled: offlineOnly != true`（✔） |
| `pages/home_page.dart` | 308 | 云项目页签从 `_scopes` 移除（✔） |
| `pages/home_page.dart` | 430 | 菜单“新建云项目”判 `offlineOnly`（✔） |
| `pages/home_page.dart` | 550 | 项目列表过滤 `!project.isCloud`（✔） |
| `pages/home_page.dart` | 700 | `_reloadProjects` 离线提前返回，不再拉云项目（✔） |
| `pages/local_content_pages.dart` | 605 | `isOffline` 选本地教程/示例（✔） |
| `pages/profile_page.dart` | 81-228 | 离线隐藏账号头/统计/签到积分/管理/退出/ICP（✔） |
| `services/runner_service.dart` | 175 | 离线 hint 文案“离线版无法使用在线终端”（✔） |

---

## 3. 漏门控明细

### G1 — 编辑器菜单 `git` / `cloud_pull` 未门控（高）

`qfli_studio_core/lib/editor/editor_page.dart:1585-1611`

```dart
const PopupMenuItem(          // 1585  —— 无 offlineOnly 判断
  value: 'git',
  child: Row(children: [Icon(Icons.account_tree_outlined, size: 20),
                        SizedBox(width: 12), Text('Git')]),
),
if (widget.project.isCloud)   // 1598 —— 仅判 isCloud，未判 offlineOnly
  const PopupMenuItem(
    value: 'cloud_pull',
    child: Row(children: [Icon(Icons.cloud_download_outlined, size: 20),
                          SizedBox(width: 12), Text('从云端拉取')]),
  ),
```

菜单回调（`editor_page.dart:1430-1435`）同样未门控：

```dart
case 'online_terminal': unawaited(_openOnlineTerminal());  // 该菜单项本身已被隐藏
case 'git':        _openGit();
case 'cloud_pull': _pullFromCloud();
```

`GitPage`（`lib/pages/git_page.dart`）中以下动作**走网络**：
- `git_page.dart:8` 引入 `api_client.dart`，`:81` `CloudSyncService.open(...)`
- `:176` “推送” → `_runCloud('push')` / `GitService.push`
- `:176` “拉取” → `_runCloud('pull')` / `GitService.pull`
- `:190` “远程仓库” → `GitService.setRemote`（https 地址）
- `:121` `_runCloud` 调 `CloudSyncService.git()`（服务器执行 git）

**行为差异**：
- 桌面本地项目：`git init/add/commit/status/log` 是本地 CLI（离线可接受），但 **push/pull/remote 是联网动作**。
- 移动端：`GitService.isSupported` 为 false，`canLocalGit=false`，但 `_cloudMode` 时 `canGit=true`，走服务器 git。

**建议（供主代理决策，本审计不实施）**：以 `StudioProfile.current?.offlineOnly == true` 隐藏 `git` 菜单项，或在 `GitPage` 内对 `offlineOnly` 禁用 push/pull/remote/云端分支（保留本地 init/add/commit/status/log）。

### G2 — 设置页 AI 入口在离线档位仍未隐藏（中）

- `pages/settings_page.dart:30` `this.showAi = true`（默认可见），`:135` `if (widget.showAi) ... “个人 AI 接口”`，`:148` `editAiSettings(context, settings)`（可配置任意 OpenAI 兼容端点 → 联网）。
- 编辑器侧正确：`editor_page.dart:1415-1419` 传 `showAi: offlineOnly != true`。
- **Profile 侧遗漏**：`pages/profile_page.dart:58-68` `_openSettings()` 构造 `SettingsPage(settings:..., auth:..., store:...)`，**未传 `showAi`** → 取默认 `true`。

**建议**：`profile_page.dart` 的 `_openSettings` 传 `showAi: StudioProfile.current?.offlineOnly != true`（或让 `SettingsPage` 自身读档位）。

### N3 — OHOS 声明 INTERNET，Android release 未声明（观察项，非缺陷）

- `ohos/entry/src/main/module.json5` `requestPermissions` 含 `{"name":"ohos.permission.INTERNET"}`（另有 `READ_PASTEBOARD`）。
- `android/app/src/main/AndroidManifest.xml` **无任何权限**；`android/app/src/debug/AndroidManifest.xml` 与 `.../profile/AndroidManifest.xml` 各含 `android.permission.INTERNET`（Flutter 调试用）。

**事实（只读）**：OHOS 与 Android release 的 manifest 权限声明存在平台差异。

**纠正**：这**不构成缺陷**。`ohos.permission.INTERNET` 可能是本地 HTML 预览等能力的合法依赖（`local_web_server.dart:74` 绑 `loopbackIPv4`；部分内核对 loopback 监听也要求该权限）。**未经验证不得删除**该权限声明。是否与 `isOffline` 冲突应在“实际联网可行性测试”后再判定，而非按声明推断。

**建议（待验证）**：留待验证阶段，在无网络或抓包条件下确认 Lua 是否存在任何非 loopback 外联；仅当确证外联且不符合产品定位时才复议。当前仅记录差异。

---

## 4. 发布构建准备审计

### N4 — OHOS 签名材料缺失且口令入库（环境阻塞 + 待评估泄露面）

`ohos/build-profile.json5`（**被 git 跟踪**，`git ls-files` 确认）当前（未提交）指向：

```
certpath : C:\Users\lichengyu\.ohos\config\default_ohos_C1vJ4NN0Q6XpqerisOq_v-z6tDNBlzN1uJ029cmXAYU=.cer
profile  : ...C1vJ...=.p7b
storeFile: ...C1vJ...=.p12
keyPassword / storePassword : DevEco 生成的密文
```

**实测**：`C:\Users\lichengyu\.ohos\config\` 下**不存在** `C1vJ...` 与旧提交引用的 `EyK2...`；实际存在的是
`Gu8zVby71b0t4gfRa-4NpIdkL2QGfz2fVEJ7JnRdkBg`、`udwsx4szjsVYdfsIlGUHNWjABzLiV5jMmp6fUlekYQM`、`weTSdRQhDd0CYsbdTNnMl7u-9OyyrAJo7t072jC8Yw4`。

未提交 diff 显示签名从 `EyK2...` 换成 `C1vJ...`，但两者在磁盘上都不存在。

**结论（环境阻塞）**：按当前 `build-profile.json5`，签名所需材料在本机缺失，**OHOS 打包会受阻**。`code:9568320 no signature file` 只是该文件注释里记录过的历史症状之一；实际形态可能是 SignHap 报错中止，或产出 unsigned HAP —— **须实测确认，不得预先断言一定产出 unsigned**。本审计未执行构建，故记为**环境阻塞**而非确定缺陷。

**风险（待评估）**：`build-profile.json5` 被跟踪 + 内含 `keyPassword/storePassword`（DevEco 可逆编码）→ 存在口令泄露面。建议评估是否将签名材料字段移出仓库（改为 DevEco 本地/CI 注入），并考虑轮换已入库口令。此点独立于构建能否成功。

### N6 — Android release 使用 debug 签名（观察项，可用于本轮验证）

`android/app/build.gradle.kts`（release 段）：

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```

应用 ID `com.azurekiln.qfli.script`，namespace 一致；`android/local.properties` 无 release 密钥配置。

**结论**：该 debug 签名产物**完全可用于本次设备安装与功能验证**，不阻塞本轮。仅当进入商店上架阶段时才需替换为正式 release keystore。**不得**将其表述为“商店签名已就绪”，也**不得**将其表述为“当前验证受阻”。

### N5 — OHPM 生成锁文件引用项目外 SDK/Pub Cache（观察项，非自动故障）

`ohos/entry/oh-package-lock.json5`：

```json5
"@ohos/flutter_ohos@../../../../ProgramFiles/flutter_ohos/bin/cache/artifacts/engine/ohos-arm64/flutter_embedding_debug.har"
"flutter_native_arm64_v8a@../../../../ProgramFiles/flutter_ohos/bin/cache/artifacts/engine/ohos-arm64/arm64_v8a_debug.har"
"path_provider_ohos@../../../../AppData/Local/Pub/Cache/hosted/pub.dev/path_provider_ohos-2.2.1/ohos"
```

**纠正**：该文件为 **ohpm 自动生成的锁文件**（`ohos/.gitignore:13` 忽略 `**/oh-package-lock.json5`，故未跟踪），其 `registryType: "local"` 条目以相对路径指向项目外的 SDK `har` 与 Pub Cache —— **这是 ohpm 解析本地依赖的正常机制**。`../../../../` 只是在 `ohos/entry/` 深度下回到盘根的相对写法，**不自动等于故障**。

**判定标准（据协调意见）**：只有以下情形才算真实缺陷——
- 锁文件出现 NUL 字节等损坏；
- 引用的目标文件**确实缺失**（当前机器上需逐项确认）；
- 实际执行 `ohpm install`/构建时报错。

**当前状态**：仅确认路径形态与生成机制，未运行构建，**不下“不可移植/逃逸”结论**。若后续构建报路径解析错误，再据实登记到 `10-08-ohpm-lock-repair`。

### N7 — 现有产物早于当前改动（证据有效性）

| 产物 | 时间 | 备注 |
| --- | --- | --- |
| `build/app/outputs/apk/release/app-release.apk` (69,981,813) | 2026-10-02 | 早于当前未提交 native/ohos 改动 |
| `build/ohos/hap/entry-default-signed.hap` (118,326,782) | 2026-10-12 | 早于当前签名/native 改动；含 `libs/arm64-v8a/{libflutter,libqfli_lua,libc++_shared}.so` + `ets/modules.abc` |
| `build/release/QFLIScript-Android-arm64-release…` | 2026-09-30 | 分发副本 |
| `build/release/QFLIScript-HarmonyOS-{arm64,x64}-release…` | 2026-09-30 | 分发副本 |

`app-release.apk` 内含 3 ABI（arm64-v8a / armeabi-v7a / x86_64）各带匹配的 `libapp.so`、`libflutter.so`、`libqfli_lua.so`（ABI 一致 ✔，符合 `lua-toolchain.md`）。但产物**不能作为当前源码的通过证据**。

### N8 — 缺 `hvigorw` 包装器（观察项，非发布阻塞）

项目 `ohos/` 下无 `hvigorw` / `hvigorw.bat`；DevEco 全局工具存在：`D:\ProgramFiles\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`、`tools\ohpm\bin\ohpm.bat`、`tools\node\node.exe`。

**纠正**：缺包装器**不代表发布阻塞**。Flutter 提供官方 OHOS 构建入口 `flutter build hap`，DevEco Studio 也是受支持路径。此项仅影响“纯命令行、脱离 DevEco 路径”的复现方式，记为观察项。

---

## 5. 环境检查结果（只读，全部非破坏）

### 5.1 工具链

| 项 | 路径 | 状态 |
| --- | --- | --- |
| Flutter | `D:\ProgramFiles\flutter_ohos\bin\flutter.bat` | ✅ `3.27.5-ohos-1.0.1`，Dart 3.11.5 |
| Android SDK | `D:\ProgramData\Android\Sdk` | ✅ 存在 |
| Android NDK | `...\ndk\27.0.12077973` | ✅ 与 `build.gradle.kts` `ndkVersion` 一致 |
| JBR（DevEco） | `D:\ProgramFiles\Huawei\DevEco Studio\jbr\bin\java.exe` | ✅ |
| JBR（Android Studio） | `D:\ProgramFiles\Android\Android Studio\jbr\bin\java.exe` | ✅ |
| HarmonyOS SDK | `D:\ProgramFiles\Huawei\DevEco Studio\sdk`（default/hms/openharmony） | ✅ |
| OHOS toolchains（含 hdc） | `...\sdk\default\openharmony\toolchains` | ✅ |
| ohpm | `...\DevEco Studio\tools\ohpm\bin\ohpm.bat` | ✅ |
| hvigor | `...\DevEco Studio\tools\hvigor\bin\hvigorw.bat` | ✅ |
| Node | `D:\ProgramFiles\nodejs\node.exe` + DevEco 自带 node | ✅ |

注意：系统 PATH `java` 指向 `C:\Program Files\Common Files\Oracle\Java\javapath\java.exe`（非 JBR）；Android/OHOS 构建应显式使用 JBR，避免 JDK 版本漂移。

### 5.2 设备（只读）

```
adb devices -l
adb-d361e7a0-gqqQSM (2)._adb-tls-connect._tcp  device  product:OPD2413 model:OPD2413 device:OP615EL1  transport_id:1

hdc list targets
192.168.68.207:46551
```

→ Android 无线调试设备 1 台（OPD2413）、OHOS 网络设备 1 台（192.168.68.207:46551）均在线。**未安装、未调试、未改动设备。**

### 5.3 未提交配置来源识别

`git status` 显示 27 项改动 + 未跟踪目录。与发布配置相关的未提交来源：

| 文件 | 状态 | 来源/性质 |
| --- | --- | --- |
| `ohos/build-profile.json5` | M | 签名材料从 `EyK2...` 换为 `C1vJ...`（两者磁盘均不存在）；被跟踪 |
| `ohos/entry/src/main/ets/entryability/EntryAbility.ets` | M | 新增 `openAgreement` / `startupProgress` 平台通道，`window, router` 导入 |
| `ohos/entry/src/main/ets/pages/Index.ets` | M | 新增 `StartupSplash`（图标+进度条），`FlutterPage.splashScreenView` |
| `ohos/entry/src/main/resources/base/profile/main_pages.json` | M | 注册 `pages/AgreementReader` |
| `ohos/entry/src/main/ets/pages/AgreementReader.ets` | ?? (未跟踪) | 新页面实体 |
| `pubspec.yaml` / `pubspec.lock` | M | 新增 `flutter_localizations`、`path_provider_platform_interface`（dev） |
| `lib/main.dart`, `lib/lua_runner.dart` | M | 原生启动推迟首帧 + runner 调整 |
| `native/src/*.c/.h`, `native/test/*`, `native/README.md` | M | Lua 桥/输入/Windows 宽路径 |
| `.trellis/tasks/10-15-*`, `.codex/`, `.trae/`, `tools/`, `test/*` | ?? | 任务/工具/测试新增 |

`android/local.properties`、`ohos/local.properties`、`ohos/**/oh-package-lock.json5` 均**被 gitignore**（未跟踪），属本机环境派生。

---

## 6. 建议的构建 / 产物验证 / 设备测试方案

> 以下为**方案**，本审计**未执行**。执行需主代理/用户授权，且不得回滚他人改动。

### 6.1 开工前准备与环境阻塞（非全部“发布阻塞”）

1. **已确证缺陷修复（G1/G2）**：按第 3 节建议修复（共享核心改动需主代理协调）。
2. **OHOS 签名材料（N4，环境阻塞）**：在实际打包时可能因材料缺失而失败；若受阻，在 DevEco 中为 `com.azurekiln.qfli.script` 重新“Automatically generate signature”，或将 `build-profile.json5` 指向磁盘上**真实存在**的 `.cer/.p7b/.p12`。**具体失败形态待实测**。
3. **Android 签名（N6）**：**本轮验证不需要改动** —— debug 签名 release APK 可直接用于设备安装/功能验证；仅商店上架阶段才需正式 keystore。
4. **OHPM 锁（N5）**：**无需改动**，除非实测出现 NUL/缺文件/构建报错（如上，才转向 `10-08`）。

### 6.2 静态与测试门（qfli_lua 根）

```powershell
flutter analyze --no-pub
flutter test --no-pub
# 原生 CTest（需 CMake/Ninja/VS）
cmake -S native -B native/build -G Ninja
cmake --build native/build
ctest --test-dir native/build --output-on-failure
```

### 6.3 Android 构建与产物验证

```powershell
# 单 ABI release（推荐手机验证）
flutter build apk --release --target-platform android-arm64
# 或分 ABI
flutter build apk --release --split-per-abi
```

产物验证（只读解包）：

```powershell
$apk = "build/app/outputs/flutter-apk/app-release.apk"
# 1) ABI 与 native 一致：libapp.so / libflutter.so / libqfli_lua.so 三者 ABI 集合必须相同
# 2) 导出符号：libqfli_lua.so 应导出 qfli_lua_run_with_token/qfli_lua_check/qfli_lua_compile/qfli_lua_free
# 3) 16KiB 页兼容（NDK 27 + ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES）：检查 64 位 ELF LOAD 段对齐
# 4) release manifest 权限（当前无 INTERNET；仅为事实核对，非要求，见 N3）
# 5) 记录 SHA-256
Get-FileHash $apk -Algorithm SHA256
```

可用工具：`D:\ProgramData\Android\Sdk\build-tools\<ver>\aapt2.exe dump badging`、`llvm-readelf`（NDK `toolchains\llvm\prebuilt\windows-x86_64\bin`）。

设备测试（Android，OPD2413，需授权）：

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.azurekiln.qfli.script/.MainActivity
# 真机验证：独立终端 + 编辑器内终端执行 print(6*7) → 42；check/compile；取消 → 130；错误退出码；Unicode+括号文件名
```

### 6.4 OHOS 构建与产物验证

```powershell
# 官方入口（推荐）：
flutter build hap --release
# 或 DevEco 全局 hvigor（非唯一入口；缺 hvigorw 包装器不影响官方路径，N8）
& "D:\ProgramFiles\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p product=default -p module=entry@default assembleHap --no-daemon
```

或 DevEco Studio 内 Build → Build Hap(s)/APP(s)。

产物验证（只读解包，已有先例）：

```powershell
# 产物名以实际构出为准（signed / unsigned 待实测，N4）
$hap = "build/ohos/hap/entry-default-signed.hap"
# 内容核对：ets/modules.abc、libs/arm64-v8a/libflutter.so、libqfli_lua.so、module.json
# 若构建因签名材料缺失而失败或产出 unsigned HAP，据实记录为环境阻塞（不预设结论）
Get-FileHash $hap -Algorithm SHA256
```

设备测试（OHOS，`192.168.68.207:46551`，需授权）：

```powershell
hdc install build/ohos/hap/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.azurekiln.qfli.script
# 验证原生启动遮罩（图标+进度条）在首页布局完成后淡出（native-startup.md §6）
# 验证 libqfli_lua.so 在设备上被加载并跑通 Lua 场景
```

### 6.5 通过判据 / 证据

- 每种产物：路径 + SHA-256 + 打包内 native 清单（ABI 一一对应）+ 签名状态。
- 设备运行：命令 + 输出片段（成功 `42`、退出码 127/130 语义）。
- **环境阻塞必须显式记录**，不得标通过（如签名材料缺失、未授权安装）。

---

## 7. 风险与未决项

| 风险/未决项 | 说明 |
| --- | --- |
| 联网漏门控（已确证） | Git push/pull/remote（G1）、设置页 AI 接口（G2）在离线档位可达 |
| 签名口令入库（待评估） | `ohos/build-profile.json5` 被跟踪且含可逆口令（N4）；建议评估移出/轮换，独立于构建成败 |
| OHOS 签名材料缺失（环境阻塞） | 当前配置引用的 cert/p7b/p12 不在盘上；实际失败形态待实测（N4） |
| OHOS INTERNET 声明（待验证） | 可能是 loopback 预览等合法依赖，未验证前不删除（N3） |
| OHPM 锁路径形态（待验证） | ignored 生成文件引用项目外 SDK/Pub Cache，属正常机制；仅 NUL/缺文件/构建报错才算缺陷（N5） |
| Android release 签名（非阻塞） | debug 签名可用于本轮验证；商店上架需正式 keystore（N6） |
| 证据过期 | 现有 APK/HAP 早于当前改动（N7），不可作为通过依据 |
| OHOS 构建入口 | 缺 `hvigorw` 包装器不影响官方 `flutter build hap` / DevEco（N8） |
| 并发工作区 | 存在他人未提交改动；共享核心由主代理协调，本审计不修改 |

---

## 8. 明确未做（符合本轮约束）

- 未修改任何产品/配置文件（含共享核心），未 `build clean`，未安装/调试设备。
- 未运行 `flutter build` / `hvigorw` / `adb install` / `hdc install`。
- 未 `task.py start`，未提交，未回滚他人改动。
- 设备与 SDK 检查均为只读查询。

---

## 9. 证据索引（关键行号）

- 档位定义：`qfli_lua/lib/main.dart:24,34,65`；`qfli_studio_core/lib/services/studio_profile.dart:104-111,173-188`
- 漏门控 G1：`qfli_studio_core/lib/editor/editor_page.dart:1430-1435,1585-1611`；`lib/pages/git_page.dart:8,81,121,176,190`
- 漏门控 G2：`qfli_studio_core/lib/pages/profile_page.dart:58-68`；`lib/pages/settings_page.dart:30,135,148`
- 观察项 N3（INTERNET）：`ohos/entry/src/main/module.json5`；`android/app/src/main/AndroidManifest.xml`；`.../debug|profile/AndroidManifest.xml`
- 观察项 N4（签名材料）：`ohos/build-profile.json5`（git 跟踪；引用的 `C1vJ...`/`EyK2...` 磁盘不存在）
- 观察项 N5（OHPM 锁）：`ohos/entry/oh-package-lock.json5`（ignored 生成文件，项目外路径属正常机制）
- 观察项 N6（Android 签名）：`android/app/build.gradle.kts` release 段
- 证据 N7：`build/app/outputs/apk/release/app-release.apk`（2026-10-02）、`build/ohos/hap/entry-default-signed.hap`（2026-10-12）
- 观察项 N8（hvigorw）：项目无包装器；官方入口 `flutter build hap`
