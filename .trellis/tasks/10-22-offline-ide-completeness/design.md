# Design

Language runtime/content stays product-owned. Reuse StudioProfile runner, terminalCommandDelegate, toolsTabBuilder, contentRepositoryFactory and editorFileTools. Lua-owned assets avoid shared aggregate JSON conflicts; retain other Script entries through a filtered fallback until their OHOS capabilities are audited. New common APIs require a global ownership claim and live-file reread before integration. Root owns main.dart, pubspec and Git operations. Workers preserve parallel changes and never commit.

Content uses ContentCatalog/ContentRepository with stable explicit IDs, types, fixtures, expected output and lesson links. Each entry executes in a separate project using bundled Lua 5.4.8. Authored expected output must not be replaced with captured output to mask failures. Label host, cross-compiled and target execution evidence separately.

Tools/terminal use LuaToolchain, not unavailable OHOS executable spawning. Syntax checks never execute user code; bytecode has the same VM version. Diagnostic providers report actual errors and source revision so old results cannot underline newer text. Debug controls require real VM pause/step/resume; unsupported providers must remain honest.

Workspace persistence uses ProjectHistory and per-editor live state. Capture root/generation across async reads so stale restore cannot contaminate a switched project. Multi-root browsing retains correct owning project and run context. Product tools embed a scroll body in FunctionsTab, without nested Scaffold or gateway card. Keep existing ABI and null-default hooks compatible, with additive versioned extensions only when needed.

Changes are additive or small and independently revertible. Preserve pre-existing diffs; no reset or blind staging. Coordinate SDK locks across roots. Normal pushes only; record failures without rewriting history.
