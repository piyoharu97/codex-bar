import Foundation

struct ReleaseVersion: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int
    init?(_ input: String) {
        let value = input.hasPrefix("v") ? String(input.dropFirst()) : input
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]), let minor = Int(parts[1]),
              let patch = Int(parts.count == 3 ? parts[2] : "0") else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
