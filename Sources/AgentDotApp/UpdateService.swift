import Foundation
import AppKit
import Combine
import CryptoKit
import AgentDotCore

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(UpdateManifest)
    case downloading(progress: Double)
    case verifying
    case installing
    case failed(String)
}

final class UpdateService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published private(set) var state: UpdateState = .idle

    private let configStore: ConfigStore
    private let feedURL: URL?
    private let updatePublicKey: String?
    private let currentVersion: SemanticVersion?
    private let currentVersionString: String
    private let fileManager = FileManager.default

    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var pendingManifest: UpdateManifest?
    private var pendingUpdatesDirectory: URL?
    private var timer: Timer?

    private var isConfigured: Bool {
        feedURL != nil
            && updatePublicKey?.isEmpty == false
            && currentVersion != nil
    }

    init(configStore: ConfigStore) {
        self.configStore = configStore
        let info = Bundle.main.infoDictionary
        self.feedURL = (info?["AgentDotUpdateFeedURL"] as? String)
            .flatMap(URL.init(string:))
        self.updatePublicKey = info?["AgentDotUpdatePublicKey"] as? String
        let versionString = info?["CFBundleShortVersionString"] as? String
        self.currentVersionString = versionString ?? "0.0.0-dev"
        self.currentVersion = versionString.flatMap(SemanticVersion.init)
        super.init()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 300
        configuration.httpAdditionalHeaders = [
            "User-Agent": "AgentDot/\(currentVersionString)"
        ]
        self.session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }

    deinit {
        timer?.invalidate()
        session?.invalidateAndCancel()
    }

    var versionString: String {
        currentVersionString
    }

    func startAutomaticChecks() {
        timer?.invalidate()
        timer = nil
        guard isConfigured else { return }

        let config = configStore.load()
        guard config.automaticUpdateChecks else { return }

        let now = Int64(Date().timeIntervalSince1970)
        if let last = config.lastUpdateCheckAt,
           now - last < 86_400 {
            scheduleTimer()
            return
        }

        check(manual: false)
        scheduleTimer()
    }

    func stopAutomaticChecks() {
        timer?.invalidate()
        timer = nil
    }

    func setAutomaticChecks(_ enabled: Bool) {
        var config = configStore.load()
        config.automaticUpdateChecks = enabled
        try? configStore.save(config)

        if enabled {
            startAutomaticChecks()
        } else {
            stopAutomaticChecks()
            if case .checking = state {
                state = .idle
            }
        }
    }

    func check(
        manual: Bool,
        completion: ((String) -> Void)? = nil
    ) {
        guard isConfigured, let feedURL, let currentVersion else {
            let message = "开发构建不支持更新检查"
            if manual {
                state = .failed(message)
                completion?(message)
            }
            return
        }
        if case .downloading = state { return }
        if case .verifying = state { return }
        if case .installing = state { return }
        if case .checking = state { return }

        if manual {
            state = .checking
        }

        var request = URLRequest(
            url: feedURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.finishCheck(
                    state: manual ? .failed("检查更新失败：\(error.localizedDescription)") : .idle,
                    message: "检查更新失败：\(error.localizedDescription)",
                    manual: manual,
                    completion: completion
                )
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                self.finishCheck(
                    state: .upToDate,
                    message: "暂无可用发布版本",
                    manual: manual,
                    completion: completion
                )
                return
            }
            guard let data,
                  let manifest = try? JSONDecoder().decode(
                    UpdateManifest.self,
                    from: data
                  ) else {
                self.finishCheck(
                    state: manual ? .failed("更新清单格式无效") : .idle,
                    message: "更新清单格式无效",
                    manual: manual,
                    completion: completion
                )
                return
            }

            let os = ProcessInfo.processInfo.operatingSystemVersion
            let macOS = SemanticVersion(
                major: os.majorVersion,
                minor: os.minorVersion,
                patch: os.patchVersion
            )

            do {
                try manifest.validate(
                    currentVersion: currentVersion,
                    macOSVersion: macOS
                )
            } catch UpdateManifestError.notNewer {
                self.recordCheckTime()
                self.finishCheck(
                    state: .upToDate,
                    message: "已是最新版本 \(currentVersion)",
                    manual: manual,
                    completion: completion
                )
                return
            } catch {
                self.finishCheck(
                    state: manual ? .failed(error.localizedDescription) : .idle,
                    message: error.localizedDescription,
                    manual: manual,
                    completion: completion
                )
                return
            }

            self.recordCheckTime()
            let config = self.configStore.load()
            if !manual, config.skippedUpdateVersion == manifest.version {
                self.finishCheck(
                    state: .idle,
                    message: "新版本 \(manifest.version) 已跳过",
                    manual: false,
                    completion: nil
                )
                return
            }

            self.finishCheck(
                state: .available(manifest),
                message: "发现新版本 \(manifest.version)",
                manual: manual,
                completion: completion
            )
        }.resume()
    }

    func upgrade() {
        guard case .available(let manifest) = state,
              isConfigured,
              let currentVersion else {
            return
        }

        let os = ProcessInfo.processInfo.operatingSystemVersion
        let macOS = SemanticVersion(
            major: os.majorVersion,
            minor: os.minorVersion,
            patch: os.patchVersion
        )
        do {
            try manifest.validate(
                currentVersion: currentVersion,
                macOSVersion: macOS
            )
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        do {
            let updatesDirectory = try prepareUpdatesDirectory(
                version: manifest.version
            )
            pendingManifest = manifest
            pendingUpdatesDirectory = updatesDirectory
        } catch {
            state = .failed("准备更新目录失败：\(error)")
            return
        }

        state = .downloading(progress: 0)
        let task = session.downloadTask(with: manifest.zipURL)
        downloadTask = task
        task.resume()
    }

    func skip(version: String) {
        var config = configStore.load()
        config.skippedUpdateVersion = version
        try? configStore.save(config)
        state = .idle
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected: Int64
        if totalBytesExpectedToWrite > 0 {
            expected = totalBytesExpectedToWrite
        } else {
            expected = Int64(pendingManifest?.size ?? 0)
        }
        let progress = expected > 0
            ? min(1, Double(totalBytesWritten) / Double(expected))
            : 0
        DispatchQueue.main.async {
            if case .downloading = self.state {
                self.state = .downloading(progress: progress)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let manifest = pendingManifest,
              let updatesDirectory = pendingUpdatesDirectory else {
            return
        }

        let zipURL = updatesDirectory.appendingPathComponent("AgentDot.zip")
        do {
            if fileManager.fileExists(atPath: zipURL.path) {
                try fileManager.removeItem(at: zipURL)
            }
            try fileManager.moveItem(at: location, to: zipURL)
        } catch {
            fail("保存更新包失败：\(error)")
            return
        }

        DispatchQueue.main.async {
            self.state = .verifying
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.verifyAndInstall(
                zipURL: zipURL,
                updatesDirectory: updatesDirectory,
                manifest: manifest
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard task === downloadTask, let error else { return }
        if case .downloading = state {
            fail("下载失败：\(error.localizedDescription)")
        }
    }

    private func verifyAndInstall(
        zipURL: URL,
        updatesDirectory: URL,
        manifest: UpdateManifest
    ) {
        guard let data = try? Data(contentsOf: zipURL) else {
            fail("无法读取更新包")
            return
        }
        guard data.count == manifest.size else {
            fail("更新包大小不一致（期望 \(manifest.size)，实际 \(data.count)）")
            return
        }

        let digest = SHA256.hash(data: data)
        let sha256 = digest.map { String(format: "%02x", $0) }.joined()
        guard sha256 == manifest.sha256.lowercased() else {
            fail("更新包 SHA256 校验失败")
            return
        }
        guard let publicKey = updatePublicKey,
              UpdateSignature.verify(
                fileData: data,
                signatureBase64: manifest.signature,
                publicKeyBase64: publicKey
              ) else {
            fail("更新包签名校验失败")
            return
        }

        let extractDirectory = updatesDirectory
            .appendingPathComponent("Extracted", isDirectory: true)
        try? fileManager.removeItem(at: extractDirectory)
        do {
            try fileManager.createDirectory(
                at: extractDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            fail("创建解压目录失败：\(error)")
            return
        }

        let dittoStatus = runProcess(
            "/usr/bin/ditto",
            ["-x", "-k", zipURL.path, extractDirectory.path]
        )
        guard dittoStatus == 0 else {
            fail("解压更新包失败")
            return
        }

        let newApp = extractDirectory.appendingPathComponent("AgentDot.app")
        let newInfo = NSDictionary(
            contentsOf: newApp.appendingPathComponent("Contents/Info.plist")
        )
        guard newInfo?["CFBundleIdentifier"] as? String == "dev.agentdot.app",
              newInfo?["CFBundleShortVersionString"] as? String == manifest.version else {
            fail("更新包内容校验失败")
            return
        }

        let currentApp = Bundle.main.bundleURL
        let currentPath = currentApp.standardizedFileURL.path
        let homeApplications = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .standardizedFileURL
            .path
        guard currentApp.pathExtension == "app",
              currentPath.hasPrefix(homeApplications + "/") else {
            fail("请先将 AgentDot 安装到 ~/Applications 再自动更新")
            return
        }
        guard fileManager.isWritableFile(
            atPath: currentApp.deletingLastPathComponent().path
        ) else {
            fail("当前安装位置不可写，请将 AgentDot 移到 ~/Applications")
            return
        }

        let backupDirectory = AgentDotPaths.stateDirectory
            .appendingPathComponent("Backups", isDirectory: true)
        do {
            try UpdaterEngine().install(
                currentApp: currentApp,
                newApp: newApp,
                expectedVersion: manifest.version,
                backupDirectory: backupDirectory
            )
        } catch {
            fail("自动安装失败：\(error)。请手动下载 DMG。")
            return
        }

        AppInstaller.removeQuarantine(at: currentApp)
        DispatchQueue.main.async {
            self.state = .installing
            AppInstaller.relaunch(currentApp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }

    private func prepareUpdatesDirectory(version: String) throws -> URL {
        let root = AgentDotPaths.stateDirectory
            .appendingPathComponent("Updates", isDirectory: true)
        let directory = root.appendingPathComponent(version, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func recordCheckTime() {
        var config = configStore.load()
        config.lastUpdateCheckAt = Int64(Date().timeIntervalSince1970)
        try? configStore.save(config)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 86_400, repeats: true) { [weak self] _ in
            self?.check(manual: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func finishCheck(
        state: UpdateState,
        message: String,
        manual: Bool,
        completion: ((String) -> Void)?
    ) {
        DispatchQueue.main.async {
            self.state = state
            completion?(message)
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.state = .failed(message)
        }
    }

    private func runProcess(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
