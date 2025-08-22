enum AppError: Error {
    case invalidConfig(message: String)
    case authenticationFailed(message: String)
}
