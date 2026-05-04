# AtomVoice — Claude 协作指南

## 项目简介

macOS 菜单栏语音输入工具，名称 **AtomVoice**（中文：原子微语）。按住 Fn 键录音，松开后自动将识别文字注入到当前输入框。
纯 Swift + AppKit，目标系统 macOS 14+。

## 构建与运行

### 开发调试
```bash
make dev        # 编译并安装到 dist/Test/AtomVoice.app（供确认后使用，含 DEBUG_BUILD 标记）
make run        # 编译并直接运行（当前机器原生架构，含 DEBUG_BUILD 标记）
```

### 发版构建
```bash
make release    # 构建三个架构：AppleSilicon / Intel / Universal，产物在 dist/
```

> 每次 `make release` 前先更新版本号（见下方发版流程）。

### 清理
```bash
make clean      # 清除 .build 和 dist
```

## 架构概览

```
AppDelegate
├── FnKeyMonitor          — 全局 Fn 键监听（CGEvent tap）
├── AudioEngineController — AVAudioEngine 录音 + 喂给识别器
├── SpeechRecognizerController — SFSpeechRecognizer 封装
├── CapsuleWindowController    — 浮动胶囊 UI（NSPanel + NSVisualEffectView / NSGlassEffectView）
├── LLMRefiner            — 可选 LLM 文字润色（OpenAI-compatible API）
├── TextInjector          — 剪贴板 + Cmd+V 注入，自动处理 CJK 输入法切换
└── MenuBarController     — NSStatusItem + 所有菜单项 + 设置窗口
```

数据流：`FnDown → startRecording()` → 识别回调实时更新胶囊文字 → `FnUp → stopRecording()` → 可选 LLM 润色 → `TextInjector.inject()` → 胶囊消失。

## 代码规范

- **注释用中文**。
- **新功能所有用户可见字符串必须走 `loc()`**，并同步更新全部 7 个 lproj 文件：
  `Resources/en.lproj/` `zh-Hans.lproj/` `zh-Hant.lproj/` `ja.lproj/` `ko.lproj/` `es.lproj/` `fr.lproj/` `de.lproj/`
- 不硬编码用户界面字符串。
- 可以主动建议编写测试（目前项目无测试）。

## Debug 专属功能

`make dev` / `make run` 编译时带 `-Xswiftc -DDEBUG_BUILD` 标记，`make release` 不带。
所有 debug 专属 UI 必须用 `#if DEBUG_BUILD` 包裹，**绝不出现在正式发版中**：

- **「关于」窗口**：版本号下显示橙色 "⚙ Development Build" 标识（`AboutWindow.swift`）
- **胶囊计时器**：录音时胶囊右侧实时显示已录时长，格式 "10s" / "1:05"（`CapsuleWindow.swift`）

新增 debug 专属功能时沿用 `#if DEBUG_BUILD` 模式，同时更新本节。

## 发版流程

> **只在用户明确说"发版"后才执行，编译完成后等待确认。**

1. **自动建议版本号**：仅递增 patch 位（如当前 `0.9.1` → 建议 `0.9.2`）。未经用户主动提及，不更新 major / minor。
2. **用户确认版本号后**，同步修改两处：
   - `Sources/AtomVoice/Info.plist` → `CFBundleShortVersionString`
   - `Makefile` 顶部 `VERSION` 变量
3. 运行 `make release`，完成后**停下来等用户指令**。
4. 用户确认发版后，依次执行：
   ```bash
   git add -p                          # 按需暂存
   git commit -m "chore: release vX.Y.Z"
   git tag vX.Y.Z
   git push && git push --tags
   gh release create vX.Y.Z dist/AtomVoice-X.Y.Z-*.zip --title "vX.Y.Z" --notes "<bilingual notes>"
   ```
5. **Release Notes 格式**：必须使用英文+中文双语格式，英文在前，中文在后：
   ```
   ## What's New
   - English description...

   ## Improvements
   - English description...

   ## Bug Fixes
   - English description...

   ---

   ## 新功能
   - 中文描述...

   ## 优化
   - 中文描述...

   ## Bug 修复
   - 中文描述...
   ```
6. 测试版在 title 后加 " Beta"，并加 `--prerelease` 标记。

## 权限要求

应用运行需要三项授权，缺一不可：
- **麦克风**（AVCaptureDevice）
- **语音识别**（SFSpeechRecognizer）
- **辅助功能**（Accessibility，用于 CGEvent tap 监听 Fn 键 + TextInjector 注入）

## 签名

Makefile 中已配置 Apple Development 证书（`codesign --sign "Apple Development: miaolingru@gmail.com (XJS89V9J9T)"`），构建时自动签名，无需额外操作。

## 本地化

支持 7 种语言：English / 简体中文 / 繁體中文 / 日本語 / 한국어 / Español / Français / Deutsch。  
新增字符串时，所有 lproj 必须同步，缺失会导致回退到 key 名显示。
