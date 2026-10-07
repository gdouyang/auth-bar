# AuthBar for Mac (macOS 原生菜单栏身份验证器)

**AuthBar** 是一款专为 macOS 设计的轻量、现代化双重认证（2FA / TOTP）工具。它常驻在屏幕顶部的系统菜单栏，随时随地一键复制动态验证码。

---

## ✨ 核心特性

- 🚀 **极简 Mac 原生体验**：基于 Swift 6 + SwiftUI + AppKit 开发，超轻量，秒开且极度省电省内存。
- 📌 **常驻顶部菜单栏**：点击菜单栏盾牌图标随时展开面板，不占用 Dock 栏空间。
- 🔍 **屏幕二维码一键识别**：网页上开启 2FA 出现二维码时，点击「一键识别屏幕二维码」，免掏手机扫码直接抓取导入！
- 📋 **智能剪贴板感知**：支持 `Cmd+V` 快速粘贴，支持一键从剪贴板自动解析并填入密钥或 `otpauth://` 链接。
- 📲 **支持 Google 迁移码导入**：完整支持 Google Authenticator 手机端「转移账户」导出的二维码格式（`otpauth-migration://` Protobuf 解码）。
- ⏱️ **平滑倒计时进度环**：30 秒精准倒计时动画，剩余时间小于 8 秒橙色预警、小于 4 秒红色告警。
- 📋 **一键复制与快捷操作**：单击验证码或复制按钮直接拷贝并展示反馈动画；支持复制后自动收起弹窗。
- 🔎 **实时搜索与置顶**：支持按服务商（Issuer）或账户名快速过滤，支持将常用账户置顶。
- 🔒 **Touch ID / 密码安全锁定**：支持调用 macOS 系统的 Touch ID 指纹或锁屏密码解锁，防止他人窥视。
- 💾 **数据备份与恢复**：支持一键导出与导入标准 JSON 格式数据。
- ✅ **100% RFC 标准兼容**：通过 RFC 6238 (TOTP) 及 RFC 4226 (HOTP) 标准测试向量验证，支持 SHA1 / SHA256 / SHA512 与 6 位 / 8 位动态码。

---

## 🏗️ 目录结构

```
google_auth/
├── Package.swift                    # Swift Package Manager 配置
├── AuthBar.app                      # 已打包好的 macOS 应用程序
├── Sources/
│   └── google_auth/
│       ├── Main.swift              # 程序入口与 NSStatusBar 菜单栏挂载
│       ├── Core/
│       │   ├── Base32.swift        # RFC 4648 Base32 编解码
│       │   ├── OTPGenerator.swift  # RFC 6238 TOTP / RFC 4226 HOTP 核心生成器
│       │   ├── OTPAuthURL.swift    # otpauth:// 链接解析与构建
│       │   ├── GoogleMigrationDecoder.swift # Google 迁移二维码 Protobuf 解码
│       │   └── StorageManager.swift# 本地安全存储 (0600 POSIX 权限)
│       ├── Models/
│       │   ├── AccountItem.swift   # 账户数据模型与品牌图标/配色
│       │   └── AppSettings.swift   # 应用配置
│       ├── Services/
│       │   ├── AccountManager.swift# 核心业务管理（倒计时、搜索、剪贴板等）
│       │   ├── BarcodeScanner.swift# Vision 框架二维码识别（屏幕截图/图片）
│       │   └── BiometricAuth.swift # Touch ID / LocalAuthentication 指纹认证
│       └── Views/
│           ├── MenuBarView.swift   # 菜单栏主弹窗视图
│           ├── AccountRowView.swift# 账户卡片与复制交互
│           ├── AddAccountSheet.swift# 添加账户窗口（扫码/手动/URI）
│           ├── EditAccountSheet.swift# 编辑账户窗口
│           ├── SettingsView.swift  # 设置窗口与备份恢复
│           └── CircularTimerView.swift # 倒计时环形进度动画
├── scripts/
│   ├── build_app.sh                # 编译 Release 并打包 .app 脚本
│   └── create_icon.swift           # 原生 App 图标生成脚本
└── Tests/
    └── google_authTests/
        └── google_authTests.swift  # RFC 测试向量与单元测试
```

---

## 🛠️ 编译与运行

### 1. 运行测试
```bash
swift test
```

### 2. 编译并打包 `.app`
```bash
./scripts/build_app.sh
```
打包成功后，将在当前目录生成 `AuthBar.app`。

### 3. 安装到系统应用程序
你可以直接将生成的 `AuthBar.app` 拖入 `/Applications`（应用程序）目录中：
```bash
cp -R "AuthBar.app" /Applications/
```

### 4. 启动应用
```bash
open "AuthBar.app"
```
启动后，macOS 顶部菜单栏右上角将出现一个蓝白色盾牌图标。

---

## 💡 使用指南

1. **添加双重认证账户**：
   - **屏幕一键扫码**：在浏览器打开包含 2FA 二维码的网页，点击菜单栏应用右上角的 `[扫码]` 按钮，即可自动从屏幕中捕获并识别添加。
   - **剪贴板智能添加**：复制密钥后，点击 `[剪贴板]` 图标或在添加界面点击「从剪贴板粘贴」，程序会自动识别并填入。
   - **手机迁移**：在手机端 Google Authenticator 中选择「转移账户 -> 导出账户」，把生成的二维码截图或显示在屏幕上，点击屏幕识别或选择图片即可一次性导入所有账户。
   - **手动添加**：点击 `[+]` 按钮，选择「手动输入」录入密钥（Secret Key）。
   - **URI 导入**：支持粘贴标准的 `otpauth://...` 链接。

2. **复制验证码**：
   - 鼠标点击任意账户右侧的复制图标，或右键选择「复制验证码」，即可复制到系统剪贴板。

3. **安全锁定与设置**：
   - 点击右上角齿轮图标进入偏好设置，可启用「Touch ID / 密码解锁」以及「复制后自动关闭弹窗」等选项。
