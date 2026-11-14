import Foundation

enum PingStatus: Equatable {
    case idle
    case pinging
    case success(url: String, latencyMs: Int, detail: String)
    case failure(reason: String)
}

final class ServerPingService {
    static let shared = ServerPingService()
    private init() {}

    static func normalize(rawInput: String) -> String {
        var trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }

        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    func ping(rawInput: String) async -> PingStatus {
        let normalized = Self.normalize(rawInput: rawInput)
        guard let baseURL = URL(string: normalized), let host = baseURL.host, !host.isEmpty else {
            return .failure(reason: "Ungueltige Server-Adresse oder IP.")
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 5.0
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)

        let candidates = [
            baseURL.appendingPathComponent("api/health"),
            baseURL.appendingPathComponent("api/state"),
            baseURL
        ]

        let startTime = CFAbsoluteTimeGetCurrent()

        for candidateURL in candidates {
            var request = URLRequest(url: candidateURL)
            request.httpMethod = "GET"
            request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }

                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

                // 200..299, 401 (Auth required), 403 all prove the server is reachable and active
                if (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 401 {
                    var detail = "Server antwortet (\(httpResponse.statusCode))"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let status = json["status"] as? String {
                            detail = "Status: \(status)"
                        } else if let version = json["version"] as? String {
                            detail = "Version: \(version)"
                        }
                    }
                    return .success(url: normalized, latencyMs: max(elapsedMs, 1), detail: detail)
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorTimedOut:
                        return .failure(reason: "Zeitueberschreitung: Der Server hat nicht rechtzeitig geantwortet.")
                    case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                        return .failure(reason: "Verbindung verweigert: Bitte stelle sicher, dass der Server laeuft und der Port offen ist.")
                    case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                        return .failure(reason: "Host nicht gefunden: Bitte ueberpruefe die IP-Adresse oder den Hostnamen.")
                    case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                        return .failure(reason: "Sicherheitsrichtlinie (ATS): HTTPS erforderlich oder HTTP-Ausnahme aktivieren.")
                    default:
                        break
                    }
                }
            }
        }

        return .failure(reason: "Server konnte unter dieser Adresse nicht erreicht werden.")
    }
}
