import Foundation
import FlyingFox

struct ArtworkProxyHandler: HTTPHandler {
    private static let allowedHosts = [
        "mzstatic.com",
        "googleusercontent.com",
        "ggpht.com",
        "ytimg.com",
        "scdn.co",
        "spotifycdn.com",
        "i.scdn.co",
    ]

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let raw = request.query.first(where: { $0.name == "url" })?.value,
              let normalized = ArtworkURLNormalizer.normalize(raw),
              let url = URL(string: normalized),
              let host = url.host?.lowercased(),
              Self.allowedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            return HTTPResponse(statusCode: .badRequest, body: Data("invalid artwork url".utf8))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 8
        urlRequest.setValue("image/*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
                return HTTPResponse(statusCode: .badGateway)
            }

            var headers = HTTPHeaders()
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "image/jpeg"
            headers[.contentType] = contentType
            headers.addValue("public, max-age=86400", for: HTTPHeader("Cache-Control"))
            return HTTPResponse(statusCode: .ok, headers: headers, body: data)
        } catch {
            return HTTPResponse(statusCode: .badGateway, body: Data("artwork fetch failed".utf8))
        }
    }
}
