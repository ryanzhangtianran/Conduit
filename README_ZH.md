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

---

Conduit 是一款 macOS 原生应用，把 SSH 服务器的连接管理、终端、端口转发、
文件管理和系统监控整合在一处。日常管理完全基于 SSH——不在服务器上安装任何东西。

基于 [Solsynth MaidKit](https://github.com/Solsynth/MaidKit) 二次开发。

---

## 功能

### 连接管理

- 服务器仪表盘：实时状态、SSH 往返延迟、负载、内存、GPU、运行时间
- 凭据直接存放在服务器条目中（密码或私钥），私钥永不回显
- **跳板机**（可链式）与按服务器配置的 **HTTP CONNECT / SOCKS5 代理**
- 与本地 `~/.ssh/config` **双向同步**：表格化管理 Host 条目，
  可把已保存的服务器写入配置文件，也可从中导入主机
- 连接的导入/导出（Conduit 文件），整库加密备份（`.conduit`）

### SSH 密钥

- 一键生成密钥对（`ed25519` / `rsa` / `ecdsa`）并把公钥安装到服务器——
  复用当前会话，经跳板机的服务器同样可用
- 同服务器同类型幂等：重新生成会在本地替换旧密钥对，
  并清除服务器 `authorized_keys` 里的旧行
- 本地/远端存放路径可配置，权限自动设置（600/644/700）

### 终端

- libghostty-vt 渲染器，独立的字体、字号、行高设置
- 会话侧边栏、活动指示、工作目录跟踪
- Nerd Font 图标完整显示
- ⌘+点击终端里的 URL（纯文本或 OSC 8 超链接）在浏览器中打开

### 端口转发

- 本地 / 远程 / SOCKS5 隧道
- 预设连接时自动启动，断开后自动重建（keep-alive 监督）
- 统一的转发管理表格：状态、活跃连接数、实时流量

### 监控

- 实时活动曲线：CPU、内存、GPU（`nvidia-smi`）、网络、磁盘
- 进程管理、双栏 SFTP 文件管理（含内置编辑器）

### 安全

- AES-GCM 256 位加密保险库，PBKDF2 密钥派生
- Touch ID 解锁
- 加密备份到 iCloud 云盘，可在你的任意 Mac 上恢复

---

## 安装

从[最新 Release](https://github.com/ryanzhangtianran/Conduit/releases)
下载 `Conduit.dmg`，挂载后把 Conduit 拖入「应用程序」。

> 首次打开如提示「无法验证开发者」，请**右键 → 打开**（此构建未经 Apple 公证）。

---

## 从源码构建

需要 macOS 与 [Flutter SDK](https://flutter.dev)（^3.12.2）。

```bash
flutter pub get
flutter run -d macos          # 调试运行
flutter build macos --release # 发布构建
```

修改路由注解或 Drift 表结构后：

```bash
dart run build_runner build
```

提交前检查：

```bash
dart format lib test
flutter analyze
flutter test
```

---

## 架构

功能模块平铺在 `lib/<feature>/` 下：

- **Riverpod** 状态管理
- **auto_route** 路由
- **Drift**（SQLite）本地持久化
- **dartssh2** SSH 连接
- **flterm / libghostty-vt** 终端渲染（随仓库携带于 `packages/`）

---

## 许可

本项目采用 GNU Affero 通用公共许可证 v3.0（AGPL-3.0）。部署、二次开发或
分发修改版本须遵守其条款，包括保留版权声明并提供对应源代码。

Conduit 基于 MaidKit 开发；LittleSheep、Solsynth 及该项目贡献者的原始署名
与版权归属在适用处予以保留。完整文本见 [LICENSE.txt](./LICENSE.txt)。
