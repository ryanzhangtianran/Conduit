# Conduit

<p align="center">
  <img src="assets/icons/icon-padded.png" width="120" alt="Conduit Logo">
</p>

<p align="center">
  <b>macOS 上的 SSH 服务器管理工具</b>
</p>

<p align="center">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License"></a>
  <a href="https://github.com/ryanzhangtianran/Conduit/releases"><img src="https://img.shields.io/github/v/release/ryanzhangtianran/Conduit" alt="Release"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · 简体中文
</p>

把 SSH 服务器的连接、终端、文件管理、监控和端口转发放进一个 macOS 原生窗口。
一切都走普通 SSH，服务器上不需要安装任何东西。

## 安装

从 [最新 release](https://github.com/ryanzhangtianran/Conduit/releases/latest)
下载 `Conduit.dmg`，打开后把 Conduit 拖进 **应用程序**。

本版本未经 Apple 公证：首次启动请右键点击应用选择 **打开**。

## 用法

**保险库** — 首次启动设置一个保险库密码。所有凭据都加密存储；用密码或
Touch ID 解锁（*设置 → 安全*）。

**服务器** — *仪表盘 → 添加服务器*：主机、用户名、密码或私钥，可选跳板机和
HTTP/SOCKS5 代理。已连接的服务器在仪表盘显示延迟、负载、内存、GPU 和运行
时间。在编辑器的 *SSH 密钥* 区域可以一键生成密钥对并安装到服务器。*连接*
页把服务器和 `~/.ssh/config` 里的 Host 放在一起，双向同步。

**终端** — *终端* 标签页选一台服务器。多标签、侧边栏、⌘F 查找、⌘+点击打开
链接、原生复制粘贴。*Shift+Tab* 打开命令面板。字体、字号、行高和配色在
*设置 → 终端*。

**文件** — 从终端侧边栏或命令面板打开服务器的文件管理器：双窗格（左侧本机
或另一台服务器，右侧当前服务器），拖放、跨窗格复制/剪切/粘贴、打包/解包，
内置编辑器支持文本、JSON、YAML、TOML。传输在后台进行，可暂停、取消。

**监控** — CPU、内存、GPU、网络、磁盘实时曲线，进程列表可直接结束进程。

**端口转发** — 本地、远程和 SOCKS5 隧道。保存的预设可在连接时自动启动并
自动保活；表格显示每条转发的流量。

**GitHub** — 设备流登录，固定仓库后监控 Actions 运行；有失败时标签页显示角标。

**备份** — *设置 → 同步*：以 Conduit 文件或 CSV 导入/导出连接，把整个保险库
导出为加密的 `.conduit` 备份，或在 iCloud 云盘自动保留最近十份备份。

**菜单栏** — 托盘图标显示连接状态，可直接连接、开终端、切换转发和退出。
关闭窗口只是隐藏，会话继续运行。

**更新** — *设置 → 关于* 会在 GitHub Releases 上检查新版本（启动后不久也会
自动检查，最多每六小时一次，可关闭），并可下载 DMG、原地替换应用并重新启动。

## 从源码构建

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

代码结构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 许可

[AGPL-3.0](LICENSE.txt)。Conduit 起源于 LittleSheep / Solsynth 的
[MaidKit](https://github.com/Solsynth/MaidKit)，按许可证要求保留此署名。
