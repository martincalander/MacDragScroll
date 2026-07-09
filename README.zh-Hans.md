<p align="center">
  <img src="docs/assets/mac-drag-scroll-icon.png" width="128" alt="Mac Drag Scroll应用图标">
</p>

<h1 align="center">Mac Drag Scroll</h1>

<p align="center">
  <strong>让 macOS 外接鼠标拥有 Windows 风格的拖拽滚动。</strong>
</p>

<p align="center">
  按住鼠标中键，移动鼠标，即可不碰滚轮，向任意方向滚动。
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/ci.yml"><img alt="Quality Gate" src="https://github.com/martincalander/MacDragScroll/actions/workflows/ci.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/martincalander/MacDragScroll/actions/workflows/codeql.yml/badge.svg?branch=main"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/martincalander/MacDragScroll"><img alt="OpenSSF Scorecard" src="https://api.scorecard.dev/projects/github.com/martincalander/MacDragScroll/badge"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/secret-scan.yml"><img alt="Secret Scan" src="https://github.com/martincalander/MacDragScroll/actions/workflows/secret-scan.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/martincalander/MacDragScroll?display_name=tag&sort=semver"></a>
  <img alt="macOS 26.2及以上" src="https://img.shields.io/badge/macOS-26.2%2B-111111?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="许可证: MIT" src="https://img.shields.io/badge/license-MIT-2f80ed.svg"></a>
</p>

<p align="center">
  <img src="docs/assets/mac-drag-scroll-hero.png" alt="Mac Drag Scroll Liquid Glass拖拽指示器预览">
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><strong>下载最新版本</strong></a>
</p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.ja.md">日本語</a> | 简体中文
</p>

## 功能

Mac Drag Scroll 把 Windows 上熟悉的中键拖拽滚动手势带到 macOS。它适合使用外接鼠标，并希望在长页面、代码编辑器、电子表格、设计画布和聊天应用中快速、舒适滚动的用户。

- **按住并拖拽即可滚动**：按住鼠标中键，朝想滚动的方向移动鼠标。
- **支持任意方向**：同一个手势可用于纵向、横向或斜向滚动。
- **保持原窗口活动**：滚动会持续发送到拖拽开始时所在的窗口。
- **小巧的 Liquid Glass 指示器**：低调的原点标记会显示拖拽开始的位置，以及当前拉动的距离。
- **常驻菜单栏**：应用在后台运行，不占用 Dock 空间。
- **安全设计**：避开触控板手势，只监听已配置的鼠标触发方式。

## 安装

推荐：

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

手动安装：

1. 打开[最新版本](https://github.com/martincalander/MacDragScroll/releases/latest)。
2. 下载 `MacDragScroll.dmg`。
3. 打开磁盘映像，并将 **Mac Drag Scroll** 移到“应用程序”文件夹。
4. 仅首次启动需要：在 Finder 中右键点击 **Mac Drag Scroll**，选择**打开**，然后确认。
5. 当 macOS 提示时，授予辅助功能和输入监控权限。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-install-demo.gif" width="760" alt="Mac Drag Scroll安装演示">
</p>

当前版本未签名，也未经过 Apple 公证，因此 macOS 可能会在首次启动时拦截。这对免费的发布流程来说是预期行为。每个下载的构建版本只需要右键选择**打开**绕过一次。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-gatekeeper-bypass.gif" width="760" alt="如何打开未签名的Mac Drag Scroll构建版本">
</p>

不使用 Homebrew 的 CLI 安装：

```sh
curl -fsSL https://github.com/martincalander/MacDragScroll/raw/main/install.sh | bash
```

## 授予权限

Mac Drag Scroll 需要辅助功能和输入监控权限，才能全局检测鼠标中键并发送滚动事件。

1. 打开**系统设置**。
2. 进入**隐私与安全性**。
3. 打开**辅助功能**，启用 **Mac Drag Scroll**。
4. 打开**输入监控**，启用 **Mac Drag Scroll**。
5. 如果 macOS 要求重新启动应用，请退出并重新打开 Mac Drag Scroll。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-permission-demo.gif" width="760" alt="Mac Drag Scroll权限演示">
</p>

应用会在设置中显示权限状态。如果任一必需权限被移除，拖拽滚动会自动禁用。

## 使用

1. 按住鼠标中键。
2. 将鼠标从起点移开。
3. 松开鼠标中键即可停止。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-usage-demo.gif" width="760" alt="Mac Drag Scroll拖拽滚动使用演示">
</p>

拖拽离原点越远，滚动速度越快。除非在设置中关闭，否则拖拽时会显示一个小巧的玻璃风格指示器。

## 设置

从菜单栏图标打开设置。

| 设置 | 作用 |
| --- | --- |
| Enable | 开启或关闭 Mac Drag Scroll。 |
| Keep in Menu Bar | 关闭设置窗口后，仍让应用在菜单栏继续运行。 |
| Speed | 调整滚动速度。 |
| Acceleration | 改变拖拽距离变远时速度提升的方式。 |
| Dead zone | 设置原点周围尚未开始滚动的小范围。 |
| Visualizer | 控制大小、透明度、色调、Liquid Glass 强度和动画。 |
| Launch at Login | 登录时自动启动 Mac Drag Scroll。 |
| Excluded Apps | 在选定应用中禁用拖拽滚动。 |
| Permissions | 显示辅助功能和输入监控状态，并提供修复入口。 |
| Updates | 通过 Sparkle 检查 GitHub Releases，并显示版本历史。 |

设置按 macOS 用户保存到：

```text
~/Library/Preferences/com.martincalander.macdragscroll.plist
```

可恢复的应用设置也会镜像到备份文件：

```text
~/Library/Application Support/Mac Drag Scroll/Preferences.plist
```

正常删除应用、重新安装、Homebrew 升级和 Sparkle 更新都不会删除这些文件，因此偏好设置会在更新和卸载后保留。

## 诊断

如果应用崩溃，设置中会显示 **Crash Reports** 区域，可用于打开文件夹、复制最新报告、在 Finder 中显示最新报告，或清除已保存的报告。

崩溃报告会保存在本机：

```text
~/Library/Application Support/Mac Drag Scroll/Crash Reports
```

## 隐私

Mac Drag Scroll 被设计为本地工具。它需要辅助功能和输入监控权限来实现拖拽滚动手势，但不会记录你的输入内容、检查文档内容或跟踪浏览行为。

请阅读完整的[隐私说明](PRIVACY.md)。

## 更新

使用**设置 -> 更新**，或菜单栏中的**检查更新**命令来检查新版本。更新由 Sparkle 验证，并托管在 GitHub Releases。除非未来版本另有说明，本应用未经过 Apple 公证。

## 支持

需要帮助时，请先查看[支持](SUPPORT.md)。如果问题可以复现，再创建 Issue。

## 要求

- macOS 26.2 或更高版本
- 带中键或滚轮点击的外接鼠标
- 辅助功能和输入监控权限

## 作者

Mac Drag Scroll 由 [Martin Calander（马丁）](https://martincalander.com) 制作。

开发者和贡献者可以阅读 [Contributing](CONTRIBUTING.md)。

发布维护者可以阅读 [Releasing](docs/RELEASING.md)。
