import Foundation

@MainActor
final class ServerManager {
    enum State: Equatable {
        case idle
        case starting
        case running(port: Int, launchedProcess: Bool)
        case failed(String)
    }

    private(set) var state: State = .idle
    private var serverProcess: Process?

    var failureMessage: String? {
        if case .failed(let message) = state {
            return message
        }
        return nil
    }

    nonisolated static func findBinary(named name: String) -> String? {
        if let resolved = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map({ "\($0)/\(name)" })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return resolved
        }

        if let executablePath = Bundle.main.executablePath {
            let macOSDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
            let bundledBinary = macOSDirectory.appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: bundledBinary) {
                return bundledBinary
            }
        }

        let fallbacks = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/\(name)",
        ]
        return fallbacks.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated static func findApfelBinary() -> String? {
        findBinary(named: "apfel")
    }

    nonisolated static func candidatePorts(startingAt preferredPort: Int = 11435) -> [Int] {
        var ports = [preferredPort]
        ports.append(contentsOf: Array(11440...11449))
        return ports
    }

    nonisolated static func isPortAvailable(_ port: Int) -> Bool {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return false }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        var option: Int32 = 1
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &option,
            socklen_t(MemoryLayout<Int32>.size)
        )

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(
                    socketDescriptor,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }

        return result == 0
    }

    nonisolated static func buildArguments(port: Int) -> [String] {
        ["--serve", "--port", "\(port)", "--cors", "--permissive"]
    }

    nonisolated static func findAvailablePort(preferredPort: Int = 11435) -> Int? {
        candidatePorts(startingAt: preferredPort).first(where: { isPortAvailable($0) })
    }

    func start(preferredPort: Int = 11435) async -> Int? {
        state = .starting

        if let runningPort = await tryExistingServer(preferredPort: preferredPort) {
            state = .running(port: runningPort, launchedProcess: false)
            return runningPort
        }

        guard let port = Self.findAvailablePort(preferredPort: preferredPort) else {
            state = .failed("No free local port was available for apfel.")
            return nil
        }

        if await isApfelHealthy(on: port) {
            state = .running(port: port, launchedProcess: false)
            return port
        }

        guard let apfelPath = Self.findApfelBinary() else {
            state = .failed("apfel not found. Install: brew install Arthur-Ficial/tap/apfel")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: apfelPath)
        process.arguments = Self.buildArguments(port: port)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            serverProcess = process
        } catch {
            state = .failed("Failed to launch apfel: \(error.localizedDescription)")
            return nil
        }

        if await waitForReady(port: port, timeout: 8) {
            state = .running(port: port, launchedProcess: true)
            return port
        }

        process.terminate()
        serverProcess = nil
        state = .failed("apfel did not become healthy within 8 seconds.")
        return nil
    }

    func stop() {
        if let process = serverProcess, process.isRunning {
            process.terminate()
        }
        serverProcess = nil
        state = .idle
    }

    private func waitForReady(port: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await isApfelHealthy(on: port) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }

    private func isApfelHealthy(on port: Int) async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func tryExistingServer(preferredPort: Int) async -> Int? {
        for port in Self.candidatePorts(startingAt: preferredPort) {
            if await isApfelHealthy(on: port) {
                return port
            }
        }
        return nil
    }
}
