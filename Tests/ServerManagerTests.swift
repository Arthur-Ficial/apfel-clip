import Testing
@testable import apfel_clip

@Suite("ServerManager")
struct ServerManagerTests {
    @Test("findBinary finds swift in PATH")
    func findBinary() {
        #expect(ServerManager.findBinary(named: "swift") != nil)
    }

    @Test("buildArguments creates expected flags")
    func buildArguments() {
        let arguments = ServerManager.buildArguments(port: 11435)
        #expect(arguments == ["--serve", "--port", "11435", "--cors", "--permissive"])
    }

    @Test("isPortAvailable returns true for unused high port")
    func portAvailable() {
        #expect(ServerManager.isPortAvailable(59995))
    }

    @Test("findAvailablePort returns a candidate port")
    func findAvailablePort() {
        let port = ServerManager.findAvailablePort(preferredPort: 59994)
        #expect(port != nil)
    }
}
