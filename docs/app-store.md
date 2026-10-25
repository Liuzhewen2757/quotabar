# Mac App Store 发布准备

## 当前状态

QuotaBar 目前可以生成通用的 macOS 菜单栏 App，但本地构建脚本使用 ad-hoc 签名。它还会启动 `/Applications/ChatGPT.app` 内置的 Codex CLI，并读取登录用户的本地额度。这个运行方式适合 GitHub 或个人安装，不能直接作为 Mac App Store 版本提交。

当前构建的 Bundle ID 是 `local.codex.quotabar.v6`，`build-app.sh` 生成的是 arm64/x86_64 通用包并用 `codesign --sign -` 做临时签名。临时签名没有 Team ID、App Store provisioning profile 或 App Sandbox entitlement；它不等同于 App Store 分发签名。

## 最关键的技术阻塞

App Store 版本不能只给现有包加一份 entitlements 文件。当前程序在运行时：

1. 搜索另一个 App（ChatGPT.app）包内的私有 Codex CLI；
2. 启动这个外部 CLI 的 `app-server --stdio` 子进程；
3. 通过该子进程取得当前登录账号的 `account/rateLimits/read` 结果。

启用 App Sandbox 后，应用不能把 ChatGPT.app 内部 CLI、其登录状态或 `~/.codex` 数据当作自己的稳定 API。即使加入 `com.apple.security.app-sandbox`、网络客户端或用户选择文件权限，也不能把另一个产品的私有实现变成可审核的 App Store 集成。把当前二进制直接用 App Store 证书重签，只会把问题推迟到运行时或审核阶段。

因此需要先选一种受支持的集成方案：

- 由 ChatGPT/Codex 提供正式的本地 IPC/API，并让 QuotaBar 只调用该接口；或
- 由 QuotaBar 在沙盒内使用官方远程 Usage 接口，并让用户在应用内完成合法授权；或
- 明确采用用户选择的文件夹/文件、security-scoped bookmark 等沙盒授权机制，并确认数据源和登录凭证允许这种访问。

在方案确定前，不要添加一个“看起来像 App Store”的 entitlement 实验目标：它会使当前可工作的本地 CLI 读取失败，却不能解决审核阻塞。

## 必需条件

1. Apple Developer Program 账号和已安装的 Mac App Distribution 证书/私钥。
2. 一个确定的 App Store Bundle ID，以及对应的 App Store Connect App 记录。
3. 一个经过沙盒审核的本地 Codex 集成方案。App Store 沙盒不能默认执行任意外部 CLI，也不能直接读取用户的 `~/.codex` 和 `/Applications/ChatGPT.app` 内部文件。
4. App Store Connect 的应用名称、描述、隐私政策 URL、支持 URL、分类、价格/可用地区和截图。

## 可自动完成与必须人工完成

仓库内可以自动完成：源码、README、许可证、构建脚本、通用 GitHub release zip、SHA-256、GitHub Actions，以及沙盒改造后的本地归档命令。以下事项必须在用户自己的 Apple Developer 账号中完成，不能由脚本代办：

- 在 Xcode 登录 Apple ID，并让系统生成或安装有效的开发/分发签名身份；
- 在 Certificates, Identifiers & Profiles 中注册正式的反向域名 Bundle ID（不要继续使用 `local.*`）；
- 创建 App Store Connect App 记录、同意协议、设置税务/银行信息和应用元数据；
- 选择 Mac App Store 分发证书与 provisioning profile，并在 Xcode/Transporter 中上传；
- 提供隐私政策、支持网址、截图和审核备注。

登录后可用下面的只读检查确认环境已具备签名身份（不代表已具备 App Store 记录）：

```bash
security find-identity -v -p codesigning
xcodebuild -version
```

如果第一条命令仍显示 `0 valid identities found`，当前机器还不能生成可上传的签名包。

## 提交流程

完成沙盒改造后，在 Mac App Store 专用构建配置中：

1. 使用正式 Bundle ID、版本号和签名证书构建 universal App。
2. 用 `codesign` 验证签名和 entitlements。
3. 用 `xcodebuild -archive` 生成归档，并用 `xcodebuild -exportArchive` 导出上传包。
4. 用 Xcode Organizer 或 Transporter 上传到 App Store Connect。
5. 在 App Store Connect 填完元数据，提交 TestFlight 审核，再提交 App Review。

在没有 Apple 账号、签名身份和沙盒目标之前，不要把本地 ad-hoc zip 改名成 App Store 包上传。

## 两条分发线

在沙盒架构完成前，建议保持两条明确的产物线：

- GitHub/个人安装：沿用当前菜单栏程序和本地 app-server 集成；使用 Developer ID + notarization（或当前 ad-hoc 包用于测试），并在 release 说明中写明需要安装并登录 ChatGPT。
- Mac App Store：单独的沙盒 target、正式 Bundle ID、App Store provisioning profile 和商店元数据；只能在新的受支持数据源实现后构建。

两条产物不要共用“重签即可上传”的假设，也不要把用户认证令牌或 ChatGPT.app 私有文件复制进仓库或发布包。
