import Foundation

/// Claude Code 需要用户介入的状态标识（写入 SessionState.notificationType）。
public enum SessionAttention {
    /// 工具执行超过阈值仍未返回，可能正在等待系统/IDE 授权。
    public static let externalWait = "external_wait"
    /// Stop 时检测到 Claude 的最后回复在向用户提问。
    public static let plainQuestion = "plain_question"
    /// AskUserQuestion 工具等待用户选择。
    public static let userQuestion = "user_question"
    /// ExitPlanMode 等待用户批准计划。
    public static let planApproval = "plan_approval"
    /// MCP elicitation 弹窗（普通 / URL）。
    public static let elicitationDialog = "elicitation_dialog"
    public static let elicitationURLDialog = "elicitation_url_dialog"
    public static let workerPermissionPrompt = "worker_permission_prompt"

    /// 工具执行超过该秒数仍未返回时提示可能正在等待授权。
    public static let externalWaitThreshold: Int64 = 7

    /// 这些状态不依赖「终端标签是否激活」自动消警，必须等工具结束或用户手动忽略。
    public static func requiresManualAcknowledgment(_ notificationType: String?) -> Bool {
        notificationType == externalWait || notificationType == plainQuestion
    }

    public static func isElicitation(_ notificationType: String?) -> Bool {
        notificationType == elicitationDialog
            || notificationType == elicitationURLDialog
            || notificationType == workerPermissionPrompt
    }
}

public extension SessionState {
    /// 运行中的工具长时间未返回时，推导为「等待外部处理」。
    func applyingExternalWaitAttention(now: Int64) -> SessionState {
        guard state == .running,
              currentTool != nil,
              lastActivityAt > 0,
              now - lastActivityAt >= SessionAttention.externalWaitThreshold else {
            return self
        }
        var copy = self
        copy.state = .waitingPermission
        copy.notificationType = SessionAttention.externalWait
        copy.waitingSince = lastActivityAt
        return copy
    }

    /// Stop 后若最后一条回复是在向用户提问，则不要标记为已完成。
    func applyingPlainQuestionAttention(now: Int64, isQuestion: Bool) -> SessionState {
        guard isQuestion, state == .done else { return self }
        var copy = self
        copy.state = .waitingPermission
        copy.notificationType = SessionAttention.plainQuestion
        copy.waitingSince = now
        copy.turnEndedAt = now
        copy.currentTool = nil
        copy.lastActivityAt = now
        return copy
    }
}
