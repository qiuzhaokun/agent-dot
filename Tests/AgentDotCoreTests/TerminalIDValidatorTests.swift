import Foundation
import AgentDotCore

func runTerminalIDValidatorTests() {
    runTest("TerminalIDValidator validates tty") {
        expect(TerminalIDValidator.isValidTTY("/dev/ttys003"))
        expect(!TerminalIDValidator.isValidTTY("/dev/ttys003\"; do shell script \"rm -rf ~\""))
        expect(!TerminalIDValidator.isValidTTY("ttys003"))
    }

    runTest("TerminalIDValidator extracts iTerm UUID") {
        expectEqual(TerminalIDValidator.itermUUID(from: "w0t0p0:ABCD-1234"), "ABCD-1234")
        expectNil(TerminalIDValidator.itermUUID(from: "no-colon"))
        expectNil(TerminalIDValidator.itermUUID(from: "w0t0p0:"))
    }

    runTest("TerminalIDValidator validates pane and surface ids") {
        expect(TerminalIDValidator.isValidPaneID("3"))
        expect(!TerminalIDValidator.isValidPaneID("3; rm -rf ~"))
        expect(TerminalIDValidator.isValidSurfaceID("123456789"))
        expect(TerminalIDValidator.isValidSurfaceID("deadBEEF"))
        expect(!TerminalIDValidator.isValidSurfaceID("12ab; rm -rf ~"))
    }

    runTest("TerminalIDValidator escapes AppleScript strings") {
        let input = "a\"b\\c"
        expectEqual(TerminalIDValidator.escapeAppleScript(input), "a\\\"b\\\\c")
        expectEqual(TerminalIDValidator.escapeAppleScript("line1\nline2"), "line1line2")
        expectEqual(TerminalIDValidator.escapeAppleScript("a\tb\u{7}"), "ab")
    }
}
