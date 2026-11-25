import Foundation

public struct SemanticVersion: Comparable, Equatable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init?( _ raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        let components = value.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard (1...3).contains(components.count) else { return nil }

        var numbers: [Int] = []
        for component in components {
            guard !component.isEmpty,
                  component.allSatisfy(\.isNumber),
                  let number = Int(component),
                  number >= 0 else {
                return nil
            }
            numbers.append(number)
        }
        while numbers.count < 3 {
            numbers.append(0)
        }

        self.major = numbers[0]
        self.minor = numbers[1]
        self.patch = numbers[2]
    }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}
