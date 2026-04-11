enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable(newVersion: String)
    case installing(newVersion: String)
    case installed(newVersion: String)
    case error(message: String)
}
