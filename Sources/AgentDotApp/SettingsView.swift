import AppKit
import SwiftUI
import AgentDotCore

struct SettingsView: View {
    @ObservedObject var viewModel: HUDViewModel
    let configStore: ConfigStore

    var body: some View {
        Form {
            Section {
                Stepper(
                    value: Binding(
                        get: { viewModel.config.thresholdN },
                        set: { newValue in
                            var config = viewModel.config
                            config.thresholdN = newValue
                            update(config)
                        }
                    ),
                    in: 1...9
                ) {
                    Text("超过 \(viewModel.config.thresholdN) 个会话时，小球显示数字（最多 9 个小点）")
                }
            } header: {
                Text("显示")
            }

            Section {
                Toggle(
                    "开机自启",
                    isOn: Binding(
                        get: { viewModel.config.launchAtLogin },
                        set: { newValue in
                            if newValue {
                                let appPath = Bundle.main.bundleURL
                                guard appPath.pathExtension == "app" else {
                                    viewModel.settingsStatus = "请先安装 AgentDot.app 再开启自启"
                                    return
                                }
                                do {
                                    try LaunchAtLogin.enable(appPath: appPath)
                                    var config = viewModel.config
                                    config.launchAtLogin = true
                                    update(config)
                                } catch {
                                    viewModel.settingsStatus = "开启自启失败：\(error)"
                                }
                            } else {
                                try? LaunchAtLogin.disable()
                                var config = viewModel.config
                                config.launchAtLogin = false
                                update(config)
                            }
                        }
                    )
                )
                Text("开机自启在安装为 AgentDot.app 后生效。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("启动")
            }

            Section {
                Text("当前版本 \(viewModel.currentVersionString)")
                Toggle(
                    "自动检查更新",
                    isOn: Binding(
                        get: { viewModel.config.automaticUpdateChecks },
                        set: { enabled in
                            var config = viewModel.config
                            config.automaticUpdateChecks = enabled
                            update(config)
                            viewModel.setAutomaticUpdateChecks(enabled)
                        }
                    )
                )
                Button("检查更新") {
                    viewModel.checkForUpdates(manual: true)
                }
                if !viewModel.updateStatusText.isEmpty {
                    Text(viewModel.updateStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("更新")
            }

            Section {
                Button("修复 Claude Code Hooks") {
                    viewModel.repairHooks()
                }
                Button("打开状态目录") {
                    NSWorkspace.shared.open(AgentDotPaths.stateDirectory)
                }
                if !viewModel.settingsStatus.isEmpty {
                    Text(viewModel.settingsStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("AgentDot \(viewModel.currentVersionString) · 跳转需要自动化权限")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("维护")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .padding(12)
    }

    private func update(_ config: AppConfig) {
        viewModel.updateConfig(config)
        try? configStore.save(config)
    }
}
