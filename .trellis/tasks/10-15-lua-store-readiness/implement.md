# 实施与验收计划

## 规划门禁

- [x] 用户已同意创建任务与规划。
- [x] 3 个 Lua pi 的 workspace/pane/cwd 已核实并分工；报告已写入 research/。
- [x] PRD 收敛，复杂设计与子任务边界落盘。
- [ ] 用户批准本版最终规划后运行 task.py start；此前不实施产品修改。

## 执行顺序

1. 校验上下文 manifests，提交规划文档；确认最终批准后激活主任务及对应子任务。
2. 主代理记录两仓 HEAD、diff 和文件所有权。A 在 Lua 仓实现终端 delegate、必要原生传参及真实回归；B 准备 120 个主题、Lua 专属生成/验证工具；C 形成离线策略精确补丁并检查平台环境。三者不交叉写文件，核心公共生产文件与聚合 JSON 由主代理集成。
3. 修复确认的 Git/云拉取、AI 设置漏门控与终端文案；修复导入文件名生产回归及 Windows 测试资源清理失败。
4. A 通过原生重编/CTest、终端与应用测试后提交；B 对全部代码进行真实引擎验证，主代理读取活聚合 JSON 合并 Lua 条目，核对非 Lua 指纹后提交核心内容。
5. 运行完整应用与核心 lib/test 静态分析，应用完整测试、核心完整测试及必要终端/离线/内容跨层回归。失败须定位并修复或记录明确外部阻塞，不能笼统记为通过。
6. 最终源码稳定后串行执行 Android 与 OHOS 发布构建。检查 ABI/桥接导出/16KiB 对齐/ArkTS/签名与哈希。
7. 设备在线且授权允许时使用 adb/hdc 覆盖安装并测试；遇到签名冲突不得卸载或清数据。安装失败也保留完整构建证据。
8. 对旧内容导入、原生平台、OHPM、终端任务逐项核对已实现内容和未提交变更，只归档真实完成项。更新规格与 journal，分批 Conventional Commits，最终复查两仓状态。

## 核心命令

在 Lua 根执行，Flutter 调用使用完整 Dart/snapshot 路径以避免 wrapper 差异：

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot analyze --no-pub
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot test --no-pub --reporter expanded
& D:/ProgramData/Android/Sdk/cmake/3.22.1/bin/cmake.exe --build native/build/windows
& D:/ProgramData/Android/Sdk/cmake/3.22.1/bin/ctest.exe --test-dir native/build/windows --output-on-failure
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe run tools/lua_stdin_smoke.dart native/build/windows/libqfli_lua.dll
```

共享核心在自己的 cwd 执行 analyze --no-pub lib test 与完整 test --no-pub；只排除已确认不属于主包的 vendor 示例配置，不跳过失败。

最终平台构建使用 Flutter build apk --release --no-pub、build hap --release --target-platform ohos-arm64 --no-pub，并显式选择兼容 JBR。具体 target ABI 及签名状态写入 verification.md。生成锁损坏时先保留证据，重新生成仅相关工作区生成文件。

## 评审与回退

- 各批提交前 git diff --check（CRLF 用 core.whitespace=cr-at-eol）与实际行为回归。
- 子任务完成后交叉复核；最终调用 trellis-check 审查 specs、数据流、接口与测试真实性。
- 每次核心合并前后核对非本任务 diff；检测重叠即协调，禁止提交整仓已有变更。
- 回退仅撤回本任务自己的明确 patch/commit，不 reset/clean、不删除用户代码/设备数据。
