# AtomVoice — Codex 协作指南

## 项目简介

macOS 菜单栏语音输入工具，名称 **AtomVoice**（中文：原子微语）。按住 Fn 键录音，松开后自动将识别文字注入到当前输入框。
纯 Swift + AppKit，目标系统 macOS 14+。

## 构建与运行

### 开发调试
```bash
make dev        # 编译并安装到 dist/Test/AtomVoice.app（含 DEBUG_BUILD 标记）
make run        # 编译并直接运行（当前机器原生架构，含 DEBUG_BUILD 标记）
```

### 发版构建
```bash
make release    # 构建三个架构：AppleSilicon / Intel / Universal，产物在 dist/
```

> 每次 `make release` 前先更新版本号（见下方发版流程）。

## 代码规范

- **注释用中文**。
- **新功能所有用户可见字符串必须走 `loc()`**，并同步更新全部 7 个 lproj 文件：
  `Resources/en.lproj/` `zh-Hans.lproj/` `zh-Hant.lproj/` `ja.lproj/` `ko.lproj/` `es.lproj/` `fr.lproj/` `de.lproj/`
- 不硬编码用户界面字符串。

## 发版流程

> **只在用户明确说"发版"后才执行，编译完成后等待确认。**

1. **自动建议版本号**：仅递增 patch 位（如当前 `0.9.1` → 建议 `0.9.2`）。未经用户主动提及，不更新 major / minor。
2. **用户确认版本号后**，同步修改两处：
   - `Sources/AtomVoice/Info.plist` → `CFBundleShortVersionString`
   - `Makefile` 顶部 `VERSION` 变量
3. 运行 `make release`，完成后**停下来等用户指令**。
4. 用户确认发版后，依次执行：
   ```bash
   git add -p
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

## 本地化

支持 7 种语言：English / 简体中文 / 繁體中文 / 日本語 / 한국어 / Español / Français / Deutsch。
