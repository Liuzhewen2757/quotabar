# QuotaBar

macOS 菜单栏额度查看器。它每 60 秒通过本机 Codex app-server 的标准输入输出接口读取 `account/rateLimits/read`，菜单栏显示当前周期剩余百分比；点击后可立即刷新、打开额度窗口或打开官方 Usage 页面。

## 构建

在 macOS 上运行：

```bash
./build-app.sh
```

脚本会生成兼容 macOS 13+ 的 Intel/Apple 芯片通用应用 `QuotaBar.app`。

运行：

双击 `QuotaBar.app`，或在终端执行 `open QuotaBar.app`。启动后不会自动弹出窗口，点击菜单栏的 `Codex …%`，再选择“打开额度窗口”即可查看详情。

如果旧版本曾解压为 `QuotaBar 2.app`，请改用最新压缩包中的标准 `QuotaBar.app`。

若显示“找不到 ChatGPT.app 内的 Codex CLI”，请先安装并登录 ChatGPT。应用会依次检查 `/Applications/ChatGPT.app` 和 `~/Applications/ChatGPT.app`。

## 下载

GitHub 上提供已校验的通用版压缩包：[QuotaBar-0.4.0-macOS-universal.zip](https://github.com/Liuzhewen2757/quotabar/raw/main/dist/QuotaBar-0.4.0-macOS-universal.zip)。下载后解压并打开 `QuotaBar.app`；校验值见同目录的 `.sha256` 文件。

## 说明

额度和重置时间来自 Codex 当前登录账号。工具只读取额度，不保存或输出认证令牌。官方 Usage 页面仍是最终核对来源。

## Release

运行 `./release.sh` 会先校验 App，再生成 `dist/QuotaBar-<version>-macOS-universal.zip` 和对应的 SHA-256 文件。这个包使用本地 ad-hoc 签名，适合个人测试或 GitHub 的源码/测试发布；正式分发需要 Developer ID 签名和公证。

## App Store 状态

当前实现依赖本机已安装的 ChatGPT/Codex CLI，并启动本地 `app-server` 子进程。Mac App Store 的沙盒和审核要求需要单独的分发目标、Apple Developer 签名以及对本地 Codex 集成方式的审核确认，不能直接把这个 ad-hoc 包上传到 App Store。准备流程记录在 `docs/app-store.md`。
