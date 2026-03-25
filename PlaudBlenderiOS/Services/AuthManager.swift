import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.gunndamental.PlaudBlenderiOS", category: "Auth")

/// Manages authentication state and token storage via Keychain.
@Observable
final class AuthManager: Sendable {
    private static let apiKeyKey = "chronos_api_key"
    private static let serverURLKey = "chronos_server_url"
    private static let localLoopbackURL = "http://127.0.0.1:8000"
    private static let serverURLInfoPlistKey = "ChronosServerURL"

    /// Detect the Mac's LAN IP for simulator use.
    /// localhost/127.0.0.1 doesn't reliably work from the iOS simulator.
    /// Falls back to localhost if no Wi-Fi/Ethernet IP is found.
    static var defaultServerURL: String {
        if let configuredServerURL = Self.configuredServerURL {
            return configuredServerURL
        }

        #if targetEnvironment(simulator)
        if let lanIP = Self.detectLanIP() {
            return "http://\(lanIP):8000"
        }
        #endif
        return Self.localLoopbackURL
    }

    var isAuthenticated: Bool {
        getToken() != nil
    }

    var serverURL: String {
        if let storedURL = Self.preferredServerURL(from: KeychainService.load(key: Self.serverURLKey)) {
            return storedURL
        }
        return Self.defaultServerURL
    }

    func getToken() -> String? {
        KeychainService.load(key: Self.apiKeyKey)
    }

    func setToken(_ token: String) throws {
        try KeychainService.save(key: Self.apiKeyKey, value: token)
    }

    func setServerURL(_ url: String) throws {
        let normalized = Self.preferredServerURL(from: url) ?? Self.defaultServerURL
        try KeychainService.save(key: Self.serverURLKey, value: normalized)
    }

    func candidateServerURLs() -> [String] {
        var candidates: [String] = []

        if let storedURL = Self.preferredServerURL(from: KeychainService.load(key: Self.serverURLKey)) {
            candidates.append(storedURL)
        }

        if let configuredServerURL = Self.configuredServerURL {
            candidates.append(configuredServerURL)
        }

        #if targetEnvironment(simulator)
        if let lanIP = Self.detectLanIP() {
            candidates.append("http://\(lanIP):8000")
        }
        #endif

        #if targetEnvironment(simulator)
        candidates.append(Self.localLoopbackURL)
        candidates.append("http://localhost:8000")
        #endif

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    func clearServerURL() {
        KeychainService.delete(key: Self.serverURLKey)
    }

    func logout() {
        KeychainService.delete(key: Self.apiKeyKey)
    }

    // MARK: - LAN IP Detection

    private static var configuredServerURL: String? {
        normalizedServerURL(Bundle.main.object(forInfoDictionaryKey: serverURLInfoPlistKey) as? String)
    }

    private static func preferredServerURL(from value: String?) -> String? {
        guard let normalized = normalizedServerURL(value) else {
            return nil
        }

        #if targetEnvironment(simulator)
        return normalized
        #else
        return isLoopbackURL(normalized) ? configuredServerURL : normalized
        #endif
    }

    private static func normalizedServerURL(_ value: String?) -> String? {
        guard var rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        if !rawValue.contains("://") {
            rawValue = "http://\(rawValue)"
        }

        guard let components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        var normalized = "\(scheme)://\(host)"
        if let port = components.port {
            normalized += ":\(port)"
        }
        return normalized
    }

    private static func isLoopbackURL(_ value: String) -> Bool {
        guard let host = URLComponents(string: value)?.host?.lowercased() else {
            return false
        }

        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    /// Returns the first non-loopback IPv4 address (en0/en1), or nil.
    private static func detectLanIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard let address = iface.ifa_addr else { continue }
            let family = iface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue } // IPv4 only

            let flags = Int32(iface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard isUp && !isLoopback else { continue }

            let name = String(cString: iface.ifa_name)
            let excludedPrefixes = ["lo", "utun", "awdl", "llw", "bridge"]
            guard !excludedPrefixes.contains(where: name.hasPrefix) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address, socklen_t(address.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            )
            if result == 0 {
                let ip = String(cString: hostname)
                logger.info("🌐 Detected LAN IP: \(ip, privacy: .public) on \(name, privacy: .public)")
                return ip
            }
        }
        logger.warning("⚠️ Could not detect LAN IP, falling back to localhost")
        return nil
    }
}
