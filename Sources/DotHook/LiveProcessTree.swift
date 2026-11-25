import Foundation
import Darwin
import AgentDotCore

final class LiveProcessTree: ProcessTreeProviding {
    private struct Entry {
        var ppid: Int32
        var name: String
        var tdev: dev_t
    }

    private var entries: [Int32: Entry] = [:]
    private var pathCache: [Int32: String?] = [:]
    private var ttyCache: [Int32: String?] = [:]
    private let lock = NSLock()
    private var loaded = false

    init() {}

    func parentPID(of pid: Int32) -> Int32? {
        entry(pid)?.ppid
    }

    func processName(of pid: Int32) -> String? {
        entry(pid)?.name
    }

    func executablePath(of pid: Int32) -> String? {
        lock.lock()
        if let cached = pathCache[pid] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let path = Self.executablePath(pid: pid)
        lock.lock()
        pathCache[pid] = path
        lock.unlock()
        return path
    }

    func commandLine(of pid: Int32) -> String? {
        entry(pid)?.name
    }

    func tty(of pid: Int32) -> String? {
        lock.lock()
        if let cached = ttyCache[pid] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let entry = entry(pid), entry.tdev > 0 else {
            lock.lock()
            ttyCache[pid] = String?.none
            lock.unlock()
            return nil
        }

        let tty = devname(entry.tdev, mode_t(S_IFCHR))
            .map { String(cString: $0) }
        lock.lock()
        ttyCache[pid] = tty
        lock.unlock()
        return tty
    }

    private func entry(_ pid: Int32) -> Entry? {
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return entries[pid]
    }

    private func ensureLoaded() {
        lock.lock()
        if loaded {
            lock.unlock()
            return
        }
        loaded = true
        lock.unlock()
        reload()
    }

    private func reload() {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else {
            return
        }

        var processes: [kinfo_proc] = []
        for _ in 0..<2 {
            let count = size / MemoryLayout<kinfo_proc>.stride
            processes = [kinfo_proc](
                repeating: kinfo_proc(),
                count: max(count, 1)
            )
            if sysctl(&mib, 4, &processes, &size, nil, 0) == 0 {
                break
            }
            size = size + size / 8
        }
        guard !processes.isEmpty else { return }

        var map: [Int32: Entry] = [:]
        for process in processes {
            let pid = process.kp_proc.p_pid
            guard pid > 0 else { continue }

            let name = withUnsafePointer(to: process.kp_proc.p_comm) { pointer in
                pointer.withMemoryRebound(
                    to: CChar.self,
                    capacity: MemoryLayout.size(ofValue: process.kp_proc.p_comm)
                ) {
                    String(cString: $0)
                }
            }
            map[pid] = Entry(
                ppid: Int32(process.kp_eproc.e_ppid),
                name: name,
                tdev: process.kp_eproc.e_tdev
            )
        }

        lock.lock()
        entries = map
        lock.unlock()
    }

    private static func executablePath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }
}
