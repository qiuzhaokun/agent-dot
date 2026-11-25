import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}

final class TestHarness {
    private(set) var failures: [String] = []
    private(set) var passed = 0
    private(set) var currentTest = ""

    func run(_ name: String, _ body: () throws -> Void) {
        currentTest = name
        let failuresBefore = failures.count
        do {
            try body()
            if failures.count == failuresBefore {
                passed += 1
                print("PASS \(name)")
            } else {
                print("FAIL \(name): expectation(s) failed")
            }
        } catch {
            failures.append("\(name): \(error)")
            print("FAIL \(name): \(error)")
        }
    }

    func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
        let entry = "\(file):\(line): \(message)"
        failures.append("\(currentTest): \(entry)")
        print("  FAIL \(entry)")
    }

    func expect(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        if !condition {
            fail(message.isEmpty ? "expected true" : message, file: file, line: line)
        }
    }

    func expectEqual<T: Equatable>(
        _ lhs: T,
        _ rhs: T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if lhs != rhs {
            fail("expected \(lhs) == \(rhs). \(message)", file: file, line: line)
        }
    }

    func expectNil<T>(
        _ value: T?,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if value != nil {
            fail("expected nil, got \(String(describing: value)). \(message)", file: file, line: line)
        }
    }

    @discardableResult
    func expectNotNil<T>(
        _ value: T?,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) -> T? {
        if value == nil {
            fail("expected non-nil. \(message)", file: file, line: line)
        }
        return value
    }

    func finish() -> Int32 {
        print("")
        print("\(passed) passed, \(failures.count) failed")
        if !failures.isEmpty {
            for failure in failures {
                print("FAILED: \(failure)")
            }
            return 1
        }
        return 0
    }
}

let harness = TestHarness()

func runTest(_ name: String, _ body: () throws -> Void) {
    harness.run(name, body)
}

func expect(
    _ condition: Bool,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    harness.expect(condition, message, file: file, line: line)
}

func expectEqual<T: Equatable>(
    _ lhs: T,
    _ rhs: T,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    harness.expectEqual(lhs, rhs, message, file: file, line: line)
}

func expectNil<T>(
    _ value: T?,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    harness.expectNil(value, message, file: file, line: line)
}

@discardableResult
func expectNotNil<T>(
    _ value: T?,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) -> T? {
    harness.expectNotNil(value, message, file: file, line: line)
}

func unwrap<T>(
    _ value: T?,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) throws -> T {
    guard let value else {
        throw TestFailure(message: "\(file):\(line): \(message.isEmpty ? "expected non-nil" : message) (value was nil)")
    }
    return value
}

func expectThrows<T>(
    _ body: () throws -> T,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    do {
        _ = try body()
        harness.fail(message.isEmpty ? "expected an error" : message, file: file, line: line)
    } catch {
        // expected
    }
}

func expectNoThrow<T>(
    _ body: () throws -> T,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) -> T? {
    do {
        return try body()
    } catch {
        harness.fail(message.isEmpty ? "unexpected error: \(error)" : "\(message): \(error)", file: file, line: line)
        return nil
    }
}
