import Foundation
@main struct ReleaseVersionTests {
    static func main() {
        assert(ReleaseVersion("v1.10.0")! > ReleaseVersion("1.9.9")!)
        assert(ReleaseVersion("v2.0")! > ReleaseVersion("1.99.99")!)
        assert(ReleaseVersion("1.6") == ReleaseVersion("v1.6.0"))
        assert(ReleaseVersion("1.6.1")! > ReleaseVersion("1.6.0")!)
        for value in ["", "1", "1.2.3.4", "1..2", "1.-1.0", "v1.6.1-beta", "1.2.3/../../", "1.2.3;open x", "https://example.com", "1.2.99999999999999999999999999999"] {
            assert(ReleaseVersion(value) == nil)
        }
        print("PASS: release version ordering, current-version normalization, malformed/prerelease rejection")
    }
}
