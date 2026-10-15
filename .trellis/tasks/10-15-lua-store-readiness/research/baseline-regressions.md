# 两项基线失败定位

只读研究，未修改产品代码。

## 文件名校验

共享核心 lib/services/code_import_service.dart:131-132 在非 Java 名称校验前先 trim，绕过 :163 的空白拒绝。Lua test/code_import_service_test.dart:77 的预期符合 frontend/content-code-import.md 既有契约。

最小修复：非 Java 分支以 rawName 校验并原样返回，移除该分支的提前 trim；保留 Java normalizeClassNameInput 现有语义，并回归 Java 导入重命名测试。不能通过放宽 Lua 测试掩盖回归。

## Windows 清理占用

test/content_import_workflow_test.dart:95 清理目录时 errno32。研究发现本次残留临时目录内 .qfli-project-registry-ed20122f/registry.json 为 0 字节，支持异步注册表写入未完成的判断。

链路：核心 CodeSnippet._import 调用 ProjectStore.touch/setBrowsedProject，二者触发未等待的持久化；ProjectStore._persist:144-150 异步打开临时文件。EditorPage.dispose:392 还会启动 ProjectHistory.save。测试 harness :136-144 只有固定四次20ms/pump，随后退出并停止推进该 fake zone；真实时间重试不能保证挂起写入完成。

最小修复方向：测试卸载与真实 I/O 的启动放在 runAsync，利用已有 store.refresh 等待最新写队列，再完成相关控制器/保存的资源排空；只有现有 API 不足时才考虑增加明确的 flush/whenIdle 契约。禁止仅增加 sleep、吞掉删除错误或删除断言。需在 Windows 复现并运行完整测试验证。
