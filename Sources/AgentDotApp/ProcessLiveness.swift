import Foundation
import Darwin
import AgentDotCore

protocol ProcessLivenessProviding {
    func isAlive(pid: Int32, expectedExecPath: String?) -> Bool
}

struct LiveProcessLiveness: ProcessLivenessProviding {
    func isAlive(pid: Int32, expectedExecPath: String?) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) != 0 && errno != EPERM {
            return false
        }
        guard let expectedExecPath, !expectedExecPath.isEmpty else {
            return true
        }

        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return false }
        let actual = String(cString: buffer)
        if actual == expectedExecPath {
            return true
        }
        return URL(fileURLWithPath: actual).lastPathComponent
            == URL(fileURLWithPath: expectedExecPath).lastPathComponent
    }
}
