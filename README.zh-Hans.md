<p align="center">
  <img src="docs/assets/mac-drag-scroll-icon.png" width="112" alt="Mac Drag Scroll 应用图标">
</p>

<h1 align="center">Mac Drag Scroll</h1>

<p align="center">
  <strong>自然融入 macOS 的鼠标中键拖拽滚动。</strong><br>
  按住滚轮并移动鼠标，即可流畅浏览长页面、编辑器、时间线和画布。
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/martincalander/MacDragScroll?display_name=tag&sort=semver"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/checks-summary.yml"><img alt="Checks 3/3" src="https://github.com/martincalander/MacDragScroll/actions/workflows/checks-summary.yml/badge.svg?branch=main"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/martincalander/MacDragScroll"><img alt="OpenSSF Scorecard" src="https://api.scorecard.dev/projects/github.com/martincalander/MacDragScroll/badge"></a>
  <a href="https://www.bestpractices.dev/projects/13546"><img alt="OpenSSF Best Practices" src="https://www.bestpractices.dev/projects/13546/badge"></a>
  <img alt="macOS 14 或更高版本" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="MIT 许可证" src="https://img.shields.io/badge/license-MIT-2f80ed.svg"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a>
</p>

<p align="center">
  <img src="docs/assets/mac-drag-scroll-hero.png" alt="Mac Drag Scroll 使用小巧的 Liquid Glass 拖拽指示器控制长文档">
</p>

<p align="center">
  <strong><a href="https://github.com/martincalander/MacDragScroll/releases/latest">下载 macOS 版本</a></strong>
  &nbsp;·&nbsp;
  <a href="#快速开始">使用 Homebrew 安装</a>
  &nbsp;·&nbsp;
  <a href="#从源码构建">从源码构建</a>
</p>

Mac Drag Scroll 把 Windows 上熟悉的鼠标中键拖拽手势带到 macOS 外接鼠标。它是一款轻量的原生菜单栏工具：不需要账号，不依赖云服务，也不会干扰正常的触控板手势。

## 效果演示

<p align="center">
  <img src="docs/assets/mac-drag-scroll-usage-demo.gif" width="800" alt="按住鼠标中键拖拽滚动，快速反向滑动，然后松开停止">
</p>

按住鼠标中键，然后从起点向外移动。拖拽距离决定速度，方向决定滚动向量，松开按键后立即停止。小巧的指示器可以调整大小、外观和动画，也可以完全关闭。

## 为什么选择 Mac Drag Scroll

| | |
| --- | --- |
| **自然控制** | 通过一个连续手势完成纵向、横向或斜向滚动。 |
| **目标稳定** | 整个手势始终绑定在拖拽开始时的窗口上。 |
| **专注外接鼠标** | 触控板手势会被忽略，不会被拦截或重新映射。 |
| **即时反馈** | 单点 Liquid Glass 指示器会响应方向、距离、双击和快速反向操作。 |
| **原生菜单栏体验** | 安静地在后台运行，只在需要时打开设置。 |
| **便于恢复** | 内置权限修复、持久偏好设置、本地诊断和经过验证的更新。 |

## 快速开始

### Homebrew

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

### 直接下载

