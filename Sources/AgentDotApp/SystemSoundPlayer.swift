import AppKit

/// 播放 macOS 系统提示音；同一类提醒 1 秒内最多播放一次，避免多会话叠音。
final class SystemSoundPlayer {
    static let soundNames: [String] = {
        let directory = "/System/Library/Sounds"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        let names = files
            .filter { $0.hasSuffix(".aiff") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()
        return names.isEmpty ? ["Glass", "Ping"] : names
    }()

    private var lastPlayedAt: [String: Date] = [:]

    func play(name: String, kind: String) {
        let now = Date()
        if let last = lastPlayedAt[kind],
           now.timeIntervalSince(last) < 1 {
            return
        }
        lastPlayedAt[kind] = now

        guard let sound = NSSound(named: NSSound.Name(name)) else {
            NSSound.beep()
            return
        }
        sound.play()
    }
}
