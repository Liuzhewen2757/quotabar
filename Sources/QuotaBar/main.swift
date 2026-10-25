import AppKit
import Foundation

private func diagnostic(_ text: String) {
    let data = (text + "\n").data(using: .utf8)!
    FileHandle.standardError.write(data)
}

@main
struct QuotaBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = QuotaBarDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class QuotaBarDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var windowLabel: NSTextField?
    private let model = UsageModel()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        diagnostic("QuotaBar: applicationDidFinishLaunching")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.toolTip = "Codex 额度"
        }

        createUsageWindow()
        model.onChange = { [weak self] in
            self?.refreshStatusItem()
        }
        refreshStatusItem()
        model.refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.model.refresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func refreshStatusItem() {
        statusItem?.button?.title = model.menuTitle
        statusItem?.menu = makeMenu()
        windowLabel?.stringValue = model.windowText
    }

    private func createUsageWindow() {
        let label = NSTextField(labelWithString: model.windowText)
        label.alignment = .center
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let refresh = NSButton(title: "立即刷新", target: self, action: #selector(refreshUsage))
        refresh.bezelStyle = .rounded

        let stack = NSStackView(views: [label, refresh])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 190),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Codex 额度"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = NSView()
        panel.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -24)
        ])
        panel.center()
        window = panel
        windowLabel = label
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let heading = NSMenuItem(title: "Codex 额度", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)

        if let primary = model.primary {
            addUsage(primary, title: "当前周期", to: menu)
        } else {
            let item = NSMenuItem(title: "缓存显示：剩余 (model.cachedRemaining)%*", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        if let secondary = model.secondary {
            addUsage(secondary, title: "短周期", to: menu)
        }
        if let credits = model.credits {
            let item = NSMenuItem(title: "Credits：\(credits)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        if let error = model.error {
            let item = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.attributedTitle = NSAttributedString(
                string: error,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
            menu.addItem(item)
        } else if let updated = model.lastUpdated {
            let text = "上次更新：\(updated.formatted(date: .omitted, time: .shortened))"
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let showWindow = NSMenuItem(title: "打开额度窗口", action: #selector(showUsageWindow), keyEquivalent: "")
        showWindow.target = self
        menu.addItem(showWindow)

        let refresh = NSMenuItem(title: model.isRefreshing ? "刷新中…" : "立即刷新", action: #selector(refreshUsage), keyEquivalent: "r")
        refresh.target = self
        refresh.isEnabled = !model.isRefreshing
        menu.addItem(refresh)

        let usage = NSMenuItem(title: "打开 Usage", action: #selector(openUsage), keyEquivalent: "")
        usage.target = self
        menu.addItem(usage)

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func addUsage(_ window: UsageWindow, title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: "\(title)：剩余 \(window.remaining)%", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)

        let reset = NSMenuItem(title: "重置：\(window.resetText)", action: nil, keyEquivalent: "")
        reset.isEnabled = false
        menu.addItem(reset)
    }

    @objc private func refreshUsage() {
        model.refresh()
    }

    @objc private func showUsageWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func openUsage() {
        NSWorkspace.shared.open(URL(string: "https://chatgpt.com/settings/usage")!)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

struct UsageWindow: Sendable {
    let remaining: Int
    let resetText: String
}

@MainActor
final class UsageModel {
    private(set) var primary: UsageWindow?
    private(set) var secondary: UsageWindow?
    private(set) var credits: String?
    private(set) var lastUpdated: Date?
    private(set) var error: String?
    private(set) var isRefreshing = false
    private(set) var cachedRemaining: Int
    var onChange: (() -> Void)?

    private let client = AppServerUsageClient()

    init() {
        let stored = UserDefaults.standard.integer(forKey: "codex.quotaBar.remaining")
        cachedRemaining = stored > 0 ? stored : 77
    }

    var menuTitle: String {
        if let primary { return "Codex \(primary.remaining)%" }
        return "Codex \(cachedRemaining)%*"
    }

    var windowText: String {
        var lines = [menuTitle]
        if let primary {
            lines.append("当前周期剩余：\(primary.remaining)%")
            lines.append("重置：\(primary.resetText)")
        } else {
            lines.append("缓存显示：\(cachedRemaining)%（* 表示尚未连上实时数据）")
        }
        if let error { lines.append(error) }
        if let lastUpdated {
            lines.append("更新：\(lastUpdated.formatted(date: .omitted, time: .shortened))")
        }
        return lines.joined(separator: "\n")
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        error = nil
        onChange?()

        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await client.read()
                diagnostic("QuotaBar: received rate limits")
                primary = snapshot.primary
                secondary = snapshot.secondary
                credits = snapshot.credits
                if let primary {
                    cachedRemaining = primary.remaining
                    UserDefaults.standard.set(primary.remaining, forKey: "codex.quotaBar.remaining")
                }
                lastUpdated = Date()
            } catch {
                diagnostic("QuotaBar: refresh failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
            isRefreshing = false
            onChange?()
        }
    }
}

struct UsageSnapshot: Sendable {
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let credits: String?
}

struct AppServerUsageClient: Sendable {
    func read() async throws -> UsageSnapshot {
        try await Task.detached(priority: .utility) {
            guard let codexPath = Self.findCodexPath() else {
                throw UsageError.message("找不到 ChatGPT.app 内的 Codex CLI；请先安装并登录 ChatGPT")
            }
            return try Self.readSync(codexPath: codexPath)
        }.value
    }

    private static func findCodexPath() -> String? {
        let relativePath = "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        let candidates = [
            "/Applications/ChatGPT.app/\(relativePath)",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/ChatGPT.app/\(relativePath)").path
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func readSync(codexPath: String) throws -> UsageSnapshot {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        // Start a short-lived local app-server instead of proxying through the
        // desktop control socket. The proxy socket is reserved for the desktop
        // app and rejects independent clients on newer Codex builds.
        process.arguments = ["app-server", "--stdio"]
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        try process.run()
        diagnostic("QuotaBar: started app-server pid=\(process.processIdentifier)")

        let state = ReadState()
        let done = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            let handle = output.fileHandleForReading
            while true {
                let chunk = handle.availableData
                guard !chunk.isEmpty else {
                    done.signal()
                    return
                }
                state.lock.lock()
                if state.cancelled {
                    state.lock.unlock()
                    return
                }
                state.buffer.append(chunk)
                let lines = String(decoding: state.buffer, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true)
                for line in lines {
                    let jsonData = Data(line.utf8)
                    guard let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        continue
                    }
                    if let errorObject = object["error"] as? [String: Any] {
                        state.responseError = UsageError.message((errorObject["message"] as? String) ?? "Codex app-server 返回错误")
                        done.signal()
                        break
                    }
                    if let id = object["id"] as? Int, id == 1, !state.handshakeSent {
                        state.handshakeSent = true
                        let followUps = [
                            #"{"method":"initialized","params":{}}"#,
                            #"{"id":2,"method":"account/rateLimits/read","params":{"excludeResetCreditDetails":true}}"#
                        ]
                        if !state.cancelled {
                            input.fileHandleForWriting.write(followUps.joined(separator: "\n").appending("\n").data(using: .utf8)!)
                            diagnostic("QuotaBar: sent initialized and rateLimits/read")
                        }
                    }
                    if let id = object["id"] as? Int, id == 2,
                       let result = object["result"] as? [String: Any] {
                        state.response = Self.parse(result)
                        done.signal()
                        break
                    }
                }
                state.lock.unlock()
            }
        }

        input.fileHandleForWriting.write(#"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"quotabar","version":"0.3.0"},"capabilities":{"experimentalApi":true}}}"#.appending("\n").data(using: .utf8)!)

        if done.wait(timeout: .now() + 20) == .timedOut {
            state.lock.lock()
            state.responseError = UsageError.message("Codex app-server 超时；请确认 ChatGPT/Codex 已打开并完成登录")
            state.lock.unlock()
        }
        state.lock.lock()
        state.cancelled = true
        state.lock.unlock()
        if process.isRunning { process.terminate() }
        input.fileHandleForWriting.closeFile()

        state.lock.lock()
        let result = state.response
        let failure = state.responseError
        state.lock.unlock()
        if let result { return result }
        if let failure { throw failure }
        let detail = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw UsageError.message(detail.isEmpty ? "Codex app-server 没有返回数据" : detail.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func parse(_ result: [String: Any]) -> UsageSnapshot {
        let limits = (result["rateLimits"] as? [String: Any]) ?? result
        let primary = parseWindow(limits["primary"] as? [String: Any])
        let secondary = parseWindow(limits["secondary"] as? [String: Any])
        let creditObject = limits["credits"] as? [String: Any]
        let credits: String? = {
            guard let creditObject else { return nil }
            if let unlimited = creditObject["unlimited"] as? Bool, unlimited { return "无限" }
            if let balance = creditObject["balance"] { return "\(balance)" }
            return nil
        }()
        return UsageSnapshot(primary: primary, secondary: secondary, credits: credits)
    }

    private static func parseWindow(_ value: [String: Any]?) -> UsageWindow? {
        guard let value, let used = value["usedPercent"] as? NSNumber else { return nil }
        let resetText: String
        if let timestamp = (value["resetsAt"] as? NSNumber)?.doubleValue {
            resetText = Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
        } else {
            resetText = "未知"
        }
        return UsageWindow(remaining: max(0, min(100, 100 - used.intValue)), resetText: resetText)
    }
}

private final class ReadState: @unchecked Sendable {
    let lock = NSLock()
    var buffer = Data()
    var handshakeSent = false
    var cancelled = false
    var response: UsageSnapshot?
    var responseError: Error?
}

enum UsageError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
