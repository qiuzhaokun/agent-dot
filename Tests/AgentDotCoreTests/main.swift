import Foundation

let filters = Array(CommandLine.arguments.dropFirst())

func shouldRun(_ name: String) -> Bool {
    filters.isEmpty || filters.contains(name)
}

if shouldRun("SessionState") {
    runSessionStateTests()
}

if shouldRun("StateReducer") {
    runStateReducerTests()
}

if shouldRun("SessionFileStore") {
    runSessionFileStoreTests()
}

if shouldRun("TerminalContext") {
    runTerminalContextTests()
}

if shouldRun("TerminalIDValidator") {
    runTerminalIDValidatorTests()
}

if shouldRun("SettingsMerger") {
    runSettingsMergerTests()
}

if shouldRun("AppConfig") {
    runAppConfigTests()
}

if shouldRun("SessionVisibility") {
    runSessionVisibilityTests()
}

if shouldRun("UIStateStore") {
    runUIStateStoreTests()
}

if shouldRun("AcknowledgmentPolicy") {
    runAcknowledgmentPolicyTests()
}

if shouldRun("AcknowledgmentStatePolicy") {
    runAcknowledgmentStatePolicyTests()
}

if shouldRun("SessionVisibilityTracker") {
    runSessionVisibilityTrackerTests()
}

if shouldRun("KakuActivePaneParser") {
    runKakuActivePaneParserTests()
}

if shouldRun("SessionNameResolver") {
    runSessionNameResolverTests()
}

if shouldRun("SessionReminderScheduler") {
    runSessionReminderSchedulerTests()
}

if shouldRun("Update") {
    runUpdateTests()
}

exit(harness.finish())