1. 从[最新版本](https://github.com/martincalander/MacDragScroll/releases/latest)下载 `MacDragScroll.dmg`。
2. 打开磁盘映像，将 **Mac Drag Scroll** 拖入**应用程序**文件夹。
3. 在 Finder 中右键点击应用，选择**打开**，然后确认首次启动。
4. 当 macOS 提示时，授予辅助功能和输入监控权限。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-install-demo.gif" width="800" alt="将 Mac Drag Scroll 拖入应用程序文件夹">
</p>

<details>
<summary><strong>为什么首次启动需要“右键 → 打开”？</strong></summary>

当前版本带有固定的项目代码签名，但没有使用需要付费 Apple Developer 会员资格的 Developer ID 签名或公证。因此，macOS 可能会阻止直接双击新下载的构建版本。请在 Finder 中右键点击 **Mac Drag Scroll**，选择**打开**并确认。每个手动下载的构建版本只需执行一次。

固定的项目身份可让辅助功能和输入监控权限在更新后继续有效。项目也会发布 Sparkle 签名和 GitHub 构建来源证明，方便独立验证发布文件。详情请参阅[安全说明](SECURITY.md)和[发布流程](docs/RELEASING.md)。
</details>

<details>
<summary><strong>不使用 Homebrew 安装</strong></summary>

```sh
curl -fsSL https://github.com/martincalander/MacDragScroll/raw/main/install.sh | bash
```
</details>

## 授予权限

Mac Drag Scroll 需要两项 macOS 权限：**输入监控**用于全局检测外接鼠标按键，**辅助功能**用于向目标窗口发送滚动事件。应用不会利用这些权限记录键盘输入或查看内容。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-permission-demo.gif" width="800" alt="为 Mac Drag Scroll 启用辅助功能和输入监控权限">
</p>

打开**系统设置 → 隐私与安全性**，在**辅助功能**和**输入监控**中都启用 Mac Drag Scroll。如果 macOS 要求重新启动应用，请退出后重新打开。设置中的“权限”标签页会显示实时状态并提供修复快捷入口。

## 调整操作手感

从菜单栏图标打开设置。

| 设置 | 控制内容 |
| --- | --- |
| 速度和加速度 | 基础滚动速度，以及速度随拖拽距离增长的方式。 |
| 死区 | 手势起点周围不触发滚动的中性区域。 |
| 触发方式 | 默认使用中键；主键和副键的替代方式会搭配修饰键保护。 |
| 指示器 | 大小、透明度、色调、玻璃强度和动态效果。 |
| 排除的应用 | 在指定应用中始终禁用拖拽滚动。 |
| 启动行为 | 登录时启动，以及是否继续驻留菜单栏。 |
| 更新 | 自动检查、版本历史和手动更新控制。 |

偏好设置按 macOS 用户保存，并会在应用更新、正常卸载和重新安装后保留。具体路径和恢复方法请参阅[支持](SUPPORT.md)。

## 值得信赖的设计

- **完全本地运行：** 没有账号、分析、广告或云端后端。
- **输入范围明确：** 只有已配置的鼠标触发方式会开始滚动，触控板手势会被过滤掉。
- **感知权限状态：** 缺少或撤销必需权限时，滚动功能会自动停用。
- **发布过程可检查：** 自动检查、密钥扫描、CodeQL、Sparkle 签名和 GitHub Attestations 都在公开仓库中运行。
- **诊断信息保持私密：** 崩溃报告会保留在 Mac 本机，除非用户主动选择分享。

进一步了解[隐私](PRIVACY.md)、[安全](SECURITY.md)和实现[架构](ARCHITECTURE.md)。

## 从源码构建

需要 macOS 14 或更高版本，以及 Xcode 26.2 或更高版本。

```sh
git clone https://github.com/martincalander/MacDragScroll.git
cd MacDragScroll
xcodebuild -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -configuration Debug \
  build
```

使用以下命令运行测试套件：

```sh
xcodebuild -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  test
```

欢迎参与贡献。请先阅读[贡献指南](CONTRIBUTING.md)、[行为准则](CODE_OF_CONDUCT.md)和[路线图](ROADMAP.md)。

## 项目文档

| 资源 | 用途 |
| --- | --- |
| [支持](SUPPORT.md) | 权限修复、诊断和常见问题。 |
| [架构](ARCHITECTURE.md) | 运行时边界、安全约束和事件流程。 |
| [隐私](PRIVACY.md) | 应用可以访问的内容，以及绝不会收集的信息。 |
| [安全](SECURITY.md) | 漏洞报告方式和发布验证。 |
| [治理](GOVERNANCE.md) | 维护者角色、审查策略和项目决策流程。 |
| [更新日志](CHANGELOG.md) | 版本历史和发布说明。 |
| [Scorecard 说明](docs/SCORECARD.md) | OpenSSF 状态、控制措施和当前限制。 |
| [发布流程](docs/RELEASING.md) | 面向维护者的发布和来源证明流程。 |

## 系统要求

- macOS 14 或更高版本
- 带中键或可点击滚轮的外接鼠标
- 辅助功能和输入监控权限

## 致谢

- 日语翻译审校：[uglykatsuki](https://github.com/uglykatsuki)

## 许可证

Mac Drag Scroll 采用 [MIT License](LICENSE) 开源。

<p align="center">
  由 <a href="https://martincalander.com">Martin Calander（马丁）</a> 制作。
</p>
