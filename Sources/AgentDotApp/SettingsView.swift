import AppKit
import SwiftUI
import AgentDotCore

struct SettingsView: View {
    @ObservedObject var viewModel: HUDViewModel
    let configStore: ConfigStore

    var body: some View {
        Form {
            Section {
                opacityRow(
                    title: "悬浮球背景",
                    value: viewModel.config.ballBackgroundOpacity
                ) { newValue in
                    var config = viewModel.config
                    config.ballBackgroundOpacity = newValue
                    update(config)
                }
                opacityRow(
                    title: "列表面板背景",
                    value: viewModel.config.listBackgroundOpacity
                ) { newValue in
                    var config = viewModel.config
                    config.listBackgroundOpacity = newValue
                    update(config)
                }
                Text("仅背景变透明，文字和按钮保持清晰；最小 10%。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("外观")
            }

            Section {
                Toggle(
                    "等待授权时播放提示音",
                    isOn: Binding(
                        get: { viewModel.config.authorizationSoundEnabled },
                        set: { enabled in
                            var config = viewModel.config
                            config.authorizationSoundEnabled = enabled
                            update(config)
                        }
                    )
                )
                soundPicker(
                    title: "等待授权声音",
                    selection: viewModel.config.authorizationSoundName,
                    enabled: viewModel.config.authorizationSoundEnabled
                ) { name in
                    var config = viewModel.config
                    config.authorizationSoundName = name
                    update(config)
                }

                Toggle(
                    "任务完成时播放提示音",
                    isOn: Binding(
                        get: { viewModel.config.completionSoundEnabled },
                        set: { enabled in
                            var config = viewModel.config
                            config.completionSoundEnabled = enabled
                            update(config)
                        }
                    )
                )
                soundPicker(
                    title: "任务完成声音",
                    selection: viewModel.config.completionSoundName,
                    enabled: viewModel.config.completionSoundEnabled
                ) { name in
                    var config = viewModel.config
                    config.completionSoundName = name
                    update(config)
                }
            } header: {
                Text("提醒")
            }

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
                Text("开机自启在安装为 AgentDot.app 后生效；应用运行中开启不会立刻启动第二个实例，下次登录生效。")
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
                Button("退出 AgentDot") {
                    NSApp.terminate(nil)
                }
            } header: {
                Text("维护")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .padding(12)
    }

    private func opacityRow(
        title: String,
        value: Double,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.rounded()))%")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                in: AppConfig.minBackgroundOpacity...AppConfig.maxBackgroundOpacity,
                step: 1
            )
        }
    }

    private func soundPicker(
        title: String,
        selection: String,
        enabled: Bool,
        onChange: @escaping (String) -> Void
    ) -> some View {
        Picker(
            title,
            selection: Binding(
                get: { selection },
                set: { onChange($0) }
            )
        ) {
            ForEach(soundOptions(current: selection), id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .pickerStyle(.menu)
        .disabled(!enabled)
    }

    private func soundOptions(current: String) -> [String] {
        var names = SystemSoundPlayer.soundNames
        if !names.contains(current) {
            names.insert(current, at: 0)
        }
        return names
    }

    private func update(_ config: AppConfig) {
        viewModel.updateConfig(config)
        try? configStore.save(config)
    }
}
