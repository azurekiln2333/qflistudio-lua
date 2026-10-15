# Lua 双终端完整性执行计划

## 前置

- [ ] 用户批准父任务最终规划。
- [ ] 读取父任务 PRD/design/implement、适用 specs 和本项 research，上下文 validate 后激活任务。

## 步骤

1. 读取原生与核心终端接口，明确新增模块边界。
2. 实现 delegate 与必要的非破坏性原生传参，补真实桥接回归。
3. 重编原生库、CTest、Lua 专属/完整应用测试与静态检查。
4. 主代理复核后提交终端批次，交由平台子任务构建。

## 验证与提交

遵循父任务 implement.md 中的具体命令及质量门禁。所有执行命令、结果、产物与阻塞写 verification.md。主代理显式按文件暂存并使用 Conventional Commits；不自行并发 Git 提交。
